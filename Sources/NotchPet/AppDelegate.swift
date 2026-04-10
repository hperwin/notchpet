import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindow: PetWindow!
    private var petInteraction: PetInteraction!
    private var walkController: WalkController!
    private var panelWindow: PanelWindow!
    private var keyboardMonitor: KeyboardMonitor!
    private var gameSystems: GameSystems!
    private var petState: PetState!
    private var foodSpawner: FoodSpawner!
    private var partyStrip: PartyStrip!
    private var tickTimer: Timer?
    private var panelRefreshNeeded: Bool = false
    private var panelRefreshTimer: Timer?
    private var onboardingWindow: OnboardingWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check accessibility before doing anything else
        if !accessibilityIsWorking() {
            showOnboarding()
            return
        }

        finishLaunching()
    }

    private func accessibilityIsWorking() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        // AXIsProcessTrusted can lie after binary replacement — verify with a real tap
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        ) else {
            return false
        }
        CGEvent.tapEnable(tap: tap, enable: false)
        return true
    }

    private func showOnboarding() {
        let window = OnboardingWindow()
        window.onAccessibilityGranted = { [weak self] in
            self?.onboardingWindow = nil
            self?.finishLaunching()
        }
        window.makeKeyAndOrderFront(nil)
        window.startPolling()
        onboardingWindow = window

        // Also trigger the system prompt
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func finishLaunching() {
        // Load persistent state
        petState = PetState.load()

        // Game systems
        gameSystems = GameSystems(state: petState)
        gameSystems.onEvent = { [weak self] event in
            self?.handleGameEvent(event)
        }
        gameSystems.startPolling()
        // processAppLaunch moved to after all UI is set up (below)

        // Pet window
        petWindow = PetWindow()

        // Set up running bounds
        let petView = petWindow.petView
        let windowWidth = petWindow.frame.width
        petView.minRunX = 0
        petView.maxRunX = windowWidth - PetWindow.petSize
        petView.homeX = PetWindow.notchLeftOffset - PetWindow.petSize - 4
        petView.setPetLocalX(petView.homeX)

        // Show lead party member sprite + start occasional bouncing
        loadLeadPokemon()
        petView.startRandomBouncing()

        // Panel window
        panelWindow = PanelWindow(contentRect: .zero)
        panelWindow.onPartyChanged = { [weak self] newParty in
            guard let self = self else { return }
            self.petState.party = newParty
            self.petState.save()
            self.updatePartyStrip()
            self.loadLeadPokemon()
        }
        panelWindow.refreshData(petState)

        // Interaction handler
        petInteraction = PetInteraction(
            window: petWindow,
            petView: petWindow.petView,
            resetPosition: { [weak self] in
                self?.resetPosition()
            },
            quit: {
                NSApplication.shared.terminate(nil)
            }
        )
        petInteraction.onClickAction = { [weak self] in
            self?.togglePanel()
        }
        petWindow.petView.interaction = petInteraction

        // Walk controller (disabled)
        walkController = WalkController()

        // Party strip — shows party Pokemon to the right of the notch
        partyStrip = PartyStrip()
        partyStrip.onPokemonTapped = { [weak self] id in
            guard let self = self else { return }
            if !self.panelWindow.isOpen {
                self.panelWindow.refreshData(self.petState)
                self.panelWindow.toggle(from: self.petWindow.frame)
            }
            self.panelWindow.showDetailForPokemon(id)
        }
        updatePartyStrip()
        partyStrip.show()

        // Food spawner — berries appear to the right of the notch
        foodSpawner = FoodSpawner(petWindowFrame: { [weak self] in
            // Return the frame of just the pet sprite in screen coordinates
            guard let self = self else { return .zero }
            let petView = self.petWindow.petView
            let localPetFrame = petView.imageView.frame
            let windowOrigin = self.petWindow.frame.origin
            return NSRect(
                x: windowOrigin.x + localPetFrame.origin.x,
                y: windowOrigin.y + localPetFrame.origin.y,
                width: localPetFrame.width,
                height: localPetFrame.height
            )
        })
        foodSpawner.onFoodEaten = { [weak self] berryName in
            self?.handleFoodEaten(berryName)
        }
        foodSpawner.partyFramesProvider = { [weak self] in
            self?.partyStrip.allPokemonFrames() ?? []
        }
        foodSpawner.onPartyPokemonFed = { [weak self] pokemonId, berryName in
            self?.handlePartyPokemonFed(pokemonId: pokemonId, berryName: berryName)
        }
        foodSpawner.onDragOverParty = { [weak self] foodFrame in
            self?.partyStrip.highlightPokemon(at: .zero, foodFrame: foodFrame)
        }
        foodSpawner.onDragEnd = { [weak self] in
            self?.partyStrip.clearHighlights()
        }
        foodSpawner.onPartyPokemonBounce = { [weak self] pokemonId in
            self?.partyStrip.playFeedBounce(for: pokemonId)
        }
        foodSpawner.start()

        // Keyboard monitor
        keyboardMonitor = KeyboardMonitor()
        keyboardMonitor.onKeypress = { [weak self] in
            self?.gameSystems.recordKeypress()
            self?.panelRefreshNeeded = true
        }
        keyboardMonitor.onWordBoundary = { [weak self] in
            self?.gameSystems.recordWord()
        }
        keyboardMonitor.onWPMUpdate = { [weak self] wpm in
            self?.petState.currentWPM = wpm
            // Don't refresh panel on every WPM update — causes scroll glitch
        }
        keyboardMonitor.onTypingStateChanged = { [weak self] state in
            self?.handleTypingStateChange(state)
        }
        keyboardMonitor.start()

        // Tick timer
        tickTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.gameSystems.tick()
        }

        // Throttled panel refresh — updates XP display every 2s while typing
        panelRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self = self, self.panelRefreshNeeded else { return }
            self.panelRefreshNeeded = false
            if self.panelWindow.isOpen { self.panelWindow.refreshData(self.petState) }
        }

        // Now that all UI is ready, process app launch (may fire events)
        gameSystems.processAppLaunch()

        // Auto-launch on first run
        if !Preferences.shared.hasLaunchedBefore {
            Preferences.shared.hasLaunchedBefore = true
            Preferences.shared.isAutoLaunchEnabled = true
        }

        // Don't show the pet window — party strip IS the party, no separate lead pet
        // petWindow.orderFront(nil)
    }

    // MARK: - Lead Pokemon

    private func loadLeadPokemon() {
        petWindow.petView.setPokemonSprite(petState.party.first ?? "leafeon")
    }

    // MARK: - Food

    private func handleFoodEaten(_ berryName: String) {
        guard let leadId = petState.party.first,
              var instance = petState.pokemonInstances[leadId] else { return }
        instance.foodEaten += 1
        let baseXP = Int.random(in: 15...30)
        let leveledUp = instance.addXP(baseXP)
        petState.pokemonInstances[leadId] = instance
        petState.save()
        petWindow.petView.playEatAnimation()
        if leveledUp {
            let name = PetCollection.entry(for: leadId)?.displayName ?? leadId
            partyStrip.showLevelUp(pokemonName: name, newLevel: instance.level)
        }
        if panelWindow.isOpen { panelWindow.refreshData(petState) }
    }

    // MARK: - Party Pokemon Feeding

    private func handlePartyPokemonFed(pokemonId: String, berryName: String) {
        guard var instance = petState.pokemonInstances[pokemonId] else { return }
        instance.foodEaten += 1
        let baseXP = Int.random(in: 15...30)
        let leveledUp = instance.addXP(baseXP)
        petState.pokemonInstances[pokemonId] = instance
        petState.save()
        if leveledUp {
            let name = PetCollection.entry(for: pokemonId)?.displayName ?? pokemonId
            partyStrip.showLevelUp(pokemonName: name, newLevel: instance.level)
        }
        if panelWindow.isOpen { panelWindow.refreshData(petState) }
    }

    // MARK: - Panel

    private func togglePanel() {
        if !panelWindow.isOpen {
            panelWindow.refreshData(petState)
        }
        panelWindow.toggle(from: petWindow.frame)
    }

    // MARK: - Game Events

    private func handleGameEvent(_ event: GameSystems.GameEvent) {
        switch event {
        case .levelUp(let level):
            updatePartyStrip()
            NSLog("NotchPet: Level up! Now level \(level)")
            // Find which Pokemon hit this level
            for id in petState.party {
                if let inst = petState.pokemonInstances[id], inst.level == level {
                    let name = PetCollection.entry(for: id)?.displayName ?? id
                    partyStrip.showLevelUp(pokemonName: name, newLevel: level)
                    break
                }
            }

        case .achievementUnlocked(let achievement):
            NSLog("NotchPet: Achievement unlocked: \(achievement.name)")
            animatePetCelebration()

        case .cosmeticRolled(let cosmetic):
            NSLog("NotchPet: Got cosmetic: \(cosmetic.name) (\(cosmetic.rarity.name))")

        case .challengeComplete(let challenge):
            NSLog("NotchPet: Challenge complete: \(challenge.description)")
            animatePetCelebration()

        case .streakUpdate(let streak):
            NSLog("NotchPet: Typing streak: \(streak) days")

        case .comboChanged(let stage):
            partyStrip.updateCombo(stage)
            petState.currentComboLabel = stage.label ?? "x1"
            if panelWindow.isOpen { panelWindow.refreshData(petState) }

        case .appTierChanged(let tier):
            NSLog("NotchPet: App tier changed to \(tier.name)")
            petState.currentAppTierName = tier.name
            if panelWindow.isOpen { panelWindow.refreshData(petState) }

        default:
            break
        }

        // Flush throttled panel refresh if typing triggered it
        if panelRefreshNeeded {
            panelRefreshNeeded = false
            if panelWindow.isOpen { panelWindow.refreshData(petState) }
        }
    }

    // MARK: - Typing State

    private func handleTypingStateChange(_ state: TypingState) {
        let petView = petWindow.petView
        switch state {
        case .idle:
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 1.0
            pulse.toValue = 0.5
            pulse.duration = 1.0
            pulse.autoreverses = true
            pulse.repeatCount = 3
            petView.imageView.layer?.add(pulse, forKey: "focusAlert")

        case .typing:
            petView.imageView.layer?.removeAnimation(forKey: "focusAlert")

        case .fast:
            let dance = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            let angle = CGFloat.pi / 30
            dance.values = [0, angle, 0, -angle, 0]
            dance.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
            dance.duration = 0.5
            dance.repeatCount = .infinity
            petView.imageView.layer?.add(dance, forKey: "typingDance")

        case .burst:
            let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
            bounce.values = [1.0, 1.15, 1.0, 1.1, 1.0]
            bounce.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
            bounce.duration = 0.4
            bounce.repeatCount = .infinity
            petView.imageView.layer?.add(bounce, forKey: "burstBounce")

            let spin = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            let angle = CGFloat.pi / 20
            spin.values = [0, angle, 0, -angle, 0]
            spin.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
            spin.duration = 0.3
            spin.repeatCount = .infinity
            petView.imageView.layer?.add(spin, forKey: "typingDance")
        }
    }

    // MARK: - Pet Visuals

    private func updatePetVisuals() {
        loadLeadPokemon()
    }

    private func animatePetCelebration() {
        // No longer using the pet window — celebration is visual in the party strip
        // Could add a party-wide bounce here in the future
    }

    // MARK: - Party Strip

    private func updatePartyStrip() {
        // Show ALL party members in the strip — no separate "lead" pet
        partyStrip.updateParty(petState.party, level: petState.highestLevel)
    }

    // MARK: - Helpers

    private func resetPosition() {
        petWindow.petView.setPetLocalX(petWindow.petView.homeX)
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stop()
        walkController.stop()
        foodSpawner.stop()
        tickTimer?.invalidate()
        panelRefreshTimer?.invalidate()
        gameSystems.stopPolling()
        petState.save()
    }
}

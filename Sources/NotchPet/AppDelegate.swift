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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load persistent state
        petState = PetState.load()

        // Game systems
        gameSystems = GameSystems(state: petState)
        gameSystems.onEvent = { [weak self] event in
            self?.handleGameEvent(event)
        }
        gameSystems.processAppLaunch()

        // Pet window
        petWindow = PetWindow()

        // Set up running bounds
        let petView = petWindow.petView
        let windowWidth = petWindow.frame.width
        petView.minRunX = 0
        petView.maxRunX = windowWidth - PetWindow.petSize
        petView.homeX = PetWindow.notchLeftOffset - PetWindow.petSize - 4
        petView.setPetLocalX(petView.homeX)

        // Show selected Pokemon sprite + start occasional bouncing
        loadSelectedPet()
        petView.startRandomBouncing()

        // Panel window
        panelWindow = PanelWindow(contentRect: .zero)
        panelWindow.onPrestige = { [weak self] in
            self?.handlePrestige()
        }
        panelWindow.onPetSelected = { [weak self] petId, shiny in
            self?.selectPet(petId, shiny: shiny)
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
            self?.selectPet(id, shiny: false)
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
        foodSpawner.start()

        // Keyboard monitor
        keyboardMonitor = KeyboardMonitor()
        keyboardMonitor.onKeypress = { [weak self] in
            self?.gameSystems.recordKeypress()
        }
        keyboardMonitor.onWordBoundary = { [weak self] in
            self?.gameSystems.recordWord()
        }
        keyboardMonitor.onWPMUpdate = { [weak self] wpm in
            self?.petState.currentWPM = wpm
            if self?.panelWindow.isOpen == true {
                self?.panelWindow.refreshData(self!.petState)
            }
        }
        keyboardMonitor.onTypingStateChanged = { [weak self] state in
            self?.handleTypingStateChange(state)
        }
        keyboardMonitor.start()

        // Tick timer
        tickTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.gameSystems.tick()
        }

        // Auto-launch on first run
        if !Preferences.shared.hasLaunchedBefore {
            Preferences.shared.hasLaunchedBefore = true
            Preferences.shared.isAutoLaunchEnabled = true
        }

        // Dev: unlock requested Pokemon
        if petState.level < 40 {
            petState.level = 40
        }
        if !petState.unlockedShinies.contains("charizard") {
            petState.unlockedShinies.append("charizard")
        }
        petState.party = ["leafeon", "rayquaza", "charizard", "umbreon", "dragonite", "pikachu"]
        petState.save()
        updatePartyStrip()

        petWindow.orderFront(nil)
    }

    // MARK: - Pet Selection

    private func loadSelectedPet() {
        petWindow.petView.setPokemonSprite(petState.selectedPet, shiny: petState.useShiny)
    }

    private func selectPet(_ id: String, shiny: Bool) {
        petState.selectedPet = id
        petState.useShiny = shiny
        petState.save()
        petWindow.petView.setPokemonSprite(id, shiny: shiny)
        updatePetVisuals()
    }

    // MARK: - Food

    private func handleFoodEaten(_ berryName: String) {
        petState.foodEaten += 1

        // Give XP for feeding (15-30 XP per berry)
        let baseXP = Int.random(in: 15...30)
        let totalXP = Int(Double(baseXP) * petState.totalMultiplier)
        petState.xp += totalXP
        petState.totalXPEarned += totalXP
        petState.save()

        // Play eat animation
        petWindow.petView.playEatAnimation()

        // Check for level up etc
        gameSystems.checkAfterXPGain()

        // 3% chance to unlock a shiny on feeding
        if petState.unlockedShinies.count < PetCollection.allPokemon.count {
            if Double.random(in: 0...1) < 0.03 {
                let candidates = PetCollection.unlockedPets(for: petState.level)
                    .filter { !petState.unlockedShinies.contains($0.id) && $0.hasShiny }
                if let pick = candidates.randomElement() {
                    petState.unlockedShinies.append(pick.id)
                    petState.save()
                    NSLog("NotchPet: Shiny unlocked: \(pick.displayName)!")
                    animatePetCelebration()
                }
            }
        }

        // Refresh panel if open
        if panelWindow.isOpen {
            panelWindow.refreshData(petState)
        }
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
            animatePetCelebration()
            updatePetVisuals()
            updatePartyStrip()
            NSLog("NotchPet: Level up! Now level \(level)")

        case .evolved(let stage):
            updatePetVisuals()
            animatePetCelebration()
            NSLog("NotchPet: Evolved to \(stage.name)!")

        case .achievementUnlocked(let achievement):
            NSLog("NotchPet: Achievement unlocked: \(achievement.name)")
            animatePetCelebration()

        case .prestigeComplete(let count):
            updatePetVisuals()
            NSLog("NotchPet: Prestige #\(count)!")

        case .cosmeticRolled(let cosmetic):
            NSLog("NotchPet: Got cosmetic: \(cosmetic.name) (\(cosmetic.rarity.name))")

        case .mutationOccurred(let color):
            NSLog("NotchPet: Mutation! Color: \(color)")
            updatePetVisuals()

        case .challengeComplete(let challenge):
            NSLog("NotchPet: Challenge complete: \(challenge.description)")
            animatePetCelebration()

        case .streakUpdate(let streak):
            NSLog("NotchPet: Typing streak: \(streak) days")
        }

        if panelWindow.isOpen {
            panelWindow.refreshData(petState)
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
        let stage = petState.evolutionStage
        let petView = petWindow.petView

        // Don't scale Pokemon sprites — they're already proper size
        // Only apply glow at higher evolution stages
        if let glow = stage.glowColor {
            petView.imageView.layer?.shadowColor = CGColor(
                red: glow.r, green: glow.g, blue: glow.b, alpha: 1.0
            )
            petView.imageView.layer?.shadowRadius = 6
            petView.imageView.layer?.shadowOpacity = 0.8
            petView.imageView.layer?.shadowOffset = .zero
        } else {
            petView.imageView.layer?.shadowOpacity = 0
        }

        if let hexColor = petState.mutationColor {
            let tint = colorFromHex(hexColor)
            petView.imageView.contentTintColor = tint
        }
    }

    private func animatePetCelebration() {
        let petView = petWindow.petView
        let celebrate = CAKeyframeAnimation(keyPath: "transform.scale")
        celebrate.values = [1.0, 1.3, 0.9, 1.1, 1.0]
        celebrate.keyTimes = [0, 0.2, 0.5, 0.8, 1.0]
        celebrate.duration = 0.5
        petView.imageView.layer?.add(celebrate, forKey: "celebrate")
    }

    // MARK: - Prestige

    private func handlePrestige() {
        let success = gameSystems.prestige()
        if success {
            updatePetVisuals()
            panelWindow.refreshData(petState)
        }
    }

    // MARK: - Party Strip

    private func updatePartyStrip() {
        // Use saved party, or auto-fill if empty
        if petState.party.isEmpty {
            let unlocked = PetCollection.unlockedPets(for: petState.level).prefix(6).map(\.id)
            petState.party = Array(unlocked)
        }
        partyStrip.updateParty(petState.party, level: petState.level)
    }

    // MARK: - Helpers

    private func resetPosition() {
        petWindow.petView.setPetLocalX(petWindow.petView.homeX)
    }

    private func colorFromHex(_ hex: String) -> NSColor {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexStr.hasPrefix("#") { hexStr.removeFirst() }
        guard hexStr.count == 6, let value = UInt64(hexStr, radix: 16) else {
            return .white
        }
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stop()
        walkController.stop()
        foodSpawner.stop()
        tickTimer?.invalidate()
        petState.save()
    }
}

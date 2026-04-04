import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindow: PetWindow!
    private var petInteraction: PetInteraction!
    private var walkController: WalkController!
    private var panelWindow: PanelWindow!
    private var keyboardMonitor: KeyboardMonitor!
    private var gameSystems: GameSystems!
    private var petState: PetState!
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

        // Restore saved position
        if let savedX = Preferences.shared.savedWindowX {
            petWindow.setXPosition(savedX)
        }

        // Apply saved animation speed
        petWindow.petView.setAnimationSpeed(Preferences.shared.animationSpeed)

        // Apply evolution stage visual
        updatePetVisuals()

        // Panel window
        panelWindow = PanelWindow(contentRect: .zero)
        panelWindow.onPrestige = { [weak self] in
            self?.handlePrestige()
        }
        panelWindow.refreshData(petState)

        // Interaction handler — click opens panel instead of squish
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
        // Override click to toggle panel
        petInteraction.onClickAction = { [weak self] in
            self?.togglePanel()
        }
        petWindow.petView.interaction = petInteraction

        // Walk controller
        walkController = WalkController(window: petWindow, interaction: petInteraction)

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

        // Tick timer — every 60 seconds for session tracking + rest XP
        tickTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.gameSystems.tick()
        }

        // Auto-launch on first run
        if !Preferences.shared.hasLaunchedBefore {
            Preferences.shared.hasLaunchedBefore = true
            Preferences.shared.isAutoLaunchEnabled = true
        }

        petWindow.orderFront(nil)
    }

    // MARK: - Panel

    private func togglePanel() {
        // Refresh data before showing
        if !panelWindow.isOpen {
            panelWindow.refreshData(petState)
        }
        panelWindow.toggle(from: petWindow.frame)
    }

    // MARK: - Game Events

    private func handleGameEvent(_ event: GameSystems.GameEvent) {
        switch event {
        case .levelUp(let level):
            // Flash the pet
            animatePetCelebration()
            updatePetVisuals()
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

        // Refresh panel if open
        if panelWindow.isOpen {
            panelWindow.refreshData(petState)
        }
    }

    // MARK: - Typing State

    private func handleTypingStateChange(_ state: TypingState) {
        let petView = petWindow.petView
        switch state {
        case .idle:
            // Gentle pulse to remind user — focus alert
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
            // Pet dances — more energetic wiggle
            let dance = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            let angle = CGFloat.pi / 30 // ~6 degrees
            dance.values = [0, angle, 0, -angle, 0]
            dance.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
            dance.duration = 0.5
            dance.repeatCount = .infinity
            petView.imageView.layer?.add(dance, forKey: "typingDance")

        case .burst:
            // Pet goes wild — rapid bouncing + rotation
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

        // Update sprite scale based on evolution
        let scale = stage.spriteScale
        petView.imageView.layer?.transform = CATransform3DMakeScale(scale, scale, 1)

        // Glow effect
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

        // Mutation tint
        if let hexColor = petState.mutationColor {
            let tint = colorFromHex(hexColor)
            petView.imageView.contentTintColor = tint
        }
    }

    private func animatePetCelebration() {
        let petView = petWindow.petView

        // Quick scale-up bounce
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

    // MARK: - Helpers

    private func resetPosition() {
        let frame = PetWindow.calculateDefaultFrame()
        petWindow.setXPosition(frame.origin.x)
        Preferences.shared.savedWindowX = nil
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
        tickTimer?.invalidate()
        petState.save()
    }
}

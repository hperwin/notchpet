import AppKit

final class WalkController {
    private weak var window: PetWindow?
    private weak var interaction: PetInteraction?
    private var walkTimer: Timer?

    init(window: PetWindow, interaction: PetInteraction) {
        self.window = window
        self.interaction = interaction
        scheduleNextWalk()
    }

    private func scheduleNextWalk() {
        let interval = Double.random(in: 120...300) // 2-5 minutes
        walkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.attemptWalk()
        }
    }

    private func attemptWalk() {
        guard let window = window else {
            scheduleNextWalk()
            return
        }

        let petView = window.petView

        // Skip if already running or user dragged recently
        if petView.isRunning {
            scheduleNextWalk()
            return
        }
        if let interaction = interaction,
           Date().timeIntervalSince(interaction.lastDragTime) < 60 {
            scheduleNextWalk()
            return
        }

        // Pick a random target within run bounds
        let currentX = petView.petLocalX
        let distance = CGFloat.random(in: 40...80)
        let direction: CGFloat = Bool.random() ? 1 : -1
        var targetX = currentX + distance * direction

        // Clamp to bounds
        targetX = max(petView.minRunX, min(targetX, petView.maxRunX))

        // If target is same as current (at edge), go the other way
        if abs(targetX - currentX) < 10 {
            targetX = currentX - distance * direction
            targetX = max(petView.minRunX, min(targetX, petView.maxRunX))
        }

        petView.startRunning(to: targetX)

        // After a bit, run back home
        let runDuration = Double(abs(targetX - currentX)) / 1.5 / 60.0 + 2.0
        Timer.scheduledTimer(withTimeInterval: runDuration, repeats: false) { [weak self] _ in
            petView.returnHome()
            self?.scheduleNextWalk()
        }
    }

    func stop() {
        walkTimer?.invalidate()
        walkTimer = nil
    }
}

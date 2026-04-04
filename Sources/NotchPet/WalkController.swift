import AppKit

final class WalkController {
    private weak var window: PetWindow?
    private weak var interaction: PetInteraction?
    private var walkTimer: Timer?
    private var isWalking = false

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
        guard !isWalking else {
            scheduleNextWalk()
            return
        }

        // Skip if user dragged within last 60 seconds
        if let interaction = interaction {
            let timeSinceDrag = Date().timeIntervalSince(interaction.lastDragTime)
            if timeSinceDrag < 60 {
                scheduleNextWalk()
                return
            }
        }

        performWalk()
    }

    private func performWalk() {
        guard window != nil else {
            scheduleNextWalk()
            return
        }

        isWalking = true
        let distance = CGFloat.random(in: 30...50) * (Bool.random() ? 1 : -1)
        let steps = 20
        let stepDistance = distance / CGFloat(steps)
        let stepDuration: TimeInterval = 0.1 // 20 steps over ~2 seconds
        var currentStep = 0

        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self, let window = self.window else {
                timer.invalidate()
                return
            }

            currentStep += 1

            // Move
            let screen = NSScreen.main ?? NSScreen.screens[0]
            let newX = window.frame.origin.x + stepDistance
            let clampedX = max(screen.frame.minX, min(newX, screen.frame.maxX - window.frame.width))
            window.setXPosition(clampedX)

            // Waddle: alternate tilt
            let tiltAngle: CGFloat = (currentStep % 2 == 0) ? 0.05 : -0.05
            window.contentView?.layer?.setAffineTransform(CGAffineTransform(rotationAngle: tiltAngle))

            if currentStep >= steps {
                timer.invalidate()
                // Reset tilt
                window.contentView?.layer?.setAffineTransform(.identity)
                // Save position
                Preferences.shared.savedWindowX = window.frame.origin.x
                self.isWalking = false
                self.scheduleNextWalk()
            }
        }
    }

    func stop() {
        walkTimer?.invalidate()
        walkTimer = nil
    }
}

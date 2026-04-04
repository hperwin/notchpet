import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindow: PetWindow!
    private var petInteraction: PetInteraction!
    private var walkController: WalkController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        petWindow = PetWindow()

        // Restore saved position or use default
        if let savedX = Preferences.shared.savedWindowX {
            petWindow.setXPosition(savedX)
        }

        // Apply saved animation speed
        petWindow.petView.setAnimationSpeed(Preferences.shared.animationSpeed)

        // Create interaction handler
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
        petWindow.petView.interaction = petInteraction

        // Create walk controller
        walkController = WalkController(window: petWindow, interaction: petInteraction)

        // Enable auto-launch on first run
        if !Preferences.shared.hasLaunchedBefore {
            Preferences.shared.hasLaunchedBefore = true
            Preferences.shared.isAutoLaunchEnabled = true
        }

        petWindow.orderFront(nil)
    }

    private func resetPosition() {
        let frame = PetWindow.calculateDefaultFrame()
        petWindow.setXPosition(frame.origin.x)
        Preferences.shared.savedWindowX = nil
    }

    func applicationWillTerminate(_ notification: Notification) {
        walkController.stop()
    }
}

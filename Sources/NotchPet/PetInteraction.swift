import AppKit

final class PetInteraction {
    private weak var window: PetWindow?
    private weak var petView: PetView?
    private var isDragging = false
    private var dragStartX: CGFloat = 0
    private var windowStartX: CGFloat = 0
    var lastDragTime: Date = .distantPast
    /// Override default click behavior (squish) — e.g. to open the panel
    var onClickAction: (() -> Void)?

    private var resetPositionAction: (() -> Void)?
    private var quitAction: (() -> Void)?

    init(window: PetWindow, petView: PetView, resetPosition: @escaping () -> Void, quit: @escaping () -> Void) {
        self.window = window
        self.petView = petView
        self.resetPositionAction = resetPosition
        self.quitAction = quit
    }

    func handleMouseDown(with event: NSEvent) {
        isDragging = false
        dragStartX = NSEvent.mouseLocation.x
        windowStartX = window?.frame.origin.x ?? 0
    }

    func handleMouseDragged(with event: NSEvent) {
        isDragging = true
        guard let window = window else { return }

        let currentX = NSEvent.mouseLocation.x
        let deltaX = currentX - dragStartX
        let newX = windowStartX + deltaX

        // Clamp to screen bounds
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let clampedX = max(screen.frame.minX, min(newX, screen.frame.maxX - window.frame.width))

        window.setXPosition(clampedX)
        lastDragTime = Date()
    }

    func handleMouseUp(with event: NSEvent) {
        if isDragging {
            // Save position after drag
            if let window = window {
                Preferences.shared.savedWindowX = window.frame.origin.x
            }
            lastDragTime = Date()
        } else {
            // Click — squish + custom action (open panel)
            petView?.squish()
            onClickAction?()
        }
        isDragging = false
    }

    func handleRightMouseDown(with event: NSEvent) {
        guard let petView = petView else { return }
        let menu = buildContextMenu()
        NSMenu.popUpContextMenu(menu, with: event, for: petView)
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu(title: "NotchPet")

        // Animation Speed submenu
        let speedMenu = NSMenu(title: "Animation Speed")
        let currentSpeed = Preferences.shared.animationSpeed
        for speed in [AnimationSpeed.slow, .normal, .fast] {
            let item = NSMenuItem(title: speed.label, action: #selector(speedSelected(_:)), keyEquivalent: "")
            item.target = self
            item.tag = speed.rawValue
            item.state = speed == currentSpeed ? .on : .off
            speedMenu.addItem(item)
        }
        let speedItem = NSMenuItem(title: "Animation Speed", action: nil, keyEquivalent: "")
        speedItem.submenu = speedMenu
        menu.addItem(speedItem)

        // Launch at Login
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleAutoLaunch(_:)), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = Preferences.shared.isAutoLaunchEnabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())

        // Reset Position
        let resetItem = NSMenuItem(title: "Reset Position", action: #selector(resetPosition(_:)), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: "Hide Pets",
            action: #selector(hidePets(_:)),
            keyEquivalent: "h"
        )
        hideItem.target = self
        menu.addItem(hideItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit NotchPet", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func speedSelected(_ sender: NSMenuItem) {
        guard let speed = AnimationSpeed(rawValue: sender.tag) else { return }
        Preferences.shared.animationSpeed = speed
        petView?.setAnimationSpeed(speed)
    }

    @objc private func toggleAutoLaunch(_ sender: NSMenuItem) {
        let newValue = !Preferences.shared.isAutoLaunchEnabled
        Preferences.shared.isAutoLaunchEnabled = newValue
    }

    @objc private func resetPosition(_ sender: NSMenuItem) {
        resetPositionAction?()
    }

    @objc private func hidePets(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: .init("notchpet.hideApp"), object: nil)
    }

    @objc private func quitApp(_ sender: NSMenuItem) {
        quitAction?()
    }
}

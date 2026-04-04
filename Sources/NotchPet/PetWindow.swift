import AppKit

final class PetWindow: NSWindow {
    static let petSize: CGFloat = 28
    static let windowWidth: CGFloat = 40
    static let windowHeight: CGFloat = 37

    let petView: PetView

    init() {
        let frame = PetWindow.calculateDefaultFrame()
        petView = PetView(frame: NSRect(x: 0, y: 0, width: frame.width, height: frame.height))

        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = .statusBar
        backgroundColor = .black
        isOpaque = true
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isMovableByWindowBackground = false
        contentView = petView
    }

    static func calculateDefaultFrame() -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let menuBarHeight = windowHeight

        // Use auxiliaryTopLeftArea to find the notch position
        if let auxArea = screen.auxiliaryTopLeftArea {
            // auxArea is the region to the left of the notch
            // Place window so its right edge is flush with the right edge of auxArea (left of notch)
            let x = auxArea.origin.x + auxArea.width - windowWidth
            let y = screen.frame.maxY - menuBarHeight
            return NSRect(x: x, y: y, width: windowWidth, height: menuBarHeight)
        }

        // Fallback: center of menu bar area
        let x = screen.frame.midX - windowWidth / 2
        let y = screen.frame.maxY - menuBarHeight
        return NSRect(x: x, y: y, width: windowWidth, height: menuBarHeight)
    }

    func setXPosition(_ x: CGFloat) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let y = screen.frame.maxY - PetWindow.windowHeight
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

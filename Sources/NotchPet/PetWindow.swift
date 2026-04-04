import AppKit

final class PetWindow: NSWindow {
    static let petSize: CGFloat = 28
    /// Notch corner radius — matches Apple's hardware notch rounding
    static let notchCornerRadius: CGFloat = 8.0
    /// How wide the black extension should be (pet + padding)
    static let extensionWidth: CGFloat = 50

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
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isMovableByWindowBackground = false
        contentView = petView
    }

    /// Position the window just to the LEFT of the notch.
    /// The window is a small black extension that looks like it's part of the notch.
    /// The right edge matches the notch's left edge, with rounded bottom-left corner.
    static func calculateDefaultFrame() -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens[0]

        if let auxLeft = screen.auxiliaryTopLeftArea,
           let _ = screen.auxiliaryTopRightArea {
            // auxLeft's right edge = notch's left edge
            let notchLeftEdge = auxLeft.origin.x + auxLeft.width
            let menuBarHeight = auxLeft.height
            let x = notchLeftEdge - extensionWidth
            let y = screen.frame.maxY - menuBarHeight
            return NSRect(x: x, y: y, width: extensionWidth, height: menuBarHeight)
        }

        // Fallback for non-notch Macs
        let notchWidth: CGFloat = 185
        let notchLeftEdge = (screen.frame.width - notchWidth) / 2
        let x = notchLeftEdge - extensionWidth
        let y = screen.frame.maxY - 32
        return NSRect(x: x, y: y, width: extensionWidth, height: 32)
    }

    func setXPosition(_ x: CGFloat) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let auxHeight = screen.auxiliaryTopLeftArea?.height ?? 32
        let y = screen.frame.maxY - auxHeight
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

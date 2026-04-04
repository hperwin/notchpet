import AppKit

final class PetWindow: NSWindow {
    static let petSize: CGFloat = 32
    static let notchCornerRadius: CGFloat = 8.0
    /// Extra width beyond the notch on each side for the pet to run around
    static let runPadding: CGFloat = 60

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

    /// Window spans from (notchLeft - runPadding) to (notchRight + runPadding)
    /// giving the pet room to run left and right around the notch area.
    static func calculateDefaultFrame() -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens[0]

        if let auxLeft = screen.auxiliaryTopLeftArea,
           let auxRight = screen.auxiliaryTopRightArea {
            let notchLeft = auxLeft.origin.x + auxLeft.width
            let notchRight = auxRight.origin.x
            let menuBarHeight = auxLeft.height
            let x = notchLeft - runPadding
            let width = (notchRight - notchLeft) + runPadding * 2
            let y = screen.frame.maxY - menuBarHeight
            return NSRect(x: x, y: y, width: width, height: menuBarHeight)
        }

        // Fallback
        let notchWidth: CGFloat = 185
        let notchLeft = (screen.frame.width - notchWidth) / 2
        let x = notchLeft - runPadding
        let width = notchWidth + runPadding * 2
        let y = screen.frame.maxY - 32
        return NSRect(x: x, y: y, width: width, height: 32)
    }

    /// The x-offset within the window where the notch left edge is
    static var notchLeftOffset: CGFloat { runPadding }
    /// The x-offset within the window where the notch right edge is
    static var notchRightOffset: CGFloat {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        if let auxLeft = screen.auxiliaryTopLeftArea,
           let auxRight = screen.auxiliaryTopRightArea {
            let notchWidth = auxRight.origin.x - (auxLeft.origin.x + auxLeft.width)
            return runPadding + notchWidth
        }
        return runPadding + 185
    }

    func setXPosition(_ x: CGFloat) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let auxHeight = screen.auxiliaryTopLeftArea?.height ?? 32
        let y = screen.frame.maxY - auxHeight
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

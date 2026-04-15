import AppKit
import QuartzCore

final class GiftSpawner {
    var onGiftOpened: ((String, [String]) -> Void)?  // (giftId, berryNames)

    private var giftWindow: NSWindow?

    func spawnGift(giftId: String, fromName: String, treats: [String]) {
        guard giftWindow == nil else { return }  // one at a time

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let size: CGFloat = 40

        // Position near the notch area
        let x = screen.frame.midX + CGFloat.random(in: -60...60)
        let menuBarH = screen.auxiliaryTopLeftArea?.height ?? 32
        let y = screen.frame.maxY - menuBarH - size - 10

        let window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: size, height: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .statusBar
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let view = GiftView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        view.giftId = giftId
        view.treats = treats
        view.fromName = fromName
        view.spawner = self
        window.contentView = view

        giftWindow = window
        window.alphaValue = 0
        window.orderFront(nil)

        // Fade + bounce in
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            window.animator().alphaValue = 1
        }

        // Auto-dismiss after 60 seconds if not clicked
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.dismissGift()
        }
    }

    fileprivate func handleGiftClicked(giftId: String, treats: [String]) {
        onGiftOpened?(giftId, treats)
        dismissGift()
    }

    private func dismissGift() {
        guard let window = giftWindow else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            self.giftWindow = nil
        })
    }
}

// MARK: - Gift Icon View

private class GiftView: NSView {
    var giftId: String = ""
    var treats: [String] = []
    var fromName: String = ""
    weak var spawner: GiftSpawner?

    private let label = NSTextField(labelWithString: "\u{1F381}")

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        label.font = NSFont.systemFont(ofSize: 28)
        label.frame = bounds
        label.alignment = .center
        label.drawsBackground = false
        label.isBordered = false
        addSubview(label)

        // Gentle bobbing animation
        let bob = CABasicAnimation(keyPath: "transform.translation.y")
        bob.fromValue = 0
        bob.toValue = 4
        bob.duration = 1.5
        bob.autoreverses = true
        bob.repeatCount = .infinity
        layer?.add(bob, forKey: "bob")
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        // Quick squish animation
        let squish = CAKeyframeAnimation(keyPath: "transform.scale")
        squish.values = [1.0, 1.3, 0.9, 1.1, 1.0]
        squish.keyTimes = [0, 0.2, 0.5, 0.8, 1.0]
        squish.duration = 0.3
        layer?.add(squish, forKey: "squish")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.spawner?.handleGiftClicked(giftId: self.giftId, treats: self.treats)
        }
    }
}

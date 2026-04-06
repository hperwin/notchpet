import AppKit
import QuartzCore

// MARK: - Grass Pet View (each party Pokemon)

private class GrassPetView: NSView {
    let imageView = NSImageView()
    var pokemonId: String = ""
    weak var strip: PartyStrip?
    private var dragStart: NSPoint = .zero
    private var windowStart: NSPoint = .zero
    private var jumpTimer: Timer?
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        imageView.frame = bounds
        imageView.autoresizingMask = [.width, .height]
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.magnificationFilter = .nearest
        addSubview(imageView)

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Idle Jumping

    func startIdleJumping() {
        scheduleNextJump()
    }

    func stopIdleJumping() {
        jumpTimer?.invalidate()
        jumpTimer = nil
    }

    private func scheduleNextJump() {
        jumpTimer?.invalidate()
        let wait = Double.random(in: 3.0...8.0)
        jumpTimer = Timer.scheduledTimer(withTimeInterval: wait, repeats: false) { [weak self] _ in
            self?.doJump()
            self?.scheduleNextJump()
        }
    }

    private func doJump() {
        let jump = CAKeyframeAnimation(keyPath: "transform.translation.y")
        let height = CGFloat.random(in: 3...6)
        jump.values = [0, height, 0]
        jump.keyTimes = [0, 0.4, 1.0]
        jump.duration = 0.3
        jump.timingFunction = CAMediaTimingFunction(name: .easeOut)
        imageView.layer?.add(jump, forKey: "idleJump")
    }

    // MARK: - Hover

    override func mouseEntered(with event: NSEvent) {
        guard !pokemonId.isEmpty else { return }
        // Bounce on hover
        let bounce = CAKeyframeAnimation(keyPath: "transform.translation.y")
        bounce.values = [0, 4, 0, 2, 0]
        bounce.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
        bounce.duration = 0.3
        imageView.layer?.add(bounce, forKey: "hoverBounce")
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with event: NSEvent) {
        imageView.layer?.removeAnimation(forKey: "hoverBounce")
        NSCursor.pop()
    }

    // MARK: - Click / Drag

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        windowStart = window?.frame.origin ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        let dx = current.x - dragStart.x
        window?.setFrameOrigin(NSPoint(x: windowStart.x + dx, y: windowStart.y))
    }

    override func mouseUp(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        let distance = abs(current.x - dragStart.x)
        if distance < 3 {
            strip?.handleTap(pokemonId: pokemonId)
        }
    }

    // MARK: - Food Glow

    func showFoodGlow() {
        layer?.shadowColor = NSColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 1).cgColor
        layer?.shadowRadius = 8
        layer?.shadowOpacity = 0.9
        layer?.shadowOffset = .zero
        let pulse = CABasicAnimation(keyPath: "shadowOpacity")
        pulse.fromValue = 0.5
        pulse.toValue = 1.0
        pulse.duration = 0.4
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        layer?.add(pulse, forKey: "foodGlow")
    }

    func hideFoodGlow() {
        layer?.removeAnimation(forKey: "foodGlow")
        layer?.shadowOpacity = 0
    }

    func playFeedBounce() {
        let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
        bounce.values = [1.0, 1.25, 0.9, 1.1, 1.0]
        bounce.keyTimes = [0, 0.2, 0.5, 0.8, 1.0]
        bounce.duration = 0.4
        imageView.layer?.add(bounce, forKey: "feedBounce")
    }
}

// MARK: - Party Strip

final class PartyStrip {
    var onPokemonTapped: ((String) -> Void)?
    var onPokemonFed: ((String) -> Void)?

    private var grassWindow: NSWindow?
    private var pokemonWindows: [NSWindow] = []
    private var currentParty: [String] = []
    private var isVisible = false

    private static let grassHeight: CGFloat = 14
    private static let pokemonSize: CGFloat = 26
    private static let slotCount = 6
    private static let spacing: CGFloat = 6

    func show() {
        guard grassWindow == nil else { return }
        guard let screen = NSScreen.main,
              let auxRight = screen.auxiliaryTopRightArea else { return }

        let startX = auxRight.origin.x + 8
        let totalWidth = CGFloat(Self.slotCount) * (Self.pokemonSize + Self.spacing) - Self.spacing
        let menuBarY = screen.frame.maxY - 32

        // --- Grass strip window (decorative, at the bottom of the menu bar) ---
        let grassFrame = NSRect(x: startX - 4, y: menuBarY, width: totalWidth + 8, height: Self.grassHeight)
        let grassView = NSImageView(frame: NSRect(origin: .zero, size: grassFrame.size))
        grassView.imageScaling = .scaleAxesIndependently
        grassView.wantsLayer = true
        grassView.layer?.magnificationFilter = .nearest
        if let url = Bundle.module.url(forResource: "grass_strip", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            grassView.image = img
        }

        let grassWin = NSWindow(
            contentRect: grassFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        grassWin.level = .statusBar
        grassWin.backgroundColor = .clear
        grassWin.isOpaque = false
        grassWin.hasShadow = false
        grassWin.collectionBehavior = [.canJoinAllSpaces, .stationary]
        grassWin.ignoresMouseEvents = true
        grassWin.contentView = grassView
        grassWin.orderFront(nil)
        grassWindow = grassWin

        // --- Individual Pokemon windows (sitting in the grass) ---
        for i in 0..<Self.slotCount {
            let x = startX + CGFloat(i) * (Self.pokemonSize + Self.spacing)
            // Pokemon sit with their bottom half behind the grass
            let y = menuBarY + Self.grassHeight / 2 - Self.pokemonSize / 2 + 2

            let petFrame = NSRect(x: x, y: y, width: Self.pokemonSize, height: Self.pokemonSize)
            let petView = GrassPetView(frame: NSRect(origin: .zero, size: petFrame.size))
            petView.strip = self

            let win = NSWindow(
                contentRect: petFrame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            win.level = .statusBar
            win.backgroundColor = .clear
            win.isOpaque = false
            win.hasShadow = false
            win.collectionBehavior = [.canJoinAllSpaces, .stationary]
            win.isMovableByWindowBackground = false
            win.contentView = petView
            win.orderOut(nil)
            pokemonWindows.append(win)
        }

        // Grass should appear IN FRONT of the Pokemon (they're behind it)
        grassWin.order(.above, relativeTo: pokemonWindows.first?.windowNumber ?? 0)

        isVisible = true
        refreshSprites()
    }

    func hide() {
        grassWindow?.orderOut(nil)
        grassWindow = nil
        for win in pokemonWindows {
            (win.contentView as? GrassPetView)?.stopIdleJumping()
            win.orderOut(nil)
        }
        pokemonWindows.removeAll()
        isVisible = false
    }

    func updateParty(_ party: [String], level: Int) {
        currentParty = Array(party.prefix(Self.slotCount))
        refreshSprites()
    }

    func allPokemonFrames() -> [(id: String, frame: NSRect)] {
        var results: [(id: String, frame: NSRect)] = []
        for (i, win) in pokemonWindows.enumerated() {
            guard i < currentParty.count, win.isVisible else { continue }
            results.append((id: currentParty[i], frame: win.frame))
        }
        return results
    }

    func highlightPokemon(at screenPoint: NSPoint, foodFrame: NSRect) {
        for (i, win) in pokemonWindows.enumerated() {
            guard i < currentParty.count, win.isVisible,
                  let petView = win.contentView as? GrassPetView else { continue }
            if win.frame.intersects(foodFrame) {
                petView.showFoodGlow()
            } else {
                petView.hideFoodGlow()
            }
        }
    }

    func clearHighlights() {
        for win in pokemonWindows {
            (win.contentView as? GrassPetView)?.hideFoodGlow()
        }
    }

    func playFeedBounce(for pokemonId: String) {
        for (i, win) in pokemonWindows.enumerated() {
            guard i < currentParty.count, currentParty[i] == pokemonId,
                  let petView = win.contentView as? GrassPetView else { continue }
            petView.hideFoodGlow()
            petView.playFeedBounce()
        }
    }

    // MARK: - Internal

    fileprivate func handleTap(pokemonId: String) {
        onPokemonTapped?(pokemonId)
    }

    private func refreshSprites() {
        guard isVisible else { return }
        for (i, win) in pokemonWindows.enumerated() {
            guard let petView = win.contentView as? GrassPetView else { continue }
            if i < currentParty.count {
                let id = currentParty[i]
                petView.pokemonId = id
                petView.imageView.image = PetCollection.spriteImage(for: id)
                win.orderFront(nil)
                petView.startIdleJumping()
                // Keep grass in front
                grassWindow?.order(.above, relativeTo: win.windowNumber)
            } else {
                petView.pokemonId = ""
                petView.imageView.image = nil
                petView.stopIdleJumping()
                win.orderOut(nil)
            }
        }
    }
}

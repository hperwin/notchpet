import AppKit
import QuartzCore

// MARK: - Pixel Grass View (drawn programmatically, no white bg)

private class PixelGrassView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        let bladeWidth: CGFloat = 3

        // Draw grass blades from bottom up
        let colors: [NSColor] = [
            NSColor(red: 0.15, green: 0.55, blue: 0.15, alpha: 1),  // dark green
            NSColor(red: 0.20, green: 0.65, blue: 0.20, alpha: 1),  // medium green
            NSColor(red: 0.30, green: 0.75, blue: 0.25, alpha: 1),  // light green
            NSColor(red: 0.18, green: 0.60, blue: 0.18, alpha: 1),  // mid-dark
        ]

        var x: CGFloat = 0
        var seed: UInt64 = 42
        while x < w {
            // Simple deterministic random for consistent look
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let colorIdx = Int(seed >> 60) % colors.count
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let bladeH = CGFloat(6 + Int(seed >> 60) % 8) // 6-13pt tall
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let lean = CGFloat(Int(seed >> 60) % 5) - 2 // -2 to 2 lean

            ctx.setFillColor(colors[colorIdx].cgColor)
            // Triangle blade shape
            let base = NSPoint(x: x, y: 0)
            let baseR = NSPoint(x: x + bladeWidth, y: 0)
            let tip = NSPoint(x: x + bladeWidth / 2 + lean, y: bladeH)

            ctx.move(to: base)
            ctx.addLine(to: baseR)
            ctx.addLine(to: tip)
            ctx.closePath()
            ctx.fillPath()

            x += bladeWidth - 0.5  // slight overlap
        }
    }
}

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

    // MARK: - Idle Jumping + Wandering

    func startIdleBehavior() {
        scheduleNextJump()
    }

    func stopIdleBehavior() {
        jumpTimer?.invalidate()
        jumpTimer = nil
    }

    private func scheduleNextJump() {
        jumpTimer?.invalidate()
        let wait = Double.random(in: 4.0...10.0)
        jumpTimer = Timer.scheduledTimer(withTimeInterval: wait, repeats: false) { [weak self] _ in
            self?.doJumpAndHop()
            self?.scheduleNextJump()
        }
    }

    /// Jump up AND move sideways a few pixels — looks like a natural hop
    private func doJumpAndHop() {
        guard let win = window else { return }

        // Vertical jump animation on the sprite
        let height = CGFloat.random(in: 2...5)
        let jump = CAKeyframeAnimation(keyPath: "transform.translation.y")
        jump.values = [0, height, 0]
        jump.keyTimes = [0, 0.4, 1.0]
        jump.duration = 0.25
        jump.timingFunction = CAMediaTimingFunction(name: .easeOut)
        imageView.layer?.add(jump, forKey: "idleJump")

        // Horizontal hop — directly move the window origin
        let dx = CGFloat.random(in: -5...5)
        let origin = win.frame.origin
        win.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y))
    }

    // MARK: - Hover

    override func mouseEntered(with event: NSEvent) {
        guard !pokemonId.isEmpty else { return }
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
        let distance = abs(NSEvent.mouseLocation.x - dragStart.x)
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

    private static let grassHeight: CGFloat = 7
    private static let pokemonSize: CGFloat = 26
    private static let slotCount = 6
    private static let spacing: CGFloat = 6

    func show() {
        guard grassWindow == nil else { return }
        guard let screen = NSScreen.main,
              let auxRight = screen.auxiliaryTopRightArea else { return }

        let startX = auxRight.origin.x + 8
        let totalWidth = CGFloat(Self.slotCount) * (Self.pokemonSize + Self.spacing) - Self.spacing
        let menuBarBottom = auxRight.origin.y
        let menuBarHeight = auxRight.height

        // --- Grass strip (programmatic, no image) ---
        let grassFrame = NSRect(x: startX - 6, y: menuBarBottom, width: totalWidth + 12, height: Self.grassHeight)
        let grassView = PixelGrassView(frame: NSRect(origin: .zero, size: grassFrame.size))

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

        // --- Individual Pokemon windows ---
        for i in 0..<Self.slotCount {
            let x = startX + CGFloat(i) * (Self.pokemonSize + Self.spacing)
            let y = menuBarBottom + (menuBarHeight - Self.pokemonSize) / 2

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

        isVisible = true
        refreshSprites()
    }

    func hide() {
        grassWindow?.orderOut(nil)
        grassWindow = nil
        for win in pokemonWindows {
            (win.contentView as? GrassPetView)?.stopIdleBehavior()
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
                petView.startIdleBehavior()
            } else {
                petView.pokemonId = ""
                petView.imageView.image = nil
                petView.stopIdleBehavior()
                win.orderOut(nil)
            }
        }
        // Grass in front
        grassWindow?.orderFront(nil)
    }
}

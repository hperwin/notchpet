import AppKit
import QuartzCore

// MARK: - Pixel Grass View

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
        let bladeWidth: CGFloat = 3
        let colors: [NSColor] = [
            NSColor(red: 0.15, green: 0.55, blue: 0.15, alpha: 1),
            NSColor(red: 0.20, green: 0.65, blue: 0.20, alpha: 1),
            NSColor(red: 0.30, green: 0.75, blue: 0.25, alpha: 1),
            NSColor(red: 0.18, green: 0.60, blue: 0.18, alpha: 1),
        ]
        var x: CGFloat = 0
        var seed: UInt64 = 42
        while x < w {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let colorIdx = Int(seed >> 60) % colors.count
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let bladeH = CGFloat(5 + Int(seed >> 60) % 7)
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let lean = CGFloat(Int(seed >> 60) % 5) - 2
            ctx.setFillColor(colors[colorIdx].cgColor)
            ctx.move(to: NSPoint(x: x, y: 0))
            ctx.addLine(to: NSPoint(x: x + bladeWidth, y: 0))
            ctx.addLine(to: NSPoint(x: x + bladeWidth / 2 + lean, y: bladeH))
            ctx.closePath()
            ctx.fillPath()
            x += bladeWidth - 0.5
        }
    }
}

// MARK: - Grass Pet View

private class GrassPetView: NSView {
    let imageView = NSImageView()
    var pokemonId: String = ""
    weak var strip: PartyStrip?
    var minX: CGFloat = 0
    var maxX: CGFloat = 10000
    var homeX: CGFloat = 0
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
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func startIdleBehavior() { scheduleNextJump() }
    func stopIdleBehavior() { jumpTimer?.invalidate(); jumpTimer = nil }

    private func scheduleNextJump() {
        jumpTimer?.invalidate()
        let wait = Double.random(in: 4.0...10.0)
        jumpTimer = Timer.scheduledTimer(withTimeInterval: wait, repeats: false) { [weak self] _ in
            self?.doJumpAndHop()
            self?.scheduleNextJump()
        }
    }

    private func doJumpAndHop() {
        guard let win = window else { return }
        let height = CGFloat.random(in: 2...5)
        let jump = CAKeyframeAnimation(keyPath: "transform.translation.y")
        jump.values = [0, height, 0]
        jump.keyTimes = [0, 0.4, 1.0]
        jump.duration = 0.25
        jump.timingFunction = CAMediaTimingFunction(name: .easeOut)
        imageView.layer?.add(jump, forKey: "idleJump")
        // Bias toward home position so they don't drift
        let currentX = win.frame.origin.x
        let distFromHome = homeX - currentX
        let bias = distFromHome * 0.3  // gentle pull toward home
        let dx = CGFloat.random(in: -4...4) + bias
        let newX = max(minX, min(currentX + dx, maxX))
        win.setFrameOrigin(NSPoint(x: newX, y: win.frame.origin.y))
    }

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

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        windowStart = window?.frame.origin ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        let dx = current.x - dragStart.x
        let newX = max(minX, min(windowStart.x + dx, maxX))
        window?.setFrameOrigin(NSPoint(x: newX, y: windowStart.y))
    }

    override func mouseUp(with event: NSEvent) {
        if abs(NSEvent.mouseLocation.x - dragStart.x) < 3 {
            strip?.handleTap(pokemonId: pokemonId)
        }
    }

    func showFoodGlow() {
        layer?.shadowColor = NSColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 1).cgColor
        layer?.shadowRadius = 8
        layer?.shadowOpacity = 0.9
        layer?.shadowOffset = .zero
        let pulse = CABasicAnimation(keyPath: "shadowOpacity")
        pulse.fromValue = 0.5; pulse.toValue = 1.0; pulse.duration = 0.4
        pulse.autoreverses = true; pulse.repeatCount = .infinity
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

// MARK: - Party Strip (Two Grass Patches)

final class PartyStrip {
    var onPokemonTapped: ((String) -> Void)?

    private var leftGrassWindow: NSWindow?
    private var rightGrassWindow: NSWindow?
    private var pokemonWindows: [NSWindow] = []
    private var currentParty: [String] = []
    private var isVisible = false
    private var levelUpWindow: NSWindow?
    private var levelUpTimer: Timer?
    private var comboBadgeWindow: NSWindow?
    private var comboBadgeLabel: NSTextField?
    private var currentComboStage: GameSystems.ComboStage = .none

    private static let grassHeight: CGFloat = 7
    private static let pokemonSize: CGFloat = 26
    private static let pokemonsPerSide = 3
    private static let spacing: CGFloat = 8

    func show() {
        guard leftGrassWindow == nil else { return }
        guard let screen = NSScreen.main,
              let auxLeft = screen.auxiliaryTopLeftArea,
              let auxRight = screen.auxiliaryTopRightArea else { return }

        let menuBarBottom = auxLeft.origin.y
        let menuBarHeight = auxLeft.height

        let patchWidth = CGFloat(Self.pokemonsPerSide) * (Self.pokemonSize + Self.spacing) - Self.spacing + 12

        // LEFT grass patch — to the left of the notch
        let leftX = auxLeft.origin.x + auxLeft.width - patchWidth - 8
        leftGrassWindow = makeGrassWindow(x: leftX, y: menuBarBottom, width: patchWidth)

        // RIGHT grass patch — to the right of the notch
        let rightX = auxRight.origin.x + 8
        rightGrassWindow = makeGrassWindow(x: rightX, y: menuBarBottom, width: patchWidth)

        // Create 6 Pokemon windows — 3 left, 3 right
        for i in 0..<6 {
            let isLeft = i < Self.pokemonsPerSide
            let slotIndex = isLeft ? i : i - Self.pokemonsPerSide
            let patchX = isLeft ? leftX : rightX

            let x = patchX + 6 + CGFloat(slotIndex) * (Self.pokemonSize + Self.spacing)
            let y = menuBarBottom + (menuBarHeight - Self.pokemonSize) / 2

            let petFrame = NSRect(x: x, y: y, width: Self.pokemonSize, height: Self.pokemonSize)
            let petView = GrassPetView(frame: NSRect(origin: .zero, size: petFrame.size))
            petView.strip = self
            petView.minX = patchX
            petView.maxX = patchX + patchWidth - Self.pokemonSize
            petView.homeX = x

            let win = NSWindow(contentRect: petFrame, styleMask: .borderless, backing: .buffered, defer: false)
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

    private func makeGrassWindow(x: CGFloat, y: CGFloat, width: CGFloat) -> NSWindow {
        let frame = NSRect(x: x, y: y, width: width, height: Self.grassHeight)
        let grassView = PixelGrassView(frame: NSRect(origin: .zero, size: frame.size))
        let win = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.level = .statusBar
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.ignoresMouseEvents = true
        win.contentView = grassView
        win.orderFront(nil)
        return win
    }

    func hide() {
        leftGrassWindow?.orderOut(nil); leftGrassWindow = nil
        rightGrassWindow?.orderOut(nil); rightGrassWindow = nil
        for win in pokemonWindows {
            (win.contentView as? GrassPetView)?.stopIdleBehavior()
            win.orderOut(nil)
        }
        pokemonWindows.removeAll()
        isVisible = false
    }

    func updateParty(_ party: [String], level: Int) {
        currentParty = Array(party.prefix(6))
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
            if win.frame.intersects(foodFrame) { petView.showFoodGlow() }
            else { petView.hideFoodGlow() }
        }
    }

    func clearHighlights() {
        for win in pokemonWindows { (win.contentView as? GrassPetView)?.hideFoodGlow() }
    }

    func playFeedBounce(for pokemonId: String) {
        for (i, win) in pokemonWindows.enumerated() {
            guard i < currentParty.count, currentParty[i] == pokemonId,
                  let petView = win.contentView as? GrassPetView else { continue }
            petView.hideFoodGlow()
            petView.playFeedBounce()
        }
    }

    // MARK: - Level Up Popup

    func showLevelUp(pokemonName: String, newLevel: Int) {
        guard !Preferences.shared.isAppHidden else { return }
        guard let screen = NSScreen.main else { return }

        levelUpTimer?.invalidate()
        levelUpWindow?.orderOut(nil)

        let popupW: CGFloat = 220
        let popupH: CGFloat = 44
        let centerX = screen.frame.midX - popupW / 2
        let y = screen.frame.maxY - 32 - popupH - 4  // just below menu bar

        let popupFrame = NSRect(x: centerX, y: y, width: popupW, height: popupH)

        // Programmatic banner — no image, just drawn in code
        let bgView = NSView(frame: NSRect(origin: .zero, size: popupFrame.size))
        bgView.wantsLayer = true
        bgView.layer?.cornerRadius = 8
        bgView.layer?.backgroundColor = NSColor(red: 0x1a/255, green: 0x1a/255, blue: 0x1a/255, alpha: 0.95).cgColor
        bgView.layer?.borderColor = DS.gold.cgColor
        bgView.layer?.borderWidth = 2

        // Gold accent line at top
        let topAccent = NSView(frame: NSRect(x: 2, y: 0, width: popupW - 4, height: 2))
        topAccent.wantsLayer = true
        topAccent.layer?.backgroundColor = DS.gold.cgColor
        bgView.addSubview(topAccent)

        // Text
        let label = DS.label("\(pokemonName) grew to Lv.\(newLevel)!", size: 12, bold: true, color: DS.gold)
        label.translatesAutoresizingMaskIntoConstraints = true
        label.alignment = .center
        label.frame = NSRect(x: 0, y: (popupH - 16) / 2, width: popupW, height: 16)
        bgView.addSubview(label)

        let win = NSWindow(contentRect: popupFrame, styleMask: .borderless, backing: .buffered, defer: false)
        win.level = .statusBar + 1
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.ignoresMouseEvents = true
        win.contentView = bgView
        win.alphaValue = 0
        win.orderFront(nil)

        // Fade in
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 1
        }

        levelUpWindow = win

        // Auto-dismiss after 3 seconds
        levelUpTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.5
                win.animator().alphaValue = 0
            }, completionHandler: {
                win.orderOut(nil)
                self?.levelUpWindow = nil
            })
        }
    }

    // MARK: - Combo Badge

    func updateCombo(_ stage: GameSystems.ComboStage) {
        guard !Preferences.shared.isAppHidden else { return }
        guard stage != currentComboStage else { return }
        let oldStage = currentComboStage
        currentComboStage = stage

        if stage == .none {
            hideCombo()
            return
        }

        guard let label = stage.label else { return }

        if comboBadgeWindow == nil {
            createComboBadge()
        }

        guard let badgeWin = comboBadgeWindow,
              let badgeLabel = comboBadgeLabel else { return }

        badgeLabel.stringValue = label
        let color = comboColor(for: stage)
        badgeWin.contentView?.layer?.backgroundColor = color.withAlphaComponent(0.85).cgColor
        badgeWin.contentView?.layer?.borderColor = color.cgColor

        if oldStage == .none {
            badgeWin.alphaValue = 0
            badgeWin.orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                badgeWin.animator().alphaValue = 1
            }
        }

        if stage > oldStage && oldStage != .none {
            let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
            pulse.values = [1.0, 1.3, 1.0]
            pulse.keyTimes = [0, 0.4, 1.0]
            pulse.duration = 0.3
            badgeWin.contentView?.layer?.add(pulse, forKey: "stagePulse")
        }

        if stage == .flow {
            addFlameToLead()
        } else {
            removeFlameFromLead()
        }
    }

    private func createComboBadge() {
        guard let screen = NSScreen.main else { return }

        let badgeW: CGFloat = 44
        let badgeH: CGFloat = 20
        let centerX = screen.frame.midX - badgeW / 2
        let y = screen.frame.maxY - 32 - badgeH - 4  // same position as level-up banner

        let badgeFrame = NSRect(x: centerX, y: y, width: badgeW, height: badgeH)

        let bgView = NSView(frame: NSRect(origin: .zero, size: badgeFrame.size))
        bgView.wantsLayer = true
        bgView.layer?.cornerRadius = 6
        bgView.layer?.borderWidth = 1

        let label = NSTextField(labelWithString: "")
        label.font = NSFont.boldSystemFont(ofSize: 10)
        label.textColor = .white
        label.alignment = .center
        label.isBordered = false
        label.drawsBackground = false
        label.isEditable = false
        label.frame = NSRect(x: 0, y: 2, width: badgeW, height: badgeH - 4)
        bgView.addSubview(label)
        comboBadgeLabel = label

        let win = NSWindow(contentRect: badgeFrame, styleMask: .borderless, backing: .buffered, defer: false)
        win.level = .statusBar + 1
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.ignoresMouseEvents = true
        win.contentView = bgView
        comboBadgeWindow = win
    }

    private func hideCombo() {
        guard let win = comboBadgeWindow else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 0
        }, completionHandler: {
            win.orderOut(nil)
        })
        removeFlameFromLead()
    }

    private func comboColor(for stage: GameSystems.ComboStage) -> NSColor {
        switch stage {
        case .none: return .clear
        case .warm: return NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        case .focused: return NSColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1)
        case .deep: return NSColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1)
        case .flow: return NSColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1)
        }
    }

    private func addFlameToLead() {
        guard let leadWin = pokemonWindows.first,
              let petView = leadWin.contentView as? GrassPetView else { return }
        petView.layer?.shadowColor = NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1).cgColor
        petView.layer?.shadowRadius = 6
        petView.layer?.shadowOpacity = 0.8
        petView.layer?.shadowOffset = .zero
        let pulse = CABasicAnimation(keyPath: "shadowOpacity")
        pulse.fromValue = 0.5
        pulse.toValue = 1.0
        pulse.duration = 0.6
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        petView.layer?.add(pulse, forKey: "flowFlame")
    }

    private func removeFlameFromLead() {
        guard let leadWin = pokemonWindows.first,
              let petView = leadWin.contentView as? GrassPetView else { return }
        petView.layer?.removeAnimation(forKey: "flowFlame")
        petView.layer?.shadowOpacity = 0
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
                petView.pokemonId = currentParty[i]
                petView.imageView.image = PetCollection.spriteImage(for: currentParty[i])
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
        leftGrassWindow?.orderFront(nil)
        rightGrassWindow?.orderFront(nil)
    }
}

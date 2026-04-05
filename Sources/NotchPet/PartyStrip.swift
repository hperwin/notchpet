import AppKit

// MARK: - Draggable Pet View

private class DraggablePetView: NSView {
    let imageView = NSImageView()
    var pokemonId: String = ""
    weak var strip: PartyStrip?
    private var dragStart: NSPoint = .zero
    private var windowStart: NSPoint = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView.frame = bounds
        imageView.autoresizingMask = [.width, .height]
        imageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        windowStart = window?.frame.origin ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        let dx = current.x - dragStart.x
        let dy = current.y - dragStart.y
        window?.setFrameOrigin(NSPoint(x: windowStart.x + dx, y: windowStart.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        // Tap detection: if barely moved, treat as a tap
        let current = NSEvent.mouseLocation
        let dx = current.x - dragStart.x
        let dy = current.y - dragStart.y
        let distance = sqrt(dx * dx + dy * dy)
        if distance < 3 {
            strip?.handleTap(pokemonId: pokemonId)
        }
        // Otherwise just stay where dropped
    }
}

// MARK: - Party Strip

final class PartyStrip {
    var onPokemonTapped: ((String) -> Void)?
    var onPokemonFed: ((String) -> Void)?

    private var backgroundWindow: NSWindow?
    private var pokemonWindows: [NSWindow] = []
    private var currentParty: [String] = []
    private var isVisible = false

    private static let stripWidth: CGFloat = 210
    private static let stripHeight: CGFloat = 28
    private static let slotCount = 6
    private static let pokemonSize: CGFloat = 26

    func show() {
        guard backgroundWindow == nil else { return }
        guard let screen = NSScreen.main,
              let auxRight = screen.auxiliaryTopRightArea else { return }

        let stripX = auxRight.origin.x + 8
        let stripY = screen.frame.maxY - 32 + 2

        // --- Strip background window ---
        let bgFrame = NSRect(x: stripX, y: stripY, width: Self.stripWidth, height: Self.stripHeight)
        let bgView = NSView(frame: NSRect(origin: .zero, size: bgFrame.size))
        bgView.wantsLayer = true
        bgView.layer?.cornerRadius = 8
        bgView.layer?.masksToBounds = true

        let bgImageView = NSImageView(frame: NSRect(origin: .zero, size: bgFrame.size))
        bgImageView.imageScaling = .scaleAxesIndependently
        if let bgURL = Bundle.module.url(forResource: "party_strip", withExtension: "png"),
           let bgImage = NSImage(contentsOf: bgURL) {
            bgImageView.image = bgImage
        }
        bgView.addSubview(bgImageView)

        let bgWin = NSWindow(
            contentRect: bgFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        bgWin.level = .statusBar
        bgWin.backgroundColor = .clear
        bgWin.isOpaque = false
        bgWin.hasShadow = false
        bgWin.collectionBehavior = [.canJoinAllSpaces, .stationary]
        bgWin.ignoresMouseEvents = true
        bgWin.contentView = bgView
        bgWin.orderFront(nil)
        backgroundWindow = bgWin

        // --- Individual Pokemon windows ---
        let slotWidth = Self.stripWidth / CGFloat(Self.slotCount)
        for i in 0..<Self.slotCount {
            let x = stripX + CGFloat(i) * slotWidth + (slotWidth - Self.pokemonSize) / 2
            let y = stripY + 1

            let petFrame = NSRect(x: x, y: y, width: Self.pokemonSize, height: Self.pokemonSize)
            let petView = DraggablePetView(frame: NSRect(origin: .zero, size: petFrame.size))
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
            // Start hidden; updateParty will show the ones that have sprites
            win.orderOut(nil)
            pokemonWindows.append(win)
        }

        isVisible = true
        refreshSprites()
    }

    func hide() {
        backgroundWindow?.orderOut(nil)
        backgroundWindow = nil
        for win in pokemonWindows {
            win.orderOut(nil)
        }
        pokemonWindows.removeAll()
        isVisible = false
    }

    func updateParty(_ party: [String], level: Int) {
        currentParty = Array(party.prefix(Self.slotCount))
        refreshSprites()
    }

    /// Returns frames of all visible party Pokemon windows (for food drop detection).
    func allPokemonFrames() -> [(id: String, frame: NSRect)] {
        var results: [(id: String, frame: NSRect)] = []
        for (i, win) in pokemonWindows.enumerated() {
            guard i < currentParty.count, win.isVisible else { continue }
            results.append((id: currentParty[i], frame: win.frame))
        }
        return results
    }

    // MARK: - Internal

    fileprivate func handleTap(pokemonId: String) {
        onPokemonTapped?(pokemonId)
    }

    private func refreshSprites() {
        guard isVisible else { return }
        for (i, win) in pokemonWindows.enumerated() {
            guard let petView = win.contentView as? DraggablePetView else { continue }
            if i < currentParty.count {
                let id = currentParty[i]
                petView.pokemonId = id
                petView.imageView.image = PetCollection.spriteImage(for: id)
                win.orderFront(nil)
            } else {
                petView.pokemonId = ""
                petView.imageView.image = nil
                win.orderOut(nil)
            }
        }
    }
}

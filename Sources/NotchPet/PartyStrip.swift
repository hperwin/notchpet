import AppKit

// MARK: - Party Strip View

private final class PartyStripView: NSView {
    static let slotCount = 6
    static let slotSize: CGFloat = 24

    var onSlotTapped: ((Int) -> Void)?

    private let backgroundImageView: NSImageView
    private var slotImageViews: [NSImageView] = []

    override init(frame frameRect: NSRect) {
        backgroundImageView = NSImageView(frame: NSRect(origin: .zero, size: frameRect.size))
        backgroundImageView.imageScaling = .scaleAxesIndependently
        if let bgURL = Bundle.module.url(forResource: "party_strip", withExtension: "png"),
           let bgImage = NSImage(contentsOf: bgURL) {
            backgroundImageView.image = bgImage
        }

        super.init(frame: frameRect)
        addSubview(backgroundImageView)

        let totalSlotWidth = CGFloat(Self.slotCount) * Self.slotSize
        let spacing = (frameRect.width - totalSlotWidth) / CGFloat(Self.slotCount + 1)

        for i in 0..<Self.slotCount {
            let x = spacing + CGFloat(i) * (Self.slotSize + spacing)
            let y = (frameRect.height - Self.slotSize) / 2
            let slot = NSImageView(frame: NSRect(x: x, y: y, width: Self.slotSize, height: Self.slotSize))
            slot.imageScaling = .scaleProportionallyUpOrDown
            slot.tag = i
            addSubview(slot)
            slotImageViews.append(slot)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    func setSlotImage(_ image: NSImage?, at index: Int) {
        guard index >= 0, index < slotImageViews.count else { return }
        slotImageViews[index].image = image
    }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        for (i, slot) in slotImageViews.enumerated() {
            if slot.frame.contains(loc), slot.image != nil {
                onSlotTapped?(i)
                return
            }
        }
    }
}

// MARK: - Party Strip

final class PartyStrip {
    var onPokemonTapped: ((String) -> Void)?

    private var window: NSWindow?
    private var stripView: PartyStripView?
    private var currentParty: [String] = []

    private static let stripWidth: CGFloat = 200
    private static let stripHeight: CGFloat = 28

    func show() {
        if window != nil { return }

        guard let screen = NSScreen.main,
              let auxRight = screen.auxiliaryTopRightArea else { return }

        let x = auxRight.origin.x + 8
        let y = screen.frame.maxY - 32 + 2
        let frame = NSRect(x: x, y: y, width: Self.stripWidth, height: Self.stripHeight)

        let view = PartyStripView(frame: NSRect(origin: .zero, size: frame.size))
        view.onSlotTapped = { [weak self] index in
            guard let self = self, index < self.currentParty.count else { return }
            self.onPokemonTapped?(self.currentParty[index])
        }
        self.stripView = view

        let win = NSWindow(
            contentRect: frame,
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
        win.contentView = view
        win.orderFront(nil)
        self.window = win
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        stripView = nil
    }

    func updateParty(_ party: [String], level: Int) {
        currentParty = Array(party.prefix(6))
        guard let stripView = stripView else { return }
        for i in 0..<PartyStripView.slotCount {
            if i < currentParty.count {
                stripView.setSlotImage(PetCollection.spriteImage(for: currentParty[i]), at: i)
            } else {
                stripView.setSlotImage(nil, at: i)
            }
        }
    }
}

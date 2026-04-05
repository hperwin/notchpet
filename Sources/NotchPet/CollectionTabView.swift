import AppKit
import QuartzCore

final class CollectionTabView: DSTabView {

    private static let bgGray = NSColor(red: 0xE8/255, green: 0xE8/255, blue: 0xE8/255, alpha: 1)
    private static let cellBg = NSColor(red: 0xF0/255, green: 0xF0/255, blue: 0xF0/255, alpha: 1)
    private static let cellBorder = NSColor(red: 0xCC/255, green: 0xCC/255, blue: 0xCC/255, alpha: 1)
    private static let lockedBg = NSColor(red: 0xDD/255, green: 0xDD/255, blue: 0xDD/255, alpha: 1)
    private static let goldDot = NSColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1)

    private static let columns = 6
    private static let cellSize: CGFloat = 78
    private static let cellGap: CGFloat = 4
    private static let padX: CGFloat = 8
    private static let padTop: CGFloat = 36

    private let scrollView = NSScrollView()
    private let contentView = FlippedView()

    init() {
        super.init(backgroundColor: CollectionTabView.bgGray)
        setupScrollView()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        scrollView.documentView = contentView
    }

    override func update(state: PetState) {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        clearHitRegions()

        let catalog = PetCollection.catalog(for: state.level)
        let partySet = Set(state.party)
        let totalRows = (catalog.count + Self.columns - 1) / Self.columns

        // Title
        let title = makeLabel("Collection (\(catalog.filter { $0.unlocked }.count)/\(catalog.count))", size: 13, bold: true, color: NSColor(white: 0.2, alpha: 1))
        title.frame = NSRect(x: 0, y: 8, width: 520, height: 18)
        title.alignment = .center
        contentView.addSubview(title)

        // Calculate content height
        let contentHeight = Self.padTop + CGFloat(totalRows) * (Self.cellSize + Self.cellGap) + 10
        contentView.frame = NSRect(x: 0, y: 0, width: 520, height: max(contentHeight, 380))

        for (index, item) in catalog.enumerated() {
            let col = index % Self.columns
            let row = index / Self.columns

            let cellX = Self.padX + CGFloat(col) * (Self.cellSize + Self.cellGap)
            let cellY = Self.padTop + CGFloat(row) * (Self.cellSize + Self.cellGap)
            let cellRect = NSRect(x: cellX, y: cellY, width: Self.cellSize, height: Self.cellSize)

            let entry = item.entry
            let unlocked = item.unlocked
            let isSelected = entry.id == state.selectedPet

            // Cell background
            let cell = NSView(frame: cellRect)
            cell.wantsLayer = true
            cell.layer?.cornerRadius = 6
            cell.layer?.backgroundColor = unlocked ? Self.cellBg.cgColor : Self.lockedBg.cgColor
            cell.layer?.borderColor = isSelected ? DSTabView.selectedRed.cgColor : Self.cellBorder.cgColor
            cell.layer?.borderWidth = isSelected ? 2.5 : 1
            contentView.addSubview(cell)

            // Sprite centered in cell
            let spriteSize: CGFloat = 48
            let spriteX = cellRect.minX + (cellRect.width - spriteSize) / 2
            let spriteY = cellRect.minY + 4
            let sprite = NSImageView(frame: NSRect(x: spriteX, y: spriteY, width: spriteSize, height: spriteSize))
            sprite.image = PetCollection.spriteImage(for: entry.id)
            sprite.imageScaling = .scaleProportionallyUpOrDown
            sprite.wantsLayer = true
            sprite.layer?.magnificationFilter = .nearest
            sprite.alphaValue = unlocked ? 1.0 : 0.2
            contentView.addSubview(sprite)

            // Name/level below sprite
            let labelY = spriteY + spriteSize + 1
            let labelText = unlocked ? entry.displayName : "Lv.\(entry.unlockLevel)"
            let labelColor: NSColor = unlocked ? NSColor(white: 0.2, alpha: 1) : .gray
            let label = makeLabel(labelText, size: 8, bold: unlocked, color: labelColor)
            label.frame = NSRect(x: cellRect.minX + 2, y: labelY, width: cellRect.width - 4, height: 12)
            label.alignment = .center
            label.lineBreakMode = .byTruncatingTail
            contentView.addSubview(label)

            // Gold dot if in party
            if unlocked && partySet.contains(entry.id) {
                let dot = NSView(frame: NSRect(x: cellRect.maxX - 10, y: cellRect.minY + 4, width: 6, height: 6))
                dot.wantsLayer = true
                dot.layer?.backgroundColor = Self.goldDot.cgColor
                dot.layer?.cornerRadius = 3
                contentView.addSubview(dot)
            }

            // Hit region (in the scrollView's content coordinates)
            addHitRegion(HitRegion(id: "collection_\(index)", rect: cellRect, action: .showDetail(pokemonId: entry.id), enabled: unlocked))
        }
    }

    // Override mouseDown to account for scroll offset
    override func mouseDown(with event: NSEvent) {
        let locInScroll = scrollView.contentView.convert(event.locationInWindow, from: nil)
        let docOffset = scrollView.contentView.bounds.origin
        let locInContent = NSPoint(x: locInScroll.x, y: locInScroll.y + docOffset.y)
        // Flip Y for the content view
        let flippedY = contentView.frame.height - locInContent.y

        for region in hitRegions where region.enabled {
            if region.rect.contains(NSPoint(x: locInContent.x, y: flippedY)) {
                onAction?(region.action)
                return
            }
        }
    }

    private func makeLabel(_ text: String, size: CGFloat, bold: Bool = true, color: NSColor = .white) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        label.textColor = color
        label.drawsBackground = false
        label.isBordered = false
        label.isEditable = false
        return label
    }
}

private class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

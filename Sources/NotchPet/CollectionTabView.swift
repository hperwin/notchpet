import AppKit
import QuartzCore

final class CollectionTabView: DSTabView {

    private static let columns = 6
    private static let cellSize: CGFloat = 88
    private static let cellGap: CGFloat = 4
    private static let padX: CGFloat = 12
    private static let padTop: CGFloat = 36
    private static let panelWidth: CGFloat = 580

    private let scrollView = NSScrollView()
    private let contentView = FlippedView()

    init() {
        super.init(backgroundColor: .clear)
        setupGradient()
        setupScrollView()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var disableHoverTracking: Bool { true }

    private func setupGradient() {
        wantsLayer = true
        let gradient = CAGradientLayer()
        gradient.colors = [DS.boxTealTop.cgColor, DS.boxTealBot.cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        gradient.frame = bounds
        gradient.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.insertSublayer(gradient, at: 0)
    }

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

        let allPokemon = PetCollection.allPokemon
        let partySet = Set(state.party)
        let totalRows = (allPokemon.count + Self.columns - 1) / Self.columns

        // Header: "BOX 1" centered
        let title = DS.label("BOX 1", size: 14, bold: true, color: .white)
        title.alignment = .center
        title.frame = NSRect(x: 0, y: 10, width: Self.panelWidth, height: 18)
        contentView.addSubview(title)

        // Content height
        let contentHeight = Self.padTop + CGFloat(totalRows) * (Self.cellSize + Self.cellGap) + 10
        contentView.frame = NSRect(x: 0, y: 0, width: Self.panelWidth, height: max(contentHeight, 380))

        for (index, entry) in allPokemon.enumerated() {
            let col = index % Self.columns
            let row = index / Self.columns

            let cellX = Self.padX + CGFloat(col) * (Self.cellSize + Self.cellGap)
            let cellY = Self.padTop + CGFloat(row) * (Self.cellSize + Self.cellGap)
            let cellRect = NSRect(x: cellX, y: cellY, width: Self.cellSize, height: Self.cellSize)

            let isInParty = partySet.contains(entry.id)

            // Cell background
            let cell = NSView(frame: cellRect)
            cell.wantsLayer = true
            cell.layer?.cornerRadius = 8
            cell.layer?.backgroundColor = DS.boxCellBg.cgColor
            if isInParty {
                cell.layer?.borderColor = DS.gold.cgColor
                cell.layer?.borderWidth = 2
            }
            contentView.addSubview(cell)

            // Sprite (52pt) centered horizontally, y=6 from cell top
            let spriteSize: CGFloat = 52
            let spriteX = cellRect.minX + (cellRect.width - spriteSize) / 2
            let spriteY = cellRect.minY + 6
            let sprite = NSImageView(frame: NSRect(x: spriteX, y: spriteY, width: spriteSize, height: spriteSize))
            sprite.image = PetCollection.spriteImage(for: entry.id)
            sprite.imageScaling = .scaleProportionallyUpOrDown
            sprite.wantsLayer = true
            sprite.layer?.magnificationFilter = .nearest
            contentView.addSubview(sprite)

            // Name (9pt white, DS shadow) centered below sprite
            let nameY = spriteY + spriteSize + 2
            let nameLabel = DS.label(entry.displayName, size: 9, bold: false, color: .white)
            nameLabel.alignment = .center
            nameLabel.lineBreakMode = .byTruncatingTail
            nameLabel.frame = NSRect(x: cellRect.minX + 2, y: nameY, width: cellRect.width - 4, height: 12)
            contentView.addSubview(nameLabel)

            // Level label if has instance
            let instance = state.pokemonInstances[entry.id]
            if let inst = instance {
                let lvY = nameY + 12
                let lvLabel = DS.label("Lv.\(inst.level)", size: 8, bold: false, color: DS.textSecondary)
                lvLabel.alignment = .center
                lvLabel.frame = NSRect(x: cellRect.minX + 2, y: lvY, width: cellRect.width - 4, height: 10)
                contentView.addSubview(lvLabel)
            }

            // Hit region
            addHitRegion(HitRegion(id: "collection_\(index)", rect: cellRect, action: .showDetail(pokemonId: entry.id), enabled: true))
        }
    }

    // Override mouseDown to account for scroll offset
    override func mouseDown(with event: NSEvent) {
        let locInContentView = contentView.convert(event.locationInWindow, from: nil)

        for region in hitRegions where region.enabled {
            if region.rect.contains(locInContentView) {
                onAction?(region.action)
                return
            }
        }
    }
}

private class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

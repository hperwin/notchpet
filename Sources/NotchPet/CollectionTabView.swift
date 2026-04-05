import AppKit
import QuartzCore

final class CollectionTabView: DSTabView {

    // Colors
    private static let bgGray = NSColor(red: 0xE8/255, green: 0xE8/255, blue: 0xE8/255, alpha: 1)
    private static let cellBg = NSColor(red: 0xF0/255, green: 0xF0/255, blue: 0xF0/255, alpha: 1)
    private static let cellBorder = NSColor(red: 0xCC/255, green: 0xCC/255, blue: 0xCC/255, alpha: 1)
    private static let lockedBg = NSColor(red: 0xDD/255, green: 0xDD/255, blue: 0xDD/255, alpha: 1)
    private static let goldDot = NSColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1)

    // Grid constants
    private static let gridOriginX: CGFloat = 16
    private static let gridOriginY: CGFloat = 40
    private static let columns = 6
    private static let rows = 5
    private static let cellSize: CGFloat = 80
    private static let cellGap: CGFloat = 4

    init() {
        super.init(backgroundColor: CollectionTabView.bgGray)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Update

    override func update(state: PetState) {
        subviews.forEach { $0.removeFromSuperview() }
        clearHitRegions()

        // Title
        let title = DSTabView.dsLabel("Collection", size: 14, bold: true, color: NSColor(white: 0.15, alpha: 1))
        title.shadow = nil  // no DS shadow on dark-on-light text
        addSubview(title)
        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: centerXAnchor),
            title.topAnchor.constraint(equalTo: topAnchor, constant: 12),
        ])

        let catalog = PetCollection.catalog(for: state.level)
        let partySet = Set(state.party)

        for (index, item) in catalog.enumerated() {
            let col = index % CollectionTabView.columns
            let row = index / CollectionTabView.columns
            guard row < CollectionTabView.rows else { break }

            let cellX = CollectionTabView.gridOriginX + CGFloat(col) * (CollectionTabView.cellSize + CollectionTabView.cellGap)
            let cellY = CollectionTabView.gridOriginY + CGFloat(row) * (CollectionTabView.cellSize + CollectionTabView.cellGap)
            let cellRect = NSRect(x: cellX, y: cellY, width: CollectionTabView.cellSize, height: CollectionTabView.cellSize)

            let entry = item.entry
            let unlocked = item.unlocked
            let isShiny = state.useShiny && state.unlockedShinies.contains(entry.id)
            let isSelected = entry.id == state.selectedPet

            // Cell background
            let cell = NSView(frame: cellRect)
            cell.wantsLayer = true
            cell.layer?.cornerRadius = 6
            cell.layer?.backgroundColor = unlocked ? CollectionTabView.cellBg.cgColor : CollectionTabView.lockedBg.cgColor
            cell.layer?.borderColor = isSelected ? DSTabView.selectedRed.cgColor : CollectionTabView.cellBorder.cgColor
            cell.layer?.borderWidth = isSelected ? 2 : 1
            addSubview(cell)

            // Sprite (centered in cell)
            let sprite = DSTabView.dsSprite(for: entry.id, shiny: isShiny, size: 48)
            sprite.alphaValue = unlocked ? 1.0 : 0.2
            addSubview(sprite)
            NSLayoutConstraint.activate([
                sprite.centerXAnchor.constraint(equalTo: leadingAnchor, constant: cellRect.midX),
                sprite.centerYAnchor.constraint(equalTo: topAnchor, constant: cellRect.midY - 8),
            ])

            if unlocked {
                // Name below sprite
                let name = DSTabView.dsLabel(entry.displayName, size: 8, bold: true, color: NSColor(white: 0.2, alpha: 1))
                name.shadow = nil
                addSubview(name)
                NSLayoutConstraint.activate([
                    name.centerXAnchor.constraint(equalTo: leadingAnchor, constant: cellRect.midX),
                    name.topAnchor.constraint(equalTo: sprite.bottomAnchor, constant: 1),
                ])

                // Gold dot if in party
                if partySet.contains(entry.id) {
                    let dot = NSView(frame: NSRect(
                        x: cellRect.maxX - 10,
                        y: cellRect.minY + 4,
                        width: 6,
                        height: 6
                    ))
                    dot.wantsLayer = true
                    dot.layer?.backgroundColor = CollectionTabView.goldDot.cgColor
                    dot.layer?.cornerRadius = 3
                    addSubview(dot)
                }
            } else {
                // Locked: show required level
                let lvlLabel = DSTabView.dsLabel("Lv.\(entry.unlockLevel)", size: 9, bold: false, color: NSColor.gray)
                lvlLabel.shadow = nil
                addSubview(lvlLabel)
                NSLayoutConstraint.activate([
                    lvlLabel.centerXAnchor.constraint(equalTo: leadingAnchor, constant: cellRect.midX),
                    lvlLabel.topAnchor.constraint(equalTo: sprite.bottomAnchor, constant: 1),
                ])
            }

            addHitRegion(HitRegion(id: "collection_\(index)", rect: cellRect, action: .showDetail(pokemonId: entry.id), enabled: unlocked))
        }
    }
}

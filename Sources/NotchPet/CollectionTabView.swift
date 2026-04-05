import AppKit

final class CollectionTabView: DSTabView {

    init() {
        super.init(backgroundImage: "bg_collection")
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Grid constants (approximate, matching the PC Box bg image)

    private static let gridOriginX: CGFloat = 40
    private static let gridOriginY: CGFloat = 50
    private static let columns = 6
    private static let rows = 5
    private static let cellSize: CGFloat = 70
    private static let cellGap: CGFloat = 5

    // MARK: - Update

    override func update(state: PetState) {
        // Remove old content but keep bg image at index 0
        subviews.dropFirst().forEach { $0.removeFromSuperview() }
        clearHitRegions()

        let catalog = PetCollection.catalog(for: state.level)
        let partySet = Set(state.party)

        let goldDot = NSColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1)

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

            // Sprite (centered in cell)
            let sprite = DSTabView.dsSprite(for: entry.id, shiny: isShiny, size: 40)
            sprite.alphaValue = unlocked ? 1.0 : 0.15
            addSubview(sprite)
            NSLayoutConstraint.activate([
                sprite.centerXAnchor.constraint(equalTo: leadingAnchor, constant: cellRect.midX),
                sprite.centerYAnchor.constraint(equalTo: topAnchor, constant: cellRect.midY - 6),
            ])

            if unlocked {
                // Name below sprite
                let name = DSTabView.dsLabel(entry.displayName, size: 8, bold: true)
                addSubview(name)
                NSLayoutConstraint.activate([
                    name.centerXAnchor.constraint(equalTo: leadingAnchor, constant: cellRect.midX),
                    name.topAnchor.constraint(equalTo: sprite.bottomAnchor, constant: 1),
                ])

                // Gold dot if in party
                if partySet.contains(entry.id) {
                    let dot = NSView()
                    dot.wantsLayer = true
                    dot.layer?.backgroundColor = goldDot.cgColor
                    dot.layer?.cornerRadius = 3
                    dot.translatesAutoresizingMaskIntoConstraints = false
                    addSubview(dot)
                    NSLayoutConstraint.activate([
                        dot.widthAnchor.constraint(equalToConstant: 6),
                        dot.heightAnchor.constraint(equalToConstant: 6),
                        dot.trailingAnchor.constraint(equalTo: leadingAnchor, constant: cellRect.maxX - 6),
                        dot.topAnchor.constraint(equalTo: topAnchor, constant: cellRect.minY + 4),
                    ])
                }

                // Selected pet highlight border
                if entry.id == state.selectedPet {
                    let border = NSView()
                    border.wantsLayer = true
                    border.layer?.borderColor = DSTabView.selectedRed.cgColor
                    border.layer?.borderWidth = 2
                    border.layer?.cornerRadius = 4
                    border.translatesAutoresizingMaskIntoConstraints = false
                    addSubview(border)
                    NSLayoutConstraint.activate([
                        border.leadingAnchor.constraint(equalTo: leadingAnchor, constant: cellRect.minX + 2),
                        border.topAnchor.constraint(equalTo: topAnchor, constant: cellRect.minY + 2),
                        border.widthAnchor.constraint(equalToConstant: cellRect.width - 4),
                        border.heightAnchor.constraint(equalToConstant: cellRect.height - 4),
                    ])
                }
            } else {
                // Locked: show required level
                let lvlLabel = DSTabView.dsLabel("Lv.\(entry.unlockLevel)", size: 9, bold: false, color: NSColor.gray)
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

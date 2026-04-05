import AppKit

final class AchievementsTabView: DSTabView {

    init() {
        super.init(backgroundImage: "bg_achievements")
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Grid Layout

    private static let gridOriginX: CGFloat = 60
    private static let gridOriginY: CGFloat = 50
    private static let cellSize: CGFloat = 100
    private static let gap: CGFloat = 8
    private static let columns = 4
    private static let rows = 4

    private func tierColor(_ tier: Achievement.Tier) -> NSColor {
        let c = tier.color
        return NSColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
    }

    // MARK: - Update

    override func update(state: PetState) {
        // Remove old content but keep bg image at index 0
        subviews.dropFirst().forEach { $0.removeFromSuperview() }
        clearHitRegions()

        // --- Header: achievement count ---
        let unlockedCount = state.achievements.filter { $0.unlocked }.count
        let totalCount = state.achievements.count
        let headerLabel = DSTabView.dsLabel("\(unlockedCount) / \(totalCount)", size: 13, bold: true, color: .white)
        addSubview(headerLabel)
        NSLayoutConstraint.activate([
            headerLabel.centerXAnchor.constraint(equalTo: leadingAnchor, constant: 260),
            headerLabel.topAnchor.constraint(equalTo: topAnchor, constant: 15),
        ])

        // --- Medal grid (4×4, first 16 achievements) ---
        let displayCount = min(state.achievements.count, AchievementsTabView.columns * AchievementsTabView.rows)

        for i in 0..<displayCount {
            let ach = state.achievements[i]
            let col = i % AchievementsTabView.columns
            let row = i / AchievementsTabView.columns

            let cellX = AchievementsTabView.gridOriginX + CGFloat(col) * (AchievementsTabView.cellSize + AchievementsTabView.gap)
            let cellY = AchievementsTabView.gridOriginY + CGFloat(row) * (AchievementsTabView.cellSize + AchievementsTabView.gap)
            let cx = cellX + AchievementsTabView.cellSize / 2
            let cy = cellY + AchievementsTabView.cellSize / 2

            // Medal icon
            if ach.unlocked {
                let star = DSTabView.dsLabel("\u{2605}", size: 20, bold: true, color: tierColor(ach.tier))
                addSubview(star)
                NSLayoutConstraint.activate([
                    star.centerXAnchor.constraint(equalTo: leadingAnchor, constant: cx),
                    star.centerYAnchor.constraint(equalTo: topAnchor, constant: cy - 8),
                ])

                // Tier-colored border glow
                let glowView = NSView()
                glowView.wantsLayer = true
                glowView.layer?.cornerRadius = AchievementsTabView.cellSize / 2 - 8
                glowView.layer?.borderWidth = 2
                glowView.layer?.borderColor = tierColor(ach.tier).withAlphaComponent(0.6).cgColor
                glowView.translatesAutoresizingMaskIntoConstraints = false
                addSubview(glowView, positioned: .below, relativeTo: star)
                let glowSize = AchievementsTabView.cellSize - 16
                NSLayoutConstraint.activate([
                    glowView.centerXAnchor.constraint(equalTo: leadingAnchor, constant: cx),
                    glowView.centerYAnchor.constraint(equalTo: topAnchor, constant: cy - 4),
                    glowView.widthAnchor.constraint(equalToConstant: glowSize),
                    glowView.heightAnchor.constraint(equalToConstant: glowSize),
                ])
            } else {
                let circle = DSTabView.dsLabel("\u{25CB}", size: 16, bold: false, color: .gray)
                addSubview(circle)
                NSLayoutConstraint.activate([
                    circle.centerXAnchor.constraint(equalTo: leadingAnchor, constant: cx),
                    circle.centerYAnchor.constraint(equalTo: topAnchor, constant: cy - 8),
                ])
            }

            // Achievement name below medal
            let nameColor: NSColor = ach.unlocked ? .white : .gray
            let nameLabel = DSTabView.dsLabel(ach.name, size: 8, bold: false, color: nameColor)
            nameLabel.alignment = .center
            nameLabel.lineBreakMode = .byTruncatingTail
            addSubview(nameLabel)
            NSLayoutConstraint.activate([
                nameLabel.centerXAnchor.constraint(equalTo: leadingAnchor, constant: cx),
                nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: cy + 16),
                nameLabel.widthAnchor.constraint(lessThanOrEqualToConstant: AchievementsTabView.cellSize - 4),
            ])

            // Hit region for each medal cell
            let cellRect = NSRect(x: cellX, y: cellY, width: AchievementsTabView.cellSize, height: AchievementsTabView.cellSize)
            addHitRegion(HitRegion(id: "ach_\(i)", rect: cellRect, action: .showDetail(pokemonId: ach.id)))
        }
    }
}

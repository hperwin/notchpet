import AppKit

final class AchievementsTabView: DSTabView {

    override var isFlipped: Bool { true }

    // DS palette
    private static let darkNavy = NSColor(red: 0x1a/255, green: 0x20/255, blue: 0x40/255, alpha: 1)
    private static let gold = NSColor(red: 0xF8/255, green: 0xA8/255, blue: 0x00/255, alpha: 1)
    private static let lockedGray = NSColor(red: 0x33/255, green: 0x33/255, blue: 0x33/255, alpha: 1)

    // Grid layout constants
    private static let gridOriginX: CGFloat = 30
    private static let gridOriginY: CGFloat = 60
    private static let cellW: CGFloat = 110
    private static let cellH: CGFloat = 75
    private static let medalDiameter: CGFloat = 50
    private static let columns = 4
    private static let rows = 4

    init() {
        super.init(backgroundColor: AchievementsTabView.darkNavy)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func tierColor(_ tier: Achievement.Tier) -> NSColor {
        let c = tier.color
        return NSColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
    }

    // MARK: - Update

    override func update(state: PetState) {
        subviews.forEach { $0.removeFromSuperview() }
        clearHitRegions()

        let unlockedCount = state.achievements.filter { $0.unlocked }.count
        let totalCount = state.achievements.count

        // --- Header: "MEDAL RALLY" ---
        let header = NSTextField(labelWithString: "MEDAL RALLY")
        header.font = NSFont.boldSystemFont(ofSize: 14)
        header.textColor = AchievementsTabView.gold
        header.drawsBackground = false
        header.isBordered = false
        header.isEditable = false
        header.shadow = DSTabView.dsShadow()
        header.sizeToFit()
        let headerX = (bounds.width - header.frame.width) / 2
        let headerFlippedY = bounds.height - 12 - header.frame.height
        header.frame.origin = NSPoint(x: headerX, y: headerFlippedY)
        addSubview(header)

        // --- Counter: "X / Y" ---
        let counter = NSTextField(labelWithString: "\(unlockedCount) / \(totalCount)")
        counter.font = NSFont.systemFont(ofSize: 12)
        counter.textColor = .white
        counter.drawsBackground = false
        counter.isBordered = false
        counter.isEditable = false
        counter.sizeToFit()
        let counterX = (bounds.width - counter.frame.width) / 2
        let counterFlippedY = bounds.height - 34 - counter.frame.height
        counter.frame.origin = NSPoint(x: counterX, y: counterFlippedY)
        addSubview(counter)

        // --- Medal grid (4x4) ---
        let displayCount = min(totalCount, AchievementsTabView.columns * AchievementsTabView.rows)
        let d = AchievementsTabView.medalDiameter
        let r = d / 2

        for i in 0..<displayCount {
            let ach = state.achievements[i]
            let col = i % AchievementsTabView.columns
            let row = i / AchievementsTabView.columns

            // Cell origin (top-down coordinates)
            let cellX = AchievementsTabView.gridOriginX + CGFloat(col) * AchievementsTabView.cellW
            let cellY = AchievementsTabView.gridOriginY + CGFloat(row) * AchievementsTabView.cellH

            // Medal circle center (top-down)
            let cx = cellX + AchievementsTabView.cellW / 2
            let cy = cellY + d / 2 + 2  // slight offset from top of cell

            // Circle view
            let circleX = cx - r
            let circleFlippedY = bounds.height - cy - r
            let circleView = NSView(frame: NSRect(x: circleX, y: circleFlippedY, width: d, height: d))
            circleView.wantsLayer = true
            circleView.layer?.cornerRadius = r

            if ach.unlocked {
                circleView.layer?.backgroundColor = AchievementsTabView.gold.cgColor

                // Tier-colored star inside
                let star = NSTextField(labelWithString: "\u{2605}")
                star.font = NSFont.boldSystemFont(ofSize: 20)
                star.textColor = tierColor(ach.tier)
                star.drawsBackground = false
                star.isBordered = false
                star.isEditable = false
                star.sizeToFit()
                star.frame.origin = NSPoint(
                    x: (d - star.frame.width) / 2,
                    y: (d - star.frame.height) / 2
                )
                circleView.addSubview(star)
            } else {
                circleView.layer?.backgroundColor = AchievementsTabView.lockedGray.cgColor
                circleView.layer?.borderWidth = 1
                circleView.layer?.borderColor = NSColor.gray.cgColor

                let circle = NSTextField(labelWithString: "\u{25CB}")
                circle.font = NSFont.systemFont(ofSize: 16)
                circle.textColor = .gray
                circle.drawsBackground = false
                circle.isBordered = false
                circle.isEditable = false
                circle.sizeToFit()
                circle.frame.origin = NSPoint(
                    x: (d - circle.frame.width) / 2,
                    y: (d - circle.frame.height) / 2
                )
                circleView.addSubview(circle)
            }

            addSubview(circleView)

            // Name label below medal
            let nameColor: NSColor = ach.unlocked ? .white : .gray
            let nameSize: CGFloat = 9
            let nameLabel = NSTextField(labelWithString: ach.name)
            nameLabel.font = NSFont.systemFont(ofSize: nameSize)
            nameLabel.textColor = nameColor
            nameLabel.drawsBackground = false
            nameLabel.isBordered = false
            nameLabel.isEditable = false
            nameLabel.alignment = .center
            nameLabel.lineBreakMode = .byTruncatingTail
            nameLabel.sizeToFit()

            // Cap width to cell width
            let maxNameW = AchievementsTabView.cellW - 4
            let nameW = min(nameLabel.frame.width, maxNameW)
            let nameTopY = cy + r + 4  // just below the circle (top-down)
            let nameFlippedY = bounds.height - nameTopY - nameLabel.frame.height
            nameLabel.frame = NSRect(
                x: cx - nameW / 2,
                y: nameFlippedY,
                width: nameW,
                height: nameLabel.frame.height
            )
            addSubview(nameLabel)

            // Hit region for the cell
            let cellFlippedY = bounds.height - cellY - AchievementsTabView.cellH
            let cellRect = NSRect(x: cellX, y: cellFlippedY,
                                  width: AchievementsTabView.cellW,
                                  height: AchievementsTabView.cellH)
            addHitRegion(HitRegion(id: "ach_\(i)", rect: cellRect, action: .showDetail(pokemonId: ach.id)))
        }
    }
}

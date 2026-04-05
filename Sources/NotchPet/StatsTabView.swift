import AppKit

final class StatsTabView: DSTabView {

    init() {
        super.init(backgroundImage: "bg_stats")
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Helpers

    private func formatXP(_ xp: Int) -> String {
        if xp >= 1_000_000 {
            return String(format: "%.1fM", Double(xp) / 1_000_000)
        } else if xp >= 1_000 {
            return String(format: "%.1fK", Double(xp) / 1_000)
        }
        return "\(xp)"
    }

    private func formatTime(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%d:%02d", h, m)
    }

    private func tierColor(_ tier: Achievement.Tier) -> NSColor {
        let c = tier.color
        return NSColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
    }

    // MARK: - Update

    override func update(state: PetState) {
        // Remove old content but keep bg image at index 0
        subviews.dropFirst().forEach { $0.removeFromSuperview() }
        clearHitRegions()

        // --- Avatar area (top-left) ---
        let shiny = state.useShiny && state.unlockedShinies.contains(state.selectedPet)
        let sprite = DSTabView.dsSprite(for: state.selectedPet, shiny: shiny, size: 50)
        addSubview(sprite)
        NSLayoutConstraint.activate([
            sprite.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            sprite.topAnchor.constraint(equalTo: topAnchor, constant: 25),
        ])

        // --- NAME field ---
        let entry = PetCollection.allPokemon.first { $0.id == state.selectedPet }
        let nameLabel = DSTabView.dsLabel(entry?.displayName ?? state.selectedPet, size: 14, bold: true)
        addSubview(nameLabel)
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 160),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 40),
        ])

        // --- ID No. field ---
        let idStr = String(format: "#%05d", state.prestigeCount)
        let idLabel = DSTabView.dsLabel(idStr, size: 11, bold: false, color: .white)
        addSubview(idLabel)
        NSLayoutConstraint.activate([
            idLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 160),
            idLabel.topAnchor.constraint(equalTo: topAnchor, constant: 80),
        ])

        // --- MONEY field (Total XP) ---
        let moneyLabel = DSTabView.dsLabel(formatXP(state.totalXPEarned), size: 11, bold: true)
        addSubview(moneyLabel)
        NSLayoutConstraint.activate([
            moneyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 100),
            moneyLabel.topAnchor.constraint(equalTo: topAnchor, constant: 130),
        ])

        // --- POKeDEX field (unlocked achievements / 30) ---
        let unlockedCount = state.achievements.filter { $0.unlocked }.count
        let dexLabel = DSTabView.dsLabel("\(unlockedCount) / 30", size: 11, bold: true)
        addSubview(dexLabel)
        NSLayoutConstraint.activate([
            dexLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 200),
            dexLabel.topAnchor.constraint(equalTo: topAnchor, constant: 130),
        ])

        // --- SCORE field ---
        let scoreLabel = DSTabView.dsLabel("Level \(state.level)", size: 11, bold: true)
        addSubview(scoreLabel)
        NSLayoutConstraint.activate([
            scoreLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 100),
            scoreLabel.topAnchor.constraint(equalTo: topAnchor, constant: 165),
        ])

        // --- TIME field ---
        let timeLabel = DSTabView.dsLabel(formatTime(minutes: state.sessionActiveMinutes), size: 11, bold: false, color: .white)
        addSubview(timeLabel)
        NSLayoutConstraint.activate([
            timeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 100),
            timeLabel.topAnchor.constraint(equalTo: topAnchor, constant: 195),
        ])

        // --- ADVENTURE STARTED (evolution stage) ---
        let stageLabel = DSTabView.dsLabel(state.evolutionStage.name, size: 11, bold: false, color: .white)
        addSubview(stageLabel)
        NSLayoutConstraint.activate([
            stageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 100),
            stageLabel.topAnchor.constraint(equalTo: topAnchor, constant: 220),
        ])

        // --- GYM BADGES grid (2×4, right side) ---
        let badgeOriginX: CGFloat = 340
        let badgeOriginY: CGFloat = 90
        let cellSize: CGFloat = 35

        for i in 0..<8 {
            let col = i % 2
            let row = i / 2
            let cx = badgeOriginX + CGFloat(col) * cellSize + cellSize / 2
            let cy = badgeOriginY + CGFloat(row) * cellSize + cellSize / 2

            if i < state.achievements.count {
                let ach = state.achievements[i]
                let symbol = ach.unlocked ? "\u{2605}" : "\u{25CB}"  // ★ or ○
                let color = ach.unlocked ? tierColor(ach.tier) : NSColor.gray
                let fontSize: CGFloat = ach.unlocked ? 18 : 14

                let badge = DSTabView.dsLabel(symbol, size: fontSize, bold: true, color: color)
                addSubview(badge)
                NSLayoutConstraint.activate([
                    badge.centerXAnchor.constraint(equalTo: leadingAnchor, constant: cx),
                    badge.centerYAnchor.constraint(equalTo: topAnchor, constant: cy),
                ])
            }
        }

        // --- SIGNATURE area (streak + WPM) ---
        let sigText = "\(state.typingStreak)d streak \u{00B7} \(Int(state.currentWPM)) WPM"
        let sigLabel = DSTabView.dsLabel(sigText, size: 10, bold: false, color: .white)
        addSubview(sigLabel)
        NSLayoutConstraint.activate([
            sigLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 340),
            sigLabel.topAnchor.constraint(equalTo: topAnchor, constant: 220),
        ])

        // --- Prestige button (bottom nav bar) ---
        if state.level >= 20 {
            let prestigeLabel = DSTabView.dsLabel("PRESTIGE \u{2605}", size: 12, bold: true, color: DSTabView.hoverGold)
            addSubview(prestigeLabel)
            NSLayoutConstraint.activate([
                prestigeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                prestigeLabel.topAnchor.constraint(equalTo: topAnchor, constant: 350),
            ])

            let prestigeRect = NSRect(x: 0, y: 340, width: 520, height: 40)
            addHitRegion(HitRegion(id: "prestige", rect: prestigeRect, action: .prestige))
        }
    }
}

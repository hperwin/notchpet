import AppKit

final class AchievementsTabView: DSTabView {

    override var isFlipped: Bool { true }

    // Palette
    private static let darkBg = NSColor(red: 0x11/255, green: 0x11/255, blue: 0x11/255, alpha: 1)
    private static let gold = NSColor(red: 0xF8/255, green: 0xA8/255, blue: 0x00/255, alpha: 1)
    private static let cardBg = NSColor(red: 0x1e/255, green: 0x1e/255, blue: 0x1e/255, alpha: 1)
    private static let cardBorder = NSColor(red: 0x33/255, green: 0x33/255, blue: 0x33/255, alpha: 1)
    private static let descGray = NSColor(red: 0x88/255, green: 0x88/255, blue: 0x88/255, alpha: 1)
    private static let trackColor = NSColor(red: 0x22/255, green: 0x22/255, blue: 0x22/255, alpha: 1)
    private static let greenCheck = NSColor(red: 0x4C/255, green: 0xD9/255, blue: 0x64/255, alpha: 1)

    // Tier colors
    private static let tierCommon = NSColor(red: 0x99/255, green: 0x99/255, blue: 0x99/255, alpha: 1)
    private static let tierRare = NSColor(red: 0x4D/255, green: 0x80/255, blue: 0xFF/255, alpha: 1)
    private static let tierLegendary = NSColor(red: 0xFF/255, green: 0xD7/255, blue: 0x00/255, alpha: 1)

    // Layout
    private static let rowHeight: CGFloat = 60
    private static let rowGap: CGFloat = 6
    private static let padX: CGFloat = 8
    private static let padTop: CGFloat = 34
    private static let cardWidth: CGFloat = 504  // 520 - 2*padX

    private let scrollView = NSScrollView()
    private let contentView = AchievementsFlippedView()

    init() {
        super.init(backgroundColor: AchievementsTabView.darkBg)
        setupScrollView()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var disableHoverTracking: Bool { true }

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

    private func tierColor(_ tier: Achievement.Tier) -> NSColor {
        switch tier {
        case .common: return Self.tierCommon
        case .rare: return Self.tierRare
        case .legendary: return Self.tierLegendary
        }
    }

    private func progress(for achievement: Achievement, state: PetState) -> (current: Int, target: Int) {
        switch achievement.id {
        case "first_words": return (state.totalWordsTyped, 100)
        case "chatterbox": return (state.totalWordsTyped, 1000)
        case "novelist": return (state.totalWordsTyped, 10000)
        case "author": return (state.totalWordsTyped, 100000)
        case "level5": return (state.highestLevel, 5)
        case "level20": return (state.highestLevel, 20)
        case "streak3": return (state.typingStreak, 3)
        case "streak7": return (state.typingStreak, 7)
        case "streak30": return (state.typingStreak, 30)
        case "hatchling": return (state.highestLevel, 5)
        case "adult": return (state.highestLevel, 30)
        case "evolved": return (state.highestLevel, 50)
        case "speed_demon": return (Int(state.currentWPM), 80)
        case "cosmetic5": return (state.cosmetics.filter(\.owned).count, 5)
        case "mutation": return (state.mutationColor != nil ? 1 : 0, 1)
        default: return (0, 1)
        }
    }

    // MARK: - Update

    override func update(state: PetState) {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        clearHitRegions()

        let unlockedCount = state.achievements.filter(\.unlocked).count
        let totalCount = state.achievements.count

        // Sort: unlocked first (by date), then locked by progress descending
        let sorted = state.achievements.sorted { a, b in
            if a.unlocked && !b.unlocked { return true }
            if !a.unlocked && b.unlocked { return false }
            if a.unlocked && b.unlocked {
                // Both unlocked — sort by date (earliest first)
                let da = a.unlockedDate ?? .distantPast
                let db = b.unlockedDate ?? .distantPast
                return da < db
            }
            // Both locked — sort by progress (closest to completion first)
            let pa = progress(for: a, state: state)
            let pb = progress(for: b, state: state)
            let progA = pa.target > 0 ? Double(pa.current) / Double(pa.target) : 0
            let progB = pb.target > 0 ? Double(pb.current) / Double(pb.target) : 0
            return progA > progB
        }

        // Header
        let header = makeLabel("Achievements (\(unlockedCount)/\(totalCount))", size: 13, bold: true, color: Self.gold)
        header.frame = NSRect(x: 0, y: 8, width: 520, height: 18)
        header.alignment = .center
        contentView.addSubview(header)

        // Content height
        let contentHeight = Self.padTop + CGFloat(sorted.count) * (Self.rowHeight + Self.rowGap) + 10
        contentView.frame = NSRect(x: 0, y: 0, width: 520, height: max(contentHeight, 380))

        for (index, ach) in sorted.enumerated() {
            let rowY = Self.padTop + CGFloat(index) * (Self.rowHeight + Self.rowGap)
            let cardRect = NSRect(x: Self.padX, y: rowY, width: Self.cardWidth, height: Self.rowHeight)

            // Card background
            let card = NSView(frame: cardRect)
            card.wantsLayer = true
            card.layer?.cornerRadius = 8
            card.layer?.backgroundColor = Self.cardBg.cgColor
            card.layer?.borderColor = Self.cardBorder.cgColor
            card.layer?.borderWidth = 1
            contentView.addSubview(card)

            // Left: star icon (inside card, relative coords)
            let starText = ach.unlocked ? "\u{2605}" : "\u{25CB}"
            let starColor = ach.unlocked ? Self.gold : NSColor.gray
            let star = makeLabel(starText, size: 20, bold: true, color: starColor)
            star.frame = NSRect(x: 10, y: (Self.rowHeight - 24) / 2, width: 24, height: 24)
            star.alignment = .center
            card.addSubview(star)

            // Middle: name + description
            let nameColor: NSColor = ach.unlocked ? .white : NSColor(white: 0.7, alpha: 1)
            let nameLabel = makeLabel(ach.name, size: 12, bold: true, color: nameColor)
            nameLabel.frame = NSRect(x: 42, y: 10, width: 260, height: 16)
            nameLabel.lineBreakMode = .byTruncatingTail
            card.addSubview(nameLabel)

            let descLabel = makeLabel(ach.description, size: 10, bold: false, color: Self.descGray)
            descLabel.frame = NSRect(x: 42, y: 28, width: 260, height: 14)
            descLabel.lineBreakMode = .byTruncatingTail
            card.addSubview(descLabel)

            // Right side
            if ach.unlocked {
                // Green checkmark
                let check = makeLabel("\u{2713}", size: 16, bold: true, color: Self.greenCheck)
                check.frame = NSRect(x: Self.cardWidth - 110, y: 10, width: 20, height: 20)
                check.alignment = .center
                card.addSubview(check)

                let doneLabel = makeLabel("Done", size: 10, bold: false, color: Self.greenCheck)
                doneLabel.frame = NSRect(x: Self.cardWidth - 90, y: 13, width: 34, height: 14)
                card.addSubview(doneLabel)

                // XP badge
                let xpBadge = makeLabel("+\(ach.xpReward) XP", size: 9, bold: true, color: Self.gold)
                xpBadge.frame = NSRect(x: Self.cardWidth - 55, y: 13, width: 45, height: 14)
                xpBadge.alignment = .right
                card.addSubview(xpBadge)
            } else {
                // Progress bar
                let prog = progress(for: ach, state: state)
                let clamped = min(prog.current, prog.target)
                let fraction = prog.target > 0 ? CGFloat(clamped) / CGFloat(prog.target) : 0

                let barX: CGFloat = Self.cardWidth - 160
                let barW: CGFloat = 100
                let barH: CGFloat = 10
                let barY: CGFloat = (Self.rowHeight - barH) / 2

                // Track
                let track = NSView(frame: NSRect(x: barX, y: barY, width: barW, height: barH))
                track.wantsLayer = true
                track.layer?.cornerRadius = barH / 2
                track.layer?.backgroundColor = Self.trackColor.cgColor
                card.addSubview(track)

                // Fill
                let fillW = max(barW * fraction, fraction > 0 ? barH : 0)  // min width for visibility
                let fill = NSView(frame: NSRect(x: 0, y: 0, width: fillW, height: barH))
                fill.wantsLayer = true
                fill.layer?.cornerRadius = barH / 2
                fill.layer?.backgroundColor = Self.gold.cgColor
                track.addSubview(fill)

                // Progress text
                let progText = makeLabel("\(clamped)/\(prog.target)", size: 9, bold: false, color: NSColor(white: 0.6, alpha: 1))
                progText.frame = NSRect(x: barX + barW + 6, y: barY - 2, width: 50, height: 14)
                card.addSubview(progText)
            }

            // Tier dot
            let dotSize: CGFloat = 6
            let dot = NSView(frame: NSRect(x: 42, y: Self.rowHeight - 14, width: dotSize, height: dotSize))
            dot.wantsLayer = true
            dot.layer?.cornerRadius = dotSize / 2
            dot.layer?.backgroundColor = tierColor(ach.tier).cgColor
            card.addSubview(dot)

            let tierLabel = makeLabel(ach.tier.name, size: 8, bold: false, color: tierColor(ach.tier))
            tierLabel.frame = NSRect(x: 52, y: Self.rowHeight - 16, width: 60, height: 12)
            card.addSubview(tierLabel)

            // Hit region
            addHitRegion(HitRegion(id: "ach_\(index)", rect: cardRect, action: .showDetail(pokemonId: ach.id)))
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

private class AchievementsFlippedView: NSView {
    override var isFlipped: Bool { true }
}

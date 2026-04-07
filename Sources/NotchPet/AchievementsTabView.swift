import AppKit

final class AchievementsTabView: DSTabView {

    override var isFlipped: Bool { true }
    override var disableHoverTracking: Bool { true }

    // Palette
    private static let darkBg = NSColor(red: 0x0d/255, green: 0x0d/255, blue: 0x0d/255, alpha: 1)
    private static let gold = NSColor(red: 0xF8/255, green: 0xA8/255, blue: 0x00/255, alpha: 1)
    private static let cardBg = NSColor(red: 0x1a/255, green: 0x1a/255, blue: 0x1a/255, alpha: 1)
    private static let descGray = NSColor(red: 0x66/255, green: 0x66/255, blue: 0x66/255, alpha: 1)
    private static let trackColor = NSColor(red: 0x25/255, green: 0x25/255, blue: 0x25/255, alpha: 1)
    private static let greenDone = NSColor(red: 0x34/255, green: 0xC7/255, blue: 0x59/255, alpha: 1)
    private static let lockedText = NSColor(red: 0x55/255, green: 0x55/255, blue: 0x55/255, alpha: 1)
    private static let progressText = NSColor(red: 0x66/255, green: 0x66/255, blue: 0x66/255, alpha: 1)

    // Tier icon colors
    private static let tierCommonGold = NSColor(red: 0xF8/255, green: 0xA8/255, blue: 0x00/255, alpha: 1)
    private static let tierRare = NSColor(red: 0x4D/255, green: 0x80/255, blue: 0xFF/255, alpha: 1)
    private static let tierLegendary = NSColor(red: 0xFF/255, green: 0xD7/255, blue: 0x00/255, alpha: 1)

    // Layout
    private static let rowHeight: CGFloat = 50
    private static let rowGap: CGFloat = 6
    private static let padX: CGFloat = 8
    private static let padTop: CGFloat = 38
    private static let cardWidth: CGFloat = 504

    private let scrollView = NSScrollView()
    private let contentView = AchievementsFlippedView()

    init() {
        super.init(backgroundColor: Self.darkBg)
        setupScrollView()
    }

    required init?(coder: NSCoder) { fatalError() }

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

    private func tierIconColor(_ tier: Achievement.Tier, unlocked: Bool) -> NSColor {
        guard unlocked else { return Self.trackColor }
        switch tier {
        case .common: return Self.tierCommonGold
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
                let da = a.unlockedDate ?? .distantPast
                let db = b.unlockedDate ?? .distantPast
                return da < db
            }
            let pa = progress(for: a, state: state)
            let pb = progress(for: b, state: state)
            let progA = pa.target > 0 ? Double(pa.current) / Double(pa.target) : 0
            let progB = pb.target > 0 ? Double(pb.current) / Double(pb.target) : 0
            return progA > progB
        }

        // Header: title + pill badge
        let headerY: CGFloat = 8
        let titleText = "Achievements"
        let badgeText = "\(unlockedCount)/\(totalCount)"

        let titleLabel = makeLabel(titleText, size: 13, bold: true, color: .white)
        titleLabel.sizeToFit()
        let badgeLabel = makeLabel(badgeText, size: 10, bold: true, color: NSColor(red: 0x1a/255, green: 0x1a/255, blue: 0x1a/255, alpha: 1))
        badgeLabel.sizeToFit()

        let badgePadH: CGFloat = 8
        let badgePadV: CGFloat = 2
        let badgeW = badgeLabel.frame.width + badgePadH * 2
        let badgeH = badgeLabel.frame.height + badgePadV * 2
        let totalHeaderW = titleLabel.frame.width + 6 + badgeW
        let headerX = (520 - totalHeaderW) / 2

        titleLabel.frame = NSRect(x: headerX, y: headerY, width: titleLabel.frame.width, height: 18)
        contentView.addSubview(titleLabel)

        let pillX = headerX + titleLabel.frame.width + 6
        let pillY = headerY + (18 - badgeH) / 2
        let pill = NSView(frame: NSRect(x: pillX, y: pillY, width: badgeW, height: badgeH))
        pill.wantsLayer = true
        pill.layer?.cornerRadius = badgeH / 2
        pill.layer?.backgroundColor = Self.gold.cgColor
        contentView.addSubview(pill)

        badgeLabel.frame = NSRect(x: badgePadH, y: badgePadV - 1, width: badgeLabel.frame.width, height: badgeLabel.frame.height)
        pill.addSubview(badgeLabel)

        // Content height
        let contentHeight = Self.padTop + CGFloat(sorted.count) * (Self.rowHeight + Self.rowGap) + 10
        contentView.frame = NSRect(x: 0, y: 0, width: 520, height: max(contentHeight, 380))

        for (index, ach) in sorted.enumerated() {
            let rowY = Self.padTop + CGFloat(index) * (Self.rowHeight + Self.rowGap)
            let cardRect = NSRect(x: Self.padX, y: rowY, width: Self.cardWidth, height: Self.rowHeight)

            // Card background — no border
            let card = NSView(frame: cardRect)
            card.wantsLayer = true
            card.layer?.cornerRadius = 10
            card.layer?.backgroundColor = Self.cardBg.cgColor
            contentView.addSubview(card)

            // Left: icon circle (28pt)
            let circleSize: CGFloat = 28
            let circleX: CGFloat = 8
            let circleY: CGFloat = (Self.rowHeight - circleSize) / 2
            let circleView = NSView(frame: NSRect(x: circleX, y: circleY, width: circleSize, height: circleSize))
            circleView.wantsLayer = true
            circleView.layer?.cornerRadius = circleSize / 2

            let iconColor = tierIconColor(ach.tier, unlocked: ach.unlocked)
            circleView.layer?.backgroundColor = iconColor.cgColor

            // Legendary glow
            if ach.unlocked && ach.tier == .legendary {
                circleView.layer?.shadowColor = Self.tierLegendary.cgColor
                circleView.layer?.shadowOffset = .zero
                circleView.layer?.shadowRadius = 6
                circleView.layer?.shadowOpacity = 0.7
            }

            card.addSubview(circleView)

            // Icon text inside circle
            let iconText: String
            let iconColor2: NSColor
            if ach.unlocked {
                iconText = "\u{2713}"  // checkmark
                iconColor2 = .white
            } else {
                iconText = "\u{25CB}"  // open circle
                iconColor2 = NSColor(white: 0.4, alpha: 1)
            }
            let iconLabel = makeLabel(iconText, size: ach.unlocked ? 14 : 12, bold: true, color: iconColor2)
            iconLabel.alignment = .center
            iconLabel.frame = NSRect(x: 0, y: (circleSize - 16) / 2, width: circleSize, height: 16)
            circleView.addSubview(iconLabel)

            // Middle: name + description
            let textX: CGFloat = 44
            let rightAreaWidth: CGFloat = 100
            let textW: CGFloat = Self.cardWidth - textX - rightAreaWidth - 12

            let nameColor: NSColor = ach.unlocked ? .white : Self.lockedText
            let nameLabel = makeLabel(ach.name, size: 12, bold: true, color: nameColor)
            nameLabel.frame = NSRect(x: textX, y: 10, width: textW, height: 16)
            nameLabel.lineBreakMode = .byTruncatingTail
            card.addSubview(nameLabel)

            let descLabel = makeLabel(ach.description, size: 10, bold: false, color: Self.descGray)
            descLabel.frame = NSRect(x: textX, y: 27, width: textW, height: 14)
            descLabel.lineBreakMode = .byTruncatingTail
            card.addSubview(descLabel)

            // Right side (100pt area)
            let rightX: CGFloat = Self.cardWidth - rightAreaWidth - 8

            if ach.unlocked {
                // Green "Done" pill badge
                let donePillW: CGFloat = 48
                let donePillH: CGFloat = 20
                let donePillY: CGFloat = (Self.rowHeight - donePillH) / 2
                let donePill = NSView(frame: NSRect(x: rightX + (rightAreaWidth - donePillW) / 2, y: donePillY, width: donePillW, height: donePillH))
                donePill.wantsLayer = true
                donePill.layer?.cornerRadius = donePillH / 2
                donePill.layer?.backgroundColor = Self.greenDone.cgColor
                card.addSubview(donePill)

                let doneLabel = makeLabel("Done", size: 10, bold: true, color: .white)
                doneLabel.alignment = .center
                doneLabel.frame = NSRect(x: 0, y: 2, width: donePillW, height: 14)
                donePill.addSubview(doneLabel)
            } else {
                // Progress bar + fraction text
                let prog = progress(for: ach, state: state)
                let clamped = min(prog.current, prog.target)
                let fraction = prog.target > 0 ? CGFloat(clamped) / CGFloat(prog.target) : 0

                let barW: CGFloat = 88
                let barH: CGFloat = 6
                let barX: CGFloat = rightX + (rightAreaWidth - barW) / 2
                let barY: CGFloat = 15

                // Track
                let track = NSView(frame: NSRect(x: barX, y: barY, width: barW, height: barH))
                track.wantsLayer = true
                track.layer?.cornerRadius = barH / 2
                track.layer?.backgroundColor = Self.trackColor.cgColor
                card.addSubview(track)

                // Fill
                let fillW = max(barW * fraction, fraction > 0 ? barH : 0)
                let fill = NSView(frame: NSRect(x: 0, y: 0, width: fillW, height: barH))
                fill.wantsLayer = true
                fill.layer?.cornerRadius = barH / 2
                fill.layer?.backgroundColor = Self.gold.cgColor
                track.addSubview(fill)

                // Progress text below bar
                let progLabel = makeLabel("\(clamped)/\(prog.target)", size: 9, bold: false, color: Self.progressText)
                progLabel.alignment = .center
                progLabel.frame = NSRect(x: barX, y: barY + barH + 3, width: barW, height: 12)
                card.addSubview(progLabel)
            }

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

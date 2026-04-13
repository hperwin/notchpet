import AppKit

final class ProfileTabView: DSTabView {

    override var isFlipped: Bool { true }
    override var disableHoverTracking: Bool { true }

    private static let darkBg = NSColor(red: 0x0d/255.0, green: 0x0d/255.0, blue: 0x0d/255.0, alpha: 1)
    private static let panelW: CGFloat = 580
    private static let contentW: CGFloat = 560
    private static let padX: CGFloat = 10

    // Achievement palette
    private static let descGray = NSColor(red: 0x66/255.0, green: 0x66/255.0, blue: 0x66/255.0, alpha: 1)
    private static let trackColor = NSColor(red: 0x25/255.0, green: 0x25/255.0, blue: 0x25/255.0, alpha: 1)
    private static let greenDone = NSColor(red: 0x34/255.0, green: 0xC7/255.0, blue: 0x59/255.0, alpha: 1)
    private static let lockedText = NSColor(red: 0x55/255.0, green: 0x55/255.0, blue: 0x55/255.0, alpha: 1)
    private static let progressText = NSColor(red: 0x66/255.0, green: 0x66/255.0, blue: 0x66/255.0, alpha: 1)

    // Tier colors
    private static let tierCommonGold = NSColor(red: 0xF8/255.0, green: 0xA8/255.0, blue: 0x00/255.0, alpha: 1)
    private static let tierRare = NSColor(red: 0x4D/255.0, green: 0x80/255.0, blue: 0xFF/255.0, alpha: 1)
    private static let tierLegendary = NSColor(red: 0xFF/255.0, green: 0xD7/255.0, blue: 0x00/255.0, alpha: 1)

    private let scrollView = NSScrollView()
    private let contentView = ProfileFlippedView()

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

    // MARK: - Update

    override func update(state: PetState) {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        clearHitRegions()

        let pad = DS.outerPad
        let ip = DS.innerPad
        let gap = DS.cardGap
        var curY: CGFloat = pad

        // ── Stats Summary Card ──

        let statsH: CGFloat = 100
        let statsCard = DS.makeCard(frame: NSRect(x: Self.padX, y: curY, width: Self.contentW, height: statsH))
        contentView.addSubview(statsCard)

        placeLabel("Stats", in: statsCard, x: ip, y: ip, size: 12, bold: true, color: DS.gold)

        // Row 1: Words + Keys
        let row1Y: CGFloat = 34
        let colW: CGFloat = Self.contentW / 3

        placeLabel("\(state.totalWordsTyped)", in: statsCard, x: ip, y: row1Y, size: 20, bold: true, color: DS.textPrimary)
        placeLabel("words typed", in: statsCard, x: ip, y: row1Y + 22, size: 9, color: DS.textSecondary)

        let wpmStr = "WPM \(Int(state.currentWPM))"
        placeLabel(wpmStr, in: statsCard, x: colW + ip, y: row1Y, size: 20, bold: true, color: DS.textPrimary)
        placeLabel("current speed", in: statsCard, x: colW + ip, y: row1Y + 22, size: 9, color: DS.textSecondary)

        // Streaks in third column
        var streakParts: [String] = []
        if state.typingStreak > 0 { streakParts.append("\(state.typingStreak)d typing") }
        if state.loginStreak > 0 { streakParts.append("\(state.loginStreak)d login") }
        let streakStr = streakParts.isEmpty ? "--" : streakParts.joined(separator: ", ")
        placeLabel(streakStr, in: statsCard, x: colW * 2 + ip, y: row1Y, size: 14, bold: true, color: DS.textPrimary)
        placeLabel("streaks", in: statsCard, x: colW * 2 + ip, y: row1Y + 18, size: 9, color: DS.textSecondary)

        // Berries pill at bottom-right of stats card
        let berryStr = "\(state.totalFoodEaten) berries fed"
        let berryPillW = makePill(berryStr, in: statsCard, x: Self.contentW - 120 - ip, y: statsH - 28)
        _ = berryPillW

        curY += statsH + gap

        // ── Party Summary Card ──

        let partyCount = min(state.party.count, 6)
        let partyRowH: CGFloat = 28
        let partyHeaderH: CGFloat = 32
        let partyH: CGFloat = partyHeaderH + CGFloat(partyCount) * partyRowH + 8
        let partyCard = DS.makeCard(frame: NSRect(x: Self.padX, y: curY, width: Self.contentW, height: partyH))
        contentView.addSubview(partyCard)

        placeLabel("Party", in: partyCard, x: ip, y: 8, size: 12, bold: true, color: DS.gold)

        for (i, pokemonId) in state.party.prefix(6).enumerated() {
            let inst = state.pokemonInstances[pokemonId]
            let entry = PetCollection.entry(for: pokemonId)
            let rowY = partyHeaderH + CGFloat(i) * partyRowH

            let shiny = state.useShiny && state.unlockedShinies.contains(pokemonId)
            let spriteSize: CGFloat = 20
            let spriteView = NSImageView(frame: NSRect(x: ip, y: rowY + 4, width: spriteSize, height: spriteSize))
            spriteView.image = PetCollection.spriteImage(for: pokemonId, shiny: shiny)
            spriteView.imageScaling = .scaleProportionallyUpOrDown
            spriteView.wantsLayer = true
            spriteView.layer?.magnificationFilter = .nearest
            partyCard.addSubview(spriteView)

            let displayName = entry?.displayName ?? pokemonId
            placeLabel(displayName, in: partyCard, x: ip + 26, y: rowY + 6, size: 11, bold: true, color: DS.textPrimary)

            let lvl = inst?.level ?? 1
            placeLabel("Lv.\(lvl)", in: partyCard, x: ip + 120, y: rowY + 7, size: 9, color: DS.textSecondary)

            // XP bar
            let barX: CGFloat = ip + 160
            let progress = inst?.levelProgress ?? 0
            let barW: CGFloat = Self.contentW - barX - ip - 60
            if barW >= 20 {
                DS.makeBar(in: partyCard, x: barX, y: rowY + 12, width: barW, progress: progress)
            }

            // Move name (right side)
            let topMove = inst?.moves.last ?? "--"
            let moveLabel = DS.label(topMove, size: 9, bold: false, color: DS.gold)
            moveLabel.sizeToFit()
            moveLabel.frame.origin = NSPoint(x: Self.contentW - ip - moveLabel.frame.width, y: rowY + 6)
            partyCard.addSubview(moveLabel)
        }

        curY += partyH + gap

        // ── Achievements Section ──

        let unlockedCount = state.achievements.filter(\.unlocked).count
        let totalCount = state.achievements.count

        // Section header
        let achHeaderLabel = DS.label("Achievements", size: 12, bold: true, color: DS.gold)
        achHeaderLabel.sizeToFit()
        achHeaderLabel.frame.origin = NSPoint(x: Self.padX + ip, y: curY)
        contentView.addSubview(achHeaderLabel)

        let badgeText = "\(unlockedCount)/\(totalCount)"
        let badge = DS.label(badgeText, size: 9, bold: true, color: NSColor(red: 0x1a/255.0, green: 0x1a/255.0, blue: 0x1a/255.0, alpha: 1))
        badge.sizeToFit()
        let badgePadH: CGFloat = 6
        let badgeW = badge.frame.width + badgePadH * 2
        let badgeH: CGFloat = 16
        let badgePill = NSView(frame: NSRect(
            x: Self.padX + ip + achHeaderLabel.frame.width + 6,
            y: curY + 1,
            width: badgeW,
            height: badgeH
        ))
        badgePill.wantsLayer = true
        badgePill.layer?.cornerRadius = badgeH / 2
        badgePill.layer?.backgroundColor = DS.gold.cgColor
        contentView.addSubview(badgePill)
        badge.frame = NSRect(x: badgePadH, y: 1, width: badge.frame.width, height: badge.frame.height)
        badgePill.addSubview(badge)

        curY += 22

        // Sort: unlocked first, then by progress
        let sorted = state.achievements.sorted { a, b in
            if a.unlocked && !b.unlocked { return true }
            if !a.unlocked && b.unlocked { return false }
            if a.unlocked && b.unlocked {
                let da = a.unlockedDate ?? .distantPast
                let db = b.unlockedDate ?? .distantPast
                return da < db
            }
            let pa = achievementProgress(for: a, state: state)
            let pb = achievementProgress(for: b, state: state)
            let progA = pa.target > 0 ? Double(pa.current) / Double(pa.target) : 0
            let progB = pb.target > 0 ? Double(pb.current) / Double(pb.target) : 0
            return progA > progB
        }

        let rowH: CGFloat = 40
        let rowGap: CGFloat = 4

        for (index, ach) in sorted.enumerated() {
            let rowY = curY + CGFloat(index) * (rowH + rowGap)
            let cardRect = NSRect(x: Self.padX, y: rowY, width: Self.contentW, height: rowH)

            let card = DS.makeCard(frame: cardRect)
            contentView.addSubview(card)

            // Icon circle
            let circleSize: CGFloat = 22
            let circleX: CGFloat = 8
            let circleY: CGFloat = (rowH - circleSize) / 2
            let circleView = NSView(frame: NSRect(x: circleX, y: circleY, width: circleSize, height: circleSize))
            circleView.wantsLayer = true
            circleView.layer?.cornerRadius = circleSize / 2
            circleView.layer?.backgroundColor = tierIconColor(ach.tier, unlocked: ach.unlocked).cgColor
            card.addSubview(circleView)

            let iconText: String
            let iconColor: NSColor
            if ach.unlocked {
                iconText = "\u{2713}"
                iconColor = .white
            } else {
                iconText = "\u{25CB}"
                iconColor = NSColor(white: 0.4, alpha: 1)
            }
            let iconLabel = makeLabel(iconText, size: ach.unlocked ? 12 : 10, bold: true, color: iconColor)
            iconLabel.alignment = .center
            iconLabel.frame = NSRect(x: 0, y: (circleSize - 14) / 2, width: circleSize, height: 14)
            circleView.addSubview(iconLabel)

            // Name
            let textX: CGFloat = 36
            let rightAreaW: CGFloat = 80
            let textW: CGFloat = Self.contentW - textX - rightAreaW - 12
            let nameColor: NSColor = ach.unlocked ? .white : Self.lockedText
            let nameLabel = makeLabel(ach.name, size: 11, bold: true, color: nameColor)
            nameLabel.frame = NSRect(x: textX, y: 6, width: textW, height: 14)
            nameLabel.lineBreakMode = .byTruncatingTail
            card.addSubview(nameLabel)

            // Description
            let descLabel = makeLabel(ach.description, size: 9, bold: false, color: Self.descGray)
            descLabel.frame = NSRect(x: textX, y: 21, width: textW, height: 12)
            descLabel.lineBreakMode = .byTruncatingTail
            card.addSubview(descLabel)

            // Right side: Done pill or progress bar
            let rightX: CGFloat = Self.contentW - rightAreaW - 8

            if ach.unlocked {
                let donePillW: CGFloat = 40
                let donePillH: CGFloat = 16
                let donePillY: CGFloat = (rowH - donePillH) / 2
                let donePill = NSView(frame: NSRect(x: rightX + (rightAreaW - donePillW) / 2, y: donePillY, width: donePillW, height: donePillH))
                donePill.wantsLayer = true
                donePill.layer?.cornerRadius = donePillH / 2
                donePill.layer?.backgroundColor = Self.greenDone.cgColor
                card.addSubview(donePill)

                let doneLabel = makeLabel("Done", size: 9, bold: true, color: .white)
                doneLabel.alignment = .center
                doneLabel.frame = NSRect(x: 0, y: 1, width: donePillW, height: 12)
                donePill.addSubview(doneLabel)
            } else {
                let prog = achievementProgress(for: ach, state: state)
                let clamped = min(prog.current, prog.target)
                let fraction = prog.target > 0 ? CGFloat(clamped) / CGFloat(prog.target) : 0

                let barW: CGFloat = 70
                let barH: CGFloat = 5
                let barX: CGFloat = rightX + (rightAreaW - barW) / 2
                let barY: CGFloat = 12

                let track = NSView(frame: NSRect(x: barX, y: barY, width: barW, height: barH))
                track.wantsLayer = true
                track.layer?.cornerRadius = barH / 2
                track.layer?.backgroundColor = DS.barTrack.cgColor
                card.addSubview(track)

                let fillW = max(barW * fraction, fraction > 0 ? barH : 0)
                let fill = NSView(frame: NSRect(x: 0, y: 0, width: fillW, height: barH))
                fill.wantsLayer = true
                fill.layer?.cornerRadius = barH / 2
                fill.layer?.backgroundColor = DS.greenFill.cgColor
                track.addSubview(fill)

                let progLabel = makeLabel("\(clamped)/\(prog.target)", size: 8, bold: false, color: Self.progressText)
                progLabel.alignment = .center
                progLabel.frame = NSRect(x: barX, y: barY + barH + 2, width: barW, height: 10)
                card.addSubview(progLabel)
            }
        }

        // Total content height
        let totalH = curY + CGFloat(sorted.count) * (rowH + rowGap) + 10
        contentView.frame = NSRect(x: 0, y: 0, width: Self.panelW, height: max(totalH, 380))
    }

    // MARK: - Helpers

    @discardableResult
    private func placeLabel(_ text: String, in parent: NSView, x: CGFloat, y: CGFloat,
                            size: CGFloat, bold: Bool = false,
                            color: NSColor = DS.textPrimary) -> NSTextField {
        let label = DS.label(text, size: size, bold: bold, color: color)
        label.sizeToFit()
        label.frame.origin = NSPoint(x: x, y: y)
        parent.addSubview(label)
        return label
    }

    @discardableResult
    private func makePill(_ text: String, in parent: NSView, x: CGFloat, y: CGFloat) -> CGFloat {
        let padH: CGFloat = 8
        let h: CGFloat = 18
        let label = DS.label(text, size: 9, bold: false, color: DS.textSecondary)
        label.sizeToFit()
        let pillW = label.frame.width + padH * 2

        let pill = NSView(frame: NSRect(x: x, y: y, width: pillW, height: h))
        pill.wantsLayer = true
        pill.layer?.backgroundColor = DS.pillBg.cgColor
        pill.layer?.cornerRadius = DS.pillRadius
        parent.addSubview(pill)

        label.frame.origin = NSPoint(x: padH, y: 2)
        pill.addSubview(label)

        return pillW
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

    private func tierIconColor(_ tier: Achievement.Tier, unlocked: Bool) -> NSColor {
        guard unlocked else { return Self.trackColor }
        switch tier {
        case .common: return Self.tierCommonGold
        case .rare: return Self.tierRare
        case .legendary: return Self.tierLegendary
        }
    }

    private func achievementProgress(for achievement: Achievement, state: PetState) -> (current: Int, target: Int) {
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

private class ProfileFlippedView: NSView {
    override var isFlipped: Bool { true }
}

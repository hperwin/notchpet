import AppKit

final class StatsTabView: DSTabView {

    override var isFlipped: Bool { true }

    // Dark dashboard palette
    private static let bgColor   = NSColor(red: 0x0d/255.0, green: 0x0d/255.0, blue: 0x0d/255.0, alpha: 1)
    private static let cardBg    = NSColor(red: 0x1a/255.0, green: 0x1a/255.0, blue: 0x1a/255.0, alpha: 1)
    private static let gold      = NSColor(red: 0xF8/255.0, green: 0xA8/255.0, blue: 0x00/255.0, alpha: 1)
    private static let textPrimary   = NSColor.white
    private static let textSecondary = NSColor(red: 0x77/255.0, green: 0x77/255.0, blue: 0x77/255.0, alpha: 1)
    private static let pillBg    = NSColor(red: 0x25/255.0, green: 0x25/255.0, blue: 0x25/255.0, alpha: 1)
    private static let xpBarBg   = NSColor(red: 0x33/255.0, green: 0x33/255.0, blue: 0x33/255.0, alpha: 1)
    private static let xpBarFill = NSColor(red: 0x4C/255.0, green: 0xAF/255.0, blue: 0x50/255.0, alpha: 1)

    // Layout constants
    private static let outerPad: CGFloat = 8
    private static let cardGap: CGFloat  = 10
    private static let cardRadius: CGFloat = 12
    private static let innerPad: CGFloat = 14

    init() {
        super.init(backgroundColor: StatsTabView.bgColor)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Helpers

    private func makeCard(frame: NSRect) -> NSView {
        let card = NSView(frame: frame)
        card.wantsLayer = true
        card.layer?.backgroundColor = StatsTabView.cardBg.cgColor
        card.layer?.cornerRadius = StatsTabView.cardRadius
        return card
    }

    private func makeLabel(_ text: String, size: CGFloat, bold: Bool = false,
                           color: NSColor = textPrimary) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        label.textColor = color
        label.drawsBackground = false
        label.isBordered = false
        label.isEditable = false
        return label
    }

    @discardableResult
    private func placeLabel(_ text: String, in parent: NSView, x: CGFloat, y: CGFloat,
                            size: CGFloat, bold: Bool = false,
                            color: NSColor = textPrimary) -> NSTextField {
        let label = makeLabel(text, size: size, bold: bold, color: color)
        label.sizeToFit()
        label.frame.origin = NSPoint(x: x, y: y)
        parent.addSubview(label)
        return label
    }

    private func makePill(_ text: String, in parent: NSView, x: CGFloat, y: CGFloat) -> CGFloat {
        let pad: CGFloat = 8
        let h: CGFloat = 20
        let label = makeLabel(text, size: 9, bold: false, color: StatsTabView.textSecondary)
        label.sizeToFit()
        let pillW = label.frame.width + pad * 2

        let pill = NSView(frame: NSRect(x: x, y: y, width: pillW, height: h))
        pill.wantsLayer = true
        pill.layer?.backgroundColor = StatsTabView.pillBg.cgColor
        pill.layer?.cornerRadius = 6
        parent.addSubview(pill)

        label.frame.origin = NSPoint(x: pad, y: 3)
        pill.addSubview(label)

        return pillW
    }

    private func makeXPBar(in parent: NSView, x: CGFloat, y: CGFloat,
                           width: CGFloat, height: CGFloat, progress: Double) {
        let bg = NSView(frame: NSRect(x: x, y: y, width: width, height: height))
        bg.wantsLayer = true
        bg.layer?.backgroundColor = StatsTabView.xpBarBg.cgColor
        bg.layer?.cornerRadius = height / 2
        parent.addSubview(bg)

        let fillWidth = max(0, width * CGFloat(min(progress, 1.0)))
        if fillWidth > 0 {
            let fill = NSView(frame: NSRect(x: 0, y: 0, width: fillWidth, height: height))
            fill.wantsLayer = true
            fill.layer?.backgroundColor = StatsTabView.xpBarFill.cgColor
            fill.layer?.cornerRadius = height / 2
            bg.addSubview(fill)
        }
    }

    // MARK: - Update

    override func update(state: PetState) {
        subviews.forEach { $0.removeFromSuperview() }
        clearHitRegions()
        needsDisplay = true

        let pad = StatsTabView.outerPad
        let gap = StatsTabView.cardGap
        let ip = StatsTabView.innerPad
        let contentW: CGFloat = bounds.width - pad * 2
        let cardW = (contentW - gap) / 2
        let topCardH: CGFloat = 130
        let partyCardH: CGFloat = 220

        // ── Top-left: Typing card ──

        let typingCard = makeCard(frame: NSRect(x: pad, y: pad, width: cardW, height: topCardH))
        addSubview(typingCard)

        placeLabel("Typing", in: typingCard, x: ip, y: ip - 2,
                   size: 12, bold: true, color: StatsTabView.gold)

        // Big word count centered
        let wordStr = "\(state.totalWordsTyped)"
        let bigLabel = placeLabel(wordStr, in: typingCard, x: 0, y: 36,
                                  size: 28, bold: true, color: StatsTabView.textPrimary)
        bigLabel.frame.origin.x = (cardW - bigLabel.frame.width) / 2

        let wordsLabel = placeLabel("words", in: typingCard, x: 0, y: 66,
                                    size: 10, color: StatsTabView.textSecondary)
        wordsLabel.frame.origin.x = (cardW - wordsLabel.frame.width) / 2

        // Bottom pill row
        let pillY: CGFloat = topCardH - 32
        let pillStartX: CGFloat = ip
        var px = pillStartX

        let wpmText = "WPM \(Int(state.currentWPM))"
        let w1 = makePill(wpmText, in: typingCard, x: px, y: pillY)
        px += w1 + 6

        if state.typingStreak > 0 {
            let streakText = "\u{1F525} \(state.typingStreak)d streak"
            let w2 = makePill(streakText, in: typingCard, x: px, y: pillY)
            px += w2 + 6
        }

        if state.loginStreak > 0 {
            let loginText = "\u{2B50} \(state.loginStreak)d login"
            _ = makePill(loginText, in: typingCard, x: px, y: pillY)
        }

        // ── Top-right: Feeding card ──

        let feedingCard = makeCard(frame: NSRect(
            x: pad + cardW + gap, y: pad, width: cardW, height: topCardH))
        addSubview(feedingCard)

        placeLabel("Feeding", in: feedingCard, x: ip, y: ip - 2,
                   size: 12, bold: true, color: StatsTabView.gold)

        // Big berry count centered
        let berryStr = "\(state.totalFoodEaten)"
        let berryLabel = placeLabel(berryStr, in: feedingCard, x: 0, y: 36,
                                    size: 28, bold: true, color: StatsTabView.textPrimary)
        berryLabel.frame.origin.x = (cardW - berryLabel.frame.width) / 2

        let fedLabel = placeLabel("berries fed", in: feedingCard, x: 0, y: 66,
                                  size: 10, color: StatsTabView.textSecondary)
        fedLabel.frame.origin.x = (cardW - fedLabel.frame.width) / 2

        // Compact per-pokemon feeding summary at bottom
        var feedParts: [String] = []
        for pokemonId in state.party.prefix(6) {
            let inst = state.pokemonInstances[pokemonId]
            let name = PetCollection.entry(for: pokemonId)?.displayName ?? pokemonId
            let fed = inst?.foodEaten ?? 0
            let shortName = name.count > 8 ? String(name.prefix(8)) : name
            feedParts.append("\(shortName) \(fed)")
        }

        if !feedParts.isEmpty {
            // Split into two lines if more than 3
            let line1 = feedParts.prefix(3).joined(separator: " \u{00B7} ")
            placeLabel(line1, in: feedingCard, x: ip, y: topCardH - 34,
                       size: 9, color: StatsTabView.textSecondary)
            if feedParts.count > 3 {
                let line2 = feedParts.dropFirst(3).joined(separator: " \u{00B7} ")
                placeLabel(line2, in: feedingCard, x: ip, y: topCardH - 20,
                           size: 9, color: StatsTabView.textSecondary)
            }
        }

        // ── Bottom: Party card (full width) ──

        let partyY = pad + topCardH + gap
        let partyCard = makeCard(frame: NSRect(
            x: pad, y: partyY, width: contentW, height: partyCardH))
        addSubview(partyCard)

        placeLabel("Party", in: partyCard, x: ip, y: 10,
                   size: 12, bold: true, color: StatsTabView.gold)

        // Party roster rows
        let rowStartY: CGFloat = 32
        let rowHeight: CGFloat = 30
        let spriteSize: CGFloat = 24

        for (i, pokemonId) in state.party.prefix(6).enumerated() {
            let inst = state.pokemonInstances[pokemonId]
            let entry = PetCollection.entry(for: pokemonId)
            let rowY = rowStartY + CGFloat(i) * rowHeight

            // Sprite
            let shiny = state.useShiny && state.unlockedShinies.contains(pokemonId)
            let spriteView = NSImageView(frame: NSRect(
                x: ip, y: rowY + 2, width: spriteSize, height: spriteSize))
            spriteView.image = PetCollection.spriteImage(for: pokemonId, shiny: shiny)
            spriteView.imageScaling = .scaleProportionallyUpOrDown
            spriteView.wantsLayer = true
            spriteView.layer?.magnificationFilter = .nearest
            partyCard.addSubview(spriteView)

            // Name
            let nameX: CGFloat = ip + spriteSize + 8
            let displayName = entry?.displayName ?? pokemonId
            placeLabel(displayName, in: partyCard, x: nameX, y: rowY + 5,
                       size: 11, bold: true, color: StatsTabView.textPrimary)

            // Level
            let lvl = inst?.level ?? 1
            let lvlLabel = placeLabel("Lv.\(lvl)", in: partyCard, x: nameX + 80, y: rowY + 6,
                                      size: 9, color: StatsTabView.textSecondary)
            _ = lvlLabel

            // XP bar
            let barX: CGFloat = nameX + 118
            let barH: CGFloat = 4
            let progress = inst?.levelProgress ?? 0

            // XP text (right side)
            let xpCur = inst?.xp ?? 0
            let xpNext = inst?.xpToNextLevel ?? 100
            let xpLabel = makeLabel("\(xpCur)/\(xpNext)", size: 9, color: StatsTabView.textSecondary)
            xpLabel.sizeToFit()
            let xpTextW = xpLabel.frame.width

            // Top move (far right)
            let topMove = inst?.moves.last ?? "--"
            let moveLabel = makeLabel(topMove, size: 9, bold: false, color: StatsTabView.gold)
            moveLabel.sizeToFit()
            let moveLabelW = moveLabel.frame.width

            let rightEdge = contentW - ip
            moveLabel.frame.origin = NSPoint(x: rightEdge - moveLabelW, y: rowY + 6)
            partyCard.addSubview(moveLabel)

            let xpTextX = rightEdge - moveLabelW - 10 - xpTextW
            xpLabel.frame.origin = NSPoint(x: xpTextX, y: rowY + 6)
            partyCard.addSubview(xpLabel)

            let barW = xpTextX - barX - 8
            if barW > 20 {
                makeXPBar(in: partyCard, x: barX, y: rowY + 10,
                          width: barW, height: barH, progress: progress)
            }
        }
    }
}

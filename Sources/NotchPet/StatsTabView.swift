import AppKit

final class StatsTabView: DSTabView {

    override var isFlipped: Bool { true }

    private static let bgColor = NSColor(red: 0x0d/255.0, green: 0x0d/255.0, blue: 0x0d/255.0, alpha: 1)

    init() {
        super.init(backgroundColor: StatsTabView.bgColor)
    }

    required init?(coder: NSCoder) { fatalError() }

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

    private func makePill(_ text: String, in parent: NSView, x: CGFloat, y: CGFloat) -> CGFloat {
        let pad: CGFloat = 8
        let h: CGFloat = 20
        let label = DS.label(text, size: 9, bold: false, color: DS.textSecondary)
        label.sizeToFit()
        let pillW = label.frame.width + pad * 2

        let pill = NSView(frame: NSRect(x: x, y: y, width: pillW, height: h))
        pill.wantsLayer = true
        pill.layer?.backgroundColor = DS.pillBg.cgColor
        pill.layer?.cornerRadius = DS.pillRadius
        parent.addSubview(pill)

        label.frame.origin = NSPoint(x: pad, y: 3)
        pill.addSubview(label)

        return pillW
    }

    // MARK: - Update

    override func update(state: PetState) {
        subviews.forEach { $0.removeFromSuperview() }
        clearHitRegions()
        needsDisplay = true

        let pad = DS.outerPad
        let gap = DS.cardGap
        let ip = DS.innerPad
        let contentW: CGFloat = 560  // 580 - 2*10
        let cardW: CGFloat = 276     // (560 - 8) / 2
        let topCardH: CGFloat = 140
        let partyCardH: CGFloat = 275

        // ── Row 1 Left: Typing card ──

        let typingCard = DS.makeCard(frame: NSRect(x: pad, y: pad, width: cardW, height: topCardH))
        addSubview(typingCard)

        placeLabel("Typing", in: typingCard, x: ip, y: ip,
                   size: 12, bold: true, color: DS.gold)

        // Big word count centered
        let wordStr = "\(state.totalWordsTyped)"
        let bigLabel = placeLabel(wordStr, in: typingCard, x: 0, y: 40,
                                  size: 28, bold: true, color: DS.textPrimary)
        bigLabel.frame.origin.x = (cardW - bigLabel.frame.width) / 2

        let wordsLabel = placeLabel("words", in: typingCard, x: 0, y: 72,
                                    size: 10, color: DS.textSecondary)
        wordsLabel.frame.origin.x = (cardW - wordsLabel.frame.width) / 2

        // Bottom pill row
        let pillY: CGFloat = topCardH - 32
        var px: CGFloat = ip

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

        // ── Row 1 Right: Feeding card ──

        let feedingCard = DS.makeCard(frame: NSRect(
            x: pad + cardW + gap, y: pad, width: cardW, height: topCardH))
        addSubview(feedingCard)

        placeLabel("Feeding", in: feedingCard, x: ip, y: ip,
                   size: 12, bold: true, color: DS.gold)

        // Big berry count centered
        let berryStr = "\(state.totalFoodEaten)"
        let berryLabel = placeLabel(berryStr, in: feedingCard, x: 0, y: 40,
                                    size: 28, bold: true, color: DS.textPrimary)
        berryLabel.frame.origin.x = (cardW - berryLabel.frame.width) / 2

        let fedLabel = placeLabel("berries fed", in: feedingCard, x: 0, y: 72,
                                  size: 10, color: DS.textSecondary)
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
            let line1 = feedParts.prefix(3).joined(separator: " \u{00B7} ")
            placeLabel(line1, in: feedingCard, x: ip, y: topCardH - 34,
                       size: 9, color: DS.textSecondary)
            if feedParts.count > 3 {
                let line2 = feedParts.dropFirst(3).joined(separator: " \u{00B7} ")
                placeLabel(line2, in: feedingCard, x: ip, y: topCardH - 20,
                           size: 9, color: DS.textSecondary)
            }
        }

        // ── Row 1.5: Focus card (full width, compact) ──

        let focusY = pad + topCardH + gap
        let focusH: CGFloat = 32
        let focusCard = DS.makeCard(frame: NSRect(
            x: pad, y: focusY, width: contentW, height: focusH))
        addSubview(focusCard)

        let tierName = state.currentAppTierName
        let comboLabel = state.currentComboLabel

        var focusPx: CGFloat = ip
        let focusTitle = placeLabel("Focus", in: focusCard, x: focusPx, y: 8,
                                     size: 10, bold: true, color: DS.gold)
        focusPx += focusTitle.frame.width + 10

        let tierPillW = makePill("App: \(tierName)", in: focusCard, x: focusPx, y: 6)
        focusPx += tierPillW + 6

        _ = makePill("Combo: \(comboLabel)", in: focusCard, x: focusPx, y: 6)

        // ── Row 2: Party card (full width) ──

        let partyY = pad + topCardH + gap + focusH + gap
        let partyCard = DS.makeCard(frame: NSRect(
            x: pad, y: partyY, width: contentW, height: partyCardH))
        addSubview(partyCard)

        placeLabel("Party", in: partyCard, x: ip, y: ip,
                   size: 12, bold: true, color: DS.gold)

        // Party roster rows
        let rowStartY: CGFloat = 36
        let rowHeight: CGFloat = 36
        let spriteSize: CGFloat = 24

        for (i, pokemonId) in state.party.prefix(6).enumerated() {
            let inst = state.pokemonInstances[pokemonId]
            let entry = PetCollection.entry(for: pokemonId)
            let rowY = rowStartY + CGFloat(i) * rowHeight

            // Sprite (pixel-art magnification)
            let shiny = state.useShiny && state.unlockedShinies.contains(pokemonId)
            let spriteView = NSImageView(frame: NSRect(
                x: ip, y: rowY + 6, width: spriteSize, height: spriteSize))
            spriteView.image = PetCollection.spriteImage(for: pokemonId, shiny: shiny)
            spriteView.imageScaling = .scaleProportionallyUpOrDown
            spriteView.wantsLayer = true
            spriteView.layer?.magnificationFilter = .nearest
            partyCard.addSubview(spriteView)

            // Name
            let nameX: CGFloat = 46
            let displayName = entry?.displayName ?? pokemonId
            placeLabel(displayName, in: partyCard, x: nameX, y: rowY + 8,
                       size: 11, bold: true, color: DS.textPrimary)

            // Level
            let lvl = inst?.level ?? 1
            placeLabel("Lv.\(lvl)", in: partyCard, x: nameX + 80, y: rowY + 9,
                       size: 9, color: DS.textSecondary)

            // Move name (far right, gold)
            let topMove = inst?.moves.last ?? "--"
            let moveLabel = DS.label(topMove, size: 10, bold: false, color: DS.gold)
            moveLabel.sizeToFit()
            let rightEdge = contentW - ip
            moveLabel.frame.origin = NSPoint(x: rightEdge - moveLabel.frame.width, y: rowY + 8)
            partyCard.addSubview(moveLabel)

            // XP text (right-aligned before move)
            let xpCur = inst?.xp ?? 0
            let xpNext = inst?.xpToNextLevel ?? 100
            let xpLabel = DS.label("\(xpCur)/\(xpNext)", size: 9, color: DS.textSecondary)
            xpLabel.sizeToFit()
            let xpTextX = rightEdge - moveLabel.frame.width - 10 - xpLabel.frame.width
            xpLabel.frame.origin = NSPoint(x: xpTextX, y: rowY + 9)
            partyCard.addSubview(xpLabel)

            // XP bar
            let barX: CGFloat = nameX + 118
            let progress = inst?.levelProgress ?? 0
            let barW = xpTextX - barX - 8
            if barW >= 20 {
                DS.makeBar(in: partyCard, x: barX, y: rowY + 16,
                           width: barW, progress: progress)
            }
        }
    }
}

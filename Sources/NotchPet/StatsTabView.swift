import AppKit

final class StatsTabView: DSTabView {

    override var isFlipped: Bool { true }

    // Dark dashboard palette
    private static let bgColor = NSColor(red: 0x11/255, green: 0x11/255, blue: 0x11/255, alpha: 1)
    private static let cardBg = NSColor(red: 0x1e/255, green: 0x1e/255, blue: 0x1e/255, alpha: 1)
    private static let cardBorder = NSColor(red: 0x33/255, green: 0x33/255, blue: 0x33/255, alpha: 1)
    private static let gold = NSColor(red: 0xF8/255, green: 0xA8/255, blue: 0x00/255, alpha: 1)
    private static let textPrimary = NSColor.white
    private static let textSecondary = NSColor(red: 0x88/255, green: 0x88/255, blue: 0x88/255, alpha: 1)
    private static let xpBarBg = NSColor(red: 0x33/255, green: 0x33/255, blue: 0x33/255, alpha: 1)
    private static let xpBarFill = NSColor(red: 0x4C/255, green: 0xAF/255, blue: 0x50/255, alpha: 1)

    // Layout constants
    private static let padding: CGFloat = 18
    private static let cardRadius: CGFloat = 10
    private static let cardBorderWidth: CGFloat = 1
    private static let topRowHeight: CGFloat = 170
    private static let bottomCardHeight: CGFloat = 208
    private static let cardGap: CGFloat = 10

    init() {
        super.init(backgroundColor: .clear)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Helpers

    private func makeCard(frame: NSRect) -> NSView {
        let card = NSView(frame: frame)
        card.wantsLayer = true
        card.layer?.backgroundColor = StatsTabView.cardBg.cgColor
        card.layer?.cornerRadius = StatsTabView.cardRadius
        card.layer?.borderWidth = StatsTabView.cardBorderWidth
        card.layer?.borderColor = StatsTabView.cardBorder.cgColor
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

        let pad = StatsTabView.padding
        let contentW: CGFloat = bounds.width - pad * 2
        let cardW = (contentW - StatsTabView.cardGap) / 2

        // ── Row 1: Typing card (left) ──

        let typingCard = makeCard(frame: NSRect(
            x: pad, y: pad,
            width: cardW, height: StatsTabView.topRowHeight))
        addSubview(typingCard)

        placeLabel("Typing", in: typingCard, x: 12, y: 10,
                   size: 13, bold: true, color: StatsTabView.gold)

        // Words typed — big number
        placeLabel("\(state.totalWordsTyped)", in: typingCard, x: 12, y: 30,
                   size: 24, bold: true, color: StatsTabView.textPrimary)
        placeLabel("words", in: typingCard, x: 12, y: 58,
                   size: 11, color: StatsTabView.textSecondary)

        // WPM
        placeLabel("WPM", in: typingCard, x: 12, y: 80,
                   size: 10, color: StatsTabView.textSecondary)
        placeLabel("\(Int(state.currentWPM))", in: typingCard, x: 42, y: 78,
                   size: 12, bold: true, color: StatsTabView.textPrimary)

        // Streaks — right column inside typing card
        let rightCol: CGFloat = cardW / 2 + 8
        placeLabel("Typing Streak", in: typingCard, x: rightCol, y: 30,
                   size: 10, color: StatsTabView.textSecondary)
        placeLabel("\(state.typingStreak)d", in: typingCard, x: rightCol, y: 44,
                   size: 16, bold: true, color: StatsTabView.textPrimary)

        placeLabel("Login Streak", in: typingCard, x: rightCol, y: 72,
                   size: 10, color: StatsTabView.textSecondary)
        placeLabel("\(state.loginStreak)d", in: typingCard, x: rightCol, y: 86,
                   size: 16, bold: true, color: StatsTabView.textPrimary)

        // ── Row 1: Feeding card (right) ──

        let feedingCard = makeCard(frame: NSRect(
            x: pad + cardW + StatsTabView.cardGap, y: pad,
            width: cardW, height: StatsTabView.topRowHeight))
        addSubview(feedingCard)

        placeLabel("Feeding", in: feedingCard, x: 12, y: 10,
                   size: 13, bold: true, color: StatsTabView.gold)

        // Total berries — big number
        placeLabel("\(state.totalFoodEaten)", in: feedingCard, x: 12, y: 30,
                   size: 24, bold: true, color: StatsTabView.textPrimary)
        placeLabel("berries", in: feedingCard, x: 12, y: 58,
                   size: 11, color: StatsTabView.textSecondary)

        // Mini list: per-pokemon food counts
        var foodY: CGFloat = 78
        for pokemonId in state.party.prefix(6) {
            let inst = state.pokemonInstances[pokemonId]
            let name = PetCollection.entry(for: pokemonId)?.displayName ?? pokemonId
            let fed = inst?.foodEaten ?? 0
            let truncName = name.count > 8 ? String(name.prefix(8)) : name
            placeLabel("\(truncName): \(fed)", in: feedingCard, x: 12, y: foodY,
                       size: 10, color: StatsTabView.textSecondary)
            foodY += 14
        }

        // ── Row 2: Party Summary card (full width) ──

        let partyY = pad + StatsTabView.topRowHeight + StatsTabView.cardGap
        let partyCard = makeCard(frame: NSRect(
            x: pad, y: partyY,
            width: contentW, height: StatsTabView.bottomCardHeight))
        addSubview(partyCard)

        placeLabel("Party", in: partyCard, x: 12, y: 8,
                   size: 13, bold: true, color: StatsTabView.gold)

        // Party roster rows
        let rowStartY: CGFloat = 30
        let rowHeight: CGFloat = 30
        let spriteSize: CGFloat = 28

        for (i, pokemonId) in state.party.prefix(6).enumerated() {
            let inst = state.pokemonInstances[pokemonId]
            let entry = PetCollection.entry(for: pokemonId)
            let rowY = rowStartY + CGFloat(i) * rowHeight

            // Sprite
            let shiny = state.useShiny && state.unlockedShinies.contains(pokemonId)
            let spriteView = NSImageView(frame: NSRect(
                x: 12, y: rowY, width: spriteSize, height: spriteSize))
            spriteView.image = PetCollection.spriteImage(for: pokemonId, shiny: shiny)
            spriteView.imageScaling = .scaleProportionallyUpOrDown
            spriteView.wantsLayer = true
            spriteView.layer?.magnificationFilter = .nearest
            partyCard.addSubview(spriteView)

            // Name
            let displayName = entry?.displayName ?? pokemonId
            placeLabel(displayName, in: partyCard, x: 46, y: rowY + 2,
                       size: 12, bold: true, color: StatsTabView.textPrimary)

            // Level
            let lvl = inst?.level ?? 1
            placeLabel("Lv.\(lvl)", in: partyCard, x: 46, y: rowY + 16,
                       size: 9, color: StatsTabView.textSecondary)

            // XP bar
            let barX: CGFloat = 130
            let barW: CGFloat = 200
            let barH: CGFloat = 6
            let progress = inst?.levelProgress ?? 0
            makeXPBar(in: partyCard, x: barX, y: rowY + 11,
                      width: barW, height: barH, progress: progress)

            // XP text
            let xpCur = inst?.xp ?? 0
            let xpNext = inst?.xpToNextLevel ?? 100
            placeLabel("\(xpCur)/\(xpNext)", in: partyCard,
                       x: barX + barW + 6, y: rowY + 6,
                       size: 9, color: StatsTabView.textSecondary)

            // Top move
            let topMove = inst?.moves.last ?? "--"
            placeLabel(topMove, in: partyCard,
                       x: contentW - 90, y: rowY + 6,
                       size: 10, bold: false, color: StatsTabView.gold)
        }
    }
}

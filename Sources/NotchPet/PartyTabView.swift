import AppKit
import QuartzCore

final class PartyTabView: DSTabView {

    private static let skyBlue = NSColor(red: 0x78/255, green: 0xC8/255, blue: 0xF0/255, alpha: 1)
    private static let cardGreenTop = NSColor(red: 0x48/255, green: 0xB0/255, blue: 0x48/255, alpha: 1)
    private static let cardGreenBot = NSColor(red: 0x38/255, green: 0xA0/255, blue: 0x38/255, alpha: 1)
    private static let cardBorder = NSColor(red: 0x28/255, green: 0x68/255, blue: 0x28/255, alpha: 1)
    private static let hpGreen = NSColor(red: 0x48/255, green: 0xD0/255, blue: 0x48/255, alpha: 1)

    // Content area: 520 x 380pt (macOS Y=0 at BOTTOM)
    private static let contentH: CGFloat = 380

    init() {
        super.init(backgroundColor: PartyTabView.skyBlue)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }  // Use top-left origin like a normal UI

    override func update(state: PetState) {
        subviews.forEach { $0.removeFromSuperview() }
        clearHitRegions()

        // Layout: Lead card on left, 5 smaller cards stacked on the right
        // Using flipped coordinates (Y=0 at TOP)
        let pad: CGFloat = 10
        let gap: CGFloat = 6

        // Lead card — left side, tall
        let leadW: CGFloat = 240
        let leadH: CGFloat = 200
        let leadRect = NSRect(x: pad, y: pad, width: leadW, height: leadH)

        // Right column — 5 cards stacked vertically
        let rightX = pad + leadW + gap
        let rightW: CGFloat = 520 - rightX - pad  // ~258pt
        let cardH: CGFloat = (leadH - gap * 2) / 3  // 3 rows, 2 in each except last
        let halfW = (rightW - gap) / 2

        // Row 0: cards 1, 2
        let card1Rect = NSRect(x: rightX, y: pad, width: halfW, height: cardH)
        let card2Rect = NSRect(x: rightX + halfW + gap, y: pad, width: halfW, height: cardH)
        // Row 1: cards 3, 4
        let card3Rect = NSRect(x: rightX, y: pad + cardH + gap, width: halfW, height: cardH)
        let card4Rect = NSRect(x: rightX + halfW + gap, y: pad + cardH + gap, width: halfW, height: cardH)
        // Row 2: card 5 (spans half or full)
        let card5Rect = NSRect(x: rightX, y: pad + (cardH + gap) * 2, width: halfW, height: cardH)

        let rects = [leadRect, card1Rect, card2Rect, card3Rect, card4Rect, card5Rect]

        for (i, rect) in rects.enumerated() {
            if i < state.party.count {
                addFilledCard(rect: rect, pokemonId: state.party[i], state: state, isLead: i == 0)
                addHitRegion(HitRegion(id: "party_\(i)", rect: rect, action: .showDetail(pokemonId: state.party[i])))
            } else {
                addEmptyCard(rect: rect)
                addHitRegion(HitRegion(id: "empty_\(i)", rect: rect, action: .switchToTab(1)))
            }
        }

        // Stats bar at bottom
        let statsY = pad + leadH + gap
        let statsLabel = DSTabView.dsLabel(
            "Lv.\(state.level)  ·  \(state.foodEaten) berries fed  ·  \(state.totalWordsTyped) words",
            size: 10, bold: false, color: NSColor.white.withAlphaComponent(0.8)
        )
        statsLabel.frame = NSRect(x: pad, y: statsY, width: 500, height: 16)
        addSubview(statsLabel)
    }

    // MARK: - Filled Card

    private func addFilledCard(rect: NSRect, pokemonId: String, state: PetState, isLead: Bool) {
        let card = NSView(frame: rect)
        card.wantsLayer = true
        card.layer?.cornerRadius = 8

        let gradient = CAGradientLayer()
        gradient.frame = CGRect(origin: .zero, size: rect.size)
        gradient.colors = [PartyTabView.cardGreenTop.cgColor, PartyTabView.cardGreenBot.cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        gradient.cornerRadius = 8
        card.layer?.insertSublayer(gradient, at: 0)
        card.layer?.borderColor = PartyTabView.cardBorder.cgColor
        card.layer?.borderWidth = 2
        addSubview(card)

        // Pokeball at top-left of card
        let pb = PokeballView(frame: NSRect(x: rect.minX + 4, y: rect.minY + 4, width: 12, height: 12))
        addSubview(pb)

        let entry = PetCollection.allPokemon.first { $0.id == pokemonId }
        let isShiny = state.useShiny && state.unlockedShinies.contains(pokemonId)

        if isLead {
            // Lead: sprite centered, name + level below
            let spriteSize: CGFloat = 80
            let spriteX = rect.midX - spriteSize / 2
            let spriteY = rect.minY + 20
            let sprite = makeSprite(pokemonId, shiny: isShiny, frame: NSRect(x: spriteX, y: spriteY, width: spriteSize, height: spriteSize))
            addSubview(sprite)

            let name = makeDSLabel(entry?.displayName ?? pokemonId, size: 14, bold: true)
            name.frame = NSRect(x: rect.minX + 8, y: spriteY + spriteSize + 4, width: rect.width - 16, height: 18)
            name.alignment = .center
            addSubview(name)

            let lvl = makeDSLabel("Lv.\(state.level)", size: 11)
            lvl.frame = NSRect(x: rect.minX + 8, y: name.frame.maxY + 2, width: rect.width - 16, height: 14)
            lvl.alignment = .center
            addSubview(lvl)

            // HP bar
            let barY = lvl.frame.maxY + 6
            addHPBar(x: rect.minX + 20, y: barY, width: rect.width - 40, progress: state.levelProgress)
        } else {
            // Small card: sprite left, text right
            let spriteSize: CGFloat = min(40, rect.height - 12)
            let spriteX = rect.minX + 6
            let spriteY = rect.minY + (rect.height - spriteSize) / 2
            let sprite = makeSprite(pokemonId, shiny: isShiny, frame: NSRect(x: spriteX, y: spriteY, width: spriteSize, height: spriteSize))
            addSubview(sprite)

            let textX = spriteX + spriteSize + 6
            let textW = rect.maxX - textX - 6
            let name = makeDSLabel(entry?.displayName ?? pokemonId, size: 11, bold: true)
            name.frame = NSRect(x: textX, y: rect.minY + 8, width: textW, height: 14)
            addSubview(name)

            let lvl = makeDSLabel("Lv.\(state.level)", size: 9)
            lvl.frame = NSRect(x: textX, y: name.frame.maxY + 2, width: textW, height: 12)
            addSubview(lvl)

            addHPBar(x: textX, y: lvl.frame.maxY + 4, width: textW, progress: state.levelProgress)
        }
    }

    // MARK: - Empty Card

    private func addEmptyCard(rect: NSRect) {
        let card = NSView(frame: rect)
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.backgroundColor = NSColor(white: 0.5, alpha: 0.15).cgColor

        let border = CAShapeLayer()
        border.path = CGPath(roundedRect: CGRect(origin: .zero, size: rect.size), cornerWidth: 8, cornerHeight: 8, transform: nil)
        border.fillColor = nil
        border.strokeColor = NSColor.gray.withAlphaComponent(0.4).cgColor
        border.lineWidth = 1.5
        border.lineDashPattern = [5, 3]
        card.layer?.addSublayer(border)
        addSubview(card)

        let label = makeDSLabel("Empty", size: 10, bold: false, color: .lightGray)
        label.frame = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
        label.alignment = .center
        addSubview(label)
    }

    // MARK: - Helpers

    private func makeSprite(_ id: String, shiny: Bool, frame: NSRect) -> NSImageView {
        let iv = NSImageView(frame: frame)
        iv.image = PetCollection.spriteImage(for: id, shiny: shiny)
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.wantsLayer = true
        iv.layer?.magnificationFilter = .nearest
        return iv
    }

    private func makeDSLabel(_ text: String, size: CGFloat, bold: Bool = true, color: NSColor = .white) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        label.textColor = color
        label.drawsBackground = false
        label.isBordered = false
        label.isEditable = false
        label.shadow = DSTabView.dsShadow()
        return label
    }

    private func addHPBar(x: CGFloat, y: CGFloat, width: CGFloat, progress: Double) {
        let h: CGFloat = 4
        let track = NSView(frame: NSRect(x: x, y: y, width: width, height: h))
        track.wantsLayer = true
        track.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1).cgColor
        track.layer?.cornerRadius = 2
        addSubview(track)

        let fillW = width * CGFloat(min(max(progress, 0), 1))
        let fill = NSView(frame: NSRect(x: x, y: y, width: fillW, height: h))
        fill.wantsLayer = true
        fill.layer?.backgroundColor = PartyTabView.hpGreen.cgColor
        fill.layer?.cornerRadius = 2
        addSubview(fill)
    }
}

// MARK: - Pokeball Icon

private class PokeballView: NSView {
    override var isFlipped: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = frame.width / 2
        layer?.masksToBounds = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let b = bounds
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let r = b.width / 2
        ctx.setFillColor(NSColor.red.cgColor)
        ctx.fillEllipse(in: b)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: r, width: b.width, height: r))
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: 0, y: r))
        ctx.addLine(to: CGPoint(x: b.width, y: r))
        ctx.strokePath()
        let ds: CGFloat = 3
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(x: r - ds/2, y: r - ds/2, width: ds, height: ds))
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(0.5)
        ctx.strokeEllipse(in: CGRect(x: r - ds/2, y: r - ds/2, width: ds, height: ds))
    }
}

import AppKit
import QuartzCore

final class PartyTabView: DSTabView {

    private static let skyTop = NSColor(red: 0x78/255.0, green: 0xC8/255.0, blue: 0xF0/255.0, alpha: 1)
    private static let skyBot = NSColor(red: 0x60/255.0, green: 0xB0/255.0, blue: 0xE0/255.0, alpha: 1)

    init() {
        super.init(backgroundColor: PartyTabView.skyTop)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        // Update sky gradient to fill bounds
        if let grad = layer?.sublayers?.first(where: { $0.name == "skyGrad" }) as? CAGradientLayer {
            grad.frame = bounds
        }
    }

    override func update(state: PetState) {
        subviews.forEach { $0.removeFromSuperview() }
        layer?.sublayers?.removeAll(where: { $0.name == "skyGrad" })
        clearHitRegions()

        // Sky gradient background
        let skyGrad = CAGradientLayer()
        skyGrad.name = "skyGrad"
        skyGrad.frame = bounds
        skyGrad.colors = [PartyTabView.skyTop.cgColor, PartyTabView.skyBot.cgColor]
        skyGrad.startPoint = CGPoint(x: 0.5, y: 0)
        skyGrad.endPoint = CGPoint(x: 0.5, y: 1)
        layer?.insertSublayer(skyGrad, at: 0)

        // Grid constants
        let pad = DS.outerPad       // 10
        let gap = DS.cardGap        // 8
        let cols = 2
        let rows = 3
        let contentW: CGFloat = 580
        let contentH: CGFloat = 430

        let cardW = (contentW - pad * 2 - gap * CGFloat(cols - 1)) / CGFloat(cols)  // 276
        let cardH = (contentH - pad - gap * CGFloat(rows)) / CGFloat(rows)           // ~130

        for i in 0..<6 {
            let col = i % cols
            let row = i / cols
            let x = pad + CGFloat(col) * (cardW + gap)
            let y = pad + CGFloat(row) * (cardH + gap)
            let rect = NSRect(x: x, y: y, width: cardW, height: cardH)

            if i < state.party.count {
                let pokemonId = state.party[i]
                addFilledCard(rect: rect, pokemonId: pokemonId, state: state, isLead: i == 0)
                addHitRegion(HitRegion(id: "party_\(i)", rect: rect, action: .showDetail(pokemonId: pokemonId)))
            } else {
                addEmptyCard(rect: rect)
                addHitRegion(HitRegion(id: "empty_\(i)", rect: rect, action: .switchToTab(1)))
            }
        }
    }

    // MARK: - Filled Card

    private func addFilledCard(rect: NSRect, pokemonId: String, state: PetState, isLead: Bool) {
        let card = NSView(frame: rect)
        card.wantsLayer = true
        card.layer?.cornerRadius = DS.cardRadius

        let gradient = CAGradientLayer()
        gradient.frame = CGRect(origin: .zero, size: rect.size)
        gradient.colors = [DS.cardGreenTop.cgColor, DS.cardGreenBot.cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        gradient.cornerRadius = DS.cardRadius
        card.layer?.insertSublayer(gradient, at: 0)
        card.layer?.borderColor = DS.cardGreenBorder.cgColor
        card.layer?.borderWidth = 2
        addSubview(card)

        // Pokeball icon at (6, 6) inside card
        let pb = PokeballView(frame: NSRect(x: rect.minX + 6, y: rect.minY + 6, width: 12, height: 12))
        addSubview(pb)

        let entry = PetCollection.entry(for: pokemonId)
        let isShiny = state.useShiny && state.unlockedShinies.contains(pokemonId)
        let instance = state.pokemonInstances[pokemonId]
        let pokemonLevel = instance?.level ?? 1
        let pokemonProgress = instance?.levelProgress ?? 0
        let cardW = rect.width
        let cardH = rect.height

        // Sprite: 48pt, left-center
        let spriteSize: CGFloat = 48
        let spriteX = rect.minX + 10
        let spriteY = rect.minY + (cardH - spriteSize) / 2
        let sprite = makeSprite(pokemonId, shiny: isShiny, frame: NSRect(x: spriteX, y: spriteY, width: spriteSize, height: spriteSize))
        addSubview(sprite)

        // Name: 12pt bold white, at x=68, y=20
        let name = DS.label(entry?.displayName ?? pokemonId, size: 12, bold: true)
        name.translatesAutoresizingMaskIntoConstraints = true
        name.frame = NSRect(x: rect.minX + 68, y: rect.minY + 20, width: cardW - 80, height: 16)
        addSubview(name)

        // Level: 10pt white, at x=68, y=38
        let lvl = DS.label("Lv.\(pokemonLevel)", size: 10)
        lvl.translatesAutoresizingMaskIntoConstraints = true
        lvl.frame = NSRect(x: rect.minX + 68, y: rect.minY + 38, width: cardW - 80, height: 14)
        addSubview(lvl)

        // HP bar: at x=68, y=cardH-20, width=cardW-80
        let barX = rect.minX + 68
        let barY = rect.minY + cardH - 20
        let barW = cardW - 80
        DS.makeBar(in: self, x: barX, y: barY, width: barW, progress: pokemonProgress)

        // LEAD pill for card 0
        if isLead {
            let pillW: CGFloat = 34
            let pillH: CGFloat = 14
            let pill = NSView(frame: NSRect(x: rect.maxX - pillW - 6, y: rect.minY + 6, width: pillW, height: pillH))
            pill.wantsLayer = true
            pill.layer?.backgroundColor = DS.pillBg.cgColor
            pill.layer?.cornerRadius = DS.pillRadius
            addSubview(pill)

            let pillLabel = DS.label("LEAD", size: 8, bold: true, color: DS.gold)
            pillLabel.translatesAutoresizingMaskIntoConstraints = true
            pillLabel.alignment = .center
            pillLabel.frame = NSRect(x: 0, y: 0, width: pillW, height: pillH)
            pill.addSubview(pillLabel)
        }
    }

    // MARK: - Empty Card

    private func addEmptyCard(rect: NSRect) {
        let card = NSView(frame: rect)
        card.wantsLayer = true
        card.layer?.cornerRadius = DS.cardRadius
        card.layer?.backgroundColor = NSColor(white: 0.5, alpha: 0.15).cgColor

        let border = CAShapeLayer()
        border.path = CGPath(roundedRect: CGRect(origin: .zero, size: rect.size),
                             cornerWidth: DS.cardRadius, cornerHeight: DS.cardRadius, transform: nil)
        border.fillColor = nil
        border.strokeColor = NSColor.gray.withAlphaComponent(0.4).cgColor
        border.lineWidth = 1.5
        border.lineDashPattern = [5, 3]
        card.layer?.addSublayer(border)
        addSubview(card)

        let label = DS.label("Empty", size: 11, bold: false, color: .lightGray)
        label.translatesAutoresizingMaskIntoConstraints = true
        label.alignment = .center
        label.frame = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
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

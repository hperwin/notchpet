import AppKit
import QuartzCore

final class PartyTabView: DSTabView {

    // DS color palette
    private static let skyBlue = NSColor(red: 0x78/255, green: 0xC8/255, blue: 0xF0/255, alpha: 1)
    private static let cardGreenTop = NSColor(red: 0x48/255, green: 0xB0/255, blue: 0x48/255, alpha: 1)
    private static let cardGreenBot = NSColor(red: 0x38/255, green: 0xA0/255, blue: 0x38/255, alpha: 1)
    private static let cardBorder = NSColor(red: 0x28/255, green: 0x68/255, blue: 0x28/255, alpha: 1)
    private static let hpGreen = NSColor(red: 0x48/255, green: 0xD0/255, blue: 0x48/255, alpha: 1)

    init() {
        super.init(backgroundColor: PartyTabView.skyBlue)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Slot definitions

    private struct SlotDef {
        let x: CGFloat; let y: CGFloat; let w: CGFloat; let h: CGFloat
        let spriteSize: CGFloat
    }

    private static let slots: [SlotDef] = [
        // Slot 0 – lead, large card
        SlotDef(x: 12,  y: 12,  w: 230, h: 240, spriteSize: 80),
        // Slots 1-5 – smaller cards in 2-col layout
        SlotDef(x: 254, y: 12,  w: 125, h: 72, spriteSize: 44),
        SlotDef(x: 387, y: 12,  w: 125, h: 72, spriteSize: 44),
        SlotDef(x: 254, y: 92,  w: 125, h: 72, spriteSize: 44),
        SlotDef(x: 387, y: 92,  w: 125, h: 72, spriteSize: 44),
        SlotDef(x: 254, y: 172, w: 125, h: 72, spriteSize: 44),
    ]

    // MARK: - Update

    override func update(state: PetState) {
        subviews.forEach { $0.removeFromSuperview() }
        clearHitRegions()

        for (i, slot) in PartyTabView.slots.enumerated() {
            let rect = NSRect(x: slot.x, y: slot.y, width: slot.w, height: slot.h)

            if i < state.party.count {
                let pokemonId = state.party[i]
                let isLead = (i == 0)
                addFilledCard(rect: rect, slot: slot, pokemonId: pokemonId, state: state, index: i, isLead: isLead)
            } else {
                addEmptyCard(rect: rect, index: i)
            }

            // Hit region for the card area
            let action: TabAction = i < state.party.count
                ? .showDetail(pokemonId: state.party[i])
                : .switchToTab(1)
            addHitRegion(HitRegion(id: i < state.party.count ? "party_\(i)" : "empty_\(i)", rect: rect, action: action))
        }
    }

    // MARK: - Filled Card

    private func addFilledCard(rect: NSRect, slot: SlotDef, pokemonId: String, state: PetState, index: Int, isLead: Bool) {
        let card = NSView(frame: rect)
        card.wantsLayer = true
        card.layer?.cornerRadius = 10

        // Green gradient background
        let gradient = CAGradientLayer()
        gradient.frame = CGRect(origin: .zero, size: rect.size)
        gradient.colors = [PartyTabView.cardGreenTop.cgColor, PartyTabView.cardGreenBot.cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        gradient.cornerRadius = 10
        card.layer?.insertSublayer(gradient, at: 0)

        // Border
        card.layer?.borderColor = PartyTabView.cardBorder.cgColor
        card.layer?.borderWidth = 2

        addSubview(card)

        // Pokeball icon at top-left
        let pokeball = PokeballView(frame: NSRect(x: rect.minX + 6, y: rect.minY + 6, width: 8, height: 8))
        addSubview(pokeball)

        let entry = PetCollection.allPokemon.first { $0.id == pokemonId }
        let isShiny = state.useShiny && state.unlockedShinies.contains(pokemonId)

        if isLead {
            // Lead card: sprite centered, name/level/HP below
            let sprite = DSTabView.dsSprite(for: pokemonId, shiny: isShiny, size: slot.spriteSize)
            addSubview(sprite)
            NSLayoutConstraint.activate([
                sprite.centerXAnchor.constraint(equalTo: leadingAnchor, constant: rect.midX),
                sprite.topAnchor.constraint(equalTo: topAnchor, constant: rect.minY + 24),
            ])

            let name = DSTabView.dsLabel(entry?.displayName ?? pokemonId, size: 14, bold: true)
            addSubview(name)
            NSLayoutConstraint.activate([
                name.centerXAnchor.constraint(equalTo: leadingAnchor, constant: rect.midX),
                name.topAnchor.constraint(equalTo: topAnchor, constant: rect.minY + 112),
            ])

            let lvl = DSTabView.dsLabel("Lv.\(state.level)", size: 11, bold: false, color: .white)
            addSubview(lvl)
            NSLayoutConstraint.activate([
                lvl.centerXAnchor.constraint(equalTo: leadingAnchor, constant: rect.midX),
                lvl.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 2),
            ])

            // HP bar centered below level
            let barWidth: CGFloat = rect.width - 40
            addHPBar(centerX: rect.midX, topAnchorView: lvl, barWidth: barWidth)
        } else {
            // Small card: sprite on the left, text on the right
            let sprite = DSTabView.dsSprite(for: pokemonId, shiny: isShiny, size: slot.spriteSize)
            addSubview(sprite)
            NSLayoutConstraint.activate([
                sprite.leadingAnchor.constraint(equalTo: leadingAnchor, constant: rect.minX + 8),
                sprite.centerYAnchor.constraint(equalTo: topAnchor, constant: rect.midY),
            ])

            let name = DSTabView.dsLabel(entry?.displayName ?? pokemonId, size: 12, bold: true)
            addSubview(name)
            NSLayoutConstraint.activate([
                name.leadingAnchor.constraint(equalTo: leadingAnchor, constant: rect.minX + slot.spriteSize + 14),
                name.topAnchor.constraint(equalTo: topAnchor, constant: rect.minY + 10),
            ])

            let lvl = DSTabView.dsLabel("Lv.\(state.level)", size: 10, bold: false, color: .white)
            addSubview(lvl)
            NSLayoutConstraint.activate([
                lvl.leadingAnchor.constraint(equalTo: name.leadingAnchor),
                lvl.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 2),
            ])

            let barWidth: CGFloat = rect.width - slot.spriteSize - 24
            addHPBarAligned(leadingX: rect.minX + slot.spriteSize + 14, topAnchorView: lvl, barWidth: barWidth)
        }
    }

    // MARK: - Empty Card

    private func addEmptyCard(rect: NSRect, index: Int) {
        let card = NSView(frame: rect)
        card.wantsLayer = true
        card.layer?.cornerRadius = 10
        card.layer?.backgroundColor = NSColor(white: 0.5, alpha: 0.2).cgColor

        // Dashed border
        let borderLayer = CAShapeLayer()
        let path = CGPath(roundedRect: CGRect(origin: .zero, size: rect.size), cornerWidth: 10, cornerHeight: 10, transform: nil)
        borderLayer.path = path
        borderLayer.fillColor = nil
        borderLayer.strokeColor = NSColor.gray.cgColor
        borderLayer.lineWidth = 2
        borderLayer.lineDashPattern = [6, 4]
        card.layer?.addSublayer(borderLayer)

        addSubview(card)

        let empty = DSTabView.dsLabel("Empty", size: 11, bold: false, color: NSColor.lightGray)
        addSubview(empty)
        NSLayoutConstraint.activate([
            empty.centerXAnchor.constraint(equalTo: leadingAnchor, constant: rect.midX),
            empty.centerYAnchor.constraint(equalTo: topAnchor, constant: rect.midY),
        ])
    }

    // MARK: - HP Bar helpers

    private func addHPBar(centerX: CGFloat, topAnchorView: NSTextField, barWidth: CGFloat) {
        let barHeight: CGFloat = 4

        let track = NSView()
        track.wantsLayer = true
        track.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1).cgColor
        track.layer?.cornerRadius = 2
        track.translatesAutoresizingMaskIntoConstraints = false
        addSubview(track)
        NSLayoutConstraint.activate([
            track.centerXAnchor.constraint(equalTo: leadingAnchor, constant: centerX),
            track.topAnchor.constraint(equalTo: topAnchorView.bottomAnchor, constant: 6),
            track.widthAnchor.constraint(equalToConstant: barWidth),
            track.heightAnchor.constraint(equalToConstant: barHeight),
        ])

        let fill = NSView()
        fill.wantsLayer = true
        fill.layer?.backgroundColor = PartyTabView.hpGreen.cgColor
        fill.layer?.cornerRadius = 2
        fill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fill)
        NSLayoutConstraint.activate([
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.widthAnchor.constraint(equalTo: track.widthAnchor),
            fill.heightAnchor.constraint(equalTo: track.heightAnchor),
        ])
    }

    private func addHPBarAligned(leadingX: CGFloat, topAnchorView: NSTextField, barWidth: CGFloat) {
        let barHeight: CGFloat = 4

        let track = NSView()
        track.wantsLayer = true
        track.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1).cgColor
        track.layer?.cornerRadius = 2
        track.translatesAutoresizingMaskIntoConstraints = false
        addSubview(track)
        NSLayoutConstraint.activate([
            track.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingX),
            track.topAnchor.constraint(equalTo: topAnchorView.bottomAnchor, constant: 4),
            track.widthAnchor.constraint(equalToConstant: barWidth),
            track.heightAnchor.constraint(equalToConstant: barHeight),
        ])

        let fill = NSView()
        fill.wantsLayer = true
        fill.layer?.backgroundColor = PartyTabView.hpGreen.cgColor
        fill.layer?.cornerRadius = 2
        fill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fill)
        NSLayoutConstraint.activate([
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.widthAnchor.constraint(equalTo: track.widthAnchor),
            fill.heightAnchor.constraint(equalTo: track.heightAnchor),
        ])
    }
}

// MARK: - Pokeball Icon View

private class PokeballView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = frame.width / 2
        layer?.masksToBounds = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let b = bounds
        let ctx = NSGraphicsContext.current!.cgContext
        let radius = b.width / 2

        // Red top half
        ctx.setFillColor(NSColor.red.cgColor)
        ctx.fillEllipse(in: b)

        // White bottom half
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: b.width, height: radius))

        // Black center line
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: 0, y: radius))
        ctx.addLine(to: CGPoint(x: b.width, y: radius))
        ctx.strokePath()

        // Center dot
        let dotSize: CGFloat = 3
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(x: radius - dotSize/2, y: radius - dotSize/2, width: dotSize, height: dotSize))
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(0.5)
        ctx.strokeEllipse(in: CGRect(x: radius - dotSize/2, y: radius - dotSize/2, width: dotSize, height: dotSize))
    }
}

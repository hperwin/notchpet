import AppKit

final class PartyTabView: DSTabView {

    init() {
        super.init(backgroundImage: "bg_party")
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Slot layout (approximate positions matching the bg image card locations)

    private struct SlotDef {
        let x: CGFloat; let y: CGFloat; let w: CGFloat; let h: CGFloat
        let spriteSize: CGFloat
    }

    private static let slots: [SlotDef] = [
        // Slot 0 – lead, larger card
        SlotDef(x: 12,  y: 200, w: 170, h: 90, spriteSize: 52),
        // Slots 1-5
        SlotDef(x: 195, y: 210, w: 155, h: 75, spriteSize: 44),
        SlotDef(x: 360, y: 210, w: 155, h: 75, spriteSize: 44),
        SlotDef(x: 195, y: 295, w: 155, h: 75, spriteSize: 44),
        SlotDef(x: 360, y: 295, w: 155, h: 75, spriteSize: 44),
        SlotDef(x: 195, y: 135, w: 155, h: 75, spriteSize: 44),
    ]

    // MARK: - Update

    override func update(state: PetState) {
        // Remove old content but keep bg image at index 0
        subviews.dropFirst().forEach { $0.removeFromSuperview() }
        clearHitRegions()

        let hpGreen = NSColor(red: 0x48/255, green: 0xD0/255, blue: 0x48/255, alpha: 1)

        for (i, slot) in PartyTabView.slots.enumerated() {
            let rect = NSRect(x: slot.x, y: slot.y, width: slot.w, height: slot.h)

            if i < state.party.count {
                let pokemonId = state.party[i]

                // Sprite
                let sprite = DSTabView.dsSprite(for: pokemonId, shiny: state.useShiny && state.unlockedShinies.contains(pokemonId), size: slot.spriteSize)
                addSubview(sprite)
                NSLayoutConstraint.activate([
                    sprite.leadingAnchor.constraint(equalTo: leadingAnchor, constant: rect.minX + 8),
                    sprite.centerYAnchor.constraint(equalTo: topAnchor, constant: rect.midY),
                ])

                // Name
                let entry = PetCollection.allPokemon.first { $0.id == pokemonId }
                let name = DSTabView.dsLabel(entry?.displayName ?? pokemonId, size: 12, bold: true)
                addSubview(name)
                NSLayoutConstraint.activate([
                    name.leadingAnchor.constraint(equalTo: sprite.trailingAnchor, constant: 6),
                    name.topAnchor.constraint(equalTo: topAnchor, constant: rect.minY + 10),
                ])

                // Level
                let lvl = DSTabView.dsLabel("Lv.\(state.level)", size: 10, bold: false, color: .white)
                addSubview(lvl)
                NSLayoutConstraint.activate([
                    lvl.leadingAnchor.constraint(equalTo: name.leadingAnchor),
                    lvl.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 2),
                ])

                // HP bar track
                let barWidth: CGFloat = rect.width - slot.spriteSize - 28
                let barHeight: CGFloat = 4

                let track = NSView()
                track.wantsLayer = true
                track.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1).cgColor
                track.layer?.cornerRadius = 2
                track.translatesAutoresizingMaskIntoConstraints = false
                addSubview(track)
                NSLayoutConstraint.activate([
                    track.leadingAnchor.constraint(equalTo: name.leadingAnchor),
                    track.topAnchor.constraint(equalTo: lvl.bottomAnchor, constant: 4),
                    track.widthAnchor.constraint(equalToConstant: barWidth),
                    track.heightAnchor.constraint(equalToConstant: barHeight),
                ])

                // HP bar fill (always full for display purposes)
                let fill = NSView()
                fill.wantsLayer = true
                fill.layer?.backgroundColor = hpGreen.cgColor
                fill.layer?.cornerRadius = 2
                fill.translatesAutoresizingMaskIntoConstraints = false
                addSubview(fill)
                NSLayoutConstraint.activate([
                    fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
                    fill.topAnchor.constraint(equalTo: track.topAnchor),
                    fill.widthAnchor.constraint(equalTo: track.widthAnchor),
                    fill.heightAnchor.constraint(equalTo: track.heightAnchor),
                ])

                addHitRegion(HitRegion(id: "party_\(i)", rect: rect, action: .showDetail(pokemonId: pokemonId)))
            } else {
                // Empty slot
                let empty = DSTabView.dsLabel("Empty", size: 11, bold: false, color: NSColor.lightGray)
                addSubview(empty)
                NSLayoutConstraint.activate([
                    empty.centerXAnchor.constraint(equalTo: leadingAnchor, constant: rect.midX),
                    empty.centerYAnchor.constraint(equalTo: topAnchor, constant: rect.midY),
                ])

                addHitRegion(HitRegion(id: "empty_\(i)", rect: rect, action: .switchToTab(1)))
            }
        }
    }
}

import AppKit
import QuartzCore

final class PartyTabView: DSTabView {

    private static let skyTop = NSColor(red: 0x78/255.0, green: 0xC8/255.0, blue: 0xF0/255.0, alpha: 1)
    private static let skyBot = NSColor(red: 0x60/255.0, green: 0xB0/255.0, blue: 0xE0/255.0, alpha: 1)

    // Grid layout
    private static let cols = 2
    private static let rows = 3
    private static let panelW: CGFloat = 580
    private static let contentH: CGFloat = 430

    // Drag state
    private var dragSlotIndex: Int? = nil
    private var dragGhost: NSView? = nil
    private var dragStartPoint: NSPoint = .zero
    private var isDragging = false
    private var slotRects: [NSRect] = []
    private var highlightView: NSView? = nil
    private var currentState: PetState? = nil

    init() {
        super.init(backgroundColor: PartyTabView.skyTop)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        if let grad = layer?.sublayers?.first(where: { $0.name == "skyGrad" }) as? CAGradientLayer {
            grad.frame = bounds
        }
    }

    // MARK: - Grid Calculation

    private func calculateSlotRects() -> [NSRect] {
        let pad = DS.outerPad
        let gap = DS.cardGap
        let cardW = (Self.panelW - pad * 2 - gap * CGFloat(Self.cols - 1)) / CGFloat(Self.cols)
        let cardH = (Self.contentH - pad - gap * CGFloat(Self.rows)) / CGFloat(Self.rows)

        var rects: [NSRect] = []
        for i in 0..<6 {
            let col = i % Self.cols
            let row = i / Self.cols
            let x = pad + CGFloat(col) * (cardW + gap)
            let y = pad + CGFloat(row) * (cardH + gap)
            rects.append(NSRect(x: x, y: y, width: cardW, height: cardH))
        }
        return rects
    }

    // MARK: - Update

    override func update(state: PetState) {
        currentState = state
        subviews.forEach { $0.removeFromSuperview() }
        layer?.sublayers?.removeAll(where: { $0.name == "skyGrad" })
        clearHitRegions()
        dragGhost = nil
        highlightView = nil

        // Sky gradient
        let skyGrad = CAGradientLayer()
        skyGrad.name = "skyGrad"
        skyGrad.frame = bounds
        skyGrad.colors = [PartyTabView.skyTop.cgColor, PartyTabView.skyBot.cgColor]
        skyGrad.startPoint = CGPoint(x: 0.5, y: 0)
        skyGrad.endPoint = CGPoint(x: 0.5, y: 1)
        layer?.insertSublayer(skyGrad, at: 0)

        slotRects = calculateSlotRects()

        for (i, rect) in slotRects.enumerated() {
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

    // MARK: - Mouse Events (Drag & Drop Reordering)

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        dragStartPoint = loc
        isDragging = false

        // Find which filled slot was clicked
        guard let state = currentState else { return }
        for (i, rect) in slotRects.enumerated() {
            if i < state.party.count && rect.contains(loc) {
                dragSlotIndex = i
                return
            }
        }
        dragSlotIndex = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let slotIdx = dragSlotIndex, let state = currentState else { return }
        let loc = convert(event.locationInWindow, from: nil)

        // Start drag if moved more than 5pt
        if !isDragging {
            let dx = loc.x - dragStartPoint.x
            let dy = loc.y - dragStartPoint.y
            if sqrt(dx * dx + dy * dy) < 5 { return }
            isDragging = true
            createDragGhost(slotIndex: slotIdx, state: state)
        }

        // Move ghost to follow cursor
        if let ghost = dragGhost {
            let ghostW = ghost.frame.width
            let ghostH = ghost.frame.height
            ghost.frame.origin = NSPoint(x: loc.x - ghostW / 2, y: loc.y - ghostH / 2)
        }

        // Highlight the slot being hovered over
        updateDropHighlight(at: loc, state: state)
    }

    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)

        if isDragging, let fromIdx = dragSlotIndex, let state = currentState {
            // Find which slot we dropped on
            var toIdx: Int? = nil
            for (i, rect) in slotRects.enumerated() {
                if i < state.party.count && rect.contains(loc) && i != fromIdx {
                    toIdx = i
                    break
                }
            }

            // Swap if dropped on a different filled slot
            if let to = toIdx {
                var newParty = state.party
                newParty.swapAt(fromIdx, to)
                onAction?(.reorderParty(newOrder: newParty))
            }

            // Clean up drag
            removeDragGhost()
        } else if !isDragging, let slotIdx = dragSlotIndex {
            // It was a tap, not a drag — trigger the normal action
            if let state = currentState, slotIdx < state.party.count {
                onAction?(.showDetail(pokemonId: state.party[slotIdx]))
            }
        }

        dragSlotIndex = nil
        isDragging = false
    }

    // MARK: - Drag Ghost

    private func createDragGhost(slotIndex: Int, state: PetState) {
        guard slotIndex < state.party.count else { return }
        let rect = slotRects[slotIndex]
        let pokemonId = state.party[slotIndex]

        // Create a snapshot card as the ghost
        let ghost = NSView(frame: rect)
        ghost.wantsLayer = true
        ghost.layer?.cornerRadius = DS.cardRadius

        let gradient = CAGradientLayer()
        gradient.frame = CGRect(origin: .zero, size: rect.size)
        gradient.colors = [DS.cardGreenTop.cgColor, DS.cardGreenBot.cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        gradient.cornerRadius = DS.cardRadius
        ghost.layer?.insertSublayer(gradient, at: 0)
        ghost.layer?.borderColor = DS.gold.cgColor
        ghost.layer?.borderWidth = 2.5

        // Add sprite to ghost
        let spriteSize: CGFloat = 48
        let sprite = NSImageView(frame: NSRect(
            x: (rect.width - spriteSize) / 2,
            y: (rect.height - spriteSize) / 2 - 8,
            width: spriteSize, height: spriteSize
        ))
        sprite.image = PetCollection.spriteImage(for: pokemonId)
        sprite.imageScaling = .scaleProportionallyUpOrDown
        sprite.wantsLayer = true
        sprite.layer?.magnificationFilter = .nearest
        ghost.addSubview(sprite)

        // Name label
        let entry = PetCollection.entry(for: pokemonId)
        let name = DS.label(entry?.displayName ?? pokemonId, size: 12, bold: true)
        name.translatesAutoresizingMaskIntoConstraints = true
        name.alignment = .center
        name.frame = NSRect(x: 0, y: rect.height - 24, width: rect.width, height: 16)
        ghost.addSubview(name)

        // Lift animation: scale up + shadow
        ghost.layer?.shadowColor = NSColor.black.cgColor
        ghost.layer?.shadowOffset = CGSize(width: 0, height: -4)
        ghost.layer?.shadowRadius = 12
        ghost.layer?.shadowOpacity = 0.5

        let lift = CABasicAnimation(keyPath: "transform.scale")
        lift.fromValue = 1.0
        lift.toValue = 1.08
        lift.duration = 0.15
        lift.fillMode = .forwards
        lift.isRemovedOnCompletion = false
        ghost.layer?.add(lift, forKey: "lift")

        addSubview(ghost)
        dragGhost = ghost

        // Create highlight view for drop targets
        let hl = NSView()
        hl.wantsLayer = true
        hl.layer?.cornerRadius = DS.cardRadius
        hl.layer?.borderColor = DS.gold.cgColor
        hl.layer?.borderWidth = 2.5
        hl.layer?.backgroundColor = DS.gold.withAlphaComponent(0.1).cgColor
        hl.isHidden = true
        addSubview(hl)
        highlightView = hl
    }

    private func updateDropHighlight(at point: NSPoint, state: PetState) {
        guard let hl = highlightView, let fromIdx = dragSlotIndex else { return }

        var foundTarget = false
        for (i, rect) in slotRects.enumerated() {
            if i < state.party.count && i != fromIdx && rect.contains(point) {
                hl.frame = rect.insetBy(dx: -2, dy: -2)
                hl.isHidden = false
                foundTarget = true
                break
            }
        }
        if !foundTarget {
            hl.isHidden = true
        }
    }

    private func removeDragGhost() {
        // Animate ghost removal
        if let ghost = dragGhost {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.15
                ghost.animator().alphaValue = 0
            }, completionHandler: {
                ghost.removeFromSuperview()
            })
        }
        highlightView?.removeFromSuperview()
        highlightView = nil
        dragGhost = nil
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

        let pb = PokeballView(frame: NSRect(x: rect.minX + 6, y: rect.minY + 6, width: 12, height: 12))
        addSubview(pb)

        let entry = PetCollection.entry(for: pokemonId)
        let isShiny = state.useShiny && state.unlockedShinies.contains(pokemonId)
        let instance = state.pokemonInstances[pokemonId]
        let pokemonLevel = instance?.level ?? 1
        let pokemonProgress = instance?.levelProgress ?? 0
        let cardW = rect.width
        let cardH = rect.height

        let spriteSize: CGFloat = 48
        let spriteX = rect.minX + 10
        let spriteY = rect.minY + (cardH - spriteSize) / 2
        let sprite = makeSprite(pokemonId, shiny: isShiny, frame: NSRect(x: spriteX, y: spriteY, width: spriteSize, height: spriteSize))
        addSubview(sprite)

        let name = DS.label(entry?.displayName ?? pokemonId, size: 12, bold: true)
        name.translatesAutoresizingMaskIntoConstraints = true
        name.frame = NSRect(x: rect.minX + 68, y: rect.minY + 20, width: cardW - 80, height: 16)
        addSubview(name)

        let lvl = DS.label("Lv.\(pokemonLevel)", size: 10)
        lvl.translatesAutoresizingMaskIntoConstraints = true
        lvl.frame = NSRect(x: rect.minX + 68, y: rect.minY + 38, width: cardW - 80, height: 14)
        addSubview(lvl)

        DS.makeBar(in: self, x: rect.minX + 68, y: rect.minY + cardH - 20, width: cardW - 80, progress: pokemonProgress)

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

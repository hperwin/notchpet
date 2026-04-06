import AppKit

final class StatsTabView: DSTabView {

    // DS palette
    private static let darkBlue = NSColor(red: 0x28/255, green: 0x38/255, blue: 0x58/255, alpha: 1)
    private static let darkerBlue = NSColor(red: 0x1a/255, green: 0x28/255, blue: 0x48/255, alpha: 1)
    private static let cream = NSColor(red: 0xF5/255, green: 0xF0/255, blue: 0xE0/255, alpha: 1)
    private static let gold = NSColor(red: 0xF8/255, green: 0xA8/255, blue: 0x00/255, alpha: 1)
    private static let fieldGray = NSColor(red: 0x33/255, green: 0x33/255, blue: 0x33/255, alpha: 1)


    // Card geometry
    private static let cardOuter = NSRect(x: 10, y: 10, width: 500, height: 360)
    private static let cardInner = NSRect(x: 18, y: 18, width: 484, height: 344)

    init() {
        super.init(backgroundColor: StatsTabView.darkBlue)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Helpers

    private func formatXP(_ xp: Int) -> String {
        if xp >= 1_000_000 {
            return String(format: "%.1fM", Double(xp) / 1_000_000)
        } else if xp >= 1_000 {
            return String(format: "%.1fK", Double(xp) / 1_000)
        }
        return "\(xp)"
    }

    private func formatTime(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%d:%02d", h, m)
    }

    private func tierColor(_ tier: Achievement.Tier) -> NSColor {
        let c = tier.color
        return NSColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
    }

    /// Place a label at an absolute position inside the view (frame-based, no Auto Layout).
    private func placeLabel(_ text: String, x: CGFloat, y: CGFloat,
                            size: CGFloat, bold: Bool = true,
                            color: NSColor = .black, shadow: Bool = false) {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        label.textColor = color
        label.drawsBackground = false
        label.isBordered = false
        label.isEditable = false
        label.sizeToFit()
        if shadow {
            label.shadow = DSTabView.dsShadow()
        }
        // NSView y-axis is bottom-up; convert top-down y
        let flippedY = bounds.height - y - label.frame.height
        label.frame.origin = NSPoint(x: x, y: flippedY)
        addSubview(label)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let outer = StatsTabView.cardOuter
        let inner = StatsTabView.cardInner

        // 1. Outer decorative border (darker blue)
        ctx.setFillColor(StatsTabView.darkerBlue.cgColor)
        let outerPath = CGPath(roundedRect: outer, cornerWidth: 8, cornerHeight: 8, transform: nil)
        ctx.addPath(outerPath)
        ctx.fillPath()

        // 2. Gold inner line (inset 2pt from outer)
        let goldRect = outer.insetBy(dx: 2, dy: 2)
        ctx.setStrokeColor(StatsTabView.gold.cgColor)
        ctx.setLineWidth(2)
        let goldPath = CGPath(roundedRect: goldRect, cornerWidth: 7, cornerHeight: 7, transform: nil)
        ctx.addPath(goldPath)
        ctx.strokePath()

        // 3. Cream card fill
        ctx.setFillColor(StatsTabView.cream.cgColor)
        let innerPath = CGPath(roundedRect: inner, cornerWidth: 6, cornerHeight: 6, transform: nil)
        ctx.addPath(innerPath)
        ctx.fillPath()

        // 4. Thin separator lines on cream card
        ctx.setStrokeColor(NSColor(red: 0xC0/255, green: 0xB8/255, blue: 0xA0/255, alpha: 1).cgColor)
        ctx.setLineWidth(1)

        // Line below sprite/name area (y=108 in top-down)
        let sepY1 = bounds.height - 108
        ctx.move(to: CGPoint(x: inner.minX + 8, y: sepY1))
        ctx.addLine(to: CGPoint(x: inner.maxX - 8, y: sepY1))
        ctx.strokePath()

        // Line above badges area (y=220 in top-down)
        let sepY2 = bounds.height - 220
        ctx.move(to: CGPoint(x: inner.minX + 8, y: sepY2))
        ctx.addLine(to: CGPoint(x: inner.maxX - 8, y: sepY2))
        ctx.strokePath()

        // Line above footer (y=310 in top-down)
        let sepY3 = bounds.height - 310
        ctx.move(to: CGPoint(x: inner.minX + 8, y: sepY3))
        ctx.addLine(to: CGPoint(x: inner.maxX - 8, y: sepY3))
        ctx.strokePath()
    }

    // MARK: - Update

    override func update(state: PetState) {
        // Remove all subviews (no bg image to preserve)
        subviews.forEach { $0.removeFromSuperview() }
        clearHitRegions()
        needsDisplay = true  // trigger draw(_:)

        let fg = StatsTabView.fieldGray

        // --- Sprite (top-left inside card) ---
        let leadId = state.party.first ?? "leafeon"
        let shiny = state.useShiny && state.unlockedShinies.contains(leadId)
        let spriteView = NSImageView()
        spriteView.image = PetCollection.spriteImage(for: leadId, shiny: shiny)
        spriteView.imageScaling = .scaleProportionallyUpOrDown
        spriteView.wantsLayer = true
        spriteView.layer?.magnificationFilter = .nearest
        let spriteY = bounds.height - 28 - 60  // top-down y=28, h=60
        spriteView.frame = NSRect(x: 28, y: spriteY, width: 60, height: 60)
        addSubview(spriteView)

        // --- NAME ---
        let entry = PetCollection.allPokemon.first { $0.id == leadId }
        placeLabel("NAME:", x: 100, y: 30, size: 11, bold: false, color: fg)
        placeLabel(entry?.displayName ?? leadId, x: 160, y: 28, size: 14, bold: true, color: .black)

        // --- PARTY ---
        placeLabel("PARTY:", x: 100, y: 54, size: 11, bold: false, color: fg)
        placeLabel("\(state.party.count)/6", x: 160, y: 54, size: 11, bold: true, color: .black)

        // --- MONEY (Total XP) ---
        placeLabel("MONEY:", x: 100, y: 78, size: 11, bold: false, color: fg)
        placeLabel("\(formatXP(state.totalXPEarned)) XP", x: 170, y: 78, size: 11, bold: true, color: .black)

        // --- POKeDEX ---
        let ownedPets = state.pokemonInstances.count
        let totalPets = PetCollection.allPokemon.count
        placeLabel("POK\u{00E9}DEX:", x: 280, y: 78, size: 11, bold: false, color: fg)
        placeLabel("\(ownedPets)/\(totalPets)", x: 360, y: 78, size: 11, bold: true, color: .black)

        // --- SCORE (Level) ---
        placeLabel("SCORE:", x: 28, y: 120, size: 11, bold: false, color: fg)
        placeLabel("Level \(state.highestLevel)", x: 100, y: 120, size: 11, bold: true, color: .black)

        // --- TIME ---
        placeLabel("TIME:", x: 28, y: 148, size: 11, bold: false, color: fg)
        placeLabel(formatTime(minutes: state.sessionActiveMinutes), x: 100, y: 148, size: 11, bold: true, color: .black)

        // --- PARTY SIZE ---
        placeLabel("PARTY:", x: 28, y: 176, size: 11, bold: false, color: fg)
        placeLabel("\(state.party.count) Pokemon", x: 110, y: 176, size: 11, bold: true, color: .black)

        // --- Right column stats ---
        placeLabel("WPM:", x: 280, y: 120, size: 11, bold: false, color: fg)
        placeLabel("\(Int(state.currentWPM))", x: 330, y: 120, size: 11, bold: true, color: .black)

        placeLabel("FED:", x: 280, y: 148, size: 11, bold: false, color: fg)
        placeLabel("\(state.totalFoodEaten) berries", x: 330, y: 148, size: 11, bold: true, color: .black)

        placeLabel("STREAK:", x: 280, y: 176, size: 11, bold: false, color: fg)
        placeLabel("\(state.typingStreak)d", x: 350, y: 176, size: 11, bold: true, color: .black)

        // --- BADGES grid (2 rows x 4 cols) ---
        placeLabel("BADGES:", x: 28, y: 232, size: 11, bold: false, color: fg)

        let badgeStartX: CGFloat = 110
        let badgeStartY: CGFloat = 228
        let badgeSize: CGFloat = 24
        let badgeGap: CGFloat = 6

        for i in 0..<8 {
            let col = i % 4
            let row = i / 4
            let bx = badgeStartX + CGFloat(col) * (badgeSize + badgeGap)
            let by = badgeStartY + CGFloat(row) * (badgeSize + badgeGap + 2)
            let flippedY = bounds.height - by - badgeSize

            let badgeView = NSView(frame: NSRect(x: bx, y: flippedY, width: badgeSize, height: badgeSize))
            badgeView.wantsLayer = true
            badgeView.layer?.cornerRadius = 4

            if i < state.achievements.count {
                let ach = state.achievements[i]
                if ach.unlocked {
                    badgeView.layer?.backgroundColor = StatsTabView.gold.cgColor
                    let star = NSTextField(labelWithString: "\u{2605}")
                    star.font = NSFont.boldSystemFont(ofSize: 14)
                    star.textColor = .white
                    star.drawsBackground = false
                    star.isBordered = false
                    star.isEditable = false
                    star.sizeToFit()
                    star.frame.origin = NSPoint(
                        x: (badgeSize - star.frame.width) / 2,
                        y: (badgeSize - star.frame.height) / 2
                    )
                    badgeView.addSubview(star)
                } else {
                    badgeView.layer?.backgroundColor = NSColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1).cgColor
                    badgeView.layer?.borderWidth = 1
                    badgeView.layer?.borderColor = NSColor.gray.cgColor
                    let circle = NSTextField(labelWithString: "\u{25CB}")
                    circle.font = NSFont.systemFont(ofSize: 12)
                    circle.textColor = .gray
                    circle.drawsBackground = false
                    circle.isBordered = false
                    circle.isEditable = false
                    circle.sizeToFit()
                    circle.frame.origin = NSPoint(
                        x: (badgeSize - circle.frame.width) / 2,
                        y: (badgeSize - circle.frame.height) / 2
                    )
                    badgeView.addSubview(circle)
                }
            } else {
                badgeView.layer?.backgroundColor = NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.3).cgColor
            }

            addSubview(badgeView)
        }

        // --- Footer: streak, WPM, fed summary ---
        let footerText = "\(state.typingStreak)d \u{00B7} \(Int(state.currentWPM)) WPM \u{00B7} \(state.totalFoodEaten) berries"
        placeLabel(footerText, x: 28, y: 320, size: 10, bold: false, color: fg)
    }
}

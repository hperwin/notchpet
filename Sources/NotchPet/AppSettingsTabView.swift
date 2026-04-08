import AppKit

final class AppSettingsTabView: DSTabView {

    override var isFlipped: Bool { true }

    private static let bgColor = NSColor(red: 0x0d/255.0, green: 0x0d/255.0, blue: 0x0d/255.0, alpha: 1)

    init() {
        super.init(backgroundColor: AppSettingsTabView.bgColor)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func update(state: PetState) {
        subviews.forEach { $0.removeFromSuperview() }
        clearHitRegions()
        needsDisplay = true

        let pad = DS.outerPad
        let gap = DS.cardGap
        let ip = DS.innerPad
        let contentW: CGFloat = 560

        // Title
        let title = DS.label("App Tiers", size: 14, bold: true, color: DS.gold)
        title.sizeToFit()
        title.frame.origin = NSPoint(x: pad + ip, y: pad)
        addSubview(title)

        let subtitle = DS.label("Tap an app to cycle: Deep Work \u{2192} Normal \u{2192} Distraction", size: 9, color: DS.textSecondary)
        subtitle.sizeToFit()
        subtitle.frame.origin = NSPoint(x: pad + ip, y: pad + 20)
        addSubview(subtitle)

        // Get running apps
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }

        // Three columns
        let colW: CGFloat = (contentW - pad * 2 - gap * 2) / 3
        let columns: [(title: String, tier: AppTier, color: NSColor)] = [
            ("Deep Work (3x)", .deepWork, NSColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1)),
            ("Normal (1x)", .normal, DS.textSecondary),
            ("Distraction (0x)", .distraction, NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1)),
        ]

        for (colIdx, col) in columns.enumerated() {
            let colX = pad + CGFloat(colIdx) * (colW + gap)
            let headerY: CGFloat = pad + 44

            let header = DS.label(col.title, size: 10, bold: true, color: col.color)
            header.sizeToFit()
            header.frame.origin = NSPoint(x: colX + ip, y: headerY)
            addSubview(header)

            let appsInTier = runningApps.filter { app in
                guard let bid = app.bundleIdentifier else { return false }
                return state.appTier(for: bid) == col.tier
            }

            var rowY = headerY + 24
            for app in appsInTier {
                guard let bundleID = app.bundleIdentifier else { continue }
                let name = app.localizedName ?? bundleID

                if let icon = app.icon {
                    let iconView = NSImageView(frame: NSRect(x: colX + ip, y: rowY, width: 16, height: 16))
                    iconView.image = icon
                    iconView.imageScaling = .scaleProportionallyUpOrDown
                    addSubview(iconView)
                }

                let nameLabel = DS.label(name, size: 10, color: DS.textPrimary)
                nameLabel.lineBreakMode = .byTruncatingTail
                nameLabel.frame = NSRect(x: colX + ip + 20, y: rowY, width: colW - ip * 2 - 20, height: 16)
                addSubview(nameLabel)

                let regionRect = NSRect(x: colX, y: rowY - 2, width: colW, height: 20)
                addHitRegion(HitRegion(
                    id: "tier_\(bundleID)",
                    rect: regionRect,
                    action: .cycleTier(bundleID: bundleID)
                ))

                rowY += 22
            }
        }
    }
}

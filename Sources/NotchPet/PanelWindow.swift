import AppKit
import QuartzCore

// MARK: - PanelWindow

final class PanelWindow: NSWindow {

    // Public API
    var isOpen: Bool = false
    var onPrestige: (() -> Void)?
    /// Called when user selects a pet from the picker: (pokemonId, isShiny)
    var onPetSelected: ((String, Bool) -> Void)?

    // Layout constants
    private let panelWidth: CGFloat = 320
    private let panelMaxHeight: CGFloat = 450
    private let bottomCornerRadius: CGFloat = 12
    private let openDuration: TimeInterval = 0.3
    private let closeDuration: TimeInterval = 0.2

    // Content
    private let scrollView = NSScrollView()
    private let contentStack = NSStackView()

    // Sections (need references for refreshData)
    private let petImageView = NSImageView()
    private let stageLabel = makeLabel(size: 13, bold: true, color: .white)
    private let levelLabel = makeLabel(size: 13, bold: true, color: .white)
    private let xpBar = ProgressBarView(accentHex: 0x4A9EFF)
    private let xpDetailLabel = makeLabel(size: 10, bold: false, color: .gray)

    private let statTotalWords = StatCell(title: "Total Words")
    private let statTypingStreak = StatCell(title: "Typing Streak")
    private let statLoginStreak = StatCell(title: "Login Streak")
    private let statWPM = StatCell(title: "WPM")
    private let statPrestige = StatCell(title: "Prestige")
    private let statMutation = StatCell(title: "Mutation")

    private var evolutionDots: [NSView] = []
    private let achievementsStack = NSStackView()
    private let cosmeticsGrid = NSStackView()
    private let challengeBar = ProgressBarView(accentHex: 0x4A9EFF)
    private let challengeLabel = makeLabel(size: 11, bold: false, color: .lightGray)
    private var challengeCard: NSView?
    private let prestigeButton = NSButton()
    private var prestigeCard: NSView?

    // Event monitors
    private var localMonitor: Any?
    private var globalMonitor: Any?

    // MARK: - Init

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isMovableByWindowBackground = false

        buildUI()
    }

    // MARK: - Toggle

    func toggle(from anchorFrame: NSRect) {
        if isOpen {
            closePanel()
        } else {
            openPanel(from: anchorFrame)
        }
    }

    // MARK: - Open / Close

    private func openPanel(from anchorFrame: NSRect) {
        guard !isOpen else { return }
        isOpen = true

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let menuBarHeight = screen.auxiliaryTopLeftArea?.height ?? 32
        let notchCenterX = anchorFrame.midX

        // Panel starts as 0-height sliver at menu bar bottom edge
        let panelX = notchCenterX - panelWidth / 2
        let topY = screen.frame.maxY - menuBarHeight // bottom of menu bar in screen coords

        // Initial frame: 0 height at top
        let startFrame = NSRect(x: panelX, y: topY, width: panelWidth, height: 0)
        setFrame(startFrame, display: true)
        alphaValue = 1
        orderFront(nil)

        // Animate to full height (grows downward, so origin.y decreases)
        let endFrame = NSRect(x: panelX, y: topY - panelMaxHeight, width: panelWidth, height: panelMaxHeight)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = openDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(endFrame, display: true)
        }

        installEventMonitors()
    }

    private func closePanel() {
        guard isOpen else { return }
        isOpen = false

        let topY = frame.maxY
        let endFrame = NSRect(x: frame.origin.x, y: topY, width: panelWidth, height: 0)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = closeDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().setFrame(endFrame, display: true)
        }, completionHandler: {
            self.orderOut(nil)
        })

        removeEventMonitors()
    }

    // MARK: - Event Monitors

    private func installEventMonitors() {
        // Escape key
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.closePanel()
                return nil
            }
            return event
        }

        // Click outside
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            let loc = NSEvent.mouseLocation
            if !self.frame.contains(loc) {
                self.closePanel()
            }
        }
    }

    private func removeEventMonitors() {
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
    }

    // MARK: - Refresh Data

    func refreshData(_ state: PetState) {
        // Pet image — load the same way PetView does
        if petImageView.image == nil {
            petImageView.image = loadPetImage()
        }
        stageLabel.stringValue = state.evolutionStage.name

        // Level & XP
        levelLabel.stringValue = "Level \(state.level)"
        xpBar.progress = state.levelProgress
        xpDetailLabel.stringValue = "\(state.xp) / \(state.xpToNextLevel) XP"

        // Stats
        statTotalWords.value = formatNumber(state.totalWordsTyped)
        statTypingStreak.value = "\(state.typingStreak) days"
        statLoginStreak.value = "\(state.loginStreak) days"
        statWPM.value = String(format: "%.0f", state.currentWPM)
        statPrestige.value = "\(state.prestigeCount)"
        statMutation.value = state.mutationColor ?? "None"

        // Evolution dots
        let currentIndex = state.evolutionStage.rawValue
        for (i, dot) in evolutionDots.enumerated() {
            dot.layer?.backgroundColor = i <= currentIndex
                ? NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1).cgColor
                : NSColor(white: 0.25, alpha: 1).cgColor
            dot.layer?.borderColor = i == currentIndex
                ? NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1).cgColor
                : NSColor.clear.cgColor
            dot.layer?.borderWidth = i == currentIndex ? 2 : 0
        }

        // Achievements
        rebuildAchievements(state.achievements)

        // Cosmetics
        rebuildCosmetics(state.cosmetics)

        // Weekly challenge
        if let challenge = state.weeklyChallenge {
            challengeCard?.isHidden = false
            challengeLabel.stringValue = challenge.description
            challengeBar.progress = challenge.progress
        } else {
            challengeCard?.isHidden = true
        }

        // Prestige button
        prestigeCard?.isHidden = state.level < 20
    }

    // MARK: - Build UI

    private func buildUI() {
        let container = PanelBackgroundView(cornerRadius: bottomCornerRadius)
        contentView = container

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        contentStack.orientation = .vertical
        contentStack.spacing = 12
        contentStack.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 16, right: 16)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let clipView = scrollView.contentView
        scrollView.documentView = contentStack

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: clipView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
        ])

        // 1. Pet Display
        contentStack.addArrangedSubview(buildPetSection())
        // 2. Level & XP
        contentStack.addArrangedSubview(buildLevelSection())
        // 3. Stats Grid
        contentStack.addArrangedSubview(buildStatsSection())
        // 4. Evolution Track
        contentStack.addArrangedSubview(buildEvolutionSection())
        // 5. Achievements
        contentStack.addArrangedSubview(buildAchievementsSection())
        // 6. Cosmetics
        contentStack.addArrangedSubview(buildCosmeticsSection())
        // 7. Weekly Challenge
        let cCard = buildChallengeSection()
        challengeCard = cCard
        contentStack.addArrangedSubview(cCard)
        // 8. Prestige
        let pCard = buildPrestigeSection()
        prestigeCard = pCard
        contentStack.addArrangedSubview(pCard)
    }

    // MARK: - Section Builders

    private func buildPetSection() -> NSView {
        let card = SectionCard()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        petImageView.imageScaling = .scaleProportionallyUpOrDown
        petImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            petImageView.widthAnchor.constraint(equalToConstant: 80),
            petImageView.heightAnchor.constraint(equalToConstant: 80),
        ])

        stageLabel.alignment = .center
        stack.addArrangedSubview(petImageView)
        stack.addArrangedSubview(stageLabel)

        card.addSubview(stack)
        pinToCard(stack, card: card)
        return card
    }

    private func buildLevelSection() -> NSView {
        let card = SectionCard()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        levelLabel.alignment = .left

        xpBar.translatesAutoresizingMaskIntoConstraints = false
        xpBar.heightAnchor.constraint(equalToConstant: 8).isActive = true

        xpDetailLabel.alignment = .right

        stack.addArrangedSubview(levelLabel)
        stack.addArrangedSubview(xpBar)
        stack.addArrangedSubview(xpDetailLabel)

        card.addSubview(stack)
        pinToCard(stack, card: card)
        return card
    }

    private func buildStatsSection() -> NSView {
        let card = SectionCard()
        let header = Self.makeLabel(size: 13, bold: true, color: .white)
        header.stringValue = "Stats"

        let grid = NSGridView(views: [
            [statTotalWords, statTypingStreak],
            [statLoginStreak, statWPM],
            [statPrestige, statMutation],
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 8
        grid.columnSpacing = 12

        // Make columns equal width
        for col in 0..<grid.numberOfColumns {
            grid.column(at: col).xPlacement = .fill
        }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(grid)

        card.addSubview(stack)
        pinToCard(stack, card: card)
        return card
    }

    private func buildEvolutionSection() -> NSView {
        let card = SectionCard()
        let header = Self.makeLabel(size: 13, bold: true, color: .white)
        header.stringValue = "Evolution"

        let dotsStack = NSStackView()
        dotsStack.orientation = .horizontal
        dotsStack.spacing = 8
        dotsStack.alignment = .centerY
        dotsStack.distribution = .fillEqually

        evolutionDots = []
        for stage in EvolutionStage.allCases {
            let dot = NSView()
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 10
            dot.layer?.backgroundColor = NSColor(white: 0.25, alpha: 1).cgColor
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 20),
                dot.heightAnchor.constraint(equalToConstant: 20),
            ])

            let label = Self.makeLabel(size: 9, bold: false, color: .gray)
            label.stringValue = stage.name
            label.alignment = .center

            let col = NSStackView()
            col.orientation = .vertical
            col.alignment = .centerX
            col.spacing = 4
            col.addArrangedSubview(dot)
            col.addArrangedSubview(label)
            dotsStack.addArrangedSubview(col)
            evolutionDots.append(dot)
        }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(dotsStack)

        card.addSubview(stack)
        pinToCard(stack, card: card)
        return card
    }

    private func buildAchievementsSection() -> NSView {
        let card = SectionCard()
        let header = Self.makeLabel(size: 13, bold: true, color: .white)
        header.stringValue = "Achievements"

        achievementsStack.orientation = .vertical
        achievementsStack.spacing = 6
        achievementsStack.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(achievementsStack)

        card.addSubview(stack)
        pinToCard(stack, card: card)
        return card
    }

    private func buildCosmeticsSection() -> NSView {
        let card = SectionCard()
        let header = Self.makeLabel(size: 13, bold: true, color: .white)
        header.stringValue = "Cosmetics"

        cosmeticsGrid.orientation = .vertical
        cosmeticsGrid.spacing = 6
        cosmeticsGrid.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(cosmeticsGrid)

        card.addSubview(stack)
        pinToCard(stack, card: card)
        return card
    }

    private func buildChallengeSection() -> NSView {
        let header = Self.makeLabel(size: 13, bold: true, color: .white)
        header.stringValue = "Weekly Challenge"

        challengeBar.translatesAutoresizingMaskIntoConstraints = false
        challengeBar.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(challengeLabel)
        stack.addArrangedSubview(challengeBar)

        let card = SectionCard()
        card.addSubview(stack)
        pinToCard(stack, card: card)
        return card
    }

    private func buildPrestigeSection() -> NSView {
        let card = SectionCard()

        prestigeButton.title = "Rebirth"
        prestigeButton.bezelStyle = .rounded
        prestigeButton.isBordered = false
        prestigeButton.wantsLayer = true
        prestigeButton.layer?.backgroundColor = NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1).cgColor
        prestigeButton.layer?.cornerRadius = 6
        prestigeButton.contentTintColor = .white
        prestigeButton.font = NSFont.boldSystemFont(ofSize: 13)
        prestigeButton.target = self
        prestigeButton.action = #selector(prestigeTapped)
        prestigeButton.translatesAutoresizingMaskIntoConstraints = false
        prestigeButton.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(prestigeButton)

        card.addSubview(stack)
        pinToCard(stack, card: card)
        return card
    }

    @objc private func prestigeTapped() {
        onPrestige?()
    }

    // MARK: - Rebuild Dynamic Sections

    private func rebuildAchievements(_ achievements: [Achievement]) {
        achievementsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        // Sort: unlocked first, then by tier descending
        let sorted = achievements.sorted { a, b in
            if a.unlocked != b.unlocked { return a.unlocked }
            return a.tier.rawValue > b.tier.rawValue
        }
        for ach in sorted.prefix(8) {
            let row = buildAchievementRow(ach)
            achievementsStack.addArrangedSubview(row)
        }
    }

    private func buildAchievementRow(_ ach: Achievement) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let tierColor = ach.tier.color
        let icon = Self.makeLabel(size: 14, bold: true, color: NSColor(
            red: tierColor.r, green: tierColor.g, blue: tierColor.b, alpha: ach.unlocked ? 1 : 0.3
        ))
        icon.stringValue = ach.unlocked ? "★" : "☆"

        let name = Self.makeLabel(size: 11, bold: true, color: ach.unlocked ? .white : .gray)
        name.stringValue = ach.name
        name.alphaValue = ach.unlocked ? 1.0 : 0.5

        let desc = Self.makeLabel(size: 10, bold: false, color: .gray)
        desc.stringValue = ach.description
        desc.alphaValue = ach.unlocked ? 0.8 : 0.4

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.addArrangedSubview(name)
        textStack.addArrangedSubview(desc)

        let row = NSStackView(views: [icon, textStack])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])
        return container
    }

    private func rebuildCosmetics(_ cosmetics: [Cosmetic]) {
        cosmeticsGrid.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Build rows of 4
        let itemsPerRow = 4
        var currentRow: [NSView] = []
        for cosmetic in cosmetics {
            let cell = buildCosmeticCell(cosmetic)
            currentRow.append(cell)
            if currentRow.count == itemsPerRow {
                let row = NSStackView(views: currentRow)
                row.orientation = .horizontal
                row.distribution = .fillEqually
                row.spacing = 8
                cosmeticsGrid.addArrangedSubview(row)
                currentRow = []
            }
        }
        if !currentRow.isEmpty {
            // Pad with spacers
            while currentRow.count < itemsPerRow {
                let spacer = NSView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                currentRow.append(spacer)
            }
            let row = NSStackView(views: currentRow)
            row.orientation = .horizontal
            row.distribution = .fillEqually
            row.spacing = 8
            cosmeticsGrid.addArrangedSubview(row)
        }
    }

    private func buildCosmeticCell(_ cosmetic: Cosmetic) -> NSView {
        let cell = NSView()
        cell.wantsLayer = true
        cell.layer?.cornerRadius = 6
        cell.layer?.backgroundColor = cosmetic.owned
            ? NSColor(white: 0.2, alpha: 1).cgColor
            : NSColor(white: 0.1, alpha: 1).cgColor
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let label = Self.makeLabel(size: 9, bold: false, color: cosmetic.owned ? .white : .darkGray)
        label.stringValue = cosmetic.name
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: cell.leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -2),
        ])
        return cell
    }

    // MARK: - Helpers

    private func pinToCard(_ view: NSView, card: NSView) {
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            view.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            view.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            view.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])
    }

    static func makeLabel(size: CGFloat, bold: Bool, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        label.textColor = color
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func loadPetImage() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "blob", withExtension: "png"),
              let image = NSImage(contentsOf: url)
        else { return nil }
        return image
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - PanelBackgroundView

/// The content view for the panel — draws an opaque black background with rounded bottom corners
/// and a straight top edge (flush with the menu bar).
private final class PanelBackgroundView: NSView {
    private let cornerRadius: CGFloat

    init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        guard let layer = layer else { return }
        layer.backgroundColor = NSColor.black.cgColor
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = true
    }
}

// MARK: - SectionCard

/// A rounded card with dark background used for each panel section.
private final class SectionCard: NSView {
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1).cgColor
        layer?.cornerRadius = 8
    }
}

// MARK: - ProgressBarView

/// A simple horizontal progress bar drawn with layers.
private final class ProgressBarView: NSView {
    var progress: Double = 0 {
        didSet { needsLayout = true }
    }

    private let trackLayer = CALayer()
    private let fillLayer = CALayer()
    private let accentColor: NSColor

    init(accentHex: UInt32) {
        let r = CGFloat((accentHex >> 16) & 0xFF) / 255
        let g = CGFloat((accentHex >> 8) & 0xFF) / 255
        let b = CGFloat(accentHex & 0xFF) / 255
        accentColor = NSColor(red: r, green: g, blue: b, alpha: 1)
        super.init(frame: .zero)
        wantsLayer = true

        trackLayer.backgroundColor = NSColor(white: 0.2, alpha: 1).cgColor
        trackLayer.cornerRadius = 4
        layer?.addSublayer(trackLayer)

        fillLayer.backgroundColor = accentColor.cgColor
        fillLayer.cornerRadius = 4
        layer?.addSublayer(fillLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        trackLayer.frame = bounds
        let fillWidth = bounds.width * CGFloat(min(max(progress, 0), 1))
        fillLayer.frame = NSRect(x: 0, y: 0, width: fillWidth, height: bounds.height)
    }
}

// MARK: - StatCell

/// A small view showing a title and a value for the stats grid.
private final class StatCell: NSView {
    private let valueLabel: NSTextField
    private let titleLabel: NSTextField

    var value: String = "" {
        didSet { valueLabel.stringValue = value }
    }

    init(title: String) {
        titleLabel = PanelWindow.makeLabel(size: 10, bold: false, color: .gray)
        valueLabel = PanelWindow.makeLabel(size: 13, bold: true, color: .white)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.stringValue = title

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 2
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(titleLabel)

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

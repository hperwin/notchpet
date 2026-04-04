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
    private let panelWidth: CGFloat = 520
    private let panelMaxHeight: CGFloat = 380
    private let bottomCornerRadius: CGFloat = 12
    private let openDuration: TimeInterval = 0.3
    private let closeDuration: TimeInterval = 0.2
    private let cardRadius: CGFloat = 10
    private let padding: CGFloat = 12
    private let cardPadding: CGFloat = 10

    // Accent color
    private let accent = NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1)   // #4A9EFF
    private let cardBg = NSColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1) // #1a1a1a
    private let cardBorder = NSColor(red: 0.165, green: 0.165, blue: 0.165, alpha: 1) // #2a2a2a

    // Cached state for rebuilds
    private var lastState: PetState?

    // Top row
    private let petImageView = NSImageView()
    private let petNameLabel = makeLabel(size: 14, bold: true, color: .white)
    private let stageLabel = makeLabel(size: 11, bold: false, color: NSColor(white: 0.53, alpha: 1))
    private let levelLabel = makeLabel(size: 13, bold: true, color: .white)
    private let xpBar = ProgressBarView(accentHex: 0x4A9EFF)
    private let xpDetailLabel = makeLabel(size: 10, bold: false, color: NSColor(white: 0.53, alpha: 1))
    private let streakLabel = makeLabel(size: 11, bold: false, color: NSColor(white: 0.53, alpha: 1))
    private let wpmLabel = makeLabel(size: 11, bold: false, color: NSColor(white: 0.53, alpha: 1))
    private let shinyToggle = NSButton()
    private var shinyToggleContainer: NSView?

    // Pokemon grid
    private let pokemonGridContainer = NSView()
    private var pokemonCells: [PokemonCellView] = []

    // Stats card
    private let statTotalWords = StatCell(title: "Words")
    private let statFoodEaten = StatCell(title: "Berries Fed")
    private let statPrestige = StatCell(title: "Prestige")
    private let statMutation = StatCell(title: "Mutation")

    // Achievements card
    private let achievementsStack = NSStackView()

    // Evolution track
    private var evolutionDots: [NSView] = []

    // Weekly challenge
    private let challengeBar = ProgressBarView(accentHex: 0x4A9EFF)
    private let challengeLabel = makeLabel(size: 10, bold: false, color: .lightGray)
    private let challengePercent = makeLabel(size: 10, bold: true, color: NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1))
    private var challengeCard: NSView?

    // Prestige
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

        let panelX = notchCenterX - panelWidth / 2
        let topY = screen.frame.maxY - menuBarHeight

        let startFrame = NSRect(x: panelX, y: topY, width: panelWidth, height: 0)
        setFrame(startFrame, display: true)
        alphaValue = 1
        orderFront(nil)

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
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.closePanel()
                return nil
            }
            return event
        }

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
        lastState = state

        // Pet sprite
        let sprite = PetCollection.spriteImage(for: state.selectedPet, shiny: state.useShiny)
        petImageView.image = sprite

        // Pet info
        let entry = PetCollection.allPokemon.first(where: { $0.id == state.selectedPet })
        petNameLabel.stringValue = entry?.displayName ?? state.selectedPet.capitalized
        stageLabel.stringValue = state.evolutionStage.name

        // Level & XP
        levelLabel.stringValue = "Level \(state.level)"
        xpBar.progress = state.levelProgress
        xpDetailLabel.stringValue = "\(state.xp) / \(state.xpToNextLevel) XP"
        streakLabel.stringValue = "Streak: \(state.typingStreak)d"
        wpmLabel.stringValue = "WPM: \(Int(state.currentWPM))"

        // Shiny toggle
        let hasShinyUnlocked = state.unlockedShinies.contains(state.selectedPet)
        shinyToggleContainer?.isHidden = !hasShinyUnlocked
        shinyToggle.state = state.useShiny ? .on : .off

        // Pokemon grid
        rebuildPokemonGrid(state)

        // Stats
        statTotalWords.value = formatNumber(state.totalWordsTyped)
        statFoodEaten.value = "\(state.foodEaten)"
        statPrestige.value = "\(state.prestigeCount)"
        statMutation.value = state.mutationColor ?? "None"

        // Evolution dots
        let currentIndex = state.evolutionStage.rawValue
        for (i, dot) in evolutionDots.enumerated() {
            dot.layer?.backgroundColor = i <= currentIndex
                ? accent.cgColor
                : NSColor(white: 0.25, alpha: 1).cgColor
            dot.layer?.borderColor = i == currentIndex
                ? accent.cgColor
                : NSColor.clear.cgColor
            dot.layer?.borderWidth = i == currentIndex ? 2 : 0
        }

        // Achievements
        rebuildAchievements(state.achievements)

        // Weekly challenge
        if let challenge = state.weeklyChallenge {
            challengeCard?.isHidden = false
            challengeLabel.stringValue = challenge.description
            challengeBar.progress = challenge.progress
            let pct = Int(challenge.progress * 100)
            challengePercent.stringValue = "\(pct)%"
        } else {
            challengeCard?.isHidden = true
        }

        // Prestige
        prestigeCard?.isHidden = state.level < 20
    }

    // MARK: - Build UI

    private func buildUI() {
        let container = PanelBackgroundView(cornerRadius: bottomCornerRadius)
        contentView = container

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // Main content view laid out with constraints
        let mainContent = NSView()
        mainContent.translatesAutoresizingMaskIntoConstraints = false

        let clipView = scrollView.contentView
        scrollView.documentView = mainContent

        NSLayoutConstraint.activate([
            mainContent.topAnchor.constraint(equalTo: clipView.topAnchor),
            mainContent.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            mainContent.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            mainContent.widthAnchor.constraint(equalTo: clipView.widthAnchor),
        ])

        // ===== ROW 1: Pet sprite (left) + Info card (right) =====
        let petCard = buildPetSpriteCard()
        let infoCard = buildInfoCard()
        mainContent.addSubview(petCard)
        mainContent.addSubview(infoCard)

        NSLayoutConstraint.activate([
            petCard.topAnchor.constraint(equalTo: mainContent.topAnchor, constant: padding),
            petCard.leadingAnchor.constraint(equalTo: mainContent.leadingAnchor, constant: padding),
            petCard.widthAnchor.constraint(equalToConstant: 120),
            petCard.heightAnchor.constraint(equalToConstant: 100),

            infoCard.topAnchor.constraint(equalTo: mainContent.topAnchor, constant: padding),
            infoCard.leadingAnchor.constraint(equalTo: petCard.trailingAnchor, constant: 8),
            infoCard.trailingAnchor.constraint(equalTo: mainContent.trailingAnchor, constant: -padding),
            infoCard.heightAnchor.constraint(equalToConstant: 100),
        ])

        // ===== ROW 2: Pokemon Collection (full width) =====
        let collectionCard = buildCollectionCard()
        mainContent.addSubview(collectionCard)

        NSLayoutConstraint.activate([
            collectionCard.topAnchor.constraint(equalTo: petCard.bottomAnchor, constant: 8),
            collectionCard.leadingAnchor.constraint(equalTo: mainContent.leadingAnchor, constant: padding),
            collectionCard.trailingAnchor.constraint(equalTo: mainContent.trailingAnchor, constant: -padding),
        ])

        // ===== ROW 3: Stats (left) + Achievements (right) =====
        let statsCard = buildStatsCard()
        let achievementsCard = buildAchievementsCard()
        mainContent.addSubview(statsCard)
        mainContent.addSubview(achievementsCard)

        NSLayoutConstraint.activate([
            statsCard.topAnchor.constraint(equalTo: collectionCard.bottomAnchor, constant: 8),
            statsCard.leadingAnchor.constraint(equalTo: mainContent.leadingAnchor, constant: padding),
            statsCard.widthAnchor.constraint(equalTo: mainContent.widthAnchor, multiplier: 0.5, constant: -(padding + 4)),

            achievementsCard.topAnchor.constraint(equalTo: collectionCard.bottomAnchor, constant: 8),
            achievementsCard.leadingAnchor.constraint(equalTo: statsCard.trailingAnchor, constant: 8),
            achievementsCard.trailingAnchor.constraint(equalTo: mainContent.trailingAnchor, constant: -padding),
        ])

        // ===== ROW 4: Evolution (left) + Weekly Challenge (right) =====
        let evoCard = buildEvolutionCard()
        let chalCard = buildChallengeCard()
        challengeCard = chalCard
        mainContent.addSubview(evoCard)
        mainContent.addSubview(chalCard)

        // Prestige button (hidden unless level >= 20)
        let pCard = buildPrestigeCard()
        prestigeCard = pCard
        mainContent.addSubview(pCard)

        NSLayoutConstraint.activate([
            evoCard.topAnchor.constraint(equalTo: statsCard.bottomAnchor, constant: 8),
            evoCard.leadingAnchor.constraint(equalTo: mainContent.leadingAnchor, constant: padding),
            evoCard.widthAnchor.constraint(equalTo: mainContent.widthAnchor, multiplier: 0.5, constant: -(padding + 4)),

            chalCard.topAnchor.constraint(equalTo: achievementsCard.bottomAnchor, constant: 8),
            chalCard.leadingAnchor.constraint(equalTo: evoCard.trailingAnchor, constant: 8),
            chalCard.trailingAnchor.constraint(equalTo: mainContent.trailingAnchor, constant: -padding),

            pCard.topAnchor.constraint(equalTo: evoCard.bottomAnchor, constant: 8),
            pCard.leadingAnchor.constraint(equalTo: mainContent.leadingAnchor, constant: padding),
            pCard.trailingAnchor.constraint(equalTo: mainContent.trailingAnchor, constant: -padding),
            pCard.heightAnchor.constraint(equalToConstant: 36),

            pCard.bottomAnchor.constraint(lessThanOrEqualTo: mainContent.bottomAnchor, constant: -padding),
            chalCard.bottomAnchor.constraint(lessThanOrEqualTo: mainContent.bottomAnchor, constant: -(padding + 44)),
            evoCard.bottomAnchor.constraint(lessThanOrEqualTo: mainContent.bottomAnchor, constant: -(padding + 44)),
        ])
    }

    // MARK: - Section Builders

    private func buildPetSpriteCard() -> NSView {
        let card = SectionCard()

        petImageView.imageScaling = .scaleProportionallyUpOrDown
        petImageView.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(petImageView)
        NSLayoutConstraint.activate([
            petImageView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            petImageView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            petImageView.widthAnchor.constraint(equalToConstant: 80),
            petImageView.heightAnchor.constraint(equalToConstant: 80),
        ])

        return card
    }

    private func buildInfoCard() -> NSView {
        let card = SectionCard()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Level label
        levelLabel.font = NSFont.boldSystemFont(ofSize: 13)

        // XP bar row
        xpBar.translatesAutoresizingMaskIntoConstraints = false
        xpBar.heightAnchor.constraint(equalToConstant: 6).isActive = true

        // Pet name + stage
        let nameRow = NSStackView(views: [petNameLabel, dotSeparator(), stageLabel])
        nameRow.orientation = .horizontal
        nameRow.spacing = 6

        // Streak + WPM row
        let statsRow = NSStackView(views: [streakLabel, dotSeparator(), wpmLabel])
        statsRow.orientation = .horizontal
        statsRow.spacing = 6

        // Shiny toggle
        shinyToggle.setButtonType(.switch)
        shinyToggle.title = "Shiny"
        shinyToggle.font = NSFont.systemFont(ofSize: 10)
        shinyToggle.contentTintColor = NSColor(white: 0.53, alpha: 1)
        (shinyToggle.cell as? NSButtonCell)?.attributedTitle = NSAttributedString(
            string: "Shiny",
            attributes: [.foregroundColor: NSColor(white: 0.53, alpha: 1), .font: NSFont.systemFont(ofSize: 10)]
        )
        shinyToggle.target = self
        shinyToggle.action = #selector(shinyToggled)
        shinyToggle.translatesAutoresizingMaskIntoConstraints = false
        let shinyContainer = NSView()
        shinyContainer.translatesAutoresizingMaskIntoConstraints = false
        shinyContainer.addSubview(shinyToggle)
        NSLayoutConstraint.activate([
            shinyToggle.leadingAnchor.constraint(equalTo: shinyContainer.leadingAnchor),
            shinyToggle.topAnchor.constraint(equalTo: shinyContainer.topAnchor),
            shinyToggle.bottomAnchor.constraint(equalTo: shinyContainer.bottomAnchor),
        ])
        shinyToggleContainer = shinyContainer

        // XP detail + shiny on same row
        let xpRow = NSStackView(views: [xpDetailLabel, shinyContainer])
        xpRow.orientation = .horizontal
        xpRow.spacing = 8

        stack.addArrangedSubview(levelLabel)
        stack.addArrangedSubview(xpBar)
        stack.addArrangedSubview(xpRow)
        stack.addArrangedSubview(nameRow)
        stack.addArrangedSubview(statsRow)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            xpBar.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            xpBar.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])
        pinToCard(stack, card: card)
        return card
    }

    private func buildCollectionCard() -> NSView {
        let card = SectionCard()

        let header = Self.makeLabel(size: 11, bold: true, color: .white)
        header.stringValue = "Collection"

        pokemonGridContainer.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(pokemonGridContainer)

        card.addSubview(stack)
        pinToCard(stack, card: card)

        // Grid container width must fill card
        NSLayoutConstraint.activate([
            pokemonGridContainer.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            pokemonGridContainer.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])

        return card
    }

    private func buildStatsCard() -> NSView {
        let card = SectionCard()
        let header = Self.makeLabel(size: 11, bold: true, color: .white)
        header.stringValue = "Stats"

        let grid = NSGridView(views: [
            [statTotalWords, statFoodEaten],
            [statPrestige, statMutation],
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 8
        grid.columnSpacing = 12
        for col in 0..<grid.numberOfColumns {
            grid.column(at: col).xPlacement = .fill
        }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(grid)

        card.addSubview(stack)
        pinToCard(stack, card: card)
        return card
    }

    private func buildAchievementsCard() -> NSView {
        let card = SectionCard()
        let header = Self.makeLabel(size: 11, bold: true, color: .white)
        header.stringValue = "Achievements"

        achievementsStack.orientation = .vertical
        achievementsStack.spacing = 4
        achievementsStack.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(achievementsStack)

        card.addSubview(stack)
        pinToCard(stack, card: card)
        return card
    }

    private func buildEvolutionCard() -> NSView {
        let card = SectionCard()
        let header = Self.makeLabel(size: 11, bold: true, color: .white)
        header.stringValue = "Evolution"

        let dotsStack = NSStackView()
        dotsStack.orientation = .horizontal
        dotsStack.spacing = 6
        dotsStack.alignment = .centerY
        dotsStack.distribution = .fillEqually

        evolutionDots = []
        for stage in EvolutionStage.allCases {
            let dot = NSView()
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 7
            dot.layer?.backgroundColor = NSColor(white: 0.25, alpha: 1).cgColor
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 14),
                dot.heightAnchor.constraint(equalToConstant: 14),
            ])

            let lbl = Self.makeLabel(size: 8, bold: false, color: NSColor(white: 0.53, alpha: 1))
            lbl.stringValue = stage.name
            lbl.alignment = .center

            let col = NSStackView()
            col.orientation = .vertical
            col.alignment = .centerX
            col.spacing = 2
            col.addArrangedSubview(dot)
            col.addArrangedSubview(lbl)
            dotsStack.addArrangedSubview(col)
            evolutionDots.append(dot)
        }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(dotsStack)

        card.addSubview(stack)
        pinToCard(stack, card: card)
        return card
    }

    private func buildChallengeCard() -> NSView {
        let card = SectionCard()
        let header = Self.makeLabel(size: 11, bold: true, color: .white)
        header.stringValue = "Weekly Challenge"

        challengeBar.translatesAutoresizingMaskIntoConstraints = false
        challengeBar.heightAnchor.constraint(equalToConstant: 6).isActive = true

        let barRow = NSStackView(views: [challengeBar, challengePercent])
        barRow.orientation = .horizontal
        barRow.spacing = 6
        barRow.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(challengeLabel)
        stack.addArrangedSubview(barRow)

        NSLayoutConstraint.activate([
            challengeBar.heightAnchor.constraint(equalToConstant: 6),
        ])

        card.addSubview(stack)
        pinToCard(stack, card: card)
        return card
    }

    private func buildPrestigeCard() -> NSView {
        let card = SectionCard()

        prestigeButton.title = "Rebirth"
        prestigeButton.bezelStyle = .rounded
        prestigeButton.isBordered = false
        prestigeButton.wantsLayer = true
        prestigeButton.layer?.backgroundColor = accent.cgColor
        prestigeButton.layer?.cornerRadius = 6
        prestigeButton.contentTintColor = .white
        prestigeButton.font = NSFont.boldSystemFont(ofSize: 12)
        prestigeButton.target = self
        prestigeButton.action = #selector(prestigeTapped)
        prestigeButton.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(prestigeButton)
        NSLayoutConstraint.activate([
            prestigeButton.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            prestigeButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            prestigeButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            prestigeButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4),
        ])

        card.isHidden = true
        return card
    }

    @objc private func prestigeTapped() {
        onPrestige?()
    }

    @objc private func shinyToggled() {
        guard let state = lastState else { return }
        let isShiny = shinyToggle.state == .on
        onPetSelected?(state.selectedPet, isShiny)
    }

    // MARK: - Pokemon Grid

    private func rebuildPokemonGrid(_ state: PetState) {
        pokemonCells.forEach { $0.removeFromSuperview() }
        pokemonCells.removeAll()

        let catalog = PetCollection.catalog(for: state.level)
        let cols = 10
        let cellSize: CGFloat = 40
        let cellSpacing: CGFloat = 4

        for (index, item) in catalog.enumerated() {
            let col = index % cols
            let row = index / cols

            let cell = PokemonCellView(
                entry: item.entry,
                unlocked: item.unlocked,
                isSelected: item.entry.id == state.selectedPet,
                hasShinyUnlocked: state.unlockedShinies.contains(item.entry.id)
            )
            cell.frame = NSRect(
                x: CGFloat(col) * (cellSize + cellSpacing),
                y: CGFloat(row) * (cellSize + cellSpacing),
                width: cellSize,
                height: cellSize
            )
            cell.target = self
            cell.onTap = { [weak self] id in
                self?.onPetSelected?(id, false)
            }
            pokemonGridContainer.addSubview(cell)
            pokemonCells.append(cell)
        }

        let totalRows = (catalog.count + cols - 1) / cols
        let gridHeight = CGFloat(totalRows) * (cellSize + cellSpacing) - cellSpacing
        // Update container height
        for c in pokemonGridContainer.constraints where c.firstAttribute == .height {
            pokemonGridContainer.removeConstraint(c)
        }
        pokemonGridContainer.heightAnchor.constraint(equalToConstant: max(gridHeight, cellSize)).isActive = true
    }

    // MARK: - Achievements

    private func rebuildAchievements(_ achievements: [Achievement]) {
        achievementsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let sorted = achievements.sorted { a, b in
            if a.unlocked != b.unlocked { return a.unlocked }
            return a.tier.rawValue > b.tier.rawValue
        }
        for ach in sorted.prefix(5) {
            let row = buildAchievementRow(ach)
            achievementsStack.addArrangedSubview(row)
        }
    }

    private func buildAchievementRow(_ ach: Achievement) -> NSView {
        let tierColor = ach.tier.color
        let icon = Self.makeLabel(size: 12, bold: true, color: NSColor(
            red: tierColor.r, green: tierColor.g, blue: tierColor.b, alpha: ach.unlocked ? 1 : 0.3
        ))
        icon.stringValue = ach.unlocked ? "\u{2605}" : "\u{2606}"

        let name = Self.makeLabel(size: 10, bold: true, color: ach.unlocked ? .white : .gray)
        name.stringValue = ach.name
        name.alphaValue = ach.unlocked ? 1.0 : 0.5

        let row = NSStackView(views: [icon, name])
        row.orientation = .horizontal
        row.spacing = 4
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    // MARK: - Helpers

    private func pinToCard(_ view: NSView, card: NSView) {
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: card.topAnchor, constant: cardPadding),
            view.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: cardPadding + 2),
            view.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -(cardPadding + 2)),
            view.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -cardPadding),
        ])
    }

    private func dotSeparator() -> NSTextField {
        let dot = Self.makeLabel(size: 11, bold: false, color: NSColor(white: 0.33, alpha: 1))
        dot.stringValue = "\u{00B7}"
        return dot
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

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - PokemonCellView

private final class PokemonCellView: NSView {
    let pokemonId: String
    var onTap: ((String) -> Void)?
    weak var target: AnyObject?

    init(entry: PokemonEntry, unlocked: Bool, isSelected: Bool, hasShinyUnlocked: Bool) {
        self.pokemonId = entry.id
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8

        if unlocked {
            layer?.backgroundColor = NSColor(white: 0.133, alpha: 1).cgColor // #222
            if isSelected {
                layer?.borderColor = NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1).cgColor
                layer?.borderWidth = 2
            } else {
                layer?.borderColor = NSColor.clear.cgColor
                layer?.borderWidth = 0
            }

            let imageView = NSImageView()
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.image = PetCollection.spriteImage(for: entry.id, shiny: false)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 30),
                imageView.heightAnchor.constraint(equalToConstant: 30),
            ])

            if hasShinyUnlocked {
                let sparkle = PanelWindow.makeLabel(size: 8, bold: false, color: .white)
                sparkle.stringValue = "\u{2728}"
                sparkle.translatesAutoresizingMaskIntoConstraints = false
                addSubview(sparkle)
                NSLayoutConstraint.activate([
                    sparkle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
                    sparkle.topAnchor.constraint(equalTo: topAnchor, constant: 1),
                ])
            }
        } else {
            layer?.backgroundColor = NSColor(white: 0.067, alpha: 1).cgColor // #111

            // Dark silhouette: load sprite but make it very dim
            let imageView = NSImageView()
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.image = PetCollection.spriteImage(for: entry.id, shiny: false)
            imageView.alphaValue = 0.15
            imageView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 30),
                imageView.heightAnchor.constraint(equalToConstant: 30),
            ])
        }

        // Click handling
        if unlocked {
            let click = NSClickGestureRecognizer(target: self, action: #selector(cellTapped))
            addGestureRecognizer(click)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func cellTapped() {
        onTap?(pokemonId)
    }
}

// MARK: - PanelBackgroundView

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

private final class SectionCard: NSView {
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = NSColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1).cgColor
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(red: 0.165, green: 0.165, blue: 0.165, alpha: 1).cgColor
    }
}

// MARK: - ProgressBarView

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
        trackLayer.cornerRadius = 3
        layer?.addSublayer(trackLayer)

        fillLayer.backgroundColor = accentColor.cgColor
        fillLayer.cornerRadius = 3
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

private final class StatCell: NSView {
    private let valueLabel: NSTextField
    private let titleLabel: NSTextField

    var value: String = "" {
        didSet { valueLabel.stringValue = value }
    }

    init(title: String) {
        titleLabel = PanelWindow.makeLabel(size: 9, bold: false, color: NSColor(white: 0.53, alpha: 1))
        valueLabel = PanelWindow.makeLabel(size: 12, bold: true, color: .white)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.stringValue = title

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 1
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

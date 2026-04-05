import AppKit
import QuartzCore

// MARK: - PanelWindow (DS Pokemon Party Screen Style)

final class PanelWindow: NSWindow {

    // Public API
    var isOpen: Bool = false
    var onPrestige: (() -> Void)?
    var onPetSelected: ((String, Bool) -> Void)?
    var onPartyChanged: (([String]) -> Void)?

    // Layout constants
    private let panelWidth: CGFloat = 520
    private let panelMaxHeight: CGFloat = 420
    private let bottomCornerRadius: CGFloat = 12
    private let openDuration: TimeInterval = 0.3
    private let closeDuration: TimeInterval = 0.2
    private var panelScrollView: NSScrollView?

    // DS Color palette
    private let skyBlue = NSColor(red: 0x78/255, green: 0xC8/255, blue: 0xF0/255, alpha: 1)
    private let cardGreenTop = NSColor(red: 0x48/255, green: 0xB0/255, blue: 0x48/255, alpha: 1)
    private let cardGreenBot = NSColor(red: 0x38/255, green: 0xA0/255, blue: 0x38/255, alpha: 1)
    private let cardBorderGreen = NSColor(red: 0x28/255, green: 0x68/255, blue: 0x28/255, alpha: 1)
    private let selectedRed = NSColor(red: 0xF8/255, green: 0x38/255, blue: 0x38/255, alpha: 1)
    private let hpGreen = NSColor(red: 0x48/255, green: 0xD0/255, blue: 0x48/255, alpha: 1)
    private let hpTrack = NSColor(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255, alpha: 1)
    private let tabBarBg = NSColor(red: 0x28/255, green: 0x68/255, blue: 0xA0/255, alpha: 1)
    private let tabActive = NSColor(red: 0xF8/255, green: 0xA8/255, blue: 0x00/255, alpha: 1)
    private let tabInactive = NSColor(red: 0x38/255, green: 0x78/255, blue: 0xB8/255, alpha: 1)
    private let statsBg = NSColor(red: 0xF0/255, green: 0xF0/255, blue: 0xF0/255, alpha: 1)

    // Cached state
    private var lastState: PetState?
    private var currentState: PetState?

    // Tab system
    private enum Tab: Int, CaseIterable {
        case party = 0
        case pokemon = 1
        case stats = 2
        case achievements = 3

        var title: String {
            switch self {
            case .party: return "Party"
            case .pokemon: return "Pokemon"
            case .stats: return "Stats"
            case .achievements: return "Achievements"
            }
        }
    }

    private var currentTab: Tab = .party
    private var tabButtons: [NSButton] = []
    private var tabContentView: NSView?
    private var tabBarView: NSView?
    private var containerView: NSView?

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

        // Scroll to top after opening
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            if let scrollView = self?.panelScrollView,
               let docView = scrollView.documentView {
                let topPoint = NSPoint(x: 0, y: docView.frame.height)
                scrollView.contentView.scroll(to: topPoint)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
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
        currentState = state
        rebuildTabContent()
    }

    // MARK: - Build UI

    private func buildUI() {
        let bg = PanelBackgroundView(cornerRadius: bottomCornerRadius, fillColor: .black)
        contentView = bg

        let mainContainer = NSView()
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(mainContainer)
        containerView = mainContainer

        NSLayoutConstraint.activate([
            mainContainer.topAnchor.constraint(equalTo: bg.topAnchor),
            mainContainer.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            mainContainer.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            mainContainer.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
        ])

        // Tab content area (scrollable)
        let scrollView = NSScrollView()
        panelScrollView = scrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        mainContainer.addSubview(scrollView)

        let contentHolder = NSView()
        contentHolder.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentHolder
        tabContentView = contentHolder

        let clipView = scrollView.contentView
        NSLayoutConstraint.activate([
            contentHolder.topAnchor.constraint(equalTo: clipView.topAnchor),
            contentHolder.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            contentHolder.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            contentHolder.widthAnchor.constraint(equalTo: clipView.widthAnchor),
        ])

        // Tab bar at bottom
        let tabBar = buildTabBar()
        tabBarView = tabBar
        mainContainer.addSubview(tabBar)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: tabBar.topAnchor),

            tabBar.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            tabBar.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    // MARK: - Tab Bar

    private func buildTabBar() -> NSView {
        let bar = NSView()
        bar.wantsLayer = true
        bar.layer?.backgroundColor = tabBarBg.cgColor
        bar.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: bar.topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -4),
        ])

        tabButtons.removeAll()
        for tab in Tab.allCases {
            let btn = NSButton(title: tab.title, target: self, action: #selector(tabTapped(_:)))
            btn.tag = tab.rawValue
            btn.isBordered = false
            btn.wantsLayer = true
            btn.font = NSFont.boldSystemFont(ofSize: 11)
            btn.contentTintColor = .white
            btn.layer?.cornerRadius = 6
            btn.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(btn)
            tabButtons.append(btn)
        }

        updateTabButtonStyles()
        return bar
    }

    private func updateTabButtonStyles() {
        for btn in tabButtons {
            let isActive = btn.tag == currentTab.rawValue
            btn.layer?.backgroundColor = isActive ? tabActive.cgColor : tabInactive.cgColor
            btn.contentTintColor = isActive ? .black : .white
        }
    }

    @objc private func tabTapped(_ sender: NSButton) {
        guard let tab = Tab(rawValue: sender.tag) else { return }
        currentTab = tab
        updateTabButtonStyles()
        rebuildTabContent()
    }

    // MARK: - Tab Content Rebuild

    private func rebuildTabContent() {
        guard let contentHolder = tabContentView else { return }

        // Remove all existing subviews
        contentHolder.subviews.forEach { $0.removeFromSuperview() }
        // Remove all existing constraints on contentHolder (except intrinsic ones)
        for c in contentHolder.constraints {
            contentHolder.removeConstraint(c)
        }

        guard let state = currentState else { return }

        switch currentTab {
        case .party:
            buildPartyTab(in: contentHolder, state: state)
        case .pokemon:
            buildPokemonTab(in: contentHolder, state: state)
        case .stats:
            buildStatsTab(in: contentHolder, state: state)
        case .achievements:
            buildAchievementsTab(in: contentHolder, state: state)
        }
    }

    // MARK: - Party Tab

    private func buildPartyTab(in container: NSView, state: PetState) {
        let bgImageView = NSImageView()
        bgImageView.imageScaling = .scaleAxesIndependently
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        if let url = Bundle.module.url(forResource: "bg_party", withExtension: "png") {
            bgImageView.image = NSImage(contentsOf: url)
        }
        container.addSubview(bgImageView)
        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: container.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let padding: CGFloat = 12
        let spacing: CGFloat = 8
        let columnSpacing: CGFloat = 8

        // Title label
        let title = Self.makeLabel(size: 14, bold: true, color: .white)
        title.stringValue = "Choose a Pokemon"
        title.shadow = Self.dsTextShadow()
        title.alignment = .center
        container.addSubview(title)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: padding),
            title.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        ])

        // Party slots: 2 columns x 3 rows
        // Slot 0 (lead) is slightly larger
        let party = state.party
        var previousBottomAnchor = title.bottomAnchor
        var previousBottomConstant: CGFloat = spacing + 4

        for row in 0..<3 {
            let leftIndex = row * 2
            let rightIndex = row * 2 + 1

            let leftCard = buildPartySlotCard(
                index: leftIndex,
                pokemonId: leftIndex < party.count ? party[leftIndex] : nil,
                state: state,
                isLead: leftIndex == 0
            )
            let rightCard = buildPartySlotCard(
                index: rightIndex,
                pokemonId: rightIndex < party.count ? party[rightIndex] : nil,
                state: state,
                isLead: false
            )

            container.addSubview(leftCard)
            container.addSubview(rightCard)

            let leftHeight: CGFloat = leftIndex == 0 ? 90 : 78
            let rightHeight: CGFloat = 78

            NSLayoutConstraint.activate([
                leftCard.topAnchor.constraint(equalTo: previousBottomAnchor, constant: previousBottomConstant),
                leftCard.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
                leftCard.trailingAnchor.constraint(equalTo: container.centerXAnchor, constant: -(columnSpacing / 2)),
                leftCard.heightAnchor.constraint(equalToConstant: leftHeight),

                rightCard.topAnchor.constraint(equalTo: previousBottomAnchor, constant: previousBottomConstant),
                rightCard.leadingAnchor.constraint(equalTo: container.centerXAnchor, constant: columnSpacing / 2),
                rightCard.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
                rightCard.heightAnchor.constraint(equalToConstant: rightHeight),
            ])

            // Use the taller card for next row anchor
            previousBottomAnchor = leftHeight >= rightHeight ? leftCard.bottomAnchor : rightCard.bottomAnchor
            previousBottomConstant = spacing
        }

        // Bottom constraint
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(spacer)
        NSLayoutConstraint.activate([
            spacer.topAnchor.constraint(equalTo: previousBottomAnchor, constant: padding),
            spacer.heightAnchor.constraint(equalToConstant: 1),
            spacer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            spacer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    private func buildPartySlotCard(index: Int, pokemonId: String?, state: PetState, isLead: Bool) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.translatesAutoresizingMaskIntoConstraints = false

        if let id = pokemonId, let entry = PetCollection.allPokemon.first(where: { $0.id == id }) {
            // Filled slot - green gradient card
            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = [cardGreenTop.withAlphaComponent(0.6).cgColor, cardGreenBot.withAlphaComponent(0.6).cgColor]
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
            gradientLayer.cornerRadius = 8
            gradientLayer.borderColor = cardBorderGreen.cgColor
            gradientLayer.borderWidth = 2
            card.layer?.cornerRadius = 8
            card.layer?.masksToBounds = true
            card.layer = gradientLayer

            // Lead indicator
            if isLead {
                let starLabel = Self.makeLabel(size: 9, bold: true, color: NSColor(red: 1, green: 0.85, blue: 0, alpha: 1))
                starLabel.stringValue = "LEAD"
                starLabel.shadow = Self.dsTextShadow()
                card.addSubview(starLabel)
                NSLayoutConstraint.activate([
                    starLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
                    starLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6),
                ])
            }

            // Sprite
            let spriteSize: CGFloat = isLead ? 52 : 44
            let spriteView = NSImageView()
            spriteView.imageScaling = .scaleProportionallyUpOrDown
            spriteView.image = PetCollection.spriteImage(for: id, shiny: state.useShiny && state.unlockedShinies.contains(id))
            spriteView.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(spriteView)

            // Name label
            let nameLabel = Self.makeLabel(size: 13, bold: true, color: .white)
            nameLabel.stringValue = entry.displayName
            nameLabel.shadow = Self.dsTextShadow()
            card.addSubview(nameLabel)

            // Level label
            let levelLabel = Self.makeLabel(size: 11, bold: false, color: .white)
            levelLabel.stringValue = "Lv.\(state.level)"
            levelLabel.shadow = Self.dsTextShadow()
            card.addSubview(levelLabel)

            // HP bar
            let hpBarTrack = NSView()
            hpBarTrack.wantsLayer = true
            hpBarTrack.layer?.backgroundColor = hpTrack.cgColor
            hpBarTrack.layer?.cornerRadius = 3
            hpBarTrack.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(hpBarTrack)

            let hpBarFill = NSView()
            hpBarFill.wantsLayer = true
            hpBarFill.layer?.backgroundColor = hpGreen.cgColor
            hpBarFill.layer?.cornerRadius = 3
            hpBarFill.translatesAutoresizingMaskIntoConstraints = false
            hpBarTrack.addSubview(hpBarFill)

            let hpLabel = Self.makeLabel(size: 9, bold: false, color: NSColor(white: 0.9, alpha: 1))
            hpLabel.stringValue = "HP"
            hpLabel.shadow = Self.dsTextShadow()
            card.addSubview(hpLabel)

            NSLayoutConstraint.activate([
                spriteView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 6),
                spriteView.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: -2),
                spriteView.widthAnchor.constraint(equalToConstant: spriteSize),
                spriteView.heightAnchor.constraint(equalToConstant: spriteSize),

                nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: isLead ? 14 : 10),
                nameLabel.leadingAnchor.constraint(equalTo: spriteView.trailingAnchor, constant: 6),

                levelLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
                levelLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),

                hpLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
                hpLabel.leadingAnchor.constraint(equalTo: spriteView.trailingAnchor, constant: 6),

                hpBarTrack.centerYAnchor.constraint(equalTo: hpLabel.centerYAnchor),
                hpBarTrack.leadingAnchor.constraint(equalTo: hpLabel.trailingAnchor, constant: 4),
                hpBarTrack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
                hpBarTrack.heightAnchor.constraint(equalToConstant: 6),

                hpBarFill.topAnchor.constraint(equalTo: hpBarTrack.topAnchor),
                hpBarFill.leadingAnchor.constraint(equalTo: hpBarTrack.leadingAnchor),
                hpBarFill.heightAnchor.constraint(equalTo: hpBarTrack.heightAnchor),
                hpBarFill.widthAnchor.constraint(equalTo: hpBarTrack.widthAnchor, multiplier: CGFloat(state.levelProgress)),
            ])

            // Tap to view detail
            let click = NSClickGestureRecognizer(target: self, action: #selector(partySlotTapped(_:)))
            card.addGestureRecognizer(click)
            card.setValue(id, forKey: "toolTip") // store pokemon id in tooltip for retrieval

        } else {
            // Empty slot - dashed appearance
            card.layer?.cornerRadius = 8
            card.layer?.borderWidth = 2
            card.layer?.borderColor = NSColor(white: 0.6, alpha: 0.5).cgColor
            card.layer?.backgroundColor = NSColor(white: 1, alpha: 0.1).cgColor

            // Draw dashed border via layer
            let dashedLayer = CAShapeLayer()
            dashedLayer.strokeColor = NSColor(white: 0.7, alpha: 0.5).cgColor
            dashedLayer.fillColor = nil
            dashedLayer.lineDashPattern = [6, 4]
            dashedLayer.lineWidth = 2
            card.layer?.addSublayer(dashedLayer)

            let emptyLabel = Self.makeLabel(size: 12, bold: false, color: NSColor(white: 0.8, alpha: 0.7))
            emptyLabel.stringValue = "Empty"
            emptyLabel.alignment = .center
            card.addSubview(emptyLabel)

            NSLayoutConstraint.activate([
                emptyLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
                emptyLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            ])

            // Tap to switch to pokemon tab
            let click = NSClickGestureRecognizer(target: self, action: #selector(emptySlotTapped))
            card.addGestureRecognizer(click)
        }

        return card
    }

    @objc private func partySlotTapped(_ sender: NSClickGestureRecognizer) {
        guard let card = sender.view, let id = card.toolTip, !id.isEmpty else { return }
        showPokemonDetail(id: id, showAddToParty: false)
    }

    @objc private func emptySlotTapped() {
        currentTab = .pokemon
        updateTabButtonStyles()
        rebuildTabContent()
    }

    // MARK: - Pokemon Tab (Collection Grid)

    private func buildPokemonTab(in container: NSView, state: PetState) {
        let bgImageView = NSImageView()
        bgImageView.imageScaling = .scaleAxesIndependently
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        if let url = Bundle.module.url(forResource: "bg_collection", withExtension: "png") {
            bgImageView.image = NSImage(contentsOf: url)
        }
        container.addSubview(bgImageView)
        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: container.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let padding: CGFloat = 12
        let catalog = PetCollection.catalog(for: state.level)
        let cols = 5
        let cellSpacing: CGFloat = 8
        // Calculate cell size to fill width
        let totalSpacing = padding * 2 + cellSpacing * CGFloat(cols - 1)

        let gridContainer = NSView()
        gridContainer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(gridContainer)

        // Title
        let title = Self.makeLabel(size: 14, bold: true, color: .white)
        title.stringValue = "Collection (\(catalog.filter { $0.unlocked }.count)/\(catalog.count))"
        title.shadow = Self.dsTextShadow()
        title.alignment = .center
        container.addSubview(title)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: padding),
            title.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            gridContainer.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            gridContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            gridContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
        ])

        // We'll lay cells out manually based on gridContainer's expected width
        let availableWidth = panelWidth - totalSpacing
        let cellSize = floor(availableWidth / CGFloat(cols))

        for (index, item) in catalog.enumerated() {
            let col = index % cols
            let row = index / cols

            let cell = buildCollectionCell(item: item, state: state, cellSize: cellSize)
            cell.frame = NSRect(
                x: CGFloat(col) * (cellSize + cellSpacing),
                y: CGFloat(row) * (cellSize + cellSpacing),
                width: cellSize,
                height: cellSize
            )
            gridContainer.addSubview(cell)
        }

        let totalRows = (catalog.count + cols - 1) / cols
        let gridHeight = CGFloat(totalRows) * (cellSize + cellSpacing)

        NSLayoutConstraint.activate([
            gridContainer.heightAnchor.constraint(equalToConstant: max(gridHeight, cellSize)),
            gridContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -padding),
        ])
    }

    private func buildCollectionCell(item: (entry: PokemonEntry, unlocked: Bool), state: PetState, cellSize: CGFloat) -> NSView {
        let cell = NSView(frame: .zero)
        cell.wantsLayer = true
        cell.layer?.cornerRadius = 8

        let isInParty = state.party.contains(item.entry.id)
        let isSelected = item.entry.id == state.selectedPet

        if item.unlocked {
            // Green card for unlocked
            let gradient = CAGradientLayer()
            gradient.colors = [cardGreenTop.withAlphaComponent(0.6).cgColor, cardGreenBot.withAlphaComponent(0.6).cgColor]
            gradient.cornerRadius = 8
            gradient.borderWidth = isSelected ? 3 : 2
            gradient.borderColor = isSelected ? selectedRed.cgColor : cardBorderGreen.cgColor
            cell.layer = gradient

            let imageView = NSImageView()
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.image = PetCollection.spriteImage(for: item.entry.id, shiny: false)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(imageView)

            let nameLabel = Self.makeLabel(size: 8, bold: true, color: .white)
            nameLabel.stringValue = item.entry.displayName
            nameLabel.shadow = Self.dsTextShadow()
            nameLabel.alignment = .center
            nameLabel.lineBreakMode = .byTruncatingTail
            cell.addSubview(nameLabel)

            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                imageView.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
                imageView.widthAnchor.constraint(equalToConstant: cellSize * 0.6),
                imageView.heightAnchor.constraint(equalToConstant: cellSize * 0.6),

                nameLabel.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -3),
                nameLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                nameLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            ])

            if isInParty {
                let partyDot = NSView()
                partyDot.wantsLayer = true
                partyDot.layer?.backgroundColor = tabActive.cgColor
                partyDot.layer?.cornerRadius = 4
                partyDot.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(partyDot)
                NSLayoutConstraint.activate([
                    partyDot.topAnchor.constraint(equalTo: cell.topAnchor, constant: 3),
                    partyDot.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -3),
                    partyDot.widthAnchor.constraint(equalToConstant: 8),
                    partyDot.heightAnchor.constraint(equalToConstant: 8),
                ])
            }

            let click = NSClickGestureRecognizer(target: self, action: #selector(collectionCellTapped(_:)))
            cell.addGestureRecognizer(click)
            cell.toolTip = item.entry.id

        } else {
            // Dark locked cell
            cell.layer?.backgroundColor = NSColor(white: 0, alpha: 0.4).cgColor
            cell.layer?.borderWidth = 1
            cell.layer?.borderColor = NSColor(white: 0.3, alpha: 0.5).cgColor

            let imageView = NSImageView()
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.image = PetCollection.spriteImage(for: item.entry.id, shiny: false)
            imageView.alphaValue = 0.15
            imageView.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(imageView)

            let lockLabel = Self.makeLabel(size: 9, bold: false, color: NSColor(white: 0.5, alpha: 1))
            lockLabel.stringValue = "Lv.\(item.entry.unlockLevel)"
            lockLabel.alignment = .center
            cell.addSubview(lockLabel)

            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                imageView.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
                imageView.widthAnchor.constraint(equalToConstant: cellSize * 0.6),
                imageView.heightAnchor.constraint(equalToConstant: cellSize * 0.6),

                lockLabel.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -3),
                lockLabel.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            ])

            // Tapping locked cell shows detail too
            let click = NSClickGestureRecognizer(target: self, action: #selector(collectionCellTapped(_:)))
            cell.addGestureRecognizer(click)
            cell.toolTip = item.entry.id
        }

        return cell
    }

    @objc private func collectionCellTapped(_ sender: NSClickGestureRecognizer) {
        guard let cell = sender.view, let id = cell.toolTip, !id.isEmpty else { return }
        showPokemonDetail(id: id, showAddToParty: true)
    }

    // MARK: - Stats Tab

    private func buildStatsTab(in container: NSView, state: PetState) {
        let bgImageView = NSImageView()
        bgImageView.imageScaling = .scaleAxesIndependently
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        if let url = Bundle.module.url(forResource: "bg_stats", withExtension: "png") {
            bgImageView.image = NSImage(contentsOf: url)
        }
        container.addSubview(bgImageView)
        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: container.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let padding: CGFloat = 16

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: padding),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -padding),
        ])

        // Level & XP card
        let levelCard = buildStatsSection(title: "Level & XP", rows: [
            ("Level", "\(state.level)"),
            ("Total XP", "\(state.totalXPEarned)"),
            ("XP to Next", "\(state.xp) / \(state.xpToNextLevel)"),
            ("Evolution", state.evolutionStage.name),
        ])
        stack.addArrangedSubview(levelCard)
        levelCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
        levelCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true

        // XP progress bar
        let xpBar = ProgressBarView(accentHex: 0x48D048)
        xpBar.progress = state.levelProgress
        xpBar.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(xpBar)
        NSLayoutConstraint.activate([
            xpBar.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            xpBar.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            xpBar.heightAnchor.constraint(equalToConstant: 8),
        ])

        // Typing stats
        let typingCard = buildStatsSection(title: "Typing", rows: [
            ("Words Typed", formatNumber(state.totalWordsTyped)),
            ("Current WPM", "\(Int(state.currentWPM))"),
            ("Typing Streak", "\(state.typingStreak) days"),
            ("Login Streak", "\(state.loginStreak) days"),
        ])
        stack.addArrangedSubview(typingCard)
        typingCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
        typingCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true

        // Pet stats
        let petCard = buildStatsSection(title: "Pet", rows: [
            ("Berries Fed", "\(state.foodEaten)"),
            ("Prestige Count", "\(state.prestigeCount)"),
            ("Mutation", state.mutationColor ?? "None"),
            ("XP Multiplier", String(format: "%.1fx", state.totalMultiplier)),
        ])
        stack.addArrangedSubview(petCard)
        petCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
        petCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true

        // Weekly challenge
        if let challenge = state.weeklyChallenge {
            let chalCard = buildStatsSection(title: "Weekly Challenge", rows: [
                ("Challenge", challenge.description),
                ("Progress", "\(challenge.currentValue)/\(challenge.targetValue)"),
            ])
            stack.addArrangedSubview(chalCard)
            chalCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
            chalCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true

            let chalBar = ProgressBarView(accentHex: 0xF8A800)
            chalBar.progress = challenge.progress
            chalBar.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(chalBar)
            NSLayoutConstraint.activate([
                chalBar.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
                chalBar.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
                chalBar.heightAnchor.constraint(equalToConstant: 8),
            ])
        }

        // Prestige button
        if state.level >= 20 {
            let prestigeBtn = NSButton(title: "Rebirth (Prestige)", target: self, action: #selector(prestigeTapped))
            prestigeBtn.isBordered = false
            prestigeBtn.wantsLayer = true
            prestigeBtn.layer?.backgroundColor = selectedRed.cgColor
            prestigeBtn.layer?.cornerRadius = 8
            prestigeBtn.contentTintColor = .white
            prestigeBtn.font = NSFont.boldSystemFont(ofSize: 13)
            prestigeBtn.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(prestigeBtn)
            NSLayoutConstraint.activate([
                prestigeBtn.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
                prestigeBtn.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
                prestigeBtn.heightAnchor.constraint(equalToConstant: 36),
            ])
        }
    }

    private func buildStatsSection(title: String, rows: [(String, String)]) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor(white: 0, alpha: 0.4).cgColor
        card.layer?.cornerRadius = 8
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor(white: 1, alpha: 0.2).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        let innerStack = NSStackView()
        innerStack.orientation = .vertical
        innerStack.spacing = 4
        innerStack.alignment = .leading
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(innerStack)

        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            innerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            innerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            innerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])

        let titleLabel = Self.makeLabel(size: 12, bold: true, color: tabActive)
        titleLabel.stringValue = title
        innerStack.addArrangedSubview(titleLabel)

        for (key, value) in rows {
            let rowStack = NSStackView()
            rowStack.orientation = .horizontal
            rowStack.spacing = 4
            rowStack.translatesAutoresizingMaskIntoConstraints = false

            let keyLabel = Self.makeLabel(size: 11, bold: false, color: NSColor(white: 0.85, alpha: 1))
            keyLabel.stringValue = key
            keyLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

            let valLabel = Self.makeLabel(size: 11, bold: true, color: .white)
            valLabel.stringValue = value
            valLabel.alignment = .right
            valLabel.setContentHuggingPriority(.required, for: .horizontal)
            valLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

            rowStack.addArrangedSubview(keyLabel)
            rowStack.addArrangedSubview(valLabel)

            innerStack.addArrangedSubview(rowStack)
            rowStack.leadingAnchor.constraint(equalTo: innerStack.leadingAnchor).isActive = true
            rowStack.trailingAnchor.constraint(equalTo: innerStack.trailingAnchor).isActive = true
        }

        return card
    }

    // MARK: - Achievements Tab

    private func buildAchievementsTab(in container: NSView, state: PetState) {
        let bgImageView = NSImageView()
        bgImageView.imageScaling = .scaleAxesIndependently
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        if let url = Bundle.module.url(forResource: "bg_achievements", withExtension: "png") {
            bgImageView.image = NSImage(contentsOf: url)
        }
        container.addSubview(bgImageView)
        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: container.topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let padding: CGFloat = 16

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: padding),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -padding),
        ])

        let title = Self.makeLabel(size: 14, bold: true, color: .white)
        let unlockedCount = state.achievements.filter { $0.unlocked }.count
        title.stringValue = "Achievements (\(unlockedCount)/\(state.achievements.count))"
        title.shadow = Self.dsTextShadow()
        stack.addArrangedSubview(title)

        // Sort: unlocked first, then by tier descending
        let sorted = state.achievements.sorted { a, b in
            if a.unlocked != b.unlocked { return a.unlocked }
            return a.tier.rawValue > b.tier.rawValue
        }

        for ach in sorted {
            let row = buildAchievementCard(ach)
            stack.addArrangedSubview(row)
            row.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
            row.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
        }
    }

    private func buildAchievementCard(_ ach: Achievement) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.translatesAutoresizingMaskIntoConstraints = false

        let tierColor = ach.tier.color
        let tierNSColor = NSColor(red: tierColor.r, green: tierColor.g, blue: tierColor.b, alpha: 1)

        if ach.unlocked {
            card.layer?.backgroundColor = NSColor(white: 0, alpha: 0.4).cgColor
            card.layer?.borderWidth = 2
            card.layer?.borderColor = tierNSColor.cgColor
        } else {
            card.layer?.backgroundColor = NSColor(white: 0, alpha: 0.2).cgColor
            card.layer?.borderWidth = 1
            card.layer?.borderColor = NSColor(white: 0.3, alpha: 0.5).cgColor
        }

        let icon = Self.makeLabel(size: 16, bold: true, color: tierNSColor.withAlphaComponent(ach.unlocked ? 1 : 0.3))
        icon.stringValue = ach.unlocked ? "\u{2605}" : "\u{2606}"

        let nameLabel = Self.makeLabel(size: 12, bold: true, color: ach.unlocked ? .white : NSColor(white: 0.5, alpha: 1))
        nameLabel.stringValue = ach.name

        let descLabel = Self.makeLabel(size: 10, bold: false, color: ach.unlocked ? NSColor(white: 0.8, alpha: 1) : NSColor(white: 0.4, alpha: 1))
        descLabel.stringValue = ach.description

        let xpLabel = Self.makeLabel(size: 10, bold: true, color: tabActive.withAlphaComponent(ach.unlocked ? 1 : 0.4))
        xpLabel.stringValue = "+\(ach.xpReward) XP"
        xpLabel.alignment = .right
        xpLabel.setContentHuggingPriority(.required, for: .horizontal)
        xpLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let tierLabel = Self.makeLabel(size: 9, bold: true, color: tierNSColor.withAlphaComponent(ach.unlocked ? 1 : 0.4))
        tierLabel.stringValue = ach.tier.name
        tierLabel.alignment = .right
        tierLabel.setContentHuggingPriority(.required, for: .horizontal)

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 1
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(descLabel)

        let rightStack = NSStackView()
        rightStack.orientation = .vertical
        rightStack.spacing = 1
        rightStack.alignment = .trailing
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        rightStack.addArrangedSubview(xpLabel)
        rightStack.addArrangedSubview(tierLabel)

        card.addSubview(icon)
        card.addSubview(textStack)
        card.addSubview(rightStack)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),

            textStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            textStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),

            rightStack.leadingAnchor.constraint(greaterThanOrEqualTo: textStack.trailingAnchor, constant: 8),
            rightStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            rightStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])

        return card
    }

    // MARK: - Detail Navigation

    private func showPokemonDetail(id: String, showAddToParty: Bool) {
        guard let state = currentState,
              let scrollView = panelScrollView,
              let entry = PetCollection.allPokemon.first(where: { $0.id == id }) else { return }

        let unlocked = entry.unlockLevel <= state.level
        let shinyUnlocked = state.unlockedShinies.contains(id)

        let detail = PokemonDetailView(entry: entry, unlocked: unlocked, shinyUnlocked: shinyUnlocked, currentLevel: state.level)
        detail.onBack = { [weak self] in
            self?.showCurrentTab()
        }
        detail.onSelectPet = { [weak self] petId, shiny in
            self?.onPetSelected?(petId, shiny)
            self?.showCurrentTab()
        }

        // If showing from pokemon tab and party isn't full and pokemon is unlocked and not in party
        if showAddToParty && unlocked && !state.party.contains(id) && state.party.count < 6 {
            // We'll add an "Add to Party" button via a wrapper
            let wrapper = NSView()
            wrapper.translatesAutoresizingMaskIntoConstraints = false

            detail.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(detail)

            let addBtn = NSButton(title: "Add to Party", target: self, action: #selector(addToPartyTapped(_:)))
            addBtn.isBordered = false
            addBtn.wantsLayer = true
            addBtn.layer?.backgroundColor = tabActive.cgColor
            addBtn.layer?.cornerRadius = 8
            addBtn.contentTintColor = .black
            addBtn.font = NSFont.boldSystemFont(ofSize: 13)
            addBtn.translatesAutoresizingMaskIntoConstraints = false
            addBtn.toolTip = id // store pokemon id
            wrapper.addSubview(addBtn)

            NSLayoutConstraint.activate([
                detail.topAnchor.constraint(equalTo: wrapper.topAnchor),
                detail.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                detail.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),

                addBtn.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 8),
                addBtn.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
                addBtn.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -16),
                addBtn.heightAnchor.constraint(equalToConstant: 36),
                addBtn.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -16),
            ])

            scrollView.documentView = wrapper
            let clipView = scrollView.contentView
            NSLayoutConstraint.activate([
                wrapper.widthAnchor.constraint(equalTo: clipView.widthAnchor),
            ])
        } else {
            detail.setAsContent(in: scrollView)
        }
    }

    @objc private func addToPartyTapped(_ sender: NSButton) {
        guard let id = sender.toolTip, !id.isEmpty, let state = currentState else { return }
        if state.party.count < 6 && !state.party.contains(id) {
            state.party.append(id)
            state.save()
            onPartyChanged?(state.party)
            // Return to party tab
            currentTab = .party
            updateTabButtonStyles()
            showCurrentTab()
        }
    }

    private func showCurrentTab() {
        guard let scrollView = panelScrollView, let contentHolder = tabContentView else { return }
        scrollView.documentView = contentHolder
        rebuildTabContent()
    }

    @objc private func prestigeTapped() {
        onPrestige?()
    }

    // MARK: - Helpers

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

    private static func dsTextShadow() -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: 0.6)
        shadow.shadowOffset = NSSize(width: 1, height: -1)
        shadow.shadowBlurRadius = 0
        return shadow
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - PanelBackgroundView

private final class PanelBackgroundView: NSView {
    private let cornerRadius: CGFloat
    private let fillColor: NSColor

    init(cornerRadius: CGFloat, fillColor: NSColor = .black) {
        self.cornerRadius = cornerRadius
        self.fillColor = fillColor
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        guard let layer = layer else { return }
        layer.backgroundColor = fillColor.cgColor
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = true
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

import AppKit
import QuartzCore

// MARK: - PanelWindow (DS Pokemon Party Screen Style)

final class PanelWindow: NSWindow {

    // Public API
    var isOpen: Bool = false
    var onPartyChanged: (([String]) -> Void)?
    var onBerriesToggled: ((Bool) -> Void)?

    // Friends callbacks (wired by AppDelegate to FriendsManager)
    var onAddFriend: ((String) -> Void)?      // friend code
    var onSendGift: ((String) -> Void)?       // friend ID
    var onAcceptRequest: ((String) -> Void)?  // request ID
    var onRefreshFriends: (() -> Void)?

    // Layout constants
    private let panelWidth: CGFloat = 580
    private let panelMaxHeight: CGFloat = 500
    private let bottomCornerRadius: CGFloat = 12
    private let openDuration: TimeInterval = 0.3
    private let closeDuration: TimeInterval = 0.2

    // Tab system
    private var tabs: [DSTab] = []
    private var currentTabIndex: Int = 0
    private var tabButtons: [RetroNavButton] = []
    private var tabContentArea: NSView!
    private var tabBarView: NSView?
    private var containerView: NSView?

    // Cached state
    private var lastState: PetState?

    // Event monitors
    private var localMonitor: Any?
    private var globalMonitor: Any?

    // Tab titles
    private static let tabTitles = ["Party", "Box", "Friends", "Profile"]

    // Collection overlay (not a tab — shown via "See All")
    private var collectionOverlay: CollectionTabView?


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
        setupTabs()
    }

    // Borderless windows must override these to accept keyboard input (for text fields)
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

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
        tabs[currentTabIndex].update(state: state)
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

        // Tab content area (fills above the tab bar)
        let contentArea = NSView()
        contentArea.translatesAutoresizingMaskIntoConstraints = false
        mainContainer.addSubview(contentArea)
        tabContentArea = contentArea

        // Tab bar at bottom
        let tabBar = buildTabBar()
        tabBarView = tabBar
        mainContainer.addSubview(tabBar)

        NSLayoutConstraint.activate([
            contentArea.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            contentArea.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            contentArea.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            contentArea.bottomAnchor.constraint(equalTo: tabBar.topAnchor),

            tabBar.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            tabBar.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    // MARK: - Tab Setup

    private func setupTabs() {
        let party = PartyTabView()
        let collection = CollectionTabView()
        let friends = FriendsTabView()
        let profile = ProfileTabView()
        let appSettings = AppSettingsTabView()

        tabs = [party, collection, friends, profile, appSettings]

        for tab in tabs {
            tab.onAction = { [weak self] action in
                self?.handleTabAction(action)
            }
        }

        switchToTab(0)
    }

    // MARK: - Tab Actions

    private func handleTabAction(_ action: TabAction) {
        switch action {
        case .showDetail(let id):
            showPokemonDetail(id: id)
        case .switchToTab(let index):
            switchToTab(index)
        case .addToParty(let id):
            if let state = lastState {
                if state.party.count < 6 && !state.party.contains(id) {
                    state.party.append(id)
                    if state.pokemonInstances[id] == nil {
                        var newInstance = PokemonInstance(pokemonId: id)
                        if let learnset = MoveData.learnsets[id], let starter = learnset.first(where: { $0.0 == 1 }) {
                            newInstance.moves = [starter.1]
                        }
                        state.pokemonInstances[id] = newInstance
                    }
                    state.save()
                    onPartyChanged?(state.party)
                    refreshData(state)
                }
            }
        case .removeFromParty(let id):
            if let state = lastState {
                state.party.removeAll { $0 == id }
                state.save()
                onPartyChanged?(state.party)
                refreshData(state)
            }
        case .reorderParty(let newOrder):
            if let state = lastState {
                state.party = newOrder
                state.save()
                onPartyChanged?(state.party)
                refreshData(state)
            }
        case .cycleTier(let bundleID):
            if let state = lastState {
                let current = state.appTier(for: bundleID)
                let next: AppTier
                switch current {
                case .deepWork: next = .normal
                case .normal: next = .distraction
                case .distraction: next = .deepWork
                }
                let defaultTier: AppTier
                if PetState.defaultDeepWorkBundleIDs.contains(bundleID) {
                    defaultTier = .deepWork
                } else if PetState.defaultDistractionBundleIDs.contains(bundleID) {
                    defaultTier = .distraction
                } else {
                    defaultTier = .normal
                }
                if next == defaultTier {
                    state.appTierOverrides.removeValue(forKey: bundleID)
                } else {
                    state.appTierOverrides[bundleID] = next
                }
                state.save()
                refreshData(state)
            }
        case .toggleBerries:
            Preferences.shared.berriesEnabled.toggle()
            onBerriesToggled?(Preferences.shared.berriesEnabled)
            if let state = lastState { refreshData(state) }

        case .showCollection:
            showCollection()

        case .addFriend(let code):
            onAddFriend?(code)

        case .sendGift(let friendId):
            onSendGift?(friendId)

        case .acceptFriendRequest(let requestId):
            onAcceptRequest?(requestId)

        case .refreshFriends:
            onRefreshFriends?()
        }
    }

    /// Access the Friends tab for external data updates.
    var friendsTabIfPresent: FriendsTabView? {
        tabs.compactMap { $0 as? FriendsTabView }.first
    }

    // MARK: - Tab Switching

    private func switchToTab(_ index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        currentTabIndex = index

        // Remove ALL subviews and their constraints
        for sub in tabContentArea.subviews {
            sub.removeFromSuperview()
        }

        // Get the tab view and set its frame directly (more reliable than constraints for cached views)
        let tabView = tabs[index].view
        tabView.translatesAutoresizingMaskIntoConstraints = true
        tabView.frame = tabContentArea.bounds
        tabView.autoresizingMask = [.width, .height]
        tabContentArea.addSubview(tabView)

        // Update tab bar button states
        updateTabBarAppearance()

        // Update content
        if let state = lastState {
            tabs[index].update(state: state)
        }

        // Force layout to prevent blank tab
        tabView.needsLayout = true
        tabView.layoutSubtreeIfNeeded()
        tabContentArea.needsLayout = true
        tabContentArea.layoutSubtreeIfNeeded()
    }

    // MARK: - Tab Bar

    private func buildTabBar() -> NSView {
        let bar = NSView()
        bar.wantsLayer = true
        bar.translatesAutoresizingMaskIntoConstraints = false

        // Blue gradient background
        let gradient = CAGradientLayer()
        gradient.colors = [DS.navBlueTop.cgColor, DS.navBlueBot.cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        bar.layer?.addSublayer(gradient)

        // 1pt light blue top border
        let topBorder = CALayer()
        let topBorderColor = NSColor(red: 0x50/255.0, green: 0x78/255.0, blue: 0xB0/255.0, alpha: 1)
        topBorder.backgroundColor = topBorderColor.cgColor
        bar.layer?.addSublayer(topBorder)

        bar.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: bar, queue: .main) { _ in
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            gradient.frame = bar.bounds
            topBorder.frame = CGRect(x: 0, y: bar.bounds.height - 1, width: bar.bounds.width, height: 1)
            CATransaction.commit()
        }

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: bar.topAnchor),
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
        ])

        let labels = ["Party", "Box", "Friends", "Profile", "Apps"]
        tabButtons.removeAll()
        for (index, title) in labels.enumerated() {
            let btn = RetroNavButton(label: title, index: index) { [weak self] idx in
                self?.switchToTab(idx)
            }
            stack.addArrangedSubview(btn)
            btn.topAnchor.constraint(equalTo: stack.topAnchor).isActive = true
            btn.bottomAnchor.constraint(equalTo: stack.bottomAnchor).isActive = true
            tabButtons.append(btn)
        }

        updateTabBarAppearance()
        return bar
    }

    private func updateTabBarAppearance() {
        for btn in tabButtons {
            btn.setActive(btn.tabIndex == currentTabIndex)
        }
    }

    /// Exposes the BattleTabView so the app delegate can set XP awarded.
    // MARK: - Collection Overlay

    private func showCollection() {
        let collection = CollectionTabView()
        collection.onAction = { [weak self] action in
            self?.handleTabAction(action)
        }
        if let state = lastState {
            collection.update(state: state)
        }
        collectionOverlay = collection

        tabContentArea.subviews.forEach { $0.removeFromSuperview() }
        let collView = collection.view
        collView.translatesAutoresizingMaskIntoConstraints = true
        collView.frame = tabContentArea.bounds
        collView.autoresizingMask = [.width, .height]
        tabContentArea.addSubview(collView)
    }

    // MARK: - Online Matchmaking

    // MARK: - Detail Navigation

    private func showPokemonDetail(id: String) {
        guard let state = lastState,
              let entry = PetCollection.entry(for: id) else { return }

        let instance = state.pokemonInstances[id]
        let shinyUnlocked = state.unlockedShinies.contains(id)
        let isInParty = state.party.contains(id)
        let partyFull = state.party.count >= 6

        let detail = PokemonDetailView(entry: entry, instance: instance, shinyUnlocked: shinyUnlocked, isInParty: isInParty, partyFull: partyFull)
        detail.translatesAutoresizingMaskIntoConstraints = false
        detail.onBack = { [weak self] in
            self?.restoreCurrentTab()
        }
        detail.onAddToParty = { [weak self] pokemonId in
            self?.handleTabAction(.addToParty(id: pokemonId))
        }
        detail.onRemoveFromParty = { [weak self] pokemonId in
            self?.handleTabAction(.removeFromParty(id: pokemonId))
        }

        // Replace tab content area with detail view
        tabContentArea.subviews.forEach { $0.removeFromSuperview() }
        tabContentArea.addSubview(detail)
        NSLayoutConstraint.activate([
            detail.topAnchor.constraint(equalTo: tabContentArea.topAnchor),
            detail.leadingAnchor.constraint(equalTo: tabContentArea.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: tabContentArea.trailingAnchor),
            detail.bottomAnchor.constraint(equalTo: tabContentArea.bottomAnchor),
        ])
    }

    func showDetailForPokemon(_ id: String) {
        showPokemonDetail(id: id)
    }

    private func restoreCurrentTab() {
        switchToTab(currentTabIndex)
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

// MARK: - RetroNavButton

private class RetroNavButton: NSView {
    let tabIndex: Int
    private let labelField: NSTextField
    private let gradientLayer = CAGradientLayer()
    private let dividerLayer = CALayer()
    private var onTap: ((Int) -> Void)?

    init(label: String, index: Int, onTap: @escaping (Int) -> Void) {
        self.tabIndex = index
        self.onTap = onTap

        let tf = NSTextField(labelWithString: label)
        tf.font = NSFont.boldSystemFont(ofSize: 11)
        tf.textColor = .white
        tf.alignment = .center
        tf.drawsBackground = false
        tf.isBordered = false
        tf.isEditable = false
        tf.shadow = nil
        tf.translatesAutoresizingMaskIntoConstraints = false
        self.labelField = tf

        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        // Gradient fill
        gradientLayer.colors = [DS.navInactiveTop.cgColor, DS.navInactiveBot.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer?.addSublayer(gradientLayer)

        // Right-side 1pt dark divider
        dividerLayer.backgroundColor = NSColor(red: 0x18/255.0, green: 0x30/255.0, blue: 0x58/255.0, alpha: 1).cgColor
        layer?.addSublayer(dividerLayer)

        addSubview(labelField)
        NSLayoutConstraint.activate([
            labelField.centerXAnchor.constraint(equalTo: centerXAnchor),
            labelField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: self, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.gradientLayer.frame = self.bounds
            self.dividerLayer.frame = CGRect(x: self.bounds.width - 1, y: 0, width: 1, height: self.bounds.height)
            CATransaction.commit()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func setActive(_ active: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if active {
            gradientLayer.colors = [DS.navActiveGreenTop.cgColor, DS.navActiveGreenBot.cgColor]
            labelField.textColor = NSColor(red: 0x1a/255.0, green: 0x3a/255.0, blue: 0x1a/255.0, alpha: 1)
        } else {
            gradientLayer.colors = [DS.navInactiveTop.cgColor, DS.navInactiveBot.cgColor]
            labelField.textColor = .white
        }
        CATransaction.commit()
    }

    override func mouseDown(with event: NSEvent) {
        onTap?(tabIndex)
    }
}

import AppKit
import QuartzCore

// MARK: - PanelWindow (DS Pokemon Party Screen Style)

final class PanelWindow: NSWindow {

    // Public API
    var isOpen: Bool = false
    var onPartyChanged: (([String]) -> Void)?

    // Layout constants
    private let panelWidth: CGFloat = 520
    private let panelMaxHeight: CGFloat = 420
    private let bottomCornerRadius: CGFloat = 12
    private let openDuration: TimeInterval = 0.3
    private let closeDuration: TimeInterval = 0.2

    // Tab bar colors
    private let tabBarBg = NSColor(red: 0x28/255, green: 0x68/255, blue: 0xA0/255, alpha: 1)
    private let tabActive = NSColor(red: 0xF8/255, green: 0xA8/255, blue: 0x00/255, alpha: 1)
    private let tabInactive = NSColor(red: 0x38/255, green: 0x78/255, blue: 0xB8/255, alpha: 1)

    // Tab system
    private var tabs: [DSTab] = []
    private var currentTabIndex: Int = 0
    private var tabButtons: [NSButton] = []
    private var tabContentArea: NSView!
    private var tabBarView: NSView?
    private var containerView: NSView?

    // Cached state
    private var lastState: PetState?

    // Event monitors
    private var localMonitor: Any?
    private var globalMonitor: Any?

    // Tab titles
    private static let tabTitles = ["Party", "Pokemon", "Stats", "Medals"]

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
        let stats = StatsTabView()
        let achievements = AchievementsTabView()

        tabs = [party, collection, stats, achievements]

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
        }
    }

    // MARK: - Tab Switching

    private func switchToTab(_ index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        currentTabIndex = index

        // Remove current tab view
        tabContentArea.subviews.forEach { $0.removeFromSuperview() }

        // Add new tab view
        let tabView = tabs[index].view
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabContentArea.addSubview(tabView)
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: tabContentArea.topAnchor),
            tabView.leadingAnchor.constraint(equalTo: tabContentArea.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: tabContentArea.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: tabContentArea.bottomAnchor),
        ])

        // Update tab bar button states
        updateTabBarAppearance()

        // Update content
        if let state = lastState {
            tabs[index].update(state: state)
        }

        // Force layout to prevent blank tab
        tabContentArea.needsLayout = true
        tabContentArea.layoutSubtreeIfNeeded()
    }

    // MARK: - Tab Bar

    private func buildTabBar() -> NSView {
        let bar = NSView()
        bar.wantsLayer = true
        // DS-style dark blue gradient bar
        let gradient = CAGradientLayer()
        gradient.colors = [
            NSColor(red: 0x30/255, green: 0x58/255, blue: 0x90/255, alpha: 1).cgColor,
            NSColor(red: 0x20/255, green: 0x40/255, blue: 0x70/255, alpha: 1).cgColor,
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        bar.layer?.insertSublayer(gradient, at: 0)
        // Top border line (pixel art style)
        let topBorder = CALayer()
        topBorder.backgroundColor = NSColor(red: 0x50/255, green: 0x78/255, blue: 0xB0/255, alpha: 1).cgColor
        bar.layer?.addSublayer(topBorder)
        bar.translatesAutoresizingMaskIntoConstraints = false

        // Store gradient and border for resizing
        bar.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: bar, queue: .main) { _ in
            gradient.frame = bar.bounds
            topBorder.frame = CGRect(x: 0, y: bar.bounds.height - 2, width: bar.bounds.width, height: 2)
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

        let titles = ["Party", "Box", "Trainer", "Medals"]
        tabButtons.removeAll()
        for (index, title) in titles.enumerated() {
            let btn = RetroTabButton(title: title, target: self, action: #selector(tabTapped(_:)))
            btn.tag = index
            btn.setContentHuggingPriority(.defaultLow, for: .vertical)
            btn.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            stack.addArrangedSubview(btn)
            // Force button to fill full height of stack
            btn.topAnchor.constraint(equalTo: stack.topAnchor).isActive = true
            btn.bottomAnchor.constraint(equalTo: stack.bottomAnchor).isActive = true
            tabButtons.append(btn)
        }

        updateTabBarAppearance()
        return bar
    }

    private func updateTabBarAppearance() {
        for btn in tabButtons {
            let isActive = btn.tag == currentTabIndex
            if let retro = btn as? RetroTabButton {
                retro.setActive(isActive)
            }
        }
    }

    @objc private func tabTapped(_ sender: NSButton) {
        switchToTab(sender.tag)
    }

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

// MARK: - Retro Tab Button (DS-style)

private class RetroTabButton: NSButton {
    private var isActiveTab = false
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    private static let activeTop = NSColor(red: 0xF8/255, green: 0xC0/255, blue: 0x30/255, alpha: 1)
    private static let activeBot = NSColor(red: 0xE0/255, green: 0x90/255, blue: 0x10/255, alpha: 1)
    private static let activeBorder = NSColor(red: 0xA0/255, green: 0x68/255, blue: 0x00/255, alpha: 1)
    private static let inactiveTop = NSColor(red: 0x40/255, green: 0x68/255, blue: 0xA8/255, alpha: 1)
    private static let inactiveBot = NSColor(red: 0x30/255, green: 0x50/255, blue: 0x88/255, alpha: 1)
    private static let inactiveBorder = NSColor(red: 0x20/255, green: 0x38/255, blue: 0x60/255, alpha: 1)

    convenience init(title: String, target: AnyObject?, action: Selector?) {
        self.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        self.isBordered = false
        self.wantsLayer = true
        self.font = NSFont.boldSystemFont(ofSize: 11)
        self.translatesAutoresizingMaskIntoConstraints = false

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
        shadow.shadowOffset = NSSize(width: 1, height: -1)
        shadow.shadowBlurRadius = 0
        self.shadow = shadow
    }

    func setActive(_ active: Bool) {
        isActiveTab = active
        needsDisplay = true
        updateAppearance()
    }

    private func updateAppearance() {
        layer?.cornerRadius = 0
        // Right-side divider line
        layer?.sublayers?.filter { $0.name == "divider" }.forEach { $0.removeFromSuperlayer() }
        let divider = CALayer()
        divider.name = "divider"
        divider.backgroundColor = NSColor(red: 0x18/255, green: 0x30/255, blue: 0x50/255, alpha: 1).cgColor
        divider.frame = CGRect(x: bounds.width - 1, y: 4, width: 1, height: bounds.height - 8)
        layer?.addSublayer(divider)

        layer?.sublayers?.filter { $0.name == "tabGrad" }.forEach { $0.removeFromSuperlayer() }
        let grad = CAGradientLayer()
        grad.name = "tabGrad"
        grad.frame = bounds
        grad.startPoint = CGPoint(x: 0.5, y: 0)
        grad.endPoint = CGPoint(x: 0.5, y: 1)

        if isActiveTab {
            contentTintColor = NSColor(red: 0x40/255, green: 0x20/255, blue: 0x00/255, alpha: 1)
            grad.colors = [Self.activeTop.cgColor, Self.activeBot.cgColor]
        } else {
            contentTintColor = .white
            let top = isHovered ? Self.inactiveTop.blended(withFraction: 0.25, of: .white)! : Self.inactiveTop
            let bot = isHovered ? Self.inactiveBot.blended(withFraction: 0.15, of: .white)! : Self.inactiveBot
            grad.colors = [top.cgColor, bot.cgColor]
        }

        layer?.insertSublayer(grad, at: 0)
    }

    override func layout() {
        super.layout()
        updateAppearance()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance()
    }
}

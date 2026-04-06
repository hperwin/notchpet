import AppKit

final class PokemonDetailView: NSView {

    var onBack: (() -> Void)?
    var onAddToParty: ((String) -> Void)?
    var onRemoveFromParty: ((String) -> Void)?

    private let entry: PokemonEntry
    private let instance: PokemonInstance?
    private let shinyUnlocked: Bool
    private let isInParty: Bool
    private let partyFull: Bool
    private var isShiny: Bool = false

    private var spriteImageView: NSImageView?
    private var normalButton: NSButton?
    private var shinyButton: NSButton?

    // Type colors
    private static let typeColors: [String: NSColor] = [
        "Normal": NSColor(red: 0xA8/255, green: 0xA8/255, blue: 0x78/255, alpha: 1),
        "Fire": NSColor(red: 0xF0/255, green: 0x80/255, blue: 0x30/255, alpha: 1),
        "Water": NSColor(red: 0x68/255, green: 0x90/255, blue: 0xF0/255, alpha: 1),
        "Grass": NSColor(red: 0x78/255, green: 0xC8/255, blue: 0x50/255, alpha: 1),
        "Electric": NSColor(red: 0xF8/255, green: 0xD0/255, blue: 0x30/255, alpha: 1),
        "Psychic": NSColor(red: 0xF8/255, green: 0x58/255, blue: 0x88/255, alpha: 1),
        "Dark": NSColor(red: 0x70/255, green: 0x58/255, blue: 0x48/255, alpha: 1),
        "Dragon": NSColor(red: 0x70/255, green: 0x38/255, blue: 0xF8/255, alpha: 1),
        "Ghost": NSColor(red: 0x70/255, green: 0x58/255, blue: 0x98/255, alpha: 1),
        "Fighting": NSColor(red: 0xC0/255, green: 0x30/255, blue: 0x28/255, alpha: 1),
        "Ice": NSColor(red: 0x98/255, green: 0xD8/255, blue: 0xD8/255, alpha: 1),
        "Fairy": NSColor(red: 0xEE/255, green: 0x99/255, blue: 0xAC/255, alpha: 1),
        "Flying": NSColor(red: 0xA8/255, green: 0x90/255, blue: 0xF0/255, alpha: 1),
        "Poison": NSColor(red: 0xA0/255, green: 0x40/255, blue: 0xA0/255, alpha: 1),
        "Ground": NSColor(red: 0xE0/255, green: 0xC0/255, blue: 0x68/255, alpha: 1),
        "Rock": NSColor(red: 0xB8/255, green: 0xA0/255, blue: 0x38/255, alpha: 1),
        "Steel": NSColor(red: 0xB8/255, green: 0xB8/255, blue: 0xD0/255, alpha: 1),
        "Bug": NSColor(red: 0xA8/255, green: 0xB8/255, blue: 0x20/255, alpha: 1),
    ]

    // MARK: - Init

    init(entry: PokemonEntry, instance: PokemonInstance?, shinyUnlocked: Bool, isInParty: Bool, partyFull: Bool) {
        self.entry = entry
        self.instance = instance
        self.shinyUnlocked = shinyUnlocked
        self.isInParty = isInParty
        self.partyFull = partyFull
        super.init(frame: .zero)
        wantsLayer = true
        buildUI()
        startIdleBounce()
    }

    private func startIdleBounce() {
        guard let sprite = spriteImageView else { return }
        sprite.wantsLayer = true

        // Small periodic hop every 3-6 seconds
        func scheduleHop() {
            let wait = Double.random(in: 3.0...6.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak sprite] in
                guard let layer = sprite?.layer else { return }
                let hop = CAKeyframeAnimation(keyPath: "transform.translation.y")
                hop.values = [0, -6, 0, -3, 0]
                hop.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
                hop.duration = 0.35
                hop.timingFunction = CAMediaTimingFunction(name: .easeOut)
                layer.add(hop, forKey: "idleHop")
                scheduleHop()
            }
        }
        scheduleHop()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public

    func setAsContent(in scrollView: NSScrollView) {
        scrollView.documentView = self
        translatesAutoresizingMaskIntoConstraints = false
        let clipView = scrollView.contentView
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalTo: clipView.widthAnchor),
        ])
    }

    // MARK: - UI Construction

    private func buildUI() {
        wantsLayer = true

        // Environment background based on Pokemon type
        let bgImageView = NSImageView()
        bgImageView.imageScaling = .scaleAxesIndependently
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        if let envImage = MoveData.environmentImage(for: entry.id) {
            bgImageView.image = envImage
        }
        addSubview(bgImageView)
        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: topAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Semi-transparent dark overlay so text is readable
        let overlay = NSView()
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.45).cgColor
        overlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: topAnchor),
            overlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Container stack
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Back button row (left-aligned)
        let backButton = makeBackButton()
        let backRow = NSStackView(views: [backButton])
        backRow.orientation = .horizontal
        backRow.alignment = .centerY
        backRow.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(backRow)
        backRow.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 16).isActive = true

        // Sprite
        let spriteContainer = NSView()
        spriteContainer.translatesAutoresizingMaskIntoConstraints = false
        spriteContainer.wantsLayer = true
        NSLayoutConstraint.activate([
            spriteContainer.widthAnchor.constraint(equalToConstant: 120),
            spriteContainer.heightAnchor.constraint(equalToConstant: 120),
        ])

        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = PetCollection.spriteImage(for: entry.id, shiny: false)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        spriteContainer.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: spriteContainer.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: spriteContainer.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: spriteContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: spriteContainer.trailingAnchor),
        ])
        self.spriteImageView = imageView

        stack.addArrangedSubview(spriteContainer)

        // Name
        let nameLabel = makeLabel(size: 18, bold: true, color: .white)
        nameLabel.stringValue = entry.displayName
        nameLabel.alignment = .center
        stack.addArrangedSubview(nameLabel)

        // Level + XP bar
        let displayLevel = instance?.level ?? 1
        let displayProgress = instance?.levelProgress ?? 0
        let displayXP = instance?.xp ?? 0
        let displayXPNeeded = instance?.xpToNextLevel ?? PokemonInstance(pokemonId: entry.id).xpToNextLevel

        let levelLabel = makeLabel(size: 14, bold: true, color: .white)
        levelLabel.stringValue = "Level \(displayLevel)"
        levelLabel.alignment = .center
        stack.addArrangedSubview(levelLabel)

        // XP progress bar row
        let xpRow = NSStackView()
        xpRow.orientation = .horizontal
        xpRow.spacing = 8
        xpRow.alignment = .centerY
        xpRow.translatesAutoresizingMaskIntoConstraints = false

        let progressBar = ProgressBarView(progress: displayProgress)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressBar.heightAnchor.constraint(equalToConstant: 8),
        ])

        let xpLabel = makeLabel(size: 11, bold: false, color: .gray)
        xpLabel.stringValue = "\(displayXP) / \(displayXPNeeded) XP"
        xpLabel.setContentHuggingPriority(.required, for: .horizontal)
        xpLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        xpRow.addArrangedSubview(progressBar)
        xpRow.addArrangedSubview(xpLabel)
        stack.addArrangedSubview(xpRow)
        xpRow.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 16).isActive = true
        xpRow.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -16).isActive = true

        // Moves section
        let movesCard = buildMovesCard()
        stack.addArrangedSubview(movesCard)
        movesCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 16).isActive = true
        movesCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -16).isActive = true

        // Stats: Berries Fed
        let foodCount = instance?.foodEaten ?? 0
        let statsLabel = makeLabel(size: 12, bold: false, color: .gray)
        statsLabel.stringValue = "Berries Fed: \(foodCount)"
        statsLabel.alignment = .center
        stack.addArrangedSubview(statsLabel)

        // Shiny section (only if shiny is unlocked)
        if shinyUnlocked && entry.hasShiny {
            let shinyCard = buildShinyCard()
            stack.addArrangedSubview(shinyCard)
            shinyCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 16).isActive = true
            shinyCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -16).isActive = true
        }

        // Party button
        if isInParty {
            let removeButton = makeActionButton(title: "Remove from Party")
            removeButton.target = self
            removeButton.action = #selector(removeFromPartyTapped)
            stack.addArrangedSubview(removeButton)
            removeButton.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 16).isActive = true
            removeButton.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -16).isActive = true
        } else if !partyFull {
            let addButton = makeActionButton(title: "Add to Party")
            addButton.target = self
            addButton.action = #selector(addToPartyTapped)
            stack.addArrangedSubview(addButton)
            addButton.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 16).isActive = true
            addButton.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -16).isActive = true
        }
    }

    // MARK: - Moves Card

    private func buildMovesCard() -> NSView {
        let card = makeCard()

        let cardStack = NSStackView()
        cardStack.orientation = .vertical
        cardStack.alignment = .leading
        cardStack.spacing = 6
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])

        let titleLabel = makeLabel(size: 13, bold: true, color: .white)
        titleLabel.stringValue = "Moves"
        cardStack.addArrangedSubview(titleLabel)

        let moves = instance?.moves ?? []
        if moves.isEmpty {
            let emptyLabel = makeLabel(size: 12, bold: false, color: .gray)
            emptyLabel.stringValue = "No moves learned yet"
            cardStack.addArrangedSubview(emptyLabel)
        } else {
            for moveName in moves {
                let moveRow = buildMoveRow(moveName: moveName)
                cardStack.addArrangedSubview(moveRow)
            }
        }

        return card
    }

    private func buildMoveRow(moveName: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        let move = MoveData.allMoves[moveName]
        let typeName = move?.type ?? "Normal"
        let typeColor = PokemonDetailView.typeColors[typeName] ?? PokemonDetailView.typeColors["Normal"]!

        // Type badge
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.backgroundColor = typeColor.cgColor
        badge.layer?.cornerRadius = 4
        badge.translatesAutoresizingMaskIntoConstraints = false

        let badgeLabel = NSTextField(labelWithString: typeName)
        badgeLabel.font = NSFont.boldSystemFont(ofSize: 9)
        badgeLabel.textColor = .white
        badgeLabel.drawsBackground = false
        badgeLabel.isBordered = false
        badgeLabel.isEditable = false
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            badgeLabel.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 6),
            badgeLabel.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -6),
            badgeLabel.topAnchor.constraint(equalTo: badge.topAnchor, constant: 2),
            badgeLabel.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -2),
        ])

        // Move name
        let nameLabel = makeLabel(size: 12, bold: false, color: .white)
        nameLabel.stringValue = moveName

        row.addArrangedSubview(badge)
        row.addArrangedSubview(nameLabel)

        return row
    }

    // MARK: - Shiny Card

    private func buildShinyCard() -> NSView {
        let card = makeCard()

        let cardStack = NSStackView()
        cardStack.orientation = .vertical
        cardStack.alignment = .leading
        cardStack.spacing = 8
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])

        let titleLabel = makeLabel(size: 13, bold: true, color: .white)
        titleLabel.stringValue = "\u{2728} Shiny Available"
        cardStack.addArrangedSubview(titleLabel)

        // Toggle buttons
        let toggleRow = NSStackView()
        toggleRow.orientation = .horizontal
        toggleRow.spacing = 8
        toggleRow.translatesAutoresizingMaskIntoConstraints = false

        let normalBtn = makeToggleButton(title: "Normal", selected: true)
        normalBtn.target = self
        normalBtn.action = #selector(normalTapped)
        self.normalButton = normalBtn

        let shinyBtn = makeToggleButton(title: "Shiny", selected: false)
        shinyBtn.target = self
        shinyBtn.action = #selector(shinyTapped)
        self.shinyButton = shinyBtn

        toggleRow.addArrangedSubview(normalBtn)
        toggleRow.addArrangedSubview(shinyBtn)
        cardStack.addArrangedSubview(toggleRow)

        return card
    }

    // MARK: - Helpers

    private func makeCard() -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1).cgColor // #1a1a1a
        card.layer?.cornerRadius = 10
        card.layer?.borderColor = NSColor(red: 0.165, green: 0.165, blue: 0.165, alpha: 1).cgColor // #2a2a2a
        card.layer?.borderWidth = 1
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }

    private func makeLabel(size: CGFloat, bold: Bool, color: NSColor) -> NSTextField {
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

    private func makeBackButton() -> NSButton {
        let button = NSButton(title: "\u{2190} Back", target: self, action: #selector(backTapped))
        button.isBordered = false
        button.contentTintColor = .white
        button.font = NSFont.systemFont(ofSize: 13)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    private func makeToggleButton(title: String, selected: Bool) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.isBordered = false
        button.wantsLayer = true
        button.font = NSFont.systemFont(ofSize: 12)
        button.contentTintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        applyToggleStyle(to: button, selected: selected)
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 28),
            button.widthAnchor.constraint(equalToConstant: 72),
        ])
        return button
    }

    private func applyToggleStyle(to button: NSButton, selected: Bool) {
        let blueColor = NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1) // #4A9EFF
        button.layer?.cornerRadius = 6
        if selected {
            button.layer?.borderColor = blueColor.cgColor
            button.layer?.borderWidth = 2
            button.layer?.backgroundColor = blueColor.withAlphaComponent(0.15).cgColor
        } else {
            button.layer?.borderColor = NSColor(white: 0.25, alpha: 1).cgColor
            button.layer?.borderWidth = 1
            button.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    private func makeActionButton(title: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.isBordered = false
        button.wantsLayer = true
        button.font = NSFont.boldSystemFont(ofSize: 14)
        button.contentTintColor = .white
        let blueColor = NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1) // #4A9EFF
        button.layer?.backgroundColor = blueColor.cgColor
        button.layer?.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 36),
        ])
        return button
    }

    // MARK: - Actions

    @objc private func backTapped() {
        onBack?()
    }

    @objc private func addToPartyTapped() {
        onAddToParty?(entry.id)
    }

    @objc private func removeFromPartyTapped() {
        onRemoveFromParty?(entry.id)
    }

    @objc private func normalTapped() {
        isShiny = false
        spriteImageView?.image = PetCollection.spriteImage(for: entry.id, shiny: false)
        applyToggleStyle(to: normalButton!, selected: true)
        applyToggleStyle(to: shinyButton!, selected: false)
    }

    @objc private func shinyTapped() {
        isShiny = true
        spriteImageView?.image = PetCollection.spriteImage(for: entry.id, shiny: true)
        applyToggleStyle(to: normalButton!, selected: false)
        applyToggleStyle(to: shinyButton!, selected: true)
    }
}

// MARK: - Progress Bar

private final class ProgressBarView: NSView {
    private let progress: Double

    init(progress: Double) {
        self.progress = max(0, min(progress, 1.0))
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let trackColor = NSColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1) // #222
        let fillColor = NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1) // #4A9EFF

        let trackPath = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
        trackColor.setFill()
        trackPath.fill()

        if progress > 0 {
            var fillRect = bounds
            fillRect.size.width = bounds.width * CGFloat(progress)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 4, yRadius: 4)
            fillColor.setFill()
            fillPath.fill()
        }
    }
}

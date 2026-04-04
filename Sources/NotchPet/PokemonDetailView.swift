import AppKit

final class PokemonDetailView: NSView {

    var onBack: (() -> Void)?
    var onSelectPet: ((String, Bool) -> Void)?

    private let entry: PokemonEntry
    private let unlocked: Bool
    private let shinyUnlocked: Bool
    private let currentLevel: Int
    private var isShiny: Bool = false

    private var spriteImageView: NSImageView?
    private var normalButton: NSButton?
    private var shinyButton: NSButton?

    // MARK: - Init

    init(entry: PokemonEntry, unlocked: Bool, shinyUnlocked: Bool, currentLevel: Int) {
        self.entry = entry
        self.unlocked = unlocked
        self.shinyUnlocked = shinyUnlocked
        self.currentLevel = currentLevel
        super.init(frame: .zero)
        wantsLayer = true
        buildUI()
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
        if !unlocked {
            imageView.alphaValue = 0.2
        }
        spriteContainer.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: spriteContainer.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: spriteContainer.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: spriteContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: spriteContainer.trailingAnchor),
        ])
        self.spriteImageView = imageView

        if !unlocked {
            let lockOverlay = makeLabel(size: 32, bold: false, color: .white)
            lockOverlay.stringValue = "\u{1F512}"
            lockOverlay.alignment = .center
            spriteContainer.addSubview(lockOverlay)
            NSLayoutConstraint.activate([
                lockOverlay.centerXAnchor.constraint(equalTo: spriteContainer.centerXAnchor),
                lockOverlay.centerYAnchor.constraint(equalTo: spriteContainer.centerYAnchor),
            ])
        }

        stack.addArrangedSubview(spriteContainer)

        // Name
        let nameLabel = makeLabel(size: 18, bold: true, color: .white)
        nameLabel.stringValue = entry.displayName
        nameLabel.alignment = .center
        stack.addArrangedSubview(nameLabel)

        if unlocked {
            // Unlock level subtitle
            let levelLabel = makeLabel(size: 12, bold: false, color: .gray)
            levelLabel.stringValue = "Level \(entry.unlockLevel) unlock"
            levelLabel.alignment = .center
            stack.addArrangedSubview(levelLabel)

            // Shiny section (only if shiny is unlocked)
            if shinyUnlocked && entry.hasShiny {
                let shinyCard = buildShinyCard()
                stack.addArrangedSubview(shinyCard)
                shinyCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 16).isActive = true
                shinyCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -16).isActive = true
            }

            // Set as Active Pet button
            let selectButton = makeActionButton(title: "Set as Active Pet")
            selectButton.target = self
            selectButton.action = #selector(selectPetTapped)
            stack.addArrangedSubview(selectButton)
            selectButton.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 16).isActive = true
            selectButton.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -16).isActive = true

        } else {
            // Locked card
            let lockedCard = buildLockedCard()
            stack.addArrangedSubview(lockedCard)
            lockedCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 16).isActive = true
            lockedCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -16).isActive = true
        }
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

    // MARK: - Locked Card

    private func buildLockedCard() -> NSView {
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

        let lockTitle = makeLabel(size: 13, bold: true, color: .white)
        lockTitle.stringValue = "\u{1F512} Locked"
        cardStack.addArrangedSubview(lockTitle)

        let unlockMsg = makeLabel(size: 12, bold: false, color: .gray)
        unlockMsg.stringValue = "Reach Level \(entry.unlockLevel) to unlock"
        cardStack.addArrangedSubview(unlockMsg)

        // Current level
        let currentLabel = makeLabel(size: 12, bold: false, color: .gray)
        currentLabel.stringValue = "Current Level: \(currentLevel)"
        cardStack.addArrangedSubview(currentLabel)

        // Progress bar
        let progressPercent = entry.unlockLevel > 0
            ? min(Double(currentLevel) / Double(entry.unlockLevel), 1.0)
            : 1.0
        let percentInt = Int(progressPercent * 100)

        let progressRow = NSStackView()
        progressRow.orientation = .horizontal
        progressRow.spacing = 8
        progressRow.alignment = .centerY
        progressRow.translatesAutoresizingMaskIntoConstraints = false

        let progressBar = ProgressBarView(progress: progressPercent)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressBar.heightAnchor.constraint(equalToConstant: 8),
        ])

        let percentLabel = makeLabel(size: 11, bold: false, color: .gray)
        percentLabel.stringValue = "\(percentInt)%"
        percentLabel.setContentHuggingPriority(.required, for: .horizontal)
        percentLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        progressRow.addArrangedSubview(progressBar)
        progressRow.addArrangedSubview(percentLabel)
        cardStack.addArrangedSubview(progressRow)
        progressRow.leadingAnchor.constraint(equalTo: cardStack.leadingAnchor).isActive = true
        progressRow.trailingAnchor.constraint(equalTo: cardStack.trailingAnchor).isActive = true

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

    @objc private func selectPetTapped() {
        onSelectPet?(entry.id, isShiny)
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

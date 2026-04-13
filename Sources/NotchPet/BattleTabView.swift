import AppKit
import QuartzCore

final class BattleTabView: DSTabView {

    // MARK: - UI State Machine

    private enum BattleUIState {
        case preBattle
        case waitingForMove
        case animating
        case battleOver(winner: BattleState.BattleWinner)
    }

    // Battle system references
    private var engine: BattleEngine?
    private var currentState: PetState?
    private var uiState: BattleUIState = .preBattle

    // Animation
    private var logMessage: String = ""
    private var pendingEvents: [MoveResult] = []
    private var flashOpponentSprite: Bool = false
    private var flashPlayerSprite: Bool = false
    private var effectivenessFlash: MoveResult.Effectiveness?

    // XP
    private var xpAwarded: Int = 0

    // MARK: - Layout Constants

    private static let panelW: CGFloat = 580

    // Background gradient
    private static let bgTop = NSColor(red: 0x1E/255.0, green: 0x3A/255.0, blue: 0x2E/255.0, alpha: 1)
    private static let bgBot = NSColor(red: 0x0E/255.0, green: 0x1E/255.0, blue: 0x14/255.0, alpha: 1)

    // HP colors
    private static let hpGreen = NSColor(red: 0x48/255.0, green: 0xD0/255.0, blue: 0x48/255.0, alpha: 1)
    private static let hpYellow = NSColor(red: 0xF8/255.0, green: 0xC8/255.0, blue: 0x20/255.0, alpha: 1)
    private static let hpRed = NSColor(red: 0xF0/255.0, green: 0x40/255.0, blue: 0x40/255.0, alpha: 1)

    // Arena colors
    private static let arenaFloor = NSColor(red: 0x3A/255.0, green: 0x6A/255.0, blue: 0x3A/255.0, alpha: 1)
    private static let platformPlayer = NSColor(red: 0x5A/255.0, green: 0x8A/255.0, blue: 0x5A/255.0, alpha: 1)
    private static let platformOpponent = NSColor(red: 0x4A/255.0, green: 0x7A/255.0, blue: 0x4A/255.0, alpha: 1)
    private static let platformShadow = NSColor(red: 0x2A/255.0, green: 0x4A/255.0, blue: 0x2A/255.0, alpha: 1)

    // Log bar
    private static let logBarBg = NSColor(red: 0x00/255.0, green: 0x00/255.0, blue: 0x00/255.0, alpha: 0.65)

    // Move button
    private static let moveBtnBg = NSColor(red: 0x28/255.0, green: 0x28/255.0, blue: 0x30/255.0, alpha: 1)
    private static let moveBtnBorder = NSColor(red: 0x48/255.0, green: 0x48/255.0, blue: 0x58/255.0, alpha: 1)

    // MARK: - Type Colors (Game-Accurate)

    private static let typeColors: [String: NSColor] = [
        "Normal":   NSColor(red: 0xA8/255.0, green: 0xA8/255.0, blue: 0x78/255.0, alpha: 1),
        "Fire":     NSColor(red: 0xF0/255.0, green: 0x80/255.0, blue: 0x30/255.0, alpha: 1),
        "Water":    NSColor(red: 0x68/255.0, green: 0x90/255.0, blue: 0xF0/255.0, alpha: 1),
        "Grass":    NSColor(red: 0x78/255.0, green: 0xC8/255.0, blue: 0x50/255.0, alpha: 1),
        "Electric": NSColor(red: 0xF8/255.0, green: 0xD0/255.0, blue: 0x30/255.0, alpha: 1),
        "Psychic":  NSColor(red: 0xF8/255.0, green: 0x58/255.0, blue: 0x88/255.0, alpha: 1),
        "Fighting": NSColor(red: 0xC0/255.0, green: 0x30/255.0, blue: 0x28/255.0, alpha: 1),
        "Dragon":   NSColor(red: 0x70/255.0, green: 0x38/255.0, blue: 0xF8/255.0, alpha: 1),
        "Dark":     NSColor(red: 0x70/255.0, green: 0x58/255.0, blue: 0x48/255.0, alpha: 1),
        "Ghost":    NSColor(red: 0x70/255.0, green: 0x58/255.0, blue: 0x98/255.0, alpha: 1),
        "Fairy":    NSColor(red: 0xEE/255.0, green: 0x99/255.0, blue: 0xAC/255.0, alpha: 1),
        "Ice":      NSColor(red: 0x98/255.0, green: 0xD8/255.0, blue: 0xD8/255.0, alpha: 1),
        "Flying":   NSColor(red: 0xA8/255.0, green: 0x90/255.0, blue: 0xF0/255.0, alpha: 1),
        "Poison":   NSColor(red: 0xA0/255.0, green: 0x40/255.0, blue: 0xA0/255.0, alpha: 1),
        "Ground":   NSColor(red: 0xE0/255.0, green: 0xC0/255.0, blue: 0x68/255.0, alpha: 1),
        "Rock":     NSColor(red: 0xB8/255.0, green: 0xA0/255.0, blue: 0x38/255.0, alpha: 1),
        "Steel":    NSColor(red: 0xB8/255.0, green: 0xB8/255.0, blue: 0xD0/255.0, alpha: 1),
        "Bug":      NSColor(red: 0xA8/255.0, green: 0xB8/255.0, blue: 0x20/255.0, alpha: 1),
    ]

    // Status condition colors
    private static let statusColors: [String: NSColor] = [
        "BRN": NSColor(red: 0xF0/255.0, green: 0x80/255.0, blue: 0x30/255.0, alpha: 1),
        "PAR": NSColor(red: 0xF8/255.0, green: 0xD0/255.0, blue: 0x30/255.0, alpha: 1),
        "PSN": NSColor(red: 0xA0/255.0, green: 0x40/255.0, blue: 0xA0/255.0, alpha: 1),
        "SLP": NSColor(red: 0x88/255.0, green: 0x88/255.0, blue: 0x88/255.0, alpha: 1),
        "FRZ": NSColor(red: 0x98/255.0, green: 0xD8/255.0, blue: 0xD8/255.0, alpha: 1),
    ]

    // MARK: - Init

    init() {
        super.init(backgroundColor: BattleTabView.bgTop)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        if let grad = layer?.sublayers?.first(where: { $0.name == "battleGrad" }) as? CAGradientLayer {
            grad.frame = bounds
        }
    }

    // MARK: - DSTab

    override func update(state: PetState) {
        currentState = state
        rebuildUI()
    }

    // MARK: - Public API

    func startBattle(engine: BattleEngine) {
        self.engine = engine
        self.xpAwarded = 0
        self.logMessage = "A wild battle began!"
        self.pendingEvents = []

        engine.onMoveExecuted = { [weak self] result in
            guard let self = self else { return }
            self.pendingEvents.append(result)
        }
        engine.onBattleOver = { [weak self] winner in
            guard let self = self else { return }
            self.uiState = .battleOver(winner: winner)
            // The animation sequence will handle the final rebuild
        }
        engine.onSwitchNeeded = { [weak self] in
            // After animation completes, the rebuild will show the new Pokemon
            _ = self
        }

        self.uiState = .waitingForMove
        rebuildUI()
    }

    func executePlayerMove(index: Int) {
        guard let engine = engine, !engine.state.isOver else { return }
        guard case .waitingForMove = uiState else { return }

        // Gather AI move
        let aiMove = BattleAI.pickMove(attacker: engine.state.opponentPokemon, defender: engine.state.playerPokemon)

        // Clear pending events before executing
        pendingEvents = []
        uiState = .animating
        rebuildUI()

        // Execute the turn (this will populate pendingEvents via callbacks)
        engine.executeTurn(playerMoveIndex: index, opponentMoveIndex: aiMove)

        // Animate events sequentially
        animateTurnEvents(pendingEvents) { [weak self] in
            guard let self = self else { return }
            if engine.state.isOver {
                if let winner = engine.state.winner {
                    self.uiState = .battleOver(winner: winner)
                }
            } else {
                self.uiState = .waitingForMove
            }
            self.rebuildUI()
        }
    }

    func endBattle() {
        engine = nil
        uiState = .preBattle
        logMessage = ""
        rebuildUI()
    }

    func setXPAwarded(_ xp: Int) {
        xpAwarded = xp
        if case .battleOver = uiState {
            rebuildUI()
        }
    }

    // MARK: - Animation

    private func animateTurnEvents(_ events: [MoveResult], completion: @escaping () -> Void) {
        guard !events.isEmpty else {
            completion()
            return
        }

        var delay: TimeInterval = 0
        for event in events {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.showEvent(event)
            }
            delay += 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            completion()
        }
    }

    private func showEvent(_ event: MoveResult) {
        // Build the log line
        var msg = "\(event.attackerName) used \(event.moveName)!"
        logMessage = msg

        // Determine which sprite to flash
        if let engine = engine {
            let defenderIsOpponent = event.defenderName == engine.state.opponentPokemon.displayName
                || engine.state.opponentTeam.contains(where: { $0.displayName == event.defenderName })
            if defenderIsOpponent {
                flashOpponentSprite = true
                flashPlayerSprite = false
            } else {
                flashPlayerSprite = true
                flashOpponentSprite = false
            }
        }

        rebuildUI()

        // Show effectiveness after a brief moment
        if event.effectiveness != .normal || event.isCrit {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                if event.isCrit {
                    msg += " Critical hit!"
                }
                if !event.effectiveness.rawValue.isEmpty {
                    msg += " \(event.effectiveness.rawValue)"
                }
                if event.defenderFainted {
                    msg += " \(event.defenderName) fainted!"
                }
                self.logMessage = msg
                self.flashOpponentSprite = false
                self.flashPlayerSprite = false
                self.rebuildUI()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self = self else { return }
                if event.defenderFainted {
                    self.logMessage = "\(event.defenderName) fainted!"
                }
                self.flashOpponentSprite = false
                self.flashPlayerSprite = false
                self.rebuildUI()
            }
        }
    }

    // MARK: - Rebuild UI

    private func rebuildUI() {
        subviews.forEach { $0.removeFromSuperview() }
        layer?.sublayers?.removeAll(where: { $0.name == "battleGrad" || $0.name == "arenaFloor" })
        clearHitRegions()

        // Background gradient
        let grad = CAGradientLayer()
        grad.name = "battleGrad"
        grad.frame = bounds
        grad.colors = [BattleTabView.bgTop.cgColor, BattleTabView.bgBot.cgColor]
        grad.startPoint = CGPoint(x: 0.5, y: 0)
        grad.endPoint = CGPoint(x: 0.5, y: 1)
        layer?.insertSublayer(grad, at: 0)

        switch uiState {
        case .preBattle:
            buildPreBattle()
        case .waitingForMove:
            buildArena(movesEnabled: true)
        case .animating:
            buildArena(movesEnabled: false)
        case .battleOver(let winner):
            buildBattleOver(winner: winner)
        }
    }

    // MARK: - Pre-Battle Screen

    private func buildPreBattle() {
        let w = bounds.width
        let h = bounds.height
        let centerX = w / 2

        // "VS" label - large centered
        let vsLabel = DS.label("VS", size: 36, bold: true, color: NSColor.white.withAlphaComponent(0.9))
        vsLabel.frame = NSRect(x: 0, y: h * 0.2, width: w, height: 44)
        vsLabel.alignment = .center
        addSubview(vsLabel)

        // Player's lead sprite on the left
        if let state = currentState, let leadId = state.party.first {
            let playerSprite = DSTabView.dsSprite(for: leadId, size: 64)
            playerSprite.translatesAutoresizingMaskIntoConstraints = true
            playerSprite.frame = NSRect(x: centerX - 100 - 64, y: h * 0.2 - 8, width: 64, height: 64)
            addSubview(playerSprite)

            let playerName = DS.label(PetCollection.entry(for: leadId)?.displayName ?? leadId.capitalized, size: 10, bold: true)
            playerName.frame = NSRect(x: centerX - 100 - 64, y: h * 0.2 + 56, width: 64, height: 14)
            playerName.alignment = .center
            addSubview(playerName)
        }

        // "?" opponent on the right
        let qLabel = DS.label("?", size: 48, bold: true, color: DS.textSecondary)
        qLabel.frame = NSRect(x: centerX + 100, y: h * 0.2 - 4, width: 64, height: 60)
        qLabel.alignment = .center
        addSubview(qLabel)

        // "Challenge a wild trainer?" text
        let challengeLabel = DS.label("Challenge a wild trainer?", size: 12, bold: false, color: DS.textSecondary)
        challengeLabel.frame = NSRect(x: 0, y: h * 0.55, width: w, height: 18)
        challengeLabel.alignment = .center
        addSubview(challengeLabel)

        // "BATTLE!" button
        let btnW: CGFloat = 180
        let btnH: CGFloat = 48
        let btnX = (w - btnW) / 2
        let btnY = h * 0.55 + 30
        let btn = makeBattleButton(label: "BATTLE!", frame: NSRect(x: btnX, y: btnY, width: btnW, height: btnH))
        addSubview(btn)
        addHitRegion(HitRegion(
            id: "startBattle",
            rect: NSRect(x: btnX, y: btnY, width: btnW, height: btnH),
            action: .startBattle
        ))

        // Party sprites row
        if let state = currentState {
            let spriteSize: CGFloat = 32
            let spacing: CGFloat = 6
            let partyCount = CGFloat(state.party.count)
            let totalW = partyCount * spriteSize + (partyCount - 1) * spacing
            var sx = (w - totalW) / 2
            let sy = btnY + btnH + 16

            let teamLabel = DS.label("Your team", size: 9, bold: false, color: DS.textSecondary)
            teamLabel.frame = NSRect(x: 0, y: sy - 14, width: w, height: 12)
            teamLabel.alignment = .center
            addSubview(teamLabel)

            for pokemonId in state.party {
                let sprite = DSTabView.dsSprite(for: pokemonId, size: spriteSize)
                sprite.translatesAutoresizingMaskIntoConstraints = true
                sprite.frame = NSRect(x: sx, y: sy, width: spriteSize, height: spriteSize)
                addSubview(sprite)
                sx += spriteSize + spacing
            }
        }
    }

    // MARK: - Arena (In-Battle)

    private func buildArena(movesEnabled: Bool) {
        guard let engine = engine else { return }
        let st = engine.state
        let w = bounds.width
        let pad: CGFloat = 14

        // --- Zone 1: Battle Log (top bar, ~30px) ---
        let logBarH: CGFloat = 28
        let logBar = NSView(frame: NSRect(x: 0, y: 0, width: w, height: logBarH))
        logBar.wantsLayer = true
        logBar.layer?.backgroundColor = BattleTabView.logBarBg.cgColor
        addSubview(logBar)

        let logLabel = DS.label(logMessage, size: 10, bold: false, color: .white)
        logLabel.frame = NSRect(x: pad, y: 0, width: w - pad * 2, height: logBarH)
        logLabel.alignment = .center
        logLabel.lineBreakMode = .byTruncatingTail
        logBar.addSubview(logLabel)

        // --- Zone 2: Arena Area (~250px) ---
        let arenaTop: CGFloat = logBarH
        let arenaH: CGFloat = 250
        let arenaBot = arenaTop + arenaH

        // Draw arena floor platforms using CAShapeLayers
        drawArenaFloor(y: arenaTop, height: arenaH, width: w)

        // -- Opponent side (top-right) --
        let oppSpriteSize: CGFloat = 48
        let oppPlatformCenterX: CGFloat = w * 0.68
        let oppPlatformCenterY: CGFloat = arenaTop + arenaH * 0.25

        // Opponent info panel (name + HP) positioned above-left of sprite
        let oppInfoX: CGFloat = oppPlatformCenterX - 140
        let oppInfoY: CGFloat = oppPlatformCenterY - 50
        let oppInfoW: CGFloat = 150

        // Opponent name + level
        let oppNameLabel = DS.label("\(st.opponentPokemon.displayName) Lv.\(st.opponentPokemon.level)", size: 11, bold: true)
        oppNameLabel.frame = NSRect(x: oppInfoX, y: oppInfoY, width: oppInfoW, height: 16)
        addSubview(oppNameLabel)

        // Opponent HP bar
        let oppHPFraction = Double(st.opponentPokemon.currentHP) / Double(max(st.opponentPokemon.maxHP, 1))
        let hpBarW: CGFloat = 120
        let hpBarH: CGFloat = 6
        addHPBar(to: self, x: oppInfoX, y: oppInfoY + 18, width: hpBarW, height: hpBarH, fraction: oppHPFraction)

        let oppHPText = DS.label("HP: \(st.opponentPokemon.currentHP)/\(st.opponentPokemon.maxHP)",
                                 size: 9, bold: false, color: DS.textSecondary)
        oppHPText.frame = NSRect(x: oppInfoX + hpBarW + 4, y: oppInfoY + 16, width: 70, height: 12)
        addSubview(oppHPText)

        // Opponent team ball indicators
        let oppAlive = st.opponentTeam.filter(\.isAlive).count
        let oppTotal = st.opponentTeam.count
        drawPokeBallIndicators(x: oppInfoX, y: oppInfoY + 32, alive: oppAlive, total: oppTotal)

        // Opponent sprite
        let oppSprite = DSTabView.dsSprite(for: st.opponentPokemon.pokemonId, size: oppSpriteSize)
        oppSprite.translatesAutoresizingMaskIntoConstraints = true
        oppSprite.frame = NSRect(
            x: oppPlatformCenterX - oppSpriteSize / 2,
            y: oppPlatformCenterY - oppSpriteSize + 8,
            width: oppSpriteSize, height: oppSpriteSize
        )
        if flashOpponentSprite {
            oppSprite.alphaValue = 0.3
        }
        addSubview(oppSprite)

        // -- Player side (bottom-left) --
        let playerSpriteSize: CGFloat = 64
        let playerPlatformCenterX: CGFloat = w * 0.28
        let playerPlatformCenterY: CGFloat = arenaTop + arenaH * 0.72

        // Player info panel (positioned to the right of sprite)
        let playerInfoX: CGFloat = playerPlatformCenterX + 40
        let playerInfoY: CGFloat = playerPlatformCenterY - 10
        let playerInfoW: CGFloat = 150

        // Player name + level
        let playerNameLabel = DS.label("\(st.playerPokemon.displayName) Lv.\(st.playerPokemon.level)", size: 11, bold: true)
        playerNameLabel.frame = NSRect(x: playerInfoX, y: playerInfoY, width: playerInfoW, height: 16)
        addSubview(playerNameLabel)

        // Player HP bar
        let playerHPFraction = Double(st.playerPokemon.currentHP) / Double(max(st.playerPokemon.maxHP, 1))
        addHPBar(to: self, x: playerInfoX, y: playerInfoY + 18, width: hpBarW, height: hpBarH, fraction: playerHPFraction)

        let playerHPText = DS.label("HP: \(st.playerPokemon.currentHP)/\(st.playerPokemon.maxHP)",
                                    size: 9, bold: false, color: DS.textSecondary)
        playerHPText.frame = NSRect(x: playerInfoX + hpBarW + 4, y: playerInfoY + 16, width: 70, height: 12)
        addSubview(playerHPText)

        // Player team ball indicators
        let playerAlive = st.playerTeam.filter(\.isAlive).count
        let playerTotal = st.playerTeam.count
        drawPokeBallIndicators(x: playerInfoX, y: playerInfoY + 32, alive: playerAlive, total: playerTotal)

        // Player sprite
        let playerSprite = DSTabView.dsSprite(for: st.playerPokemon.pokemonId, size: playerSpriteSize)
        playerSprite.translatesAutoresizingMaskIntoConstraints = true
        playerSprite.frame = NSRect(
            x: playerPlatformCenterX - playerSpriteSize / 2,
            y: playerPlatformCenterY - playerSpriteSize + 12,
            width: playerSpriteSize, height: playerSpriteSize
        )
        if flashPlayerSprite {
            playerSprite.alphaValue = 0.3
        }
        addSubview(playerSprite)

        // --- Zone 3: Move Selection (bottom, ~120px) ---
        if movesEnabled {
            buildMoveGrid(st: st, y: arenaBot + 4, width: w, pad: pad)
        } else {
            // Show "..." waiting indicator while animating
            let waitLabel = DS.label("...", size: 14, bold: true, color: DS.textSecondary)
            waitLabel.frame = NSRect(x: 0, y: arenaBot + 40, width: w, height: 20)
            waitLabel.alignment = .center
            addSubview(waitLabel)
        }
    }

    // MARK: - Arena Floor Drawing

    private func drawArenaFloor(y: CGFloat, height: CGFloat, width: CGFloat) {
        // Opponent platform (smaller, higher) - ellipse
        let oppEllipse = CAShapeLayer()
        oppEllipse.name = "arenaFloor"
        let oppCenterX = width * 0.68
        let oppCenterY = y + height * 0.32
        let oppRadiusX: CGFloat = 55
        let oppRadiusY: CGFloat = 16
        let oppPath = CGMutablePath()
        oppPath.addEllipse(in: CGRect(
            x: oppCenterX - oppRadiusX,
            y: oppCenterY - oppRadiusY,
            width: oppRadiusX * 2,
            height: oppRadiusY * 2
        ))
        oppEllipse.path = oppPath
        oppEllipse.fillColor = BattleTabView.platformOpponent.cgColor
        oppEllipse.strokeColor = BattleTabView.platformShadow.cgColor
        oppEllipse.lineWidth = 1.5
        layer?.addSublayer(oppEllipse)

        // Player platform (larger, lower) - ellipse
        let playerEllipse = CAShapeLayer()
        playerEllipse.name = "arenaFloor"
        let playerCenterX = width * 0.28
        let playerCenterY = y + height * 0.78
        let playerRadiusX: CGFloat = 70
        let playerRadiusY: CGFloat = 20
        let playerPath = CGMutablePath()
        playerPath.addEllipse(in: CGRect(
            x: playerCenterX - playerRadiusX,
            y: playerCenterY - playerRadiusY,
            width: playerRadiusX * 2,
            height: playerRadiusY * 2
        ))
        playerEllipse.path = playerPath
        playerEllipse.fillColor = BattleTabView.platformPlayer.cgColor
        playerEllipse.strokeColor = BattleTabView.platformShadow.cgColor
        playerEllipse.lineWidth = 1.5
        layer?.addSublayer(playerEllipse)
    }

    // MARK: - Poke Ball Indicators

    private func drawPokeBallIndicators(x: CGFloat, y: CGFloat, alive: Int, total: Int) {
        let dotSize: CGFloat = 8
        let spacing: CGFloat = 4
        for i in 0..<total {
            let dot = NSView(frame: NSRect(x: x + CGFloat(i) * (dotSize + spacing), y: y, width: dotSize, height: dotSize))
            dot.wantsLayer = true
            dot.layer?.cornerRadius = dotSize / 2
            if i < alive {
                dot.layer?.backgroundColor = BattleTabView.hpGreen.cgColor
            } else {
                dot.layer?.backgroundColor = NSColor(white: 0.3, alpha: 1).cgColor
            }
            addSubview(dot)
        }
    }

    // MARK: - Move Grid

    private func buildMoveGrid(st: BattleState, y: CGFloat, width: CGFloat, pad: CGFloat) {
        let moveBtnW = (width - pad * 2 - 8) / 2
        let moveBtnH: CGFloat = 50
        let moveGap: CGFloat = 6
        let moves = st.playerPokemon.moves

        // "What will \(name) do?" header
        let headerLabel = DS.label("What will \(st.playerPokemon.displayName) do?", size: 9, bold: false, color: DS.textSecondary)
        headerLabel.frame = NSRect(x: pad, y: y, width: width - pad * 2, height: 14)
        addSubview(headerLabel)

        let gridY = y + 16

        for i in 0..<4 {
            let col = i % 2
            let row = i / 2
            let mx = pad + CGFloat(col) * (moveBtnW + moveGap)
            let my = gridY + CGFloat(row) * (moveBtnH + moveGap)
            let moveRect = NSRect(x: mx, y: my, width: moveBtnW, height: moveBtnH)

            if i < moves.count {
                let moveName = moves[i]
                let moveData = MoveData.allMoves[moveName]
                let moveType = moveData?.type ?? "Normal"
                let btn = makeMoveButton(name: moveName, type: moveType, frame: moveRect)
                addSubview(btn)
                addHitRegion(HitRegion(
                    id: "move_\(i)",
                    rect: moveRect,
                    action: .battleMove(index: i)
                ))
            } else {
                let empty = makeEmptyMoveSlot(frame: moveRect)
                addSubview(empty)
            }
        }
    }

    // MARK: - Battle Over

    private func buildBattleOver(winner: BattleState.BattleWinner) {
        let w = bounds.width
        let h = bounds.height
        let isWin = winner == .player

        // Winning/losing Pokemon sprite
        if let engine = engine {
            let pokemon = isWin ? engine.state.playerPokemon : engine.state.opponentPokemon
            let spriteSize: CGFloat = 80
            let sprite = DSTabView.dsSprite(for: pokemon.pokemonId, size: spriteSize)
            sprite.translatesAutoresizingMaskIntoConstraints = true
            sprite.frame = NSRect(x: (w - spriteSize) / 2, y: h * 0.12, width: spriteSize, height: spriteSize)
            addSubview(sprite)
        }

        // Result text
        let resultText = isWin ? "VICTORY!" : "DEFEAT"
        let resultColor = isWin ? BattleTabView.hpGreen : BattleTabView.hpRed
        let resultLabel = DS.label(resultText, size: 28, bold: true, color: resultColor)
        resultLabel.frame = NSRect(x: 0, y: h * 0.38, width: w, height: 36)
        resultLabel.alignment = .center
        addSubview(resultLabel)

        // XP display
        if isWin && xpAwarded > 0 {
            let xpLabel = DS.label("+\(xpAwarded) XP to each team member!", size: 12, bold: true, color: DS.gold)
            xpLabel.frame = NSRect(x: 0, y: h * 0.38 + 40, width: w, height: 18)
            xpLabel.alignment = .center
            addSubview(xpLabel)
        }

        // Subtitle
        let subtitle = isWin ? "Your team fought well!" : "Better luck next time..."
        let subtitleLabel = DS.label(subtitle, size: 11, bold: false, color: DS.textSecondary)
        subtitleLabel.frame = NSRect(x: 0, y: h * 0.38 + (xpAwarded > 0 ? 62 : 40), width: w, height: 16)
        subtitleLabel.alignment = .center
        addSubview(subtitleLabel)

        // "Battle Again" button
        let btnW: CGFloat = 160
        let btnH: CGFloat = 44
        let btnX = (w - btnW) / 2
        let btnY = h * 0.75
        let btn = makeBattleButton(label: "Battle Again", frame: NSRect(x: btnX, y: btnY, width: btnW, height: btnH))
        addSubview(btn)
        addHitRegion(HitRegion(
            id: "playAgain",
            rect: NSRect(x: btnX, y: btnY, width: btnW, height: btnH),
            action: .startBattle
        ))
    }

    // MARK: - UI Builders

    private func makeBattleButton(label: String, frame: NSRect) -> NSView {
        let v = NSView(frame: frame)
        v.wantsLayer = true

        let grad = CAGradientLayer()
        grad.frame = v.bounds
        grad.colors = [DS.navActiveGreenTop.cgColor, DS.navActiveGreenBot.cgColor]
        grad.startPoint = CGPoint(x: 0.5, y: 0)
        grad.endPoint = CGPoint(x: 0.5, y: 1)
        grad.cornerRadius = 10
        v.layer?.addSublayer(grad)

        let border = CAShapeLayer()
        border.path = CGPath(roundedRect: v.bounds, cornerWidth: 10, cornerHeight: 10, transform: nil)
        border.fillColor = nil
        border.strokeColor = DS.cardGreenBorder.cgColor
        border.lineWidth = 1.5
        v.layer?.addSublayer(border)

        let lbl = DS.label(label, size: 15, bold: true)
        lbl.frame = v.bounds
        lbl.alignment = .center
        v.addSubview(lbl)

        return v
    }

    private func makeMoveButton(name: String, type: String, frame: NSRect) -> NSView {
        let v = NSView(frame: frame)
        v.wantsLayer = true
        v.layer?.backgroundColor = BattleTabView.moveBtnBg.cgColor
        v.layer?.cornerRadius = 8
        v.layer?.borderColor = BattleTabView.moveBtnBorder.cgColor
        v.layer?.borderWidth = 1

        // Move name (left side, larger)
        let nameLbl = DS.label(name, size: 11, bold: true)
        nameLbl.frame = NSRect(x: 10, y: 6, width: frame.width - 20, height: 16)
        nameLbl.lineBreakMode = .byTruncatingTail
        v.addSubview(nameLbl)

        // Type badge (small colored pill at bottom-left)
        let typeColor = BattleTabView.typeColors[type] ?? BattleTabView.typeColors["Normal"]!
        let badgeW: CGFloat = 50
        let badgeH: CGFloat = 16
        let badge = NSView(frame: NSRect(x: 10, y: 28, width: badgeW, height: badgeH))
        badge.wantsLayer = true
        badge.layer?.backgroundColor = typeColor.withAlphaComponent(0.85).cgColor
        badge.layer?.cornerRadius = badgeH / 2
        v.addSubview(badge)

        let typeLbl = DS.label(type.uppercased(), size: 8, bold: true)
        typeLbl.frame = badge.bounds
        typeLbl.alignment = .center
        badge.addSubview(typeLbl)

        return v
    }

    private func makeEmptyMoveSlot(frame: NSRect) -> NSView {
        let v = NSView(frame: frame)
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
        v.layer?.cornerRadius = 8

        let lbl = DS.label("---", size: 11, bold: false, color: NSColor(white: 0.3, alpha: 1))
        lbl.frame = NSRect(x: 0, y: 0, width: frame.width, height: frame.height)
        lbl.alignment = .center
        v.addSubview(lbl)

        return v
    }

    // MARK: - HP Bar

    private func addHPBar(to parent: NSView, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, fraction: Double) {
        // Track background
        let track = NSView(frame: NSRect(x: x, y: y, width: width, height: height))
        track.wantsLayer = true
        track.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1).cgColor
        track.layer?.cornerRadius = height / 2
        parent.addSubview(track)

        // HP "HP:" label to the left
        let hpTag = DS.label("HP", size: 7, bold: true, color: DS.textSecondary)
        hpTag.frame = NSRect(x: x - 20, y: y - 2, width: 18, height: 10)
        hpTag.alignment = .right
        parent.addSubview(hpTag)

        // Fill
        let fillW = width * CGFloat(min(max(fraction, 0), 1))
        if fillW > 0 {
            let fill = NSView(frame: NSRect(x: 0, y: 0, width: fillW, height: height))
            fill.wantsLayer = true
            let color: NSColor
            if fraction > 0.5 {
                color = BattleTabView.hpGreen
            } else if fraction > 0.2 {
                color = BattleTabView.hpYellow
            } else {
                color = BattleTabView.hpRed
            }
            fill.layer?.backgroundColor = color.cgColor
            fill.layer?.cornerRadius = height / 2
            track.addSubview(fill)
        }
    }
}

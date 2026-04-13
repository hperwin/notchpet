import AppKit
import QuartzCore

final class BattleTabView: DSTabView {

    // Battle system references
    private var engine: BattleEngine?
    private var currentState: PetState?

    // UI mode
    private enum Mode { case preBattle, inBattle, battleOver }
    private var mode: Mode = .preBattle

    // Battle result
    private var battleWinner: BattleState.BattleWinner?
    private var xpAwarded: Int = 0

    // Layout constants
    private static let panelW: CGFloat = 580
    private static let bgTop = NSColor(red: 0x2A/255.0, green: 0x2A/255.0, blue: 0x3A/255.0, alpha: 1)
    private static let bgBot = NSColor(red: 0x1A/255.0, green: 0x1A/255.0, blue: 0x2A/255.0, alpha: 1)
    private static let hpGreen = NSColor(red: 0x48/255.0, green: 0xD0/255.0, blue: 0x48/255.0, alpha: 1)
    private static let hpYellow = NSColor(red: 0xF8/255.0, green: 0xC8/255.0, blue: 0x20/255.0, alpha: 1)
    private static let hpRed = NSColor(red: 0xF0/255.0, green: 0x40/255.0, blue: 0x40/255.0, alpha: 1)
    private static let moveBtnBg = NSColor(red: 0x30/255.0, green: 0x50/255.0, blue: 0x80/255.0, alpha: 1)
    private static let moveBtnBorder = NSColor(red: 0x50/255.0, green: 0x78/255.0, blue: 0xB0/255.0, alpha: 1)

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
        self.mode = .inBattle
        self.battleWinner = nil
        self.xpAwarded = 0

        engine.onMoveExecuted = { [weak self] _ in
            self?.rebuildUI()
        }
        engine.onBattleOver = { [weak self] winner in
            self?.battleWinner = winner
            self?.mode = .battleOver
            self?.rebuildUI()
        }
        engine.onSwitchNeeded = { [weak self] in
            self?.rebuildUI()
        }

        rebuildUI()
    }

    func executePlayerMove(index: Int) {
        guard let engine = engine, !engine.state.isOver else { return }
        let aiMove = BattleAI.pickMove(attacker: engine.state.opponentPokemon, defender: engine.state.playerPokemon)
        engine.executeTurn(playerMoveIndex: index, opponentMoveIndex: aiMove)
    }

    func endBattle() {
        engine = nil
        mode = .preBattle
        rebuildUI()
    }

    // MARK: - Rebuild UI

    private func rebuildUI() {
        subviews.forEach { $0.removeFromSuperview() }
        layer?.sublayers?.removeAll(where: { $0.name == "battleGrad" })
        clearHitRegions()

        // Background gradient
        let grad = CAGradientLayer()
        grad.name = "battleGrad"
        grad.frame = bounds
        grad.colors = [BattleTabView.bgTop.cgColor, BattleTabView.bgBot.cgColor]
        grad.startPoint = CGPoint(x: 0.5, y: 0)
        grad.endPoint = CGPoint(x: 0.5, y: 1)
        layer?.insertSublayer(grad, at: 0)

        switch mode {
        case .preBattle:
            buildPreBattle()
        case .inBattle:
            buildInBattle()
        case .battleOver:
            buildBattleOver()
        }
    }

    // MARK: - Pre-Battle

    private func buildPreBattle() {
        let w = bounds.width
        let h = bounds.height

        // "Battle!" button centered
        let btnW: CGFloat = 160
        let btnH: CGFloat = 44
        let btnX = (w - btnW) / 2
        let btnY = h / 2 - 40

        let btn = makeButton(label: "Battle!", frame: NSRect(x: btnX, y: btnY, width: btnW, height: btnH))
        addSubview(btn)

        addHitRegion(HitRegion(
            id: "startBattle",
            rect: NSRect(x: btnX, y: btnY, width: btnW, height: btnH),
            action: .startBattle
        ))

        // "Your team:" label + party sprites
        let teamLabel = DS.label("Your team:", size: 11, bold: true, color: DS.textSecondary)
        teamLabel.frame = NSRect(x: (w - 200) / 2, y: btnY + btnH + 20, width: 200, height: 16)
        teamLabel.alignment = .center
        addSubview(teamLabel)

        if let state = currentState {
            let spriteSize: CGFloat = 36
            let spacing: CGFloat = 6
            let partyCount = CGFloat(state.party.count)
            let totalW = partyCount * spriteSize + (partyCount - 1) * spacing
            var sx = (w - totalW) / 2
            let sy = btnY + btnH + 42

            for pokemonId in state.party {
                let sprite = DSTabView.dsSprite(for: pokemonId, size: spriteSize)
                sprite.translatesAutoresizingMaskIntoConstraints = true
                sprite.frame = NSRect(x: sx, y: sy, width: spriteSize, height: spriteSize)
                addSubview(sprite)
                sx += spriteSize + spacing
            }
        }
    }

    // MARK: - In Battle

    private func buildInBattle() {
        guard let engine = engine else { return }
        let st = engine.state
        let w = bounds.width
        let pad: CGFloat = 12
        let spriteSize: CGFloat = 40
        let hpBarW: CGFloat = 120
        let hpBarH: CGFloat = 4

        // --- Battle log (single line at top) ---
        let logText: String
        if let last = st.log.last {
            var msg = "\(last.attackerName) used \(last.moveName)!"
            if last.isCrit { msg += " Critical hit!" }
            if !last.effectiveness.rawValue.isEmpty { msg += " \(last.effectiveness.rawValue)" }
            if last.defenderFainted { msg += " \(last.defenderName) fainted!" }
            logText = msg
        } else {
            logText = "A wild battle began!"
        }
        let logLabel = DS.label(logText, size: 9, bold: false, color: DS.textSecondary)
        logLabel.frame = NSRect(x: pad, y: 6, width: w - pad * 2, height: 14)
        logLabel.lineBreakMode = .byTruncatingTail
        addSubview(logLabel)

        // --- Opponent section (top area) ---
        let oppY: CGFloat = 26
        let oppSectionH: CGFloat = 70

        // Opponent card background
        let oppCard = DS.makeCard(frame: NSRect(x: pad, y: oppY, width: w - pad * 2, height: oppSectionH))
        addSubview(oppCard)

        // Opponent sprite (right side)
        let oppSprite = DSTabView.dsSprite(for: st.opponentPokemon.pokemonId, size: spriteSize)
        oppSprite.translatesAutoresizingMaskIntoConstraints = true
        oppSprite.frame = NSRect(x: w - pad - 16 - spriteSize, y: oppY + (oppSectionH - spriteSize) / 2, width: spriteSize, height: spriteSize)
        addSubview(oppSprite)

        // Opponent name + level
        let oppName = DS.label("\(st.opponentPokemon.displayName) Lv.\(st.opponentPokemon.level)", size: 11, bold: true)
        oppName.frame = NSRect(x: pad + 12, y: oppY + 10, width: 200, height: 16)
        addSubview(oppName)

        // Opponent HP bar
        let oppHPFraction = Double(st.opponentPokemon.currentHP) / Double(max(st.opponentPokemon.maxHP, 1))
        let oppHPBarX = pad + 12.0
        let oppHPBarY = oppY + 32.0
        addHPBar(to: self, x: oppHPBarX, y: oppHPBarY, width: hpBarW, height: hpBarH, fraction: oppHPFraction)

        let oppHPText = DS.label("\(st.opponentPokemon.currentHP)/\(st.opponentPokemon.maxHP)", size: 9, bold: false, color: DS.textSecondary)
        oppHPText.frame = NSRect(x: oppHPBarX, y: oppHPBarY + 6, width: hpBarW, height: 12)
        addSubview(oppHPText)

        // Opponent team indicators (small dots showing remaining team)
        let oppAlive = st.opponentTeam.filter(\.isAlive).count
        let oppTotal = st.opponentTeam.count
        let oppTeamLabel = DS.label("\(oppAlive)/\(oppTotal)", size: 9, bold: false, color: DS.textSecondary)
        oppTeamLabel.frame = NSRect(x: oppHPBarX, y: oppHPBarY + 18, width: 40, height: 12)
        addSubview(oppTeamLabel)

        // --- Player section (middle area) ---
        let playerY: CGFloat = oppY + oppSectionH + 8
        let playerSectionH: CGFloat = 70

        let playerCard = DS.makeCard(frame: NSRect(x: pad, y: playerY, width: w - pad * 2, height: playerSectionH))
        addSubview(playerCard)

        // Player sprite (left side)
        let playerSprite = DSTabView.dsSprite(for: st.playerPokemon.pokemonId, size: spriteSize)
        playerSprite.translatesAutoresizingMaskIntoConstraints = true
        playerSprite.frame = NSRect(x: pad + 16, y: playerY + (playerSectionH - spriteSize) / 2, width: spriteSize, height: spriteSize)
        addSubview(playerSprite)

        // Player name + level
        let playerName = DS.label("\(st.playerPokemon.displayName) Lv.\(st.playerPokemon.level)", size: 11, bold: true)
        playerName.frame = NSRect(x: pad + 16 + spriteSize + 12, y: playerY + 10, width: 200, height: 16)
        addSubview(playerName)

        // Player HP bar
        let playerHPFraction = Double(st.playerPokemon.currentHP) / Double(max(st.playerPokemon.maxHP, 1))
        let playerHPBarX = pad + 16 + spriteSize + 12
        let playerHPBarY = playerY + 32.0
        addHPBar(to: self, x: playerHPBarX, y: playerHPBarY, width: hpBarW, height: hpBarH, fraction: playerHPFraction)

        let playerHPText = DS.label("\(st.playerPokemon.currentHP)/\(st.playerPokemon.maxHP)", size: 9, bold: false, color: DS.textSecondary)
        playerHPText.frame = NSRect(x: playerHPBarX, y: playerHPBarY + 6, width: hpBarW, height: 12)
        addSubview(playerHPText)

        // Player team indicators
        let playerAlive = st.playerTeam.filter(\.isAlive).count
        let playerTotal = st.playerTeam.count
        let playerTeamLabel = DS.label("\(playerAlive)/\(playerTotal)", size: 9, bold: false, color: DS.textSecondary)
        playerTeamLabel.frame = NSRect(x: playerHPBarX, y: playerHPBarY + 18, width: 40, height: 12)
        addSubview(playerTeamLabel)

        // --- Move buttons (2x2 grid below player section) ---
        let moveGridY = playerY + playerSectionH + 10
        let moveBtnW = (w - pad * 2 - 8) / 2
        let moveBtnH: CGFloat = 32
        let moveGap: CGFloat = 6

        let moves = st.playerPokemon.moves
        for i in 0..<4 {
            let col = i % 2
            let row = i / 2
            let mx = pad + CGFloat(col) * (moveBtnW + moveGap)
            let my = moveGridY + CGFloat(row) * (moveBtnH + moveGap)
            let moveRect = NSRect(x: mx, y: my, width: moveBtnW, height: moveBtnH)

            if i < moves.count {
                let moveName = moves[i]
                let moveType = MoveData.allMoves[moveName]?.type ?? "Normal"
                let btn = makeMoveButton(label: moveName, type: moveType, frame: moveRect)
                addSubview(btn)
                addHitRegion(HitRegion(
                    id: "move_\(i)",
                    rect: moveRect,
                    action: .battleMove(index: i)
                ))
            } else {
                // Empty slot
                let empty = makeEmptyMoveButton(frame: moveRect)
                addSubview(empty)
            }
        }
    }

    // MARK: - Battle Over

    private func buildBattleOver() {
        let w = bounds.width
        let h = bounds.height

        let isWin = battleWinner == .player

        // Result text
        let resultText = isWin ? "You Win!" : "You Lose!"
        let resultColor = isWin ? DS.greenFill : BattleTabView.hpRed
        let resultLabel = DS.label(resultText, size: 20, bold: true, color: resultColor)
        resultLabel.frame = NSRect(x: 0, y: h / 2 - 60, width: w, height: 28)
        resultLabel.alignment = .center
        addSubview(resultLabel)

        // XP display
        if isWin && xpAwarded > 0 {
            let xpLabel = DS.label("+\(xpAwarded) XP to each team member!", size: 12, bold: false, color: DS.gold)
            xpLabel.frame = NSRect(x: 0, y: h / 2 - 28, width: w, height: 18)
            xpLabel.alignment = .center
            addSubview(xpLabel)
        }

        // Play Again button
        let btnW: CGFloat = 140
        let btnH: CGFloat = 36
        let btnX = (w - btnW) / 2
        let btnY = h / 2 + 10

        let btn = makeButton(label: "Play Again", frame: NSRect(x: btnX, y: btnY, width: btnW, height: btnH))
        addSubview(btn)
        addHitRegion(HitRegion(
            id: "playAgain",
            rect: NSRect(x: btnX, y: btnY, width: btnW, height: btnH),
            action: .startBattle
        ))
    }

    // MARK: - Set XP Awarded (called externally after battle ends)

    func setXPAwarded(_ xp: Int) {
        xpAwarded = xp
        if mode == .battleOver {
            rebuildUI()
        }
    }

    // MARK: - UI Helpers

    private func makeButton(label: String, frame: NSRect) -> NSView {
        let v = NSView(frame: frame)
        v.wantsLayer = true

        let grad = CAGradientLayer()
        grad.frame = v.bounds
        grad.colors = [DS.navActiveGreenTop.cgColor, DS.navActiveGreenBot.cgColor]
        grad.startPoint = CGPoint(x: 0.5, y: 0)
        grad.endPoint = CGPoint(x: 0.5, y: 1)
        grad.cornerRadius = 8
        v.layer?.addSublayer(grad)

        let lbl = DS.label(label, size: 13, bold: true)
        lbl.frame = v.bounds
        lbl.alignment = .center
        v.addSubview(lbl)

        return v
    }

    private func makeMoveButton(label: String, type: String, frame: NSRect) -> NSView {
        let v = NSView(frame: frame)
        v.wantsLayer = true
        v.layer?.backgroundColor = BattleTabView.moveBtnBg.cgColor
        v.layer?.cornerRadius = 6
        v.layer?.borderColor = BattleTabView.moveBtnBorder.cgColor
        v.layer?.borderWidth = 1

        // Move name
        let nameLbl = DS.label(label, size: 10, bold: true)
        nameLbl.frame = NSRect(x: 8, y: 4, width: frame.width - 50, height: 14)
        nameLbl.lineBreakMode = .byTruncatingTail
        v.addSubview(nameLbl)

        // Type label (small, right-aligned)
        let typeLbl = DS.label(type, size: 8, bold: false, color: typeColor(for: type))
        typeLbl.frame = NSRect(x: frame.width - 50, y: 4, width: 42, height: 14)
        typeLbl.alignment = .right
        v.addSubview(typeLbl)

        return v
    }

    private func makeEmptyMoveButton(frame: NSRect) -> NSView {
        let v = NSView(frame: frame)
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1).cgColor
        v.layer?.cornerRadius = 6

        let lbl = DS.label("---", size: 10, bold: false, color: DS.textSecondary)
        lbl.frame = NSRect(x: 8, y: 4, width: frame.width - 16, height: 14)
        v.addSubview(lbl)

        return v
    }

    private func addHPBar(to parent: NSView, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, fraction: Double) {
        // Track
        let track = NSView(frame: NSRect(x: x, y: y, width: width, height: height))
        track.wantsLayer = true
        track.layer?.backgroundColor = DS.barTrack.cgColor
        track.layer?.cornerRadius = height / 2
        parent.addSubview(track)

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

    private func typeColor(for type: String) -> NSColor {
        switch type {
        case "Fire": return NSColor(red: 0.95, green: 0.5, blue: 0.2, alpha: 1)
        case "Water": return NSColor(red: 0.3, green: 0.55, blue: 0.95, alpha: 1)
        case "Grass": return NSColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1)
        case "Electric": return NSColor(red: 0.95, green: 0.85, blue: 0.2, alpha: 1)
        case "Psychic": return NSColor(red: 0.95, green: 0.4, blue: 0.6, alpha: 1)
        case "Fighting": return NSColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1)
        case "Dragon": return NSColor(red: 0.4, green: 0.3, blue: 0.9, alpha: 1)
        case "Dark": return NSColor(red: 0.5, green: 0.35, blue: 0.25, alpha: 1)
        case "Ghost": return NSColor(red: 0.5, green: 0.35, blue: 0.6, alpha: 1)
        case "Fairy": return NSColor(red: 0.9, green: 0.55, blue: 0.9, alpha: 1)
        case "Ice": return NSColor(red: 0.6, green: 0.85, blue: 0.9, alpha: 1)
        case "Flying": return NSColor(red: 0.6, green: 0.6, blue: 0.9, alpha: 1)
        case "Poison": return NSColor(red: 0.65, green: 0.3, blue: 0.65, alpha: 1)
        case "Ground": return NSColor(red: 0.8, green: 0.7, blue: 0.4, alpha: 1)
        case "Rock": return NSColor(red: 0.7, green: 0.65, blue: 0.45, alpha: 1)
        case "Steel": return NSColor(red: 0.7, green: 0.7, blue: 0.8, alpha: 1)
        case "Bug": return NSColor(red: 0.6, green: 0.7, blue: 0.15, alpha: 1)
        default: return NSColor(red: 0.65, green: 0.65, blue: 0.5, alpha: 1)
        }
    }
}

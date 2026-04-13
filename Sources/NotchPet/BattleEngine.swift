import Foundation

final class BattleEngine {
    private(set) var state: BattleState

    // Callbacks (kept for backward compatibility with BattleTabView)
    var onMoveExecuted: ((MoveResult) -> Void)?
    var onBattleOver: ((BattleState.BattleWinner) -> Void)?
    var onSwitchNeeded: (() -> Void)?

    init(playerTeam: [BattlePokemon], opponentTeam: [BattlePokemon]) {
        precondition(!playerTeam.isEmpty && !opponentTeam.isEmpty)
        self.state = BattleState(
            playerPokemon: playerTeam[0],
            opponentPokemon: opponentTeam[0],
            playerTeam: playerTeam,
            opponentTeam: opponentTeam
        )
    }

    // MARK: - Turn Execution

    /// Execute one full turn. Returns a list of events for UI animation/logging.
    @discardableResult
    func executeTurn(playerMoveIndex: Int, opponentMoveIndex: Int) -> [TurnEvent] {
        guard !state.isOver else { return [] }
        state.turnNumber += 1

        var events: [TurnEvent] = []

        let playerMove = resolveMove(for: state.playerPokemon, index: playerMoveIndex)
        let opponentMove = resolveMove(for: state.opponentPokemon, index: opponentMoveIndex)

        // Determine turn order: priority first, then effective speed, then coin flip
        let playerFirst = determineOrder(
            attackerMove: playerMove,
            defenderMove: opponentMove,
            attackerSpeed: state.playerPokemon.effectiveSpeed,
            defenderSpeed: state.opponentPokemon.effectiveSpeed
        )

        if playerFirst {
            events += executeHalf(attackerIsPlayer: true, moveIndex: playerMoveIndex)
            if !state.isOver && state.opponentPokemon.isAlive {
                events += executeHalf(attackerIsPlayer: false, moveIndex: opponentMoveIndex)
            }
        } else {
            events += executeHalf(attackerIsPlayer: false, moveIndex: opponentMoveIndex)
            if !state.isOver && state.playerPokemon.isAlive {
                events += executeHalf(attackerIsPlayer: true, moveIndex: playerMoveIndex)
            }
        }

        // End-of-turn status damage
        if !state.isOver {
            events += applyEndOfTurnStatus(isPlayer: playerFirst)
            events += applyEndOfTurnStatus(isPlayer: !playerFirst)
        }

        return events
    }

    // MARK: - Switch

    func switchPlayerPokemon(to index: Int) {
        guard index >= 0, index < state.playerTeam.count else { return }
        let candidate = state.playerTeam[index]
        guard candidate.isAlive else { return }
        state.playerPokemon = candidate
    }

    // MARK: - Move Resolution

    private func resolveMove(for pokemon: BattlePokemon, index: Int) -> Move {
        let clampedIndex = pokemon.moves.isEmpty ? -1 : min(index, pokemon.moves.count - 1)
        if clampedIndex >= 0, let move = MoveData.allMoves[pokemon.moves[clampedIndex]] {
            return move
        }
        // Struggle fallback
        return Move(name: "Struggle", type: "Normal", category: .physical, power: 50, accuracy: 0, pp: 999,
                     effect: .recoil(fraction: 0.25))
    }

    // MARK: - Turn Order

    private func determineOrder(attackerMove: Move, defenderMove: Move, attackerSpeed: Double, defenderSpeed: Double) -> Bool {
        // Higher priority goes first
        if attackerMove.priority != defenderMove.priority {
            return attackerMove.priority > defenderMove.priority
        }
        // Same priority: faster goes first
        if attackerSpeed != defenderSpeed {
            return attackerSpeed > defenderSpeed
        }
        // Speed tie: coin flip
        return Bool.random()
    }

    // MARK: - Execute One Side's Move

    private func executeHalf(attackerIsPlayer: Bool, moveIndex: Int) -> [TurnEvent] {
        var events: [TurnEvent] = []
        var attacker = attackerIsPlayer ? state.playerPokemon : state.opponentPokemon
        let defender = attackerIsPlayer ? state.opponentPokemon : state.playerPokemon

        guard attacker.isAlive, defender.isAlive else { return events }

        // Check if attacker can move (status checks)
        if let blockEvent = checkCanMove(pokemon: &attacker) {
            events.append(blockEvent)
            writeBack(pokemon: attacker, isPlayer: attackerIsPlayer)
            return events
        }

        let clampedIndex = attacker.moves.isEmpty ? -1 : min(moveIndex, attacker.moves.count - 1)
        let move: Move
        let moveName: String
        // (isStruggle tracking removed -- Struggle is used as a plain move)

        if clampedIndex >= 0, let m = MoveData.allMoves[attacker.moves[clampedIndex]] {
            // Check PP
            if attacker.movePP[clampedIndex] <= 0 {
                // No PP -- use Struggle
                move = Move(name: "Struggle", type: "Normal", category: .physical, power: 50, accuracy: 0, pp: 999,
                             effect: .recoil(fraction: 0.25))
                moveName = "Struggle"
                events.append(.noPP(attackerName: attacker.displayName, moveName: m.name))
            } else {
                move = m
                moveName = m.name
                attacker.movePP[clampedIndex] -= 1
            }
        } else {
            move = Move(name: "Struggle", type: "Normal", category: .physical, power: 50, accuracy: 0, pp: 999,
                         effect: .recoil(fraction: 0.25))
            moveName = "Struggle"
        }

        events.append(.moveUsed(attackerName: attacker.displayName, moveName: moveName))

        // Accuracy check (accuracy == 0 means never miss)
        if move.accuracy > 0 {
            let roll = Int.random(in: 1...100)
            if roll > move.accuracy {
                events.append(.missed(attackerName: attacker.displayName, moveName: moveName))
                writeBack(pokemon: attacker, isPlayer: attackerIsPlayer)
                return events
            }
        }

        var updatedDefender = defender

        // Status moves
        if move.category == .status {
            let statusEvents = applyStatusMoveEffects(move: move, attacker: &attacker, defender: &updatedDefender)
            events += statusEvents

            let result = MoveResult(
                attackerName: attacker.displayName,
                defenderName: updatedDefender.displayName,
                moveName: moveName,
                damage: 0,
                effectiveness: .normal,
                isCrit: false,
                isSTAB: false,
                defenderFainted: false,
                statusInflicted: nil,
                statChange: statusEvents.isEmpty ? nil : "Effect applied",
                message: nil
            )
            state.log.append(result)
            onMoveExecuted?(result)

            writeBack(pokemon: attacker, isPlayer: attackerIsPlayer)
            writeBack(pokemon: updatedDefender, isPlayer: !attackerIsPlayer)
            return events
        }

        // --- Damage calculation ---

        let defenderType = MoveData.pokemonTypes[updatedDefender.pokemonId] ?? "Normal"
        let typeMultiplier = TypeChart.effectiveness(attackType: move.type, defenderType: defenderType)

        // Immunity check
        if typeMultiplier == 0.0 {
            let result = MoveResult(
                attackerName: attacker.displayName,
                defenderName: updatedDefender.displayName,
                moveName: moveName,
                damage: 0,
                effectiveness: .immune,
                isCrit: false,
                isSTAB: false,
                defenderFainted: false,
                statusInflicted: nil,
                statChange: nil,
                message: "It doesn't affect \(updatedDefender.displayName)..."
            )
            state.log.append(result)
            events.append(.damage(result))
            onMoveExecuted?(result)

            writeBack(pokemon: attacker, isPlayer: attackerIsPlayer)
            return events
        }

        // Determine A and D stats
        let atkStat: Double
        let defStat: Double

        switch move.category {
        case .physical:
            if moveName == "Foul Play" {
                // Foul Play uses the defender's Attack stat
                atkStat = Double(updatedDefender.baseStats.attack) * updatedDefender.statStages.attackMultiplier
            } else {
                atkStat = Double(attacker.baseStats.attack) * attacker.statStages.attackMultiplier
            }
            if moveName == "Psystrike" {
                // Psystrike targets physical Defense despite being special
                defStat = Double(updatedDefender.baseStats.defense) * updatedDefender.statStages.defenseMultiplier
            } else {
                defStat = Double(updatedDefender.baseStats.defense) * updatedDefender.statStages.defenseMultiplier
            }
        case .special:
            if moveName == "Psystrike" {
                atkStat = Double(attacker.baseStats.spAttack) * attacker.statStages.spAttackMultiplier
                defStat = Double(updatedDefender.baseStats.defense) * updatedDefender.statStages.defenseMultiplier
            } else {
                atkStat = Double(attacker.baseStats.spAttack) * attacker.statStages.spAttackMultiplier
                defStat = Double(updatedDefender.baseStats.spDefense) * updatedDefender.statStages.spDefenseMultiplier
            }
        case .status:
            // Should not reach here
            atkStat = 0; defStat = 1
        }

        // STAB
        let attackerType = MoveData.pokemonTypes[attacker.pokemonId] ?? "Normal"
        let isSTAB = move.type == attackerType
        let stabMultiplier = isSTAB ? 1.5 : 1.0

        // Critical hit: 1/16 chance, 1.5x multiplier
        let isCrit = Double.random(in: 0...1) < (1.0 / 16.0)
        let critMultiplier = isCrit ? 1.5 : 1.0

        // Random factor: 0.85 to 1.0
        let randomFactor = Double.random(in: 0.85...1.0)

        // Burn penalty: physical moves do half damage when burned
        let burnMultiplier: Double
        if attacker.status == .burn && move.category == .physical && moveName != "Foul Play" {
            burnMultiplier = 0.5
        } else {
            burnMultiplier = 1.0
        }

        // Gen V+ damage formula
        let levelFactor = Double(2 * attacker.level) / 5.0 + 2.0
        let baseDmg = (levelFactor * Double(move.power) * atkStat / Double(max(defStat, 1.0))) / 50.0 + 2.0
        var damage = Int(baseDmg * stabMultiplier * typeMultiplier * critMultiplier * randomFactor * burnMultiplier)
        damage = max(damage, 1)  // always do at least 1 damage (unless immune, handled above)

        // Apply damage
        updatedDefender.currentHP = max(updatedDefender.currentHP - damage, 0)

        // Effectiveness category
        let effectiveness: MoveResult.Effectiveness
        if typeMultiplier >= 2.0 {
            effectiveness = .superEffective
        } else if typeMultiplier <= 0.5 {
            effectiveness = .notVeryEffective
        } else {
            effectiveness = .normal
        }

        // Secondary effects (after damage)
        var statusInflicted: StatusCondition? = nil
        var statChangeMsg: String? = nil
        var extraEvents: [TurnEvent] = []

        if let effect = move.effect {
            let (inflicted, msg, evts) = applyDamageMoveEffect(
                effect: effect, move: move, attacker: &attacker, defender: &updatedDefender, damage: damage
            )
            statusInflicted = inflicted
            statChangeMsg = msg
            extraEvents = evts
        }

        // Recoil (from effect)
        if case .recoil(let fraction) = move.effect {
            let recoilDmg = max(Int(Double(damage) * fraction), 1)
            attacker.currentHP = max(attacker.currentHP - recoilDmg, 0)
            extraEvents.append(.recoilDamage(pokemonName: attacker.displayName, damage: recoilDmg))
        }

        let defenderFainted = !updatedDefender.isAlive

        let result = MoveResult(
            attackerName: attacker.displayName,
            defenderName: updatedDefender.displayName,
            moveName: moveName,
            damage: damage,
            effectiveness: effectiveness,
            isCrit: isCrit,
            isSTAB: isSTAB,
            defenderFainted: defenderFainted,
            statusInflicted: statusInflicted,
            statChange: statChangeMsg,
            message: effectiveness.rawValue.isEmpty ? nil : effectiveness.rawValue
        )
        state.log.append(result)
        events.append(.damage(result))
        events += extraEvents
        onMoveExecuted?(result)

        // Write back both pokemon
        writeBack(pokemon: attacker, isPlayer: attackerIsPlayer)
        writeBack(pokemon: updatedDefender, isPlayer: !attackerIsPlayer)

        // Handle fainting
        if defenderFainted {
            events.append(.fainted(pokemonName: updatedDefender.displayName))
            events += handleFaint(defenderIsPlayer: !attackerIsPlayer)
        }

        // Check if attacker fainted from recoil
        if !attacker.isAlive {
            events.append(.fainted(pokemonName: attacker.displayName))
            events += handleFaint(defenderIsPlayer: attackerIsPlayer)
        }

        return events
    }

    // MARK: - Status Move Effects

    private func applyStatusMoveEffects(move: Move, attacker: inout BattlePokemon, defender: inout BattlePokemon) -> [TurnEvent] {
        var events: [TurnEvent] = []

        guard let effect = move.effect else {
            // Moves like Splash / Transform with no effect
            return events
        }

        switch effect {
        case .statBoost(let stat, let stages, let target):
            switch target {
            case .self_:
                attacker.statStages.apply(stat: stat, stages: stages)
                events.append(.statChanged(pokemonName: attacker.displayName, stat: stat.rawValue, stages: stages))
            case .opponent:
                defender.statStages.apply(stat: stat, stages: stages)
                events.append(.statChanged(pokemonName: defender.displayName, stat: stat.rawValue, stages: stages))
            }

        case .multiStatBoost(let changes):
            for change in changes {
                switch change.target {
                case .self_:
                    attacker.statStages.apply(stat: change.stat, stages: change.stages)
                    events.append(.statChanged(pokemonName: attacker.displayName, stat: change.stat.rawValue, stages: change.stages))
                case .opponent:
                    defender.statStages.apply(stat: change.stat, stages: change.stages)
                    events.append(.statChanged(pokemonName: defender.displayName, stat: change.stat.rawValue, stages: change.stages))
                }
            }

        case .heal(let fraction):
            let healAmount = Int(Double(attacker.maxHP) * fraction)
            attacker.currentHP = min(attacker.currentHP + healAmount, attacker.maxHP)
            events.append(.healApplied(pokemonName: attacker.displayName, amount: healAmount))
            // Rest also puts user to sleep
            if move.name == "Rest" {
                attacker.status = .sleep
                attacker.sleepTurns = 2
                events.append(.statusInflicted(pokemonName: attacker.displayName, status: .sleep))
            }

        case .sleep(let chance):
            if defender.status == nil {
                let roll = Int.random(in: 1...100)
                if roll <= chance {
                    defender.status = .sleep
                    defender.sleepTurns = Int.random(in: 1...3)
                    events.append(.statusInflicted(pokemonName: defender.displayName, status: .sleep))
                }
            }

        case .burn(let chance):
            if defender.status == nil {
                let roll = Int.random(in: 1...100)
                if roll <= chance {
                    defender.status = .burn
                    events.append(.statusInflicted(pokemonName: defender.displayName, status: .burn))
                }
            }

        case .paralyze(let chance):
            if defender.status == nil {
                let roll = Int.random(in: 1...100)
                if roll <= chance {
                    defender.status = .paralysis
                    events.append(.statusInflicted(pokemonName: defender.displayName, status: .paralysis))
                }
            }

        case .poison(let chance):
            if defender.status == nil {
                let roll = Int.random(in: 1...100)
                if roll <= chance {
                    defender.status = .poison
                    events.append(.statusInflicted(pokemonName: defender.displayName, status: .poison))
                }
            }

        default:
            break
        }

        return events
    }

    // MARK: - Damage Move Secondary Effects

    private func applyDamageMoveEffect(
        effect: MoveEffect, move: Move,
        attacker: inout BattlePokemon, defender: inout BattlePokemon, damage: Int
    ) -> (StatusCondition?, String?, [TurnEvent]) {
        var inflicted: StatusCondition? = nil
        var msg: String? = nil
        var events: [TurnEvent] = []

        switch effect {
        case .burn(let chance):
            if defender.status == nil {
                let roll = Int.random(in: 1...100)
                if roll <= chance {
                    defender.status = .burn
                    inflicted = .burn
                    msg = "\(defender.displayName) was burned!"
                    events.append(.statusInflicted(pokemonName: defender.displayName, status: .burn))
                }
            }

        case .paralyze(let chance):
            if defender.status == nil {
                let roll = Int.random(in: 1...100)
                if roll <= chance {
                    defender.status = .paralysis
                    inflicted = .paralysis
                    msg = "\(defender.displayName) is paralyzed!"
                    events.append(.statusInflicted(pokemonName: defender.displayName, status: .paralysis))
                }
            }

        case .poison(let chance):
            if defender.status == nil {
                let roll = Int.random(in: 1...100)
                if roll <= chance {
                    defender.status = .poison
                    inflicted = .poison
                    msg = "\(defender.displayName) was poisoned!"
                    events.append(.statusInflicted(pokemonName: defender.displayName, status: .poison))
                }
            }

        case .flinch(let chance):
            // Flinch only matters if the target hasn't moved yet this turn
            // Simplified: we just roll for it; the "skip turn" is not modeled here since
            // the defender may have already acted. In games, flinch only works if you go first.
            let roll = Int.random(in: 1...100)
            if roll <= chance {
                msg = "\(defender.displayName) flinched!"
            }

        case .confuse(let chance):
            let roll = Int.random(in: 1...100)
            if roll <= chance {
                msg = "\(defender.displayName) became confused!"
                // Confusion not tracked as a status; it's volatile. Just a message.
            }

        case .statBoost(let stat, let stages, let target):
            // Some damaging moves have a % chance for stat change
            // For simplicity, Ancient Power's 10% all-stats is handled via multiStatBoost
            // Single stat boosts from damaging moves (like Psychic's 10% SpDef drop) apply always
            // when listed as an effect on a damaging move
            switch target {
            case .self_:
                attacker.statStages.apply(stat: stat, stages: stages)
                msg = statChangeMessage(pokemonName: attacker.displayName, stat: stat, stages: stages)
                events.append(.statChanged(pokemonName: attacker.displayName, stat: stat.rawValue, stages: stages))
            case .opponent:
                // 10% chance for secondary stat drops on damaging moves (Psychic, Shadow Ball, etc.)
                let roll = Int.random(in: 1...100)
                if roll <= 10 {
                    defender.statStages.apply(stat: stat, stages: stages)
                    msg = statChangeMessage(pokemonName: defender.displayName, stat: stat, stages: stages)
                    events.append(.statChanged(pokemonName: defender.displayName, stat: stat.rawValue, stages: stages))
                }
            }

        case .multiStatBoost(let changes):
            // For damaging moves with multi-stat (Close Combat self-drops always apply)
            for change in changes {
                switch change.target {
                case .self_:
                    attacker.statStages.apply(stat: change.stat, stages: change.stages)
                    let m = statChangeMessage(pokemonName: attacker.displayName, stat: change.stat, stages: change.stages)
                    if msg == nil { msg = m } else { msg! += " " + m }
                    events.append(.statChanged(pokemonName: attacker.displayName, stat: change.stat.rawValue, stages: change.stages))
                case .opponent:
                    let roll = Int.random(in: 1...100)
                    if roll <= 10 {
                        defender.statStages.apply(stat: change.stat, stages: change.stages)
                        let m = statChangeMessage(pokemonName: defender.displayName, stat: change.stat, stages: change.stages)
                        if msg == nil { msg = m } else { msg! += " " + m }
                        events.append(.statChanged(pokemonName: defender.displayName, stat: change.stat.rawValue, stages: change.stages))
                    }
                }
            }

        case .drain(let fraction):
            let healAmount = max(Int(Double(damage) * fraction), 1)
            attacker.currentHP = min(attacker.currentHP + healAmount, attacker.maxHP)
            msg = "\(attacker.displayName) drained energy!"
            events.append(.healApplied(pokemonName: attacker.displayName, amount: healAmount))

        case .recoil:
            // Handled separately after damage is applied
            break

        case .heal(let fraction):
            let healAmount = Int(Double(attacker.maxHP) * fraction)
            attacker.currentHP = min(attacker.currentHP + healAmount, attacker.maxHP)
            events.append(.healApplied(pokemonName: attacker.displayName, amount: healAmount))

        case .sleep(let chance):
            if defender.status == nil {
                let roll = Int.random(in: 1...100)
                if roll <= chance {
                    defender.status = .sleep
                    defender.sleepTurns = Int.random(in: 1...3)
                    inflicted = .sleep
                    events.append(.statusInflicted(pokemonName: defender.displayName, status: .sleep))
                }
            }
        }

        return (inflicted, msg, events)
    }

    // MARK: - Can Move Check

    private func checkCanMove(pokemon: inout BattlePokemon) -> TurnEvent? {
        switch pokemon.status {
        case .paralysis:
            // 25% chance to be fully paralyzed
            if Double.random(in: 0...1) < 0.25 {
                return .cantMove(pokemonName: pokemon.displayName, reason: "is paralyzed! It can't move!")
            }

        case .sleep:
            if pokemon.sleepTurns > 0 {
                pokemon.sleepTurns -= 1
                if pokemon.sleepTurns <= 0 {
                    pokemon.status = nil
                    // Woke up -- can still act this turn? In real games, no. We skip.
                    return .cantMove(pokemonName: pokemon.displayName, reason: "woke up!")
                }
                return .cantMove(pokemonName: pokemon.displayName, reason: "is fast asleep!")
            } else {
                pokemon.status = nil
            }

        case .freeze:
            // 20% chance to thaw each turn
            if Double.random(in: 0...1) < 0.20 {
                pokemon.status = nil
                // Thawed -- in real games you can act. We allow it by returning nil.
                return nil
            }
            return .cantMove(pokemonName: pokemon.displayName, reason: "is frozen solid!")

        default:
            break
        }

        return nil
    }

    // MARK: - End-of-Turn Status Damage

    private func applyEndOfTurnStatus(isPlayer: Bool) -> [TurnEvent] {
        var events: [TurnEvent] = []
        var pokemon = isPlayer ? state.playerPokemon : state.opponentPokemon

        guard pokemon.isAlive else { return events }

        switch pokemon.status {
        case .burn:
            let dmg = max(pokemon.maxHP / 16, 1)
            pokemon.currentHP = max(pokemon.currentHP - dmg, 0)
            events.append(.statusDamage(pokemonName: pokemon.displayName, status: .burn, damage: dmg))

        case .poison:
            let dmg = max(pokemon.maxHP / 8, 1)
            pokemon.currentHP = max(pokemon.currentHP - dmg, 0)
            events.append(.statusDamage(pokemonName: pokemon.displayName, status: .poison, damage: dmg))

        case .toxic:
            pokemon.toxicCounter += 1
            let dmg = max((pokemon.maxHP * pokemon.toxicCounter) / 16, 1)
            pokemon.currentHP = max(pokemon.currentHP - dmg, 0)
            events.append(.statusDamage(pokemonName: pokemon.displayName, status: .toxic, damage: dmg))

        default:
            break
        }

        writeBack(pokemon: pokemon, isPlayer: isPlayer)

        if !pokemon.isAlive {
            events.append(.fainted(pokemonName: pokemon.displayName))
            events += handleFaint(defenderIsPlayer: isPlayer)
        }

        return events
    }

    // MARK: - Write Back

    private func writeBack(pokemon: BattlePokemon, isPlayer: Bool) {
        if isPlayer {
            state.playerPokemon = pokemon
            if let idx = state.playerTeam.firstIndex(where: { $0.pokemonId == pokemon.pokemonId }) {
                state.playerTeam[idx] = pokemon
            }
        } else {
            state.opponentPokemon = pokemon
            if let idx = state.opponentTeam.firstIndex(where: { $0.pokemonId == pokemon.pokemonId }) {
                state.opponentTeam[idx] = pokemon
            }
        }
    }

    // MARK: - Faint Handling

    private func handleFaint(defenderIsPlayer: Bool) -> [TurnEvent] {
        var events: [TurnEvent] = []

        if defenderIsPlayer {
            if let nextIdx = state.playerTeam.firstIndex(where: { $0.isAlive }) {
                state.playerPokemon = state.playerTeam[nextIdx]
                events.append(.switched(trainerName: "Player", pokemonName: state.playerPokemon.displayName))
                onSwitchNeeded?()
            } else {
                state.isOver = true
                state.winner = .opponent
                events.append(.battleOver(winner: .opponent))
                onBattleOver?(.opponent)
            }
        } else {
            if let nextIdx = state.opponentTeam.firstIndex(where: { $0.isAlive }) {
                state.opponentPokemon = state.opponentTeam[nextIdx]
                events.append(.switched(trainerName: "Opponent", pokemonName: state.opponentPokemon.displayName))
            } else {
                state.isOver = true
                state.winner = .player
                events.append(.battleOver(winner: .player))
                onBattleOver?(.player)
            }
        }

        return events
    }

    // MARK: - Helpers

    private func statChangeMessage(pokemonName: String, stat: MoveEffect.StatType, stages: Int) -> String {
        let statName: String
        switch stat {
        case .attack: statName = "Attack"
        case .defense: statName = "Defense"
        case .spAttack: statName = "Sp. Atk"
        case .spDefense: statName = "Sp. Def"
        case .speed: statName = "Speed"
        }

        let direction: String
        switch stages {
        case 2...: direction = "rose sharply!"
        case 1: direction = "rose!"
        case -1: direction = "fell!"
        case ...(-2): direction = "fell harshly!"
        default: direction = "changed!"
        }

        return "\(pokemonName)'s \(statName) \(direction)"
    }
}

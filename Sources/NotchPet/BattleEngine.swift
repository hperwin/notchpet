import Foundation

final class BattleEngine {
    private(set) var state: BattleState

    // Callbacks
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

    /// Execute one turn. Player picks a move index, opponent picks a move index.
    /// Faster Pokemon goes first.
    func executeTurn(playerMoveIndex: Int, opponentMoveIndex: Int) {
        guard !state.isOver else { return }
        state.turnNumber += 1

        let playerSpeed = state.playerPokemon.stats.speed
        let opponentSpeed = state.opponentPokemon.stats.speed

        // Determine order: faster goes first, random tiebreak
        let playerFirst: Bool
        if playerSpeed != opponentSpeed {
            playerFirst = playerSpeed > opponentSpeed
        } else {
            playerFirst = Bool.random()
        }

        if playerFirst {
            executeMove(attackerIsPlayer: true, moveIndex: playerMoveIndex)
            if !state.isOver && state.opponentPokemon.isAlive {
                executeMove(attackerIsPlayer: false, moveIndex: opponentMoveIndex)
            }
        } else {
            executeMove(attackerIsPlayer: false, moveIndex: opponentMoveIndex)
            if !state.isOver && state.playerPokemon.isAlive {
                executeMove(attackerIsPlayer: true, moveIndex: playerMoveIndex)
            }
        }
    }

    // MARK: - Switch

    /// Switch the player's active Pokemon to the given team index.
    func switchPlayerPokemon(to index: Int) {
        guard index >= 0, index < state.playerTeam.count else { return }
        let candidate = state.playerTeam[index]
        guard candidate.isAlive else { return }
        state.playerPokemon = candidate
    }

    // MARK: - Move Execution (private)

    private func executeMove(attackerIsPlayer: Bool, moveIndex: Int) {
        let attacker = attackerIsPlayer ? state.playerPokemon : state.opponentPokemon
        let defender = attackerIsPlayer ? state.opponentPokemon : state.playerPokemon

        guard attacker.isAlive, defender.isAlive else { return }

        let clampedIndex = attacker.moves.isEmpty ? -1 : min(moveIndex, attacker.moves.count - 1)
        let moveName: String
        let moveType: String

        if clampedIndex >= 0, let move = MoveData.allMoves[attacker.moves[clampedIndex]] {
            moveName = move.name
            moveType = move.type
        } else {
            // Fallback: Struggle (Normal type)
            moveName = "Struggle"
            moveType = "Normal"
        }

        // Type effectiveness
        let defenderType = MoveData.pokemonTypes[defender.pokemonId] ?? "Normal"
        let typeMultiplier = TypeChart.effectiveness(attackType: moveType, defenderType: defenderType)

        // Determine effectiveness category
        let effectiveness: MoveResult.Effectiveness
        if typeMultiplier >= 2.0 {
            effectiveness = .superEffective
        } else if typeMultiplier == 0.0 {
            effectiveness = .immune
        } else if typeMultiplier <= 0.5 {
            effectiveness = .notVeryEffective
        } else {
            effectiveness = .normal
        }

        // Crit: 6.25% chance, 1.5x multiplier
        let isCrit = Double.random(in: 0...1) < 0.0625
        let critMultiplier = isCrit ? 1.5 : 1.0

        // Random factor 0.85 - 1.0
        let randomFactor = Double.random(in: 0.85...1.0)

        // Use higher of attack/spAttack for attacker, corresponding defense
        let atkStat: Int
        let defStat: Int
        if attacker.stats.attack >= attacker.stats.spAttack {
            atkStat = attacker.stats.attack
            defStat = defender.stats.defense
        } else {
            atkStat = attacker.stats.spAttack
            defStat = defender.stats.spDefense
        }

        let basePower = 60.0

        // Damage formula
        let levelFactor = Double(2 * attacker.level) / 5.0 + 2.0
        let raw = (levelFactor * basePower * Double(atkStat) / Double(max(defStat, 1))) / 50.0 + 2.0
        let damage = Int(raw * typeMultiplier * critMultiplier * randomFactor)

        // Apply damage
        var updatedDefender = defender
        updatedDefender.currentHP = max(updatedDefender.currentHP - damage, 0)

        // Write back
        if attackerIsPlayer {
            state.opponentPokemon = updatedDefender
            // Sync back into team array
            if let idx = state.opponentTeam.firstIndex(where: { $0.pokemonId == updatedDefender.pokemonId }) {
                state.opponentTeam[idx] = updatedDefender
            }
        } else {
            state.playerPokemon = updatedDefender
            if let idx = state.playerTeam.firstIndex(where: { $0.pokemonId == updatedDefender.pokemonId }) {
                state.playerTeam[idx] = updatedDefender
            }
        }

        let result = MoveResult(
            attackerName: attacker.displayName,
            defenderName: defender.displayName,
            moveName: moveName,
            damage: damage,
            effectiveness: effectiveness,
            isCrit: isCrit,
            defenderFainted: !updatedDefender.isAlive
        )
        state.log.append(result)
        onMoveExecuted?(result)

        // Handle fainting
        if !updatedDefender.isAlive {
            handleFaint(defenderIsPlayer: !attackerIsPlayer)
        }
    }

    private func handleFaint(defenderIsPlayer: Bool) {
        if defenderIsPlayer {
            // Try to auto-switch to next alive player Pokemon
            if let nextIdx = state.playerTeam.firstIndex(where: { $0.isAlive }) {
                state.playerPokemon = state.playerTeam[nextIdx]
                onSwitchNeeded?()
            } else {
                // All player Pokemon fainted
                state.isOver = true
                state.winner = .opponent
                onBattleOver?(.opponent)
            }
        } else {
            // Try to auto-switch opponent
            if let nextIdx = state.opponentTeam.firstIndex(where: { $0.isAlive }) {
                state.opponentPokemon = state.opponentTeam[nextIdx]
            } else {
                // All opponent Pokemon fainted
                state.isOver = true
                state.winner = .player
                onBattleOver?(.player)
            }
        }
    }
}

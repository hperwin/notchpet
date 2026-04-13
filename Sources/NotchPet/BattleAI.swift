import Foundation

enum BattleAI {
    /// Pick the best move index using a scoring system that considers power, STAB, type effectiveness,
    /// and move category. 20% chance to pick a random move for variety.
    static func pickMove(attacker: BattlePokemon, defender: BattlePokemon) -> Int {
        guard !attacker.moves.isEmpty else { return 0 }

        // 20% chance to pick a completely random move for variety
        if Double.random(in: 0...1) < 0.20 {
            return Int.random(in: 0..<attacker.moves.count)
        }

        let defenderType = MoveData.pokemonTypes[defender.pokemonId] ?? "Normal"
        let attackerType = MoveData.pokemonTypes[attacker.pokemonId] ?? "Normal"
        var bestIndex = 0
        var bestScore = -1.0

        for (i, moveName) in attacker.moves.enumerated() {
            guard let move = MoveData.allMoves[moveName] else { continue }

            // Skip moves with no PP
            if i < attacker.movePP.count && attacker.movePP[i] <= 0 {
                continue
            }

            var score: Double

            if move.category == .status {
                // Score status moves
                score = scoreStatusMove(move: move, attacker: attacker, defender: defender)
            } else {
                // Damaging move score: power * STAB * type effectiveness
                let power = Double(max(move.power, 1))
                let typeEff = TypeChart.effectiveness(attackType: move.type, defenderType: defenderType)
                let stab = (move.type == attackerType) ? 1.5 : 1.0

                // Factor in whether the move uses the attacker's better offensive stat
                let statBonus: Double
                if move.category == .physical {
                    let effAtk = Double(attacker.baseStats.attack) * attacker.statStages.attackMultiplier
                    statBonus = effAtk / 100.0
                } else {
                    let effSpAtk = Double(attacker.baseStats.spAttack) * attacker.statStages.spAttackMultiplier
                    statBonus = effSpAtk / 100.0
                }

                score = power * stab * typeEff * statBonus

                // Penalize inaccurate moves slightly
                if move.accuracy > 0 {
                    score *= Double(move.accuracy) / 100.0
                }

                // Penalize recoil moves slightly
                if case .recoil = move.effect {
                    score *= 0.85
                }

                // Bonus for priority moves if defender is low HP (finishing blow)
                if move.priority > 0 && defender.hpFraction < 0.25 {
                    score *= 1.3
                }
            }

            if score > bestScore {
                bestScore = score
                bestIndex = i
            }
        }

        return bestIndex
    }

    /// Score a status move. Returns a value comparable to damaging move scores.
    private static func scoreStatusMove(move: Move, attacker: BattlePokemon, defender: BattlePokemon) -> Double {
        guard let effect = move.effect else {
            return 0.0  // Splash, Transform -- useless
        }

        switch effect {
        case .statBoost(_, let stages, let target):
            if target == .self_ && stages > 0 {
                // Boosting own stats is good early in battle or when healthy
                let healthFactor = attacker.hpFraction > 0.5 ? 1.0 : 0.3
                return 60.0 * Double(stages) * healthFactor
            } else if target == .opponent && stages < 0 {
                return 40.0 * Double(abs(stages))
            }
            return 20.0

        case .multiStatBoost(let changes):
            var totalScore = 0.0
            for change in changes {
                if change.target == .self_ && change.stages > 0 {
                    totalScore += 50.0 * Double(change.stages)
                } else if change.target == .opponent && change.stages < 0 {
                    totalScore += 35.0 * Double(abs(change.stages))
                }
            }
            let healthFactor = attacker.hpFraction > 0.5 ? 1.0 : 0.3
            return totalScore * healthFactor

        case .heal(let fraction):
            // Healing is valuable when HP is low
            let missingHP = 1.0 - attacker.hpFraction
            return 80.0 * fraction * missingHP

        case .sleep:
            // Don't try to put something to sleep if it already has a status
            if defender.status != nil { return 0.0 }
            return 70.0

        case .burn(let chance):
            if defender.status != nil { return 0.0 }
            return 50.0 * Double(chance) / 100.0

        case .paralyze(let chance):
            if defender.status != nil { return 0.0 }
            return 55.0 * Double(chance) / 100.0

        case .poison(let chance):
            if defender.status != nil { return 0.0 }
            return 45.0 * Double(chance) / 100.0

        default:
            return 10.0
        }
    }

    /// Generate an AI team of 3 random Pokemon at levels near the player's average.
    static func generateTeam(playerParty: [PokemonInstance]) -> [BattlePokemon] {
        let avgLevel = playerParty.isEmpty ? 5 : playerParty.map(\.level).reduce(0, +) / playerParty.count
        let targetLevel = max(avgLevel, 3)

        // Pick 3 random unique Pokemon that are not in the player's party
        let playerIds = Set(playerParty.map(\.pokemonId))
        var candidates = PetCollection.allPokemon.map(\.id).filter { !playerIds.contains($0) }
        candidates.shuffle()
        let picks = Array(candidates.prefix(3))

        var team: [BattlePokemon] = []
        for pokemonId in picks {
            // Level varies by +-2 around target
            let level = max(1, targetLevel + Int.random(in: -2...2))
            var instance = PokemonInstance(pokemonId: pokemonId)
            instance.level = level

            // Give moves from learnset up to their level
            if let learnset = MoveData.learnsets[pokemonId] {
                let available = learnset.filter { $0.0 <= level }.map(\.1)
                instance.moves = Array(available.suffix(4))
            }
            // Ensure at least one move
            if instance.moves.isEmpty {
                if let learnset = MoveData.learnsets[pokemonId], let first = learnset.first {
                    instance.moves = [first.1]
                } else {
                    instance.moves = ["Tackle"]
                }
            }

            team.append(BattlePokemon(from: instance))
        }

        return team
    }
}

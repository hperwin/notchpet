import Foundation

enum BattleAI {
    /// Pick the best move index based on type effectiveness against the opponent.
    static func pickMove(attacker: BattlePokemon, defender: BattlePokemon) -> Int {
        guard !attacker.moves.isEmpty else { return 0 }

        let defenderType = MoveData.pokemonTypes[defender.pokemonId] ?? "Normal"
        var bestIndex = 0
        var bestMultiplier = -1.0

        for (i, moveName) in attacker.moves.enumerated() {
            let moveType = MoveData.allMoves[moveName]?.type ?? "Normal"
            let mult = TypeChart.effectiveness(attackType: moveType, defenderType: defenderType)
            if mult > bestMultiplier {
                bestMultiplier = mult
                bestIndex = i
            }
        }

        return bestIndex
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

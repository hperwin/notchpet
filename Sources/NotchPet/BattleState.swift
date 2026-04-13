import Foundation

struct BattlePokemon {
    let pokemonId: String
    let level: Int
    let moves: [String]
    let stats: CalculatedStats
    var currentHP: Int
    var isAlive: Bool { currentHP > 0 }

    init(from instance: PokemonInstance) {
        self.pokemonId = instance.pokemonId
        self.level = instance.level
        self.moves = instance.moves
        let s = PokemonStats.statsAt(pokemonId: instance.pokemonId, level: instance.level)
            ?? CalculatedStats(maxHP: 50, attack: 20, defense: 20, spAttack: 20, spDefense: 20, speed: 20)
        self.stats = s
        self.currentHP = s.maxHP
    }

    var displayName: String {
        PetCollection.entry(for: pokemonId)?.displayName ?? pokemonId.capitalized
    }
}

struct MoveResult {
    let attackerName: String
    let defenderName: String
    let moveName: String
    let damage: Int
    let effectiveness: Effectiveness
    let isCrit: Bool
    let defenderFainted: Bool

    enum Effectiveness: String {
        case superEffective = "It's super effective!"
        case notVeryEffective = "It's not very effective..."
        case immune = "It doesn't affect the opponent..."
        case normal = ""
    }
}

struct BattleState {
    var playerPokemon: BattlePokemon
    var opponentPokemon: BattlePokemon
    var playerTeam: [BattlePokemon]
    var opponentTeam: [BattlePokemon]
    var turnNumber: Int = 0
    var log: [MoveResult] = []
    var isOver: Bool = false
    var winner: BattleWinner?

    enum BattleWinner { case player, opponent }
}

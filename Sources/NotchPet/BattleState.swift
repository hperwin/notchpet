import Foundation

// MARK: - Status Conditions

enum StatusCondition: String, Codable {
    case burn = "BRN"
    case poison = "PSN"
    case toxic = "TOX"
    case paralysis = "PAR"
    case sleep = "SLP"
    case freeze = "FRZ"
}

// MARK: - Stat Stages

struct StatStages {
    var attack: Int = 0      // -6 to +6
    var defense: Int = 0
    var spAttack: Int = 0
    var spDefense: Int = 0
    var speed: Int = 0

    /// Standard stat stage multiplier: +1 = 3/2, +2 = 4/2, -1 = 2/3, etc.
    func multiplier(for stage: Int) -> Double {
        let clamped = min(max(stage, -6), 6)
        if clamped >= 0 {
            return Double(2 + clamped) / 2.0
        } else {
            return 2.0 / Double(2 - clamped)
        }
    }

    var attackMultiplier: Double { multiplier(for: attack) }
    var defenseMultiplier: Double { multiplier(for: defense) }
    var spAttackMultiplier: Double { multiplier(for: spAttack) }
    var spDefenseMultiplier: Double { multiplier(for: spDefense) }
    var speedMultiplier: Double { multiplier(for: speed) }

    mutating func apply(stat: MoveEffect.StatType, stages: Int) {
        switch stat {
        case .attack:    attack    = min(max(attack    + stages, -6), 6)
        case .defense:   defense   = min(max(defense   + stages, -6), 6)
        case .spAttack:  spAttack  = min(max(spAttack  + stages, -6), 6)
        case .spDefense: spDefense = min(max(spDefense + stages, -6), 6)
        case .speed:     speed     = min(max(speed     + stages, -6), 6)
        }
    }
}

// MARK: - BattlePokemon

struct BattlePokemon {
    let pokemonId: String
    let level: Int
    let moves: [String]
    let baseStats: CalculatedStats
    var currentHP: Int
    var maxHP: Int
    var status: StatusCondition?
    var statStages: StatStages
    var movePP: [Int]
    var toxicCounter: Int = 0   // increments each turn for toxic damage
    var sleepTurns: Int = 0     // turns remaining asleep

    var isAlive: Bool { currentHP > 0 }
    var hpFraction: Double { Double(currentHP) / Double(max(maxHP, 1)) }

    init(from instance: PokemonInstance) {
        self.pokemonId = instance.pokemonId
        self.level = instance.level
        self.moves = instance.moves
        let s = PokemonStats.statsAt(pokemonId: instance.pokemonId, level: instance.level)
            ?? CalculatedStats(maxHP: 50, attack: 20, defense: 20, spAttack: 20, spDefense: 20, speed: 20)
        self.baseStats = s
        self.currentHP = s.maxHP
        self.maxHP = s.maxHP
        self.status = nil
        self.statStages = StatStages()
        self.movePP = instance.moves.map { moveName in
            MoveData.allMoves[moveName]?.pp ?? 10
        }
    }

    var displayName: String {
        PetCollection.entry(for: pokemonId)?.displayName ?? pokemonId.capitalized
    }

    /// Effective speed considering stat stages and paralysis
    var effectiveSpeed: Double {
        var spd = Double(baseStats.speed) * statStages.speedMultiplier
        if status == .paralysis { spd *= 0.25 }
        return spd
    }
}

// MARK: - MoveResult

struct MoveResult {
    let attackerName: String
    let defenderName: String
    let moveName: String
    let damage: Int
    let effectiveness: Effectiveness
    let isCrit: Bool
    let isSTAB: Bool
    let defenderFainted: Bool
    let statusInflicted: StatusCondition?
    let statChange: String?
    let message: String?

    enum Effectiveness: String {
        case superEffective = "It's super effective!"
        case notVeryEffective = "It's not very effective..."
        case immune = "It doesn't affect the opponent..."
        case normal = ""
    }
}

// MARK: - Turn Events

enum TurnEvent {
    case moveUsed(attackerName: String, moveName: String)
    case damage(MoveResult)
    case statusDamage(pokemonName: String, status: StatusCondition, damage: Int)
    case statusInflicted(pokemonName: String, status: StatusCondition)
    case statChanged(pokemonName: String, stat: String, stages: Int)
    case fainted(pokemonName: String)
    case cantMove(pokemonName: String, reason: String)
    case switched(trainerName: String, pokemonName: String)
    case battleOver(winner: BattleState.BattleWinner)
    case missed(attackerName: String, moveName: String)
    case healApplied(pokemonName: String, amount: Int)
    case recoilDamage(pokemonName: String, damage: Int)
    case noPP(attackerName: String, moveName: String)
}

// MARK: - BattleState

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

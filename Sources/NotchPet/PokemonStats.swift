import Foundation

struct BaseStats {
    let hp: Int
    let attack: Int
    let defense: Int
    let spAttack: Int
    let spDefense: Int
    let speed: Int
}

enum PokemonStats {
    static let baseStats: [String: BaseStats] = [
        "eevee":     BaseStats(hp: 55, attack: 55, defense: 50, spAttack: 45, spDefense: 65, speed: 55),
        "leafeon":   BaseStats(hp: 65, attack: 110, defense: 130, spAttack: 60, spDefense: 65, speed: 95),
        "vaporeon":  BaseStats(hp: 130, attack: 65, defense: 60, spAttack: 110, spDefense: 95, speed: 65),
        "jolteon":   BaseStats(hp: 65, attack: 65, defense: 60, spAttack: 110, spDefense: 95, speed: 130),
        "flareon":   BaseStats(hp: 65, attack: 130, defense: 60, spAttack: 95, spDefense: 110, speed: 65),
        "espeon":    BaseStats(hp: 65, attack: 65, defense: 60, spAttack: 130, spDefense: 95, speed: 110),
        "umbreon":   BaseStats(hp: 95, attack: 65, defense: 110, spAttack: 60, spDefense: 130, speed: 65),
        "glaceon":   BaseStats(hp: 65, attack: 60, defense: 110, spAttack: 130, spDefense: 95, speed: 65),
        "sylveon":   BaseStats(hp: 95, attack: 65, defense: 65, spAttack: 110, spDefense: 130, speed: 60),
        "pikachu":   BaseStats(hp: 55, attack: 55, defense: 40, spAttack: 50, spDefense: 50, speed: 90),
        "charizard": BaseStats(hp: 78, attack: 84, defense: 78, spAttack: 109, spDefense: 85, speed: 100),
        "blaziken":  BaseStats(hp: 80, attack: 120, defense: 70, spAttack: 110, spDefense: 70, speed: 80),
        "greninja":  BaseStats(hp: 72, attack: 95, defense: 67, spAttack: 103, spDefense: 71, speed: 122),
        "mewtwo":    BaseStats(hp: 106, attack: 110, defense: 90, spAttack: 154, spDefense: 90, speed: 130),
        "mew":       BaseStats(hp: 100, attack: 100, defense: 100, spAttack: 100, spDefense: 100, speed: 100),
        "rayquaza":  BaseStats(hp: 105, attack: 150, defense: 90, spAttack: 150, spDefense: 90, speed: 95),
        "dragonite": BaseStats(hp: 91, attack: 134, defense: 95, spAttack: 100, spDefense: 100, speed: 80),
        "gengar":    BaseStats(hp: 60, attack: 65, defense: 60, spAttack: 130, spDefense: 75, speed: 110),
        "lucario":   BaseStats(hp: 70, attack: 110, defense: 70, spAttack: 115, spDefense: 70, speed: 90),
        "garchomp":  BaseStats(hp: 108, attack: 130, defense: 95, spAttack: 80, spDefense: 85, speed: 102),
        "gyarados":  BaseStats(hp: 95, attack: 125, defense: 79, spAttack: 60, spDefense: 100, speed: 81),
        "arcanine":  BaseStats(hp: 90, attack: 110, defense: 80, spAttack: 100, spDefense: 80, speed: 95),
        "gardevoir": BaseStats(hp: 68, attack: 65, defense: 65, spAttack: 125, spDefense: 115, speed: 80),
        "tyranitar": BaseStats(hp: 100, attack: 134, defense: 110, spAttack: 95, spDefense: 100, speed: 61),
        "salamence": BaseStats(hp: 95, attack: 135, defense: 80, spAttack: 110, spDefense: 80, speed: 100),
        "metagross": BaseStats(hp: 80, attack: 135, defense: 130, spAttack: 95, spDefense: 90, speed: 70),
        "absol":     BaseStats(hp: 65, attack: 130, defense: 60, spAttack: 75, spDefense: 60, speed: 75),
        "luxray":    BaseStats(hp: 80, attack: 120, defense: 79, spAttack: 95, spDefense: 79, speed: 70),
        "snorlax":   BaseStats(hp: 160, attack: 110, defense: 65, spAttack: 65, spDefense: 110, speed: 30),
        "zoroark":   BaseStats(hp: 60, attack: 105, defense: 60, spAttack: 120, spDefense: 60, speed: 105),
    ]

    static func effectiveStat(base: Int, level: Int, isHP: Bool = false) -> Int {
        let core = ((2 * base + 31) * level) / 100
        return isHP ? core + level + 10 : core + 5
    }

    static func statsAt(pokemonId: String, level: Int) -> CalculatedStats? {
        guard let base = baseStats[pokemonId] else { return nil }
        return CalculatedStats(
            maxHP: effectiveStat(base: base.hp, level: level, isHP: true),
            attack: effectiveStat(base: base.attack, level: level),
            defense: effectiveStat(base: base.defense, level: level),
            spAttack: effectiveStat(base: base.spAttack, level: level),
            spDefense: effectiveStat(base: base.spDefense, level: level),
            speed: effectiveStat(base: base.speed, level: level)
        )
    }
}

struct CalculatedStats {
    let maxHP: Int
    let attack: Int
    let defense: Int
    let spAttack: Int
    let spDefense: Int
    let speed: Int
}

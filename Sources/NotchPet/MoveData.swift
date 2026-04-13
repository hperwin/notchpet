import Foundation
import AppKit

struct Move {
    let name: String
    let type: String
    let category: MoveCategory
    let power: Int          // 0 for status moves
    let accuracy: Int       // 1-100, 0 = never miss
    let pp: Int
    let priority: Int       // default 0, Quick Attack = +1, etc.
    let effect: MoveEffect?

    enum MoveCategory: String {
        case physical
        case special
        case status
    }

    init(name: String, type: String, category: MoveCategory, power: Int, accuracy: Int, pp: Int, priority: Int = 0, effect: MoveEffect? = nil) {
        self.name = name
        self.type = type
        self.category = category
        self.power = power
        self.accuracy = accuracy
        self.pp = pp
        self.priority = priority
        self.effect = effect
    }
}

enum MoveEffect {
    case burn(chance: Int)
    case paralyze(chance: Int)
    case poison(chance: Int)
    case flinch(chance: Int)
    case confuse(chance: Int)
    case statBoost(stat: StatType, stages: Int, target: EffectTarget)
    case multiStatBoost(changes: [(stat: StatType, stages: Int, target: EffectTarget)])
    case recoil(fraction: Double)
    case heal(fraction: Double)
    case drain(fraction: Double)   // damage-based healing (e.g. Giga Drain heals 50% of damage dealt)
    case sleep(chance: Int)

    enum StatType: String {
        case attack, defense, spAttack, spDefense, speed
    }
    enum EffectTarget: String {
        case self_, opponent
    }
}

enum MoveData {
    static let allMoves: [String: Move] = [
        // ===== Normal =====
        "Tackle": Move(
            name: "Tackle", type: "Normal", category: .physical,
            power: 40, accuracy: 100, pp: 35
        ),
        "Quick Attack": Move(
            name: "Quick Attack", type: "Normal", category: .physical,
            power: 40, accuracy: 100, pp: 30, priority: 1
        ),
        "Swift": Move(
            name: "Swift", type: "Normal", category: .special,
            power: 60, accuracy: 0, pp: 20  // never misses
        ),
        "Take Down": Move(
            name: "Take Down", type: "Normal", category: .physical,
            power: 90, accuracy: 85, pp: 20,
            effect: .recoil(fraction: 0.25)
        ),
        "Last Resort": Move(
            name: "Last Resort", type: "Normal", category: .physical,
            power: 140, accuracy: 100, pp: 5
        ),
        "Pound": Move(
            name: "Pound", type: "Normal", category: .physical,
            power: 40, accuracy: 100, pp: 35
        ),
        "Scratch": Move(
            name: "Scratch", type: "Normal", category: .physical,
            power: 40, accuracy: 100, pp: 35
        ),
        "Body Slam": Move(
            name: "Body Slam", type: "Normal", category: .physical,
            power: 85, accuracy: 100, pp: 15,
            effect: .paralyze(chance: 30)
        ),
        "Hyper Beam": Move(
            name: "Hyper Beam", type: "Normal", category: .special,
            power: 150, accuracy: 90, pp: 5
        ),
        "Giga Impact": Move(
            name: "Giga Impact", type: "Normal", category: .physical,
            power: 150, accuracy: 90, pp: 5
        ),
        "Extreme Speed": Move(
            name: "Extreme Speed", type: "Normal", category: .physical,
            power: 80, accuracy: 100, pp: 5, priority: 2
        ),
        "Splash": Move(
            name: "Splash", type: "Normal", category: .status,
            power: 0, accuracy: 0, pp: 40
        ),
        "Double Team": Move(
            name: "Double Team", type: "Normal", category: .status,
            power: 0, accuracy: 0, pp: 15,
            effect: .statBoost(stat: .speed, stages: 1, target: .self_)
            // Simplified: original raises evasion, we boost speed instead
        ),
        "Swords Dance": Move(
            name: "Swords Dance", type: "Normal", category: .status,
            power: 0, accuracy: 0, pp: 20,
            effect: .statBoost(stat: .attack, stages: 2, target: .self_)
        ),
        "Transform": Move(
            name: "Transform", type: "Normal", category: .status,
            power: 0, accuracy: 0, pp: 10
            // Simplified: no transform mechanic, acts as wasted turn
        ),

        // ===== Fire =====
        "Ember": Move(
            name: "Ember", type: "Fire", category: .special,
            power: 40, accuracy: 100, pp: 25,
            effect: .burn(chance: 10)
        ),
        "Flamethrower": Move(
            name: "Flamethrower", type: "Fire", category: .special,
            power: 90, accuracy: 100, pp: 15,
            effect: .burn(chance: 10)
        ),
        "Blast Burn": Move(
            name: "Blast Burn", type: "Fire", category: .special,
            power: 150, accuracy: 90, pp: 5,
            effect: .burn(chance: 10)
        ),
        "Blaze Kick": Move(
            name: "Blaze Kick", type: "Fire", category: .physical,
            power: 85, accuracy: 90, pp: 10,
            effect: .burn(chance: 10)
        ),
        "Fire Fang": Move(
            name: "Fire Fang", type: "Fire", category: .physical,
            power: 65, accuracy: 95, pp: 15,
            effect: .burn(chance: 10)
        ),
        "Flare Blitz": Move(
            name: "Flare Blitz", type: "Fire", category: .physical,
            power: 120, accuracy: 100, pp: 15,
            effect: .recoil(fraction: 0.33)
        ),
        "Overheat": Move(
            name: "Overheat", type: "Fire", category: .special,
            power: 130, accuracy: 90, pp: 5,
            effect: .statBoost(stat: .spAttack, stages: -2, target: .self_)
        ),
        "Flame Wheel": Move(
            name: "Flame Wheel", type: "Fire", category: .physical,
            power: 60, accuracy: 100, pp: 25,
            effect: .burn(chance: 10)
        ),
        "Flame Aura": Move(
            // Custom move -- treat as special Fire
            name: "Flame Aura", type: "Fire", category: .special,
            power: 80, accuracy: 100, pp: 10,
            effect: .burn(chance: 20)
        ),

        // ===== Water =====
        "Water Gun": Move(
            name: "Water Gun", type: "Water", category: .special,
            power: 40, accuracy: 100, pp: 25
        ),
        "Water Pulse": Move(
            name: "Water Pulse", type: "Water", category: .special,
            power: 60, accuracy: 100, pp: 20,
            effect: .confuse(chance: 20)
        ),
        "Hydro Pump": Move(
            name: "Hydro Pump", type: "Water", category: .special,
            power: 110, accuracy: 80, pp: 5
        ),
        "Aqua Ring": Move(
            name: "Aqua Ring", type: "Water", category: .status,
            power: 0, accuracy: 0, pp: 20,
            effect: .heal(fraction: 0.125)
            // Simplified: instant 1/8 heal instead of per-turn
        ),
        "Waterfall": Move(
            name: "Waterfall", type: "Water", category: .physical,
            power: 80, accuracy: 100, pp: 15,
            effect: .flinch(chance: 20)
        ),
        "Water Shuriken": Move(
            name: "Water Shuriken", type: "Water", category: .special,
            power: 15, accuracy: 100, pp: 20, priority: 1
            // Simplified: hits once at base power (real game hits 2-5 times)
        ),

        // ===== Grass =====
        "Razor Leaf": Move(
            name: "Razor Leaf", type: "Grass", category: .physical,
            power: 55, accuracy: 95, pp: 25
        ),
        "Giga Drain": Move(
            name: "Giga Drain", type: "Grass", category: .special,
            power: 75, accuracy: 100, pp: 10,
            effect: .drain(fraction: 0.5)
        ),
        "Leaf Blade": Move(
            name: "Leaf Blade", type: "Grass", category: .physical,
            power: 90, accuracy: 100, pp: 15
        ),

        // ===== Electric =====
        "Thunder Shock": Move(
            name: "Thunder Shock", type: "Electric", category: .special,
            power: 40, accuracy: 100, pp: 30,
            effect: .paralyze(chance: 10)
        ),
        "Electro Ball": Move(
            name: "Electro Ball", type: "Electric", category: .special,
            power: 80, accuracy: 100, pp: 10
            // Simplified: fixed power (real game varies by speed ratio)
        ),
        "Thunderbolt": Move(
            name: "Thunderbolt", type: "Electric", category: .special,
            power: 90, accuracy: 100, pp: 15,
            effect: .paralyze(chance: 10)
        ),
        "Volt Tackle": Move(
            name: "Volt Tackle", type: "Electric", category: .physical,
            power: 120, accuracy: 100, pp: 15,
            effect: .recoil(fraction: 0.33)
        ),
        "Discharge": Move(
            name: "Discharge", type: "Electric", category: .special,
            power: 80, accuracy: 100, pp: 15,
            effect: .paralyze(chance: 30)
        ),
        "Thunder": Move(
            name: "Thunder", type: "Electric", category: .special,
            power: 110, accuracy: 70, pp: 10,
            effect: .paralyze(chance: 30)
        ),
        "Volt Switch": Move(
            name: "Volt Switch", type: "Electric", category: .special,
            power: 70, accuracy: 100, pp: 20
        ),
        "Spark": Move(
            name: "Spark", type: "Electric", category: .physical,
            power: 65, accuracy: 100, pp: 20,
            effect: .paralyze(chance: 30)
        ),
        "Thunder Fang": Move(
            name: "Thunder Fang", type: "Electric", category: .physical,
            power: 65, accuracy: 95, pp: 15,
            effect: .paralyze(chance: 10)
        ),
        "Wild Charge": Move(
            name: "Wild Charge", type: "Electric", category: .physical,
            power: 90, accuracy: 100, pp: 15,
            effect: .recoil(fraction: 0.25)
        ),

        // ===== Psychic =====
        "Confusion": Move(
            name: "Confusion", type: "Psychic", category: .special,
            power: 50, accuracy: 100, pp: 25,
            effect: .confuse(chance: 10)
        ),
        "Psychic": Move(
            name: "Psychic", type: "Psychic", category: .special,
            power: 90, accuracy: 100, pp: 10,
            effect: .statBoost(stat: .spDefense, stages: -1, target: .opponent)
        ),
        "Psystrike": Move(
            name: "Psystrike", type: "Psychic", category: .special,
            power: 100, accuracy: 100, pp: 10
            // Note: Psystrike targets Defense, not SpDef. Handled in engine.
        ),
        "Psybeam": Move(
            name: "Psybeam", type: "Psychic", category: .special,
            power: 65, accuracy: 100, pp: 20,
            effect: .confuse(chance: 10)
        ),
        "Future Sight": Move(
            name: "Future Sight", type: "Psychic", category: .special,
            power: 120, accuracy: 100, pp: 10
        ),
        "Psycho Cut": Move(
            name: "Psycho Cut", type: "Psychic", category: .physical,
            power: 70, accuracy: 100, pp: 20
        ),
        "Hypnosis": Move(
            name: "Hypnosis", type: "Psychic", category: .status,
            power: 0, accuracy: 60, pp: 20,
            effect: .sleep(chance: 100)  // if it hits, always puts to sleep
        ),
        "Rest": Move(
            name: "Rest", type: "Psychic", category: .status,
            power: 0, accuracy: 0, pp: 10,
            effect: .heal(fraction: 1.0)
            // Simplified: full heal, inflicts sleep on self handled in engine
        ),

        // ===== Ghost =====
        "Shadow Ball": Move(
            name: "Shadow Ball", type: "Ghost", category: .special,
            power: 80, accuracy: 100, pp: 15,
            effect: .statBoost(stat: .spDefense, stages: -1, target: .opponent)
        ),
        "Lick": Move(
            name: "Lick", type: "Ghost", category: .physical,
            power: 30, accuracy: 100, pp: 30,
            effect: .paralyze(chance: 30)
        ),
        "Dream Eater": Move(
            name: "Dream Eater", type: "Psychic", category: .special,
            power: 100, accuracy: 100, pp: 15,
            effect: .drain(fraction: 0.5)
        ),

        // ===== Fighting =====
        "Aura Sphere": Move(
            name: "Aura Sphere", type: "Fighting", category: .special,
            power: 80, accuracy: 0, pp: 20  // never misses
        ),
        "Double Kick": Move(
            name: "Double Kick", type: "Fighting", category: .physical,
            power: 60, accuracy: 100, pp: 30
            // Simplified: 30*2 = 60 total
        ),
        "Sky Uppercut": Move(
            name: "Sky Uppercut", type: "Fighting", category: .physical,
            power: 85, accuracy: 90, pp: 15
        ),
        "Force Palm": Move(
            name: "Force Palm", type: "Fighting", category: .physical,
            power: 60, accuracy: 100, pp: 10,
            effect: .paralyze(chance: 30)
        ),
        "Close Combat": Move(
            name: "Close Combat", type: "Fighting", category: .physical,
            power: 120, accuracy: 100, pp: 5,
            effect: .multiStatBoost(changes: [
                (stat: .defense, stages: -1, target: .self_),
                (stat: .spDefense, stages: -1, target: .self_),
            ])
        ),

        // ===== Dragon =====
        "Dragon Breath": Move(
            name: "Dragon Breath", type: "Dragon", category: .special,
            power: 60, accuracy: 100, pp: 20,
            effect: .paralyze(chance: 30)
        ),
        "Dragon Claw": Move(
            name: "Dragon Claw", type: "Dragon", category: .physical,
            power: 80, accuracy: 100, pp: 15
        ),
        "Outrage": Move(
            name: "Outrage", type: "Dragon", category: .physical,
            power: 120, accuracy: 100, pp: 10
        ),
        "Dragon Pulse": Move(
            name: "Dragon Pulse", type: "Dragon", category: .special,
            power: 85, accuracy: 100, pp: 10
        ),
        "Draco Meteor": Move(
            name: "Draco Meteor", type: "Dragon", category: .special,
            power: 130, accuracy: 90, pp: 5,
            effect: .statBoost(stat: .spAttack, stages: -2, target: .self_)
        ),
        "Twister": Move(
            name: "Twister", type: "Dragon", category: .special,
            power: 40, accuracy: 100, pp: 20,
            effect: .flinch(chance: 20)
        ),
        "Dragon Dance": Move(
            name: "Dragon Dance", type: "Dragon", category: .status,
            power: 0, accuracy: 0, pp: 20,
            effect: .multiStatBoost(changes: [
                (stat: .attack, stages: 1, target: .self_),
                (stat: .speed, stages: 1, target: .self_),
            ])
        ),

        // ===== Dark =====
        "Pursuit": Move(
            name: "Pursuit", type: "Dark", category: .physical,
            power: 40, accuracy: 100, pp: 20
        ),
        "Faint Attack": Move(
            name: "Faint Attack", type: "Dark", category: .physical,
            power: 60, accuracy: 0, pp: 20  // never misses
        ),
        "Dark Pulse": Move(
            name: "Dark Pulse", type: "Dark", category: .special,
            power: 80, accuracy: 100, pp: 15,
            effect: .flinch(chance: 20)
        ),
        "Bite": Move(
            name: "Bite", type: "Dark", category: .physical,
            power: 60, accuracy: 100, pp: 25,
            effect: .flinch(chance: 30)
        ),
        "Crunch": Move(
            name: "Crunch", type: "Dark", category: .physical,
            power: 80, accuracy: 100, pp: 15,
            effect: .statBoost(stat: .defense, stages: -1, target: .opponent)
        ),
        "Night Slash": Move(
            name: "Night Slash", type: "Dark", category: .physical,
            power: 70, accuracy: 100, pp: 15
        ),
        "Sucker Punch": Move(
            name: "Sucker Punch", type: "Dark", category: .physical,
            power: 70, accuracy: 100, pp: 5, priority: 1
        ),
        "Foul Play": Move(
            name: "Foul Play", type: "Dark", category: .physical,
            power: 95, accuracy: 100, pp: 15
            // Note: uses opponent's Attack stat. Handled in engine.
        ),
        "Night Daze": Move(
            name: "Night Daze", type: "Dark", category: .special,
            power: 85, accuracy: 95, pp: 10,
            effect: .statBoost(stat: .spDefense, stages: -1, target: .opponent)
        ),

        // ===== Fairy =====
        "Fairy Wind": Move(
            name: "Fairy Wind", type: "Fairy", category: .special,
            power: 40, accuracy: 100, pp: 30
        ),
        "Draining Kiss": Move(
            name: "Draining Kiss", type: "Fairy", category: .special,
            power: 50, accuracy: 100, pp: 10,
            effect: .drain(fraction: 0.75)
        ),
        "Moonblast": Move(
            name: "Moonblast", type: "Fairy", category: .special,
            power: 95, accuracy: 100, pp: 15,
            effect: .statBoost(stat: .spAttack, stages: -1, target: .opponent)
        ),
        "Misty Terrain": Move(
            name: "Misty Terrain", type: "Fairy", category: .status,
            power: 0, accuracy: 0, pp: 10,
            effect: .statBoost(stat: .spDefense, stages: 1, target: .self_)
            // Simplified: terrain -> SpDef boost
        ),
        "Moonlight": Move(
            name: "Moonlight", type: "Fairy", category: .status,
            power: 0, accuracy: 0, pp: 5,
            effect: .heal(fraction: 0.5)
        ),

        // ===== Ice =====
        "Icy Wind": Move(
            name: "Icy Wind", type: "Ice", category: .special,
            power: 55, accuracy: 95, pp: 15,
            effect: .statBoost(stat: .speed, stages: -1, target: .opponent)
        ),
        "Ice Shard": Move(
            name: "Ice Shard", type: "Ice", category: .physical,
            power: 40, accuracy: 100, pp: 30, priority: 1
        ),
        "Ice Beam": Move(
            name: "Ice Beam", type: "Ice", category: .special,
            power: 90, accuracy: 100, pp: 10,
            effect: .burn(chance: 10) // freeze simplified as burn for now
        ),
        "Blizzard": Move(
            name: "Blizzard", type: "Ice", category: .special,
            power: 110, accuracy: 70, pp: 5,
            effect: .burn(chance: 10)
        ),

        // ===== Flying =====
        "Wing Attack": Move(
            name: "Wing Attack", type: "Flying", category: .physical,
            power: 60, accuracy: 100, pp: 35
        ),
        "Air Slash": Move(
            name: "Air Slash", type: "Flying", category: .special,
            power: 75, accuracy: 95, pp: 15,
            effect: .flinch(chance: 30)
        ),
        "Brave Bird": Move(
            name: "Brave Bird", type: "Flying", category: .physical,
            power: 120, accuracy: 100, pp: 15,
            effect: .recoil(fraction: 0.33)
        ),
        "Fly": Move(
            name: "Fly", type: "Flying", category: .physical,
            power: 90, accuracy: 95, pp: 15
            // Simplified: single-turn
        ),

        // ===== Poison =====
        "Sludge Bomb": Move(
            name: "Sludge Bomb", type: "Poison", category: .special,
            power: 90, accuracy: 100, pp: 10,
            effect: .poison(chance: 30)
        ),

        // ===== Rock =====
        "Rock Throw": Move(
            name: "Rock Throw", type: "Rock", category: .physical,
            power: 50, accuracy: 90, pp: 15
        ),
        "Stone Edge": Move(
            name: "Stone Edge", type: "Rock", category: .physical,
            power: 100, accuracy: 80, pp: 5
        ),
        "Ancient Power": Move(
            name: "Ancient Power", type: "Rock", category: .special,
            power: 60, accuracy: 100, pp: 5,
            effect: .multiStatBoost(changes: [
                (stat: .attack, stages: 1, target: .self_),
                (stat: .defense, stages: 1, target: .self_),
                (stat: .spAttack, stages: 1, target: .self_),
                (stat: .spDefense, stages: 1, target: .self_),
                (stat: .speed, stages: 1, target: .self_),
            ])
            // 10% chance for all stats +1; engine rolls once for the whole set
        ),

        // ===== Ground =====
        "Sand Attack": Move(
            name: "Sand Attack", type: "Ground", category: .status,
            power: 0, accuracy: 100, pp: 15,
            effect: .statBoost(stat: .speed, stages: -1, target: .opponent)
            // Simplified: evasion -> speed debuff
        ),
        "Earthquake": Move(
            name: "Earthquake", type: "Ground", category: .physical,
            power: 100, accuracy: 100, pp: 10
        ),

        // ===== Steel =====
        "Metal Claw": Move(
            name: "Metal Claw", type: "Steel", category: .physical,
            power: 50, accuracy: 95, pp: 35,
            effect: .statBoost(stat: .attack, stages: 1, target: .self_)
        ),
        "Meteor Mash": Move(
            name: "Meteor Mash", type: "Steel", category: .physical,
            power: 90, accuracy: 90, pp: 10,
            effect: .statBoost(stat: .attack, stages: 1, target: .self_)
        ),
    ]

    /// pokemonId -> [(level, moveName)] -- moves learned at each level
    static let learnsets: [String: [(Int, String)]] = [
        "leafeon": [(1, "Razor Leaf"), (5, "Quick Attack"), (10, "Giga Drain"), (15, "Leaf Blade"), (20, "Swords Dance")],
        "eevee": [(1, "Tackle"), (5, "Quick Attack"), (10, "Swift"), (15, "Take Down"), (20, "Last Resort")],
        "pikachu": [(1, "Thunder Shock"), (5, "Quick Attack"), (10, "Electro Ball"), (15, "Thunderbolt"), (20, "Volt Tackle")],
        "charizard": [(1, "Ember"), (5, "Dragon Breath"), (10, "Flamethrower"), (15, "Air Slash"), (20, "Blast Burn")],
        "mewtwo": [(1, "Confusion"), (5, "Psychic"), (10, "Shadow Ball"), (15, "Aura Sphere"), (20, "Psystrike")],
        "blaziken": [(1, "Ember"), (5, "Double Kick"), (10, "Blaze Kick"), (15, "Sky Uppercut"), (20, "Brave Bird")],
        "dragonite": [(1, "Dragon Breath"), (5, "Wing Attack"), (10, "Dragon Claw"), (15, "Outrage"), (20, "Hyper Beam")],
        "vaporeon": [(1, "Water Gun"), (5, "Quick Attack"), (10, "Water Pulse"), (15, "Aqua Ring"), (20, "Hydro Pump")],
        "jolteon": [(1, "Thunder Shock"), (5, "Quick Attack"), (10, "Discharge"), (15, "Thunder"), (20, "Volt Switch")],
        "flareon": [(1, "Ember"), (5, "Quick Attack"), (10, "Fire Fang"), (15, "Flare Blitz"), (20, "Overheat")],
        "espeon": [(1, "Confusion"), (5, "Quick Attack"), (10, "Psybeam"), (15, "Psychic"), (20, "Future Sight")],
        "umbreon": [(1, "Tackle"), (5, "Pursuit"), (10, "Faint Attack"), (15, "Dark Pulse"), (20, "Moonlight")],
        "glaceon": [(1, "Icy Wind"), (5, "Quick Attack"), (10, "Ice Shard"), (15, "Ice Beam"), (20, "Blizzard")],
        "sylveon": [(1, "Fairy Wind"), (5, "Quick Attack"), (10, "Draining Kiss"), (15, "Moonblast"), (20, "Misty Terrain")],
        "gengar": [(1, "Lick"), (5, "Hypnosis"), (10, "Shadow Ball"), (15, "Sludge Bomb"), (20, "Dream Eater")],
        "lucario": [(1, "Force Palm"), (5, "Quick Attack"), (10, "Aura Sphere"), (15, "Close Combat"), (20, "Extreme Speed")],
        "garchomp": [(1, "Dragon Breath"), (5, "Sand Attack"), (10, "Dragon Claw"), (15, "Earthquake"), (20, "Draco Meteor")],
        "rayquaza": [(1, "Twister"), (5, "Dragon Breath"), (10, "Air Slash"), (15, "Dragon Pulse"), (20, "Outrage")],
        "gyarados": [(1, "Splash"), (5, "Bite"), (10, "Waterfall"), (15, "Dragon Dance"), (20, "Hyper Beam")],
        "arcanine": [(1, "Ember"), (5, "Bite"), (10, "Flame Wheel"), (15, "Flamethrower"), (20, "Extreme Speed")],
        "gardevoir": [(1, "Confusion"), (5, "Double Team"), (10, "Psychic"), (15, "Moonblast"), (20, "Hypnosis")],
        "tyranitar": [(1, "Bite"), (5, "Rock Throw"), (10, "Crunch"), (15, "Stone Edge"), (20, "Earthquake")],
        "salamence": [(1, "Ember"), (5, "Dragon Breath"), (10, "Fly"), (15, "Dragon Claw"), (20, "Draco Meteor")],
        "metagross": [(1, "Metal Claw"), (5, "Confusion"), (10, "Meteor Mash"), (15, "Psychic"), (20, "Hyper Beam")],
        "absol": [(1, "Scratch"), (5, "Pursuit"), (10, "Night Slash"), (15, "Psycho Cut"), (20, "Sucker Punch")],
        "luxray": [(1, "Tackle"), (5, "Spark"), (10, "Bite"), (15, "Thunder Fang"), (20, "Wild Charge")],
        "greninja": [(1, "Water Gun"), (5, "Quick Attack"), (10, "Water Shuriken"), (15, "Dark Pulse"), (20, "Hydro Pump")],
        "snorlax": [(1, "Tackle"), (5, "Rest"), (10, "Body Slam"), (15, "Crunch"), (20, "Giga Impact")],
        "mew": [(1, "Pound"), (5, "Transform"), (10, "Psychic"), (15, "Aura Sphere"), (20, "Ancient Power")],
        "zoroark": [(1, "Scratch"), (5, "Pursuit"), (10, "Night Slash"), (15, "Foul Play"), (20, "Night Daze")],
    ]

    /// Primary type for each Pokemon -- determines environment background and STAB
    static let pokemonTypes: [String: String] = [
        "leafeon": "Grass", "eevee": "Normal", "pikachu": "Electric",
        "charizard": "Fire", "mewtwo": "Psychic", "blaziken": "Fire",
        "dragonite": "Dragon", "vaporeon": "Water", "jolteon": "Electric",
        "flareon": "Fire", "espeon": "Psychic", "umbreon": "Dark",
        "glaceon": "Ice", "sylveon": "Fairy", "gengar": "Ghost",
        "lucario": "Fighting", "garchomp": "Dragon", "rayquaza": "Dragon",
        "gyarados": "Water", "arcanine": "Fire", "gardevoir": "Psychic",
        "tyranitar": "Rock", "salamence": "Dragon", "metagross": "Steel",
        "absol": "Dark", "luxray": "Electric", "greninja": "Water",
        "snorlax": "Normal", "mew": "Psychic", "zoroark": "Dark",
    ]

    /// Load the environment background image for a Pokemon's type
    static func environmentImage(for pokemonId: String) -> NSImage? {
        guard let type = pokemonTypes[pokemonId] else { return nil }
        let fileName = type.lowercased()
        guard let url = Bundle.module.url(forResource: "environments", withExtension: nil) else { return nil }
        let imageURL = url.appendingPathComponent("\(fileName).png")
        return NSImage(contentsOf: imageURL)
    }
}

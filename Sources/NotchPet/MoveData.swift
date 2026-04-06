import Foundation

struct Move {
    let name: String
    let type: String  // "Normal", "Fire", "Water", "Grass", "Electric", etc.
}

enum MoveData {
    static let allMoves: [String: Move] = [
        // Normal
        "Tackle": Move(name: "Tackle", type: "Normal"),
        "Quick Attack": Move(name: "Quick Attack", type: "Normal"),
        "Swift": Move(name: "Swift", type: "Normal"),
        "Take Down": Move(name: "Take Down", type: "Normal"),
        "Last Resort": Move(name: "Last Resort", type: "Normal"),
        "Pound": Move(name: "Pound", type: "Normal"),
        "Scratch": Move(name: "Scratch", type: "Normal"),
        "Body Slam": Move(name: "Body Slam", type: "Normal"),
        "Hyper Beam": Move(name: "Hyper Beam", type: "Normal"),
        "Giga Impact": Move(name: "Giga Impact", type: "Normal"),
        "Extreme Speed": Move(name: "Extreme Speed", type: "Normal"),
        "Splash": Move(name: "Splash", type: "Normal"),
        "Double Team": Move(name: "Double Team", type: "Normal"),
        "Swords Dance": Move(name: "Swords Dance", type: "Normal"),
        "Transform": Move(name: "Transform", type: "Normal"),
        // Fire
        "Ember": Move(name: "Ember", type: "Fire"),
        "Flamethrower": Move(name: "Flamethrower", type: "Fire"),
        "Blast Burn": Move(name: "Blast Burn", type: "Fire"),
        "Blaze Kick": Move(name: "Blaze Kick", type: "Fire"),
        "Fire Fang": Move(name: "Fire Fang", type: "Fire"),
        "Flare Blitz": Move(name: "Flare Blitz", type: "Fire"),
        "Overheat": Move(name: "Overheat", type: "Fire"),
        "Flame Wheel": Move(name: "Flame Wheel", type: "Fire"),
        "Flame Aura": Move(name: "Flame Aura", type: "Fire"),
        // Water
        "Water Gun": Move(name: "Water Gun", type: "Water"),
        "Water Pulse": Move(name: "Water Pulse", type: "Water"),
        "Hydro Pump": Move(name: "Hydro Pump", type: "Water"),
        "Aqua Ring": Move(name: "Aqua Ring", type: "Water"),
        "Waterfall": Move(name: "Waterfall", type: "Water"),
        "Water Shuriken": Move(name: "Water Shuriken", type: "Water"),
        // Grass
        "Razor Leaf": Move(name: "Razor Leaf", type: "Grass"),
        "Giga Drain": Move(name: "Giga Drain", type: "Grass"),
        "Leaf Blade": Move(name: "Leaf Blade", type: "Grass"),
        // Electric
        "Thunder Shock": Move(name: "Thunder Shock", type: "Electric"),
        "Electro Ball": Move(name: "Electro Ball", type: "Electric"),
        "Thunderbolt": Move(name: "Thunderbolt", type: "Electric"),
        "Volt Tackle": Move(name: "Volt Tackle", type: "Electric"),
        "Discharge": Move(name: "Discharge", type: "Electric"),
        "Thunder": Move(name: "Thunder", type: "Electric"),
        "Volt Switch": Move(name: "Volt Switch", type: "Electric"),
        "Spark": Move(name: "Spark", type: "Electric"),
        "Thunder Fang": Move(name: "Thunder Fang", type: "Electric"),
        "Wild Charge": Move(name: "Wild Charge", type: "Electric"),
        // Psychic
        "Confusion": Move(name: "Confusion", type: "Psychic"),
        "Psychic": Move(name: "Psychic", type: "Psychic"),
        "Shadow Ball": Move(name: "Shadow Ball", type: "Ghost"),
        "Psystrike": Move(name: "Psystrike", type: "Psychic"),
        "Psybeam": Move(name: "Psybeam", type: "Psychic"),
        "Future Sight": Move(name: "Future Sight", type: "Psychic"),
        "Psycho Cut": Move(name: "Psycho Cut", type: "Psychic"),
        "Hypnosis": Move(name: "Hypnosis", type: "Psychic"),
        // Fighting
        "Aura Sphere": Move(name: "Aura Sphere", type: "Fighting"),
        "Double Kick": Move(name: "Double Kick", type: "Fighting"),
        "Sky Uppercut": Move(name: "Sky Uppercut", type: "Fighting"),
        "Force Palm": Move(name: "Force Palm", type: "Fighting"),
        "Close Combat": Move(name: "Close Combat", type: "Fighting"),
        // Dragon
        "Dragon Breath": Move(name: "Dragon Breath", type: "Dragon"),
        "Dragon Claw": Move(name: "Dragon Claw", type: "Dragon"),
        "Outrage": Move(name: "Outrage", type: "Dragon"),
        "Dragon Pulse": Move(name: "Dragon Pulse", type: "Dragon"),
        "Draco Meteor": Move(name: "Draco Meteor", type: "Dragon"),
        "Twister": Move(name: "Twister", type: "Dragon"),
        "Dragon Dance": Move(name: "Dragon Dance", type: "Dragon"),
        // Dark
        "Pursuit": Move(name: "Pursuit", type: "Dark"),
        "Faint Attack": Move(name: "Faint Attack", type: "Dark"),
        "Dark Pulse": Move(name: "Dark Pulse", type: "Dark"),
        "Bite": Move(name: "Bite", type: "Dark"),
        "Crunch": Move(name: "Crunch", type: "Dark"),
        "Night Slash": Move(name: "Night Slash", type: "Dark"),
        "Sucker Punch": Move(name: "Sucker Punch", type: "Dark"),
        "Foul Play": Move(name: "Foul Play", type: "Dark"),
        "Night Daze": Move(name: "Night Daze", type: "Dark"),
        // Ghost
        "Lick": Move(name: "Lick", type: "Ghost"),
        "Dream Eater": Move(name: "Dream Eater", type: "Psychic"),
        // Fairy
        "Fairy Wind": Move(name: "Fairy Wind", type: "Fairy"),
        "Draining Kiss": Move(name: "Draining Kiss", type: "Fairy"),
        "Moonblast": Move(name: "Moonblast", type: "Fairy"),
        "Misty Terrain": Move(name: "Misty Terrain", type: "Fairy"),
        "Moonlight": Move(name: "Moonlight", type: "Fairy"),
        // Ice
        "Icy Wind": Move(name: "Icy Wind", type: "Ice"),
        "Ice Shard": Move(name: "Ice Shard", type: "Ice"),
        "Ice Beam": Move(name: "Ice Beam", type: "Ice"),
        "Blizzard": Move(name: "Blizzard", type: "Ice"),
        // Flying
        "Wing Attack": Move(name: "Wing Attack", type: "Flying"),
        "Air Slash": Move(name: "Air Slash", type: "Flying"),
        "Brave Bird": Move(name: "Brave Bird", type: "Flying"),
        "Fly": Move(name: "Fly", type: "Flying"),
        // Poison
        "Sludge Bomb": Move(name: "Sludge Bomb", type: "Poison"),
        // Rock
        "Rock Throw": Move(name: "Rock Throw", type: "Rock"),
        "Stone Edge": Move(name: "Stone Edge", type: "Rock"),
        "Ancient Power": Move(name: "Ancient Power", type: "Rock"),
        // Ground
        "Sand Attack": Move(name: "Sand Attack", type: "Ground"),
        "Earthquake": Move(name: "Earthquake", type: "Ground"),
        // Steel
        "Metal Claw": Move(name: "Metal Claw", type: "Steel"),
        "Meteor Mash": Move(name: "Meteor Mash", type: "Steel"),
        // Rest
        "Rest": Move(name: "Rest", type: "Psychic"),
    ]

    /// pokemonId -> [(level, moveName)] — moves learned at each level
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
}

import AppKit

// MARK: - Pokemon Entry

struct PokemonEntry {
    let id: String
    let displayName: String
    let unlockLevel: Int
    let hasShiny: Bool
}

// MARK: - Pet Collection

final class PetCollection {

    static let allPokemon: [PokemonEntry] = [
        PokemonEntry(id: "leafeon", displayName: "Leafeon", unlockLevel: 1, hasShiny: true),
        PokemonEntry(id: "eevee", displayName: "Eevee", unlockLevel: 3, hasShiny: true),
        PokemonEntry(id: "pikachu", displayName: "Pikachu", unlockLevel: 5, hasShiny: true),
        PokemonEntry(id: "flareon", displayName: "Flareon", unlockLevel: 8, hasShiny: true),
        PokemonEntry(id: "vaporeon", displayName: "Vaporeon", unlockLevel: 8, hasShiny: true),
        PokemonEntry(id: "jolteon", displayName: "Jolteon", unlockLevel: 8, hasShiny: true),
        PokemonEntry(id: "arcanine", displayName: "Arcanine", unlockLevel: 10, hasShiny: true),
        PokemonEntry(id: "snorlax", displayName: "Snorlax", unlockLevel: 10, hasShiny: true),
        PokemonEntry(id: "espeon", displayName: "Espeon", unlockLevel: 13, hasShiny: true),
        PokemonEntry(id: "umbreon", displayName: "Umbreon", unlockLevel: 13, hasShiny: true),
        PokemonEntry(id: "gengar", displayName: "Gengar", unlockLevel: 13, hasShiny: true),
        PokemonEntry(id: "absol", displayName: "Absol", unlockLevel: 16, hasShiny: true),
        PokemonEntry(id: "luxray", displayName: "Luxray", unlockLevel: 16, hasShiny: true),
        PokemonEntry(id: "glaceon", displayName: "Glaceon", unlockLevel: 20, hasShiny: true),
        PokemonEntry(id: "sylveon", displayName: "Sylveon", unlockLevel: 20, hasShiny: true),
        PokemonEntry(id: "gardevoir", displayName: "Gardevoir", unlockLevel: 20, hasShiny: true),
        PokemonEntry(id: "lucario", displayName: "Lucario", unlockLevel: 25, hasShiny: true),
        PokemonEntry(id: "greninja", displayName: "Greninja", unlockLevel: 25, hasShiny: true),
        PokemonEntry(id: "zoroark", displayName: "Zoroark", unlockLevel: 25, hasShiny: true),
        PokemonEntry(id: "dragonite", displayName: "Dragonite", unlockLevel: 30, hasShiny: true),
        PokemonEntry(id: "garchomp", displayName: "Garchomp", unlockLevel: 30, hasShiny: true),
        PokemonEntry(id: "tyranitar", displayName: "Tyranitar", unlockLevel: 30, hasShiny: true),
        PokemonEntry(id: "salamence", displayName: "Salamence", unlockLevel: 35, hasShiny: true),
        PokemonEntry(id: "metagross", displayName: "Metagross", unlockLevel: 35, hasShiny: true),
        PokemonEntry(id: "gyarados", displayName: "Gyarados", unlockLevel: 35, hasShiny: true),
        PokemonEntry(id: "blaziken", displayName: "Blaziken", unlockLevel: 40, hasShiny: true),
        PokemonEntry(id: "rayquaza", displayName: "Rayquaza", unlockLevel: 40, hasShiny: true),
        PokemonEntry(id: "mew", displayName: "Mew", unlockLevel: 45, hasShiny: true),
        PokemonEntry(id: "mewtwo", displayName: "Mewtwo", unlockLevel: 50, hasShiny: true),
        PokemonEntry(id: "charizard", displayName: "Charizard", unlockLevel: 50, hasShiny: true),
    ]

    /// Returns only the pokemon unlocked at the given level.
    static func unlockedPets(for level: Int) -> [PokemonEntry] {
        allPokemon.filter { $0.unlockLevel <= level }
    }

    /// Loads the sprite image for a pokemon from the bundle's pokemon resource directory.
    static func spriteImage(for id: String, shiny: Bool = false) -> NSImage? {
        guard let pokemonDir = Bundle.module.url(forResource: "pokemon", withExtension: nil) else {
            return nil
        }
        let filename = shiny ? "\(id)_shiny.png" : "\(id).png"
        let fileURL = pokemonDir.appendingPathComponent(filename)
        return NSImage(contentsOf: fileURL)
    }

    /// Returns the full catalog with unlock status for each entry.
    static func catalog(for level: Int) -> [(entry: PokemonEntry, unlocked: Bool)] {
        allPokemon.map { entry in
            (entry: entry, unlocked: entry.unlockLevel <= level)
        }
    }
}

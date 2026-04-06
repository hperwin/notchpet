import AppKit

// MARK: - Pokemon Entry

struct PokemonEntry {
    let id: String
    let displayName: String
    let hasShiny: Bool
}

// MARK: - Pet Collection

final class PetCollection {

    static let allPokemon: [PokemonEntry] = [
        PokemonEntry(id: "leafeon", displayName: "Leafeon", hasShiny: true),
        PokemonEntry(id: "eevee", displayName: "Eevee", hasShiny: true),
        PokemonEntry(id: "pikachu", displayName: "Pikachu", hasShiny: true),
        PokemonEntry(id: "flareon", displayName: "Flareon", hasShiny: true),
        PokemonEntry(id: "vaporeon", displayName: "Vaporeon", hasShiny: true),
        PokemonEntry(id: "jolteon", displayName: "Jolteon", hasShiny: true),
        PokemonEntry(id: "arcanine", displayName: "Arcanine", hasShiny: true),
        PokemonEntry(id: "snorlax", displayName: "Snorlax", hasShiny: true),
        PokemonEntry(id: "espeon", displayName: "Espeon", hasShiny: true),
        PokemonEntry(id: "umbreon", displayName: "Umbreon", hasShiny: true),
        PokemonEntry(id: "gengar", displayName: "Gengar", hasShiny: true),
        PokemonEntry(id: "absol", displayName: "Absol", hasShiny: true),
        PokemonEntry(id: "luxray", displayName: "Luxray", hasShiny: true),
        PokemonEntry(id: "glaceon", displayName: "Glaceon", hasShiny: true),
        PokemonEntry(id: "sylveon", displayName: "Sylveon", hasShiny: true),
        PokemonEntry(id: "gardevoir", displayName: "Gardevoir", hasShiny: true),
        PokemonEntry(id: "lucario", displayName: "Lucario", hasShiny: true),
        PokemonEntry(id: "greninja", displayName: "Greninja", hasShiny: true),
        PokemonEntry(id: "zoroark", displayName: "Zoroark", hasShiny: true),
        PokemonEntry(id: "dragonite", displayName: "Dragonite", hasShiny: true),
        PokemonEntry(id: "garchomp", displayName: "Garchomp", hasShiny: true),
        PokemonEntry(id: "tyranitar", displayName: "Tyranitar", hasShiny: true),
        PokemonEntry(id: "salamence", displayName: "Salamence", hasShiny: true),
        PokemonEntry(id: "metagross", displayName: "Metagross", hasShiny: true),
        PokemonEntry(id: "gyarados", displayName: "Gyarados", hasShiny: true),
        PokemonEntry(id: "blaziken", displayName: "Blaziken", hasShiny: true),
        PokemonEntry(id: "rayquaza", displayName: "Rayquaza", hasShiny: true),
        PokemonEntry(id: "mew", displayName: "Mew", hasShiny: true),
        PokemonEntry(id: "mewtwo", displayName: "Mewtwo", hasShiny: true),
        PokemonEntry(id: "charizard", displayName: "Charizard", hasShiny: true),
    ]

    /// Look up a single entry by ID.
    static func entry(for id: String) -> PokemonEntry? {
        allPokemon.first { $0.id == id }
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
}

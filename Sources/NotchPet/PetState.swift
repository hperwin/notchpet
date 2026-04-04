import Foundation

// MARK: - Evolution Stages

enum EvolutionStage: Int, Codable, CaseIterable {
    case egg = 0
    case hatchling = 1
    case juvenile = 2
    case adult = 3
    case evolved = 4

    var name: String {
        switch self {
        case .egg: return "Egg"
        case .hatchling: return "Hatchling"
        case .juvenile: return "Juvenile"
        case .adult: return "Adult"
        case .evolved: return "Evolved"
        }
    }

    var levelThreshold: Int {
        switch self {
        case .egg: return 0
        case .hatchling: return 5
        case .juvenile: return 15
        case .adult: return 30
        case .evolved: return 50
        }
    }

    /// Scale factor for the pet sprite at each stage
    var spriteScale: CGFloat {
        switch self {
        case .egg: return 0.6
        case .hatchling: return 0.75
        case .juvenile: return 0.9
        case .adult: return 1.0
        case .evolved: return 1.15
        }
    }

    /// Glow color at each stage (nil = no glow)
    var glowColor: (r: CGFloat, g: CGFloat, b: CGFloat)? {
        switch self {
        case .egg, .hatchling: return nil
        case .juvenile: return (0.3, 0.7, 1.0)     // light blue
        case .adult: return (0.5, 0.3, 1.0)         // purple
        case .evolved: return (1.0, 0.85, 0.0)      // gold
        }
    }
}

// MARK: - Achievement

struct Achievement: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let tier: Tier
    let xpReward: Int
    var unlocked: Bool = false
    var unlockedDate: Date?

    enum Tier: Int, Codable, CaseIterable {
        case common = 0
        case rare = 1
        case legendary = 2

        var name: String {
            switch self {
            case .common: return "Common"
            case .rare: return "Rare"
            case .legendary: return "Legendary"
            }
        }

        var color: (r: CGFloat, g: CGFloat, b: CGFloat) {
            switch self {
            case .common: return (0.6, 0.6, 0.6)
            case .rare: return (0.3, 0.5, 1.0)
            case .legendary: return (1.0, 0.85, 0.0)
            }
        }
    }
}

// MARK: - Cosmetic

struct Cosmetic: Codable, Identifiable {
    let id: String
    let name: String
    let rarity: Rarity
    var owned: Bool = false

    enum Rarity: Int, Codable, CaseIterable {
        case common = 0
        case rare = 1
        case legendary = 2

        var name: String {
            switch self {
            case .common: return "Common"
            case .rare: return "Rare"
            case .legendary: return "Legendary"
            }
        }

        var dropRate: Double {
            switch self {
            case .common: return 0.70
            case .rare: return 0.25
            case .legendary: return 0.05
            }
        }
    }
}

// MARK: - Weekly Challenge

struct WeeklyChallenge: Codable {
    let id: String
    let description: String
    let targetValue: Int
    var currentValue: Int = 0
    let xpReward: Int
    let cosmeticReward: String?
    let startDate: Date
    let endDate: Date

    var isComplete: Bool { currentValue >= targetValue }
    var progress: Double { min(Double(currentValue) / Double(targetValue), 1.0) }
}

// MARK: - Pet State (persisted)

final class PetState: Codable {
    // XP & Level
    var xp: Int = 0
    var level: Int = 1
    var totalXPEarned: Int = 0

    // Evolution
    var evolutionStage: EvolutionStage = .egg

    // Typing stats
    var totalKeysTyped: Int = 0
    var totalWordsTyped: Int = 0
    var sessionKeysTyped: Int = 0
    var currentWPM: Double = 0

    // Streaks
    var typingStreak: Int = 0       // consecutive typing days
    var longestTypingStreak: Int = 0
    var loginStreak: Int = 0        // consecutive launch days
    var longestLoginStreak: Int = 0
    var lastTypingDate: String?     // yyyy-MM-dd
    var lastLoginDate: String?      // yyyy-MM-dd

    // Prestige
    var prestigeCount: Int = 0
    var permanentXPMultiplier: Double = 1.0

    // Cosmetics
    var cosmetics: [Cosmetic] = []
    var activeCosmetic: String?     // cosmetic id

    // Achievements
    var achievements: [Achievement] = []

    // Rest / Fatigue
    var restXP: Int = 0             // accumulated while idle, max 480 (8hrs × 1/min)
    var lastActiveTime: Date?
    var sessionActiveMinutes: Int = 0

    // Pet selection
    var selectedPet: String = "leafeon"  // pokemon id
    var party: [String] = ["leafeon"]   // up to 6 pokemon ids for menu bar party strip
    var useShiny: Bool = false
    var unlockedShinies: [String] = []   // pokemon ids with shiny unlocked
    var foodEaten: Int = 0

    // Mutation
    var mutationColor: String?      // hex color, nil = normal

    // Weekly challenge
    var weeklyChallenge: WeeklyChallenge?

    // MARK: - Persistence

    private static let storageKey = "notchpet.petState"

    static func load() -> PetState {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let state = try? JSONDecoder().decode(PetState.self, from: data)
        else {
            let fresh = PetState()
            fresh.initializeDefaults()
            return fresh
        }
        // Ensure all achievements/cosmetics exist
        state.ensureAllAchievements()
        state.ensureAllCosmetics()
        return state
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: PetState.storageKey)
        }
    }

    func initializeDefaults() {
        ensureAllAchievements()
        ensureAllCosmetics()
    }

    // MARK: - XP Curve

    /// XP required to reach the given level. Exponential: 100 × 1.15^(level-1)
    static func xpForLevel(_ level: Int) -> Int {
        Int(100.0 * pow(1.15, Double(level - 1)))
    }

    /// XP needed to go from current level to next
    var xpToNextLevel: Int {
        PetState.xpForLevel(level + 1)
    }

    /// Progress 0.0 → 1.0 toward next level
    var levelProgress: Double {
        let needed = xpToNextLevel
        return needed > 0 ? min(Double(xp) / Double(needed), 1.0) : 0
    }

    // MARK: - Streak multiplier

    var streakMultiplier: Double {
        switch typingStreak {
        case 0...2: return 1.0
        case 3...6: return 1.2
        case 7...13: return 1.5
        case 14...: return 2.0
        default: return 1.0
        }
    }

    // MARK: - Fatigue multiplier

    var fatigueMultiplier: Double {
        if sessionActiveMinutes < 120 { return 1.0 }
        return 0.8 // -20% after 2 hours
    }

    // MARK: - Total XP multiplier

    var totalMultiplier: Double {
        permanentXPMultiplier * streakMultiplier * fatigueMultiplier
    }

    // MARK: - Built-in achievements

    func ensureAllAchievements() {
        let builtIn: [Achievement] = [
            // Common
            Achievement(id: "first_words", name: "First Words", description: "Type 100 words", tier: .common, xpReward: 50),
            Achievement(id: "chatterbox", name: "Chatterbox", description: "Type 1,000 words", tier: .common, xpReward: 100),
            Achievement(id: "level5", name: "Growing Up", description: "Reach level 5", tier: .common, xpReward: 75),
            Achievement(id: "streak3", name: "Three's a Charm", description: "3-day typing streak", tier: .common, xpReward: 100),
            Achievement(id: "hatchling", name: "It's Alive!", description: "Evolve to Hatchling", tier: .common, xpReward: 150),
            // Rare
            Achievement(id: "novelist", name: "Novelist", description: "Type 10,000 words", tier: .rare, xpReward: 500),
            Achievement(id: "streak7", name: "Week Warrior", description: "7-day typing streak", tier: .rare, xpReward: 300),
            Achievement(id: "level20", name: "Dedicated", description: "Reach level 20", tier: .rare, xpReward: 400),
            Achievement(id: "speed_demon", name: "Speed Demon", description: "Reach 80 WPM", tier: .rare, xpReward: 250),
            Achievement(id: "adult", name: "All Grown Up", description: "Evolve to Adult", tier: .rare, xpReward: 500),
            Achievement(id: "cosmetic5", name: "Fashionista", description: "Collect 5 cosmetics", tier: .rare, xpReward: 300),
            // Legendary
            Achievement(id: "author", name: "Author", description: "Type 100,000 words", tier: .legendary, xpReward: 2000),
            Achievement(id: "streak30", name: "Unstoppable", description: "30-day typing streak", tier: .legendary, xpReward: 1000),
            Achievement(id: "evolved", name: "Final Form", description: "Reach Evolved stage", tier: .legendary, xpReward: 1500),
            Achievement(id: "prestige3", name: "Reborn", description: "Prestige 3 times", tier: .legendary, xpReward: 2000),
            Achievement(id: "mutation", name: "Rare Specimen", description: "Get a mutation", tier: .legendary, xpReward: 1000),
        ]

        for builtin in builtIn {
            if !achievements.contains(where: { $0.id == builtin.id }) {
                achievements.append(builtin)
            }
        }
    }

    // MARK: - Built-in cosmetics

    func ensureAllCosmetics() {
        let builtIn: [Cosmetic] = [
            // Common (70% drop)
            Cosmetic(id: "sparkle_trail", name: "Sparkle Trail", rarity: .common),
            Cosmetic(id: "blush_pink", name: "Blush Pink", rarity: .common),
            Cosmetic(id: "ocean_blue", name: "Ocean Blue", rarity: .common),
            Cosmetic(id: "forest_green", name: "Forest Green", rarity: .common),
            Cosmetic(id: "sunset_orange", name: "Sunset Orange", rarity: .common),
            Cosmetic(id: "tiny_hat", name: "Tiny Hat", rarity: .common),
            Cosmetic(id: "bow_tie", name: "Bow Tie", rarity: .common),
            // Rare (25% drop)
            Cosmetic(id: "rainbow_trail", name: "Rainbow Trail", rarity: .rare),
            Cosmetic(id: "galaxy_skin", name: "Galaxy Skin", rarity: .rare),
            Cosmetic(id: "flame_aura", name: "Flame Aura", rarity: .rare),
            Cosmetic(id: "crown", name: "Crown", rarity: .rare),
            Cosmetic(id: "wizard_hat", name: "Wizard Hat", rarity: .rare),
            // Legendary (5% drop)
            Cosmetic(id: "golden_glow", name: "Golden Glow", rarity: .legendary),
            Cosmetic(id: "void_skin", name: "Void Skin", rarity: .legendary),
            Cosmetic(id: "holographic", name: "Holographic", rarity: .legendary),
        ]

        for builtin in builtIn {
            if !cosmetics.contains(where: { $0.id == builtin.id }) {
                cosmetics.append(builtin)
            }
        }
    }
}

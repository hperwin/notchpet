import Foundation

final class GameSystems {
    let state: PetState
    var onEvent: ((GameEvent) -> Void)?

    private var tickCount: Int = 0
    private var keypressSinceLastSave: Int = 0

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let mutationColors: [String] = [
        "#FF6B6B", "#6BCB77", "#4D96FF", "#FFD93D",
        "#C77DFF", "#FF922B", "#20C997", "#F06595",
        "#845EF7", "#22B8CF", "#FCC419", "#FF6B6B",
        "#51CF66", "#339AF0", "#E64980", "#5C7CFA",
    ]

    enum GameEvent {
        case levelUp(Int)
        case evolved(EvolutionStage)
        case achievementUnlocked(Achievement)
        case prestigeComplete(Int)
        case cosmeticRolled(Cosmetic)
        case mutationOccurred(String)
        case challengeComplete(WeeklyChallenge)
        case streakUpdate(Int)
    }

    init(state: PetState) {
        self.state = state
    }

    // MARK: - Public API

    func recordKeypress() {
        state.totalKeysTyped += 1
        state.sessionKeysTyped += 1

        // Every 5th keypress earns 1 base XP
        if state.totalKeysTyped % 5 == 0 {
            let baseXP = 1
            let gained = Int(Double(baseXP) * state.totalMultiplier)
            state.xp += max(gained, 1)
            state.totalXPEarned += max(gained, 1)
        }

        // Drain rest XP (1 per keypress while pool lasts)
        if state.restXP > 0 {
            state.restXP -= 1
            state.xp += 1
            state.totalXPEarned += 1
        }

        updateTypingStreak()
        checkLevelUp()
        checkAchievements()

        keypressSinceLastSave += 1
        if keypressSinceLastSave >= 50 {
            keypressSinceLastSave = 0
            state.save()
        }
    }

    func recordWord() {
        state.totalWordsTyped += 1

        // Update weekly challenge if word-based
        if var challenge = state.weeklyChallenge,
           !challenge.isComplete,
           challenge.id.hasPrefix("words_") {
            challenge.currentValue += 1
            state.weeklyChallenge = challenge
            if challenge.isComplete {
                state.xp += challenge.xpReward
                state.totalXPEarned += challenge.xpReward
                onEvent?(.challengeComplete(challenge))
            }
        }

        checkAchievements()
    }

    func processAppLaunch() {
        // Calculate rest XP from idle time
        if let lastActive = state.lastActiveTime {
            let minutesIdle = Int(Date().timeIntervalSince(lastActive) / 60.0)
            let restGain = min(minutesIdle, 480) // cap at 8 hours
            state.restXP = min(state.restXP + restGain, 480)
        }

        // Update login streak
        let today = Self.dateFormatter.string(from: Date())
        if let lastLogin = state.lastLoginDate {
            let yesterday = Self.yesterdayString()
            if lastLogin == yesterday {
                state.loginStreak += 1
            } else if lastLogin != today {
                state.loginStreak = 1
            }
        } else {
            state.loginStreak = 1
        }
        state.lastLoginDate = today
        if state.loginStreak > state.longestLoginStreak {
            state.longestLoginStreak = state.loginStreak
        }

        refreshWeeklyChallenge()
        checkAchievements()
        state.save()
    }

    func tick() {
        state.sessionActiveMinutes += 1
        state.lastActiveTime = Date()

        tickCount += 1
        if tickCount % 5 == 0 {
            state.save()
        }
    }

    func prestige() -> Bool {
        guard state.level >= 20 else { return false }

        // Reset progress
        state.xp = 0
        state.level = 1
        state.evolutionStage = .egg
        state.sessionKeysTyped = 0
        state.sessionActiveMinutes = 0

        // Keep: totalKeysTyped, totalWordsTyped, achievements, cosmetics, streaks
        state.prestigeCount += 1
        state.permanentXPMultiplier += 0.05

        let rolled = rollCosmetic()
        _ = rolled // cosmetic event fired inside rollCosmetic

        onEvent?(.prestigeComplete(state.prestigeCount))
        state.save()
        return true
    }

    @discardableResult
    func rollCosmetic() -> Cosmetic? {
        let roll = Double.random(in: 0..<1)
        let targetRarity: Cosmetic.Rarity
        if roll < 0.70 {
            targetRarity = .common
        } else if roll < 0.95 {
            targetRarity = .rare
        } else {
            targetRarity = .legendary
        }

        // Try target rarity, then escalate
        let rarities: [Cosmetic.Rarity] = {
            switch targetRarity {
            case .common: return [.common, .rare, .legendary]
            case .rare: return [.rare, .legendary, .common]
            case .legendary: return [.legendary, .rare, .common]
            }
        }()

        for rarity in rarities {
            let unowned = state.cosmetics.enumerated().filter { !$0.element.owned && $0.element.rarity == rarity }
            if let pick = unowned.randomElement() {
                state.cosmetics[pick.offset].owned = true
                let cosmetic = state.cosmetics[pick.offset]
                state.save()
                onEvent?(.cosmeticRolled(cosmetic))
                return cosmetic
            }
        }

        return nil // all cosmetics owned
    }

    func refreshWeeklyChallenge() {
        let now = Date()

        if let existing = state.weeklyChallenge, existing.endDate > now {
            return // still active
        }

        // Generate a new challenge
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 7, to: now)!

        struct ChallengeTemplate {
            let idPrefix: String
            let description: String
            let target: Int
            let xpReward: Int
        }

        let templates: [ChallengeTemplate] = [
            ChallengeTemplate(idPrefix: "words_", description: "Type 5,000 words", target: 5000, xpReward: 300),
            ChallengeTemplate(idPrefix: "streak_", description: "Maintain a 5-day streak", target: 5, xpReward: 250),
            ChallengeTemplate(idPrefix: "keys_", description: "Type 50,000 keys", target: 50000, xpReward: 350),
            ChallengeTemplate(idPrefix: "level_", description: "Gain 3 levels", target: 3, xpReward: 400),
        ]

        let template = templates.randomElement()!
        let uniqueID = "\(template.idPrefix)\(Int(now.timeIntervalSince1970))"

        // 50% chance of cosmetic reward
        var cosmeticReward: String?
        if Bool.random() {
            let unowned = state.cosmetics.filter { !$0.owned }
            cosmeticReward = unowned.randomElement()?.id
        }

        state.weeklyChallenge = WeeklyChallenge(
            id: uniqueID,
            description: template.description,
            targetValue: template.target,
            currentValue: 0,
            xpReward: template.xpReward,
            cosmeticReward: cosmeticReward,
            startDate: now,
            endDate: endDate
        )
    }

    func checkMutation() {
        guard state.mutationColor == nil else { return }

        // 2% chance when called
        guard Double.random(in: 0..<1) < 0.02 else { return }

        let color = Self.mutationColors.randomElement()!
        state.mutationColor = color
        onEvent?(.mutationOccurred(color))
        state.save()
    }

    /// Called externally after XP is added directly (e.g., from feeding)
    func checkAfterXPGain() {
        checkLevelUp()
        checkAchievements()
    }

    // MARK: - Private

    private func checkLevelUp() {
        while state.xp >= state.xpToNextLevel {
            state.xp -= state.xpToNextLevel
            state.level += 1
            onEvent?(.levelUp(state.level))
        }

        // Check evolution
        let newStage = resolveEvolutionStage()
        if newStage != state.evolutionStage {
            state.evolutionStage = newStage
            onEvent?(.evolved(newStage))
        }
    }

    private func resolveEvolutionStage() -> EvolutionStage {
        // Walk stages in reverse to find highest matching
        for stage in EvolutionStage.allCases.reversed() {
            if state.level >= stage.levelThreshold {
                return stage
            }
        }
        return .egg
    }

    private func checkAchievements() {
        for i in state.achievements.indices {
            guard !state.achievements[i].unlocked else { continue }

            let met: Bool
            switch state.achievements[i].id {
            case "first_words":  met = state.totalWordsTyped >= 100
            case "chatterbox":   met = state.totalWordsTyped >= 1000
            case "novelist":     met = state.totalWordsTyped >= 10000
            case "author":       met = state.totalWordsTyped >= 100000
            case "level5":       met = state.level >= 5
            case "level20":      met = state.level >= 20
            case "streak3":      met = state.typingStreak >= 3
            case "streak7":      met = state.typingStreak >= 7
            case "streak30":     met = state.typingStreak >= 30
            case "hatchling":    met = state.evolutionStage.rawValue >= EvolutionStage.hatchling.rawValue
            case "adult":        met = state.evolutionStage.rawValue >= EvolutionStage.adult.rawValue
            case "evolved":      met = state.evolutionStage.rawValue >= EvolutionStage.evolved.rawValue
            case "speed_demon":  met = state.currentWPM >= 80
            case "cosmetic5":    met = state.cosmetics.filter(\.owned).count >= 5
            case "prestige3":    met = state.prestigeCount >= 3
            case "mutation":     met = state.mutationColor != nil
            default:             met = false
            }

            if met {
                state.achievements[i].unlocked = true
                state.achievements[i].unlockedDate = Date()
                state.xp += state.achievements[i].xpReward
                state.totalXPEarned += state.achievements[i].xpReward
                onEvent?(.achievementUnlocked(state.achievements[i]))
            }
        }
    }

    private func updateTypingStreak() {
        let today = Self.dateFormatter.string(from: Date())
        guard state.lastTypingDate != today else { return }

        let yesterday = Self.yesterdayString()
        if state.lastTypingDate == yesterday {
            state.typingStreak += 1
        } else if state.lastTypingDate == nil {
            state.typingStreak = 1
        } else {
            state.typingStreak = 1
        }

        state.lastTypingDate = today

        if state.typingStreak > state.longestTypingStreak {
            state.longestTypingStreak = state.typingStreak
        }

        onEvent?(.streakUpdate(state.typingStreak))
    }

    private static func yesterdayString() -> String {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        return dateFormatter.string(from: yesterday)
    }
}

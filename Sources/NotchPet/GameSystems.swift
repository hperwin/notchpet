import Foundation
import AppKit

final class GameSystems {
    let state: PetState
    var onEvent: ((GameEvent) -> Void)?

    private var tickCount: Int = 0
    private var keypressSinceLastSave: Int = 0

    // Combo tracking (session-only, not persisted)
    private(set) var comboStage: ComboStage = .none
    private var comboStartTime: Date?
    private var lastComboKeypressTime: Date?
    private static let comboTimeout: TimeInterval = 60

    // App tier tracking
    private(set) var activeAppTier: AppTier = .normal
    private var pollTimer: Timer?

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
        case achievementUnlocked(Achievement)
        case cosmeticRolled(Cosmetic)
        case mutationOccurred(String)
        case challengeComplete(WeeklyChallenge)
        case streakUpdate(Int)
        case comboChanged(ComboStage)
        case appTierChanged(AppTier)
    }

    enum ComboStage: Comparable {
        case none, warm, focused, deep, flow

        var multiplier: Double {
            switch self {
            case .none: return 1.0
            case .warm: return 1.5
            case .focused: return 2.0
            case .deep: return 3.0
            case .flow: return 4.0
            }
        }

        var label: String? {
            switch self {
            case .none: return nil
            case .warm: return "x1.5"
            case .focused: return "x2"
            case .deep: return "x3"
            case .flow: return "x4"
            }
        }
    }

    init(state: PetState) {
        self.state = state
    }

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.pollTick()
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollTick() {
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            let newTier = state.appTier(for: bundleID)
            if newTier != activeAppTier {
                activeAppTier = newTier
                onEvent?(.appTierChanged(newTier))
            }
        }

        if let lastKeypress = lastComboKeypressTime {
            if Date().timeIntervalSince(lastKeypress) > Self.comboTimeout {
                resetCombo()
            } else {
                updateComboStage()
            }
        }
    }

    private func updateComboStage() {
        guard let start = comboStartTime else { return }
        let elapsed = Date().timeIntervalSince(start)
        let newStage: ComboStage
        if elapsed >= 600 {        // 10 min
            newStage = .flow
        } else if elapsed >= 300 {  // 5 min
            newStage = .deep
        } else if elapsed >= 120 {  // 2 min
            newStage = .focused
        } else if elapsed >= 30 {   // 30 sec
            newStage = .warm
        } else {
            newStage = .none
        }

        if newStage != comboStage {
            comboStage = newStage
            onEvent?(.comboChanged(newStage))
        }
    }

    private func resetCombo() {
        guard comboStage != .none || comboStartTime != nil else { return }
        comboStartTime = nil
        lastComboKeypressTime = nil
        if comboStage != .none {
            comboStage = .none
            onEvent?(.comboChanged(.none))
        }
    }

    // MARK: - Public API

    func recordKeypress() {
        state.totalKeysTyped += 1
        state.sessionKeysTyped += 1

        // Feed combo timer
        let now = Date()
        if comboStartTime == nil {
            comboStartTime = now
        }
        lastComboKeypressTime = now

        // Every 25th keypress = XP to lead, every 75th = XP to rest of party
        // Lead levels ~3x faster than party members
        if state.totalKeysTyped % 25 == 0 {
            let appMult = activeAppTier.multiplier
            let comboMult = comboStage.multiplier
            let baseGain = max(Int(1.0 * state.streakMultiplier * state.fatigueMultiplier * appMult * comboMult), 0)
            if baseGain > 0 {
                for (i, pokemonId) in state.party.enumerated() {
                    guard var instance = state.pokemonInstances[pokemonId] else { continue }
                    if i == 0 {
                        let leveledUp = instance.addXP(baseGain)
                        state.pokemonInstances[pokemonId] = instance
                        if leveledUp { onEvent?(.levelUp(instance.level)) }
                    } else if state.totalKeysTyped % 75 == 0 {
                        let leveledUp = instance.addXP(baseGain)
                        state.pokemonInstances[pokemonId] = instance
                        if leveledUp { onEvent?(.levelUp(instance.level)) }
                    }
                }
            }
        }

        // Drain rest XP (1 per keypress while pool lasts) — to lead pokemon
        if state.restXP > 0 {
            state.restXP -= 1
            if let leadId = state.party.first, var instance = state.pokemonInstances[leadId] {
                let leveledUp = instance.addXP(1)
                state.pokemonInstances[leadId] = instance
                if leveledUp { onEvent?(.levelUp(instance.level)) }
            }
        }

        updateTypingStreak()
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
        checkAchievements()
    }

    // MARK: - Private

    private func checkAchievements() {
        for i in state.achievements.indices {
            guard !state.achievements[i].unlocked else { continue }

            let met: Bool
            switch state.achievements[i].id {
            case "first_words":  met = state.totalWordsTyped >= 100
            case "chatterbox":   met = state.totalWordsTyped >= 1000
            case "novelist":     met = state.totalWordsTyped >= 10000
            case "author":       met = state.totalWordsTyped >= 100000
            case "level5":       met = state.highestLevel >= 5
            case "level20":      met = state.highestLevel >= 20
            case "streak3":      met = state.typingStreak >= 3
            case "streak7":      met = state.typingStreak >= 7
            case "streak30":     met = state.typingStreak >= 30
            case "hatchling":    met = state.highestLevel >= 5
            case "adult":        met = state.highestLevel >= 30
            case "evolved":      met = state.highestLevel >= 50
            case "speed_demon":  met = state.currentWPM >= 80
            case "cosmetic5":    met = state.cosmetics.filter(\.owned).count >= 5
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

# NotchPet Multiplayer Battles + App Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add turn-based Pokemon battles (local AI first, then multiplayer via Supabase) and a toggle to hide/show the app from the menu bar.

**Architecture:** Battle engine is a pure-logic layer (`BattleEngine`) with no UI dependencies, making it testable and reusable for both AI and multiplayer. Supabase Realtime channels handle battle state sync between two players. Stats are added to PokemonInstance via migration. A new BattleTabView renders the battle UI inside the existing PanelWindow. The app toggle is a simple Preferences flag that hides/shows all menu bar windows.

**Tech Stack:** Swift 5.9, macOS 14+, Supabase Swift SDK (supabase-swift via SPM), Supabase Realtime for WebSocket battle sync, Supabase Database for matchmaking/leaderboards, existing AppKit UI framework.

---

## Scope Breakdown

This plan is split into **3 independent sub-projects** that build on each other:

1. **Sub-Project A: App Hide/Show Toggle** (standalone, ~30 min)
2. **Sub-Project B: Local Battle Engine + AI** (standalone, ~3-4 hours)
3. **Sub-Project C: Supabase Multiplayer** (requires Sub-Project B, ~3-4 hours)

Each sub-project produces working, testable software on its own.

---

## File Structure

### Sub-Project A: App Toggle
```
Sources/NotchPet/
  Preferences.swift          (modify) — add isAppHidden preference
  AppDelegate.swift           (modify) — add hide/show logic
  PetInteraction.swift        (modify) — add toggle to right-click menu
```

### Sub-Project B: Local Battle Engine
```
Sources/NotchPet/
  PetState.swift              (modify) — add base stats to PokemonInstance
  PokemonStats.swift          (create) — base stat definitions for all 30 Pokemon
  BattleEngine.swift          (create) — pure-logic turn-based battle simulation
  TypeChart.swift             (create) — type effectiveness matrix
  BattleState.swift           (create) — battle state model (HP, status, turns)
  BattleAI.swift              (create) — simple AI opponent logic
  BattleTabView.swift         (create) — battle UI in PanelWindow
  BattleAnimations.swift      (create) — move animations and effects
  PanelWindow.swift           (modify) — add Battle tab, wire up battle flow
  DSTabView.swift             (modify) — add battle-related TabActions
  AppDelegate.swift           (modify) — wire battle tab
  Resources/
    battle_bg.png             (create) — battle background image
```

### Sub-Project C: Supabase Multiplayer
```
Sources/NotchPet/
  SupabaseManager.swift       (create) — Supabase client, auth, realtime
  MatchmakingManager.swift    (create) — find opponents, create battle rooms
  MultiplayerBattle.swift     (create) — sync BattleEngine state via Supabase Realtime
  PlayerProfile.swift         (create) — ELO rating, win/loss record
  BattleTabView.swift         (modify) — add matchmaking UI, online battle flow
  PanelWindow.swift           (modify) — wire multiplayer actions
  Package.swift               (modify) — add supabase-swift dependency
```

### Supabase Schema (SQL)
```
supabase/
  migrations/
    001_create_players.sql    (create) — players table with ELO
    002_create_battles.sql    (create) — battle rooms + state
    003_create_matchmaking.sql (create) — matchmaking queue
```

---

# SUB-PROJECT A: App Hide/Show Toggle

### Task A1: Add Hide/Show Preference and Menu Item

**Files:**
- Modify: `Sources/NotchPet/Preferences.swift`
- Modify: `Sources/NotchPet/PetInteraction.swift`
- Modify: `Sources/NotchPet/AppDelegate.swift`

- [ ] **Step 1: Add isAppHidden preference**

In `Sources/NotchPet/Preferences.swift`, add a new key and property:

```swift
// In enum Keys:
static let appHidden = "notchpet.appHidden"

// New property:
var isAppHidden: Bool {
    get { defaults.bool(forKey: Keys.appHidden) }
    set { defaults.set(newValue, forKey: Keys.appHidden) }
}
```

- [ ] **Step 2: Add hide/show methods to AppDelegate**

In `Sources/NotchPet/AppDelegate.swift`, add two methods:

```swift
// MARK: - App Visibility

func hideApp() {
    Preferences.shared.isAppHidden = true
    partyStrip.hide()
    petWindow.orderOut(nil)
    foodSpawner.stop()
    panelWindow.orderOut(nil) // close panel if open
    if panelWindow.isOpen { panelWindow.isOpen = false }
}

func showApp() {
    Preferences.shared.isAppHidden = false
    partyStrip.show()
    updatePartyStrip()
    if Preferences.shared.berriesEnabled {
        foodSpawner.start()
    }
}
```

Also in `finishLaunching()`, after `partyStrip.show()`, add:

```swift
// Respect hidden state on launch
if Preferences.shared.isAppHidden {
    partyStrip.hide()
} else {
    partyStrip.show()
}
```

(Remove the existing unconditional `partyStrip.show()` call.)

- [ ] **Step 3: Add toggle to right-click menu**

In `Sources/NotchPet/PetInteraction.swift`, find `buildContextMenu()`. Add a "Hide Pets" item before the Quit item:

```swift
// Before the separator + Quit section:
menu.addItem(.separator())

let hideItem = NSMenuItem(
    title: Preferences.shared.isAppHidden ? "Show Pets" : "Hide Pets",
    action: #selector(toggleAppVisibility(_:)),
    keyEquivalent: "h"
)
hideItem.target = self
menu.addItem(hideItem)
```

Add the action method:

```swift
@objc private func toggleAppVisibility(_ sender: NSMenuItem) {
    if Preferences.shared.isAppHidden {
        // Need to reach AppDelegate - use notification
        NotificationCenter.default.post(name: .init("notchpet.showApp"), object: nil)
    } else {
        NotificationCenter.default.post(name: .init("notchpet.hideApp"), object: nil)
    }
}
```

In AppDelegate, observe these notifications (add in `finishLaunching`):

```swift
NotificationCenter.default.addObserver(forName: .init("notchpet.hideApp"), object: nil, queue: .main) { [weak self] _ in
    self?.hideApp()
}
NotificationCenter.default.addObserver(forName: .init("notchpet.showApp"), object: nil, queue: .main) { [weak self] _ in
    self?.showApp()
}
```

**Note:** When hidden, the user can still right-click the notch area (PetWindow stays active but invisible) or use the menu bar status item to show the app again. Alternatively, we could add a small NSStatusItem (menu bar icon) that's always visible for toggling.

- [ ] **Step 4: Add a persistent status bar icon for toggling when hidden**

Since hiding the party strip removes all visible UI, add a small NSStatusItem (system tray icon) so the user can always toggle visibility:

In `AppDelegate.swift`, add:

```swift
private var statusItem: NSStatusItem?

// In finishLaunching(), add:
statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
if let button = statusItem?.button {
    button.title = "NP"
    button.font = NSFont.boldSystemFont(ofSize: 10)
    button.action = #selector(statusItemClicked)
    button.target = self
}

@objc private func statusItemClicked() {
    if Preferences.shared.isAppHidden {
        showApp()
    } else {
        hideApp()
    }
}
```

- [ ] **Step 5: Build and test**

```bash
cd ~/Developer/NotchPet && swift build
```

Test: Right-click pet → "Hide Pets" → all pets disappear. Click "NP" in menu bar → pets reappear. Quit and relaunch → respects hidden state.

- [ ] **Step 6: Commit**

```bash
git add Sources/NotchPet/Preferences.swift Sources/NotchPet/PetInteraction.swift Sources/NotchPet/AppDelegate.swift
git commit -m "feat: add hide/show toggle for app visibility"
```

---

# SUB-PROJECT B: Local Battle Engine + AI

### Task B1: Add Base Stats to Pokemon

**Files:**
- Create: `Sources/NotchPet/PokemonStats.swift`
- Modify: `Sources/NotchPet/PetState.swift`

- [ ] **Step 1: Create PokemonStats.swift with base stats for all 30 Pokemon**

Create `Sources/NotchPet/PokemonStats.swift`:

```swift
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
    /// Base stats for all 30 Pokemon. Values scaled for our game (not exact game values,
    /// but preserving relative strengths). Range: 40-130.
    static let baseStats: [String: BaseStats] = [
        // Eeveelutions
        "eevee":     BaseStats(hp: 55, attack: 55, defense: 50, spAttack: 45, spDefense: 65, speed: 55),
        "leafeon":   BaseStats(hp: 65, attack: 110, defense: 130, spAttack: 60, spDefense: 65, speed: 95),
        "vaporeon":  BaseStats(hp: 130, attack: 65, defense: 60, spAttack: 110, spDefense: 95, speed: 65),
        "jolteon":   BaseStats(hp: 65, attack: 65, defense: 60, spAttack: 110, spDefense: 95, speed: 130),
        "flareon":   BaseStats(hp: 65, attack: 130, defense: 60, spAttack: 95, spDefense: 110, speed: 65),
        "espeon":    BaseStats(hp: 65, attack: 65, defense: 60, spAttack: 130, spDefense: 95, speed: 110),
        "umbreon":   BaseStats(hp: 95, attack: 65, defense: 110, spAttack: 60, spDefense: 130, speed: 65),
        "glaceon":   BaseStats(hp: 65, attack: 60, defense: 110, spAttack: 130, spDefense: 95, speed: 65),
        "sylveon":   BaseStats(hp: 95, attack: 65, defense: 65, spAttack: 110, spDefense: 130, speed: 60),
        // Starters & Legends
        "pikachu":   BaseStats(hp: 55, attack: 55, defense: 40, spAttack: 50, spDefense: 50, speed: 90),
        "charizard": BaseStats(hp: 78, attack: 84, defense: 78, spAttack: 109, spDefense: 85, speed: 100),
        "blaziken":  BaseStats(hp: 80, attack: 120, defense: 70, spAttack: 110, spDefense: 70, speed: 80),
        "greninja":  BaseStats(hp: 72, attack: 95, defense: 67, spAttack: 103, spDefense: 71, speed: 122),
        "mewtwo":    BaseStats(hp: 106, attack: 110, defense: 90, spAttack: 154, spDefense: 90, speed: 130),
        "mew":       BaseStats(hp: 100, attack: 100, defense: 100, spAttack: 100, spDefense: 100, speed: 100),
        "rayquaza":  BaseStats(hp: 105, attack: 150, defense: 90, spAttack: 150, spDefense: 90, speed: 95),
        "dragonite": BaseStats(hp: 91, attack: 134, defense: 95, spAttack: 100, spDefense: 100, speed: 80),
        // Popular picks
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

    /// Calculate effective stat at a given level.
    /// Formula: ((2 * base + 31) * level / 100) + 5
    /// HP uses: ((2 * base + 31) * level / 100) + level + 10
    static func effectiveStat(base: Int, level: Int, isHP: Bool = false) -> Int {
        let core = ((2 * base + 31) * level) / 100
        return isHP ? core + level + 10 : core + 5
    }

    /// Get full calculated stats for a Pokemon at a given level.
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
```

- [ ] **Step 2: Build to verify**

```bash
cd ~/Developer/NotchPet && swift build
```

- [ ] **Step 3: Commit**

```bash
git add Sources/NotchPet/PokemonStats.swift
git commit -m "feat: add base stats for all 30 Pokemon"
```

---

### Task B2: Create Type Effectiveness Chart

**Files:**
- Create: `Sources/NotchPet/TypeChart.swift`

- [ ] **Step 1: Create TypeChart.swift**

Create `Sources/NotchPet/TypeChart.swift`:

```swift
import Foundation

enum TypeChart {
    /// Returns the type effectiveness multiplier.
    /// 2.0 = super effective, 0.5 = not very effective, 0.0 = immune, 1.0 = normal
    static func effectiveness(attackType: String, defenderType: String) -> Double {
        // Key: (attack, defense) → multiplier
        // Only storing non-1.0 matchups for brevity
        let chart: [String: [String: Double]] = [
            "Fire": ["Grass": 2, "Ice": 2, "Bug": 2, "Steel": 2,
                     "Water": 0.5, "Rock": 0.5, "Fire": 0.5, "Dragon": 0.5],
            "Water": ["Fire": 2, "Ground": 2, "Rock": 2,
                      "Water": 0.5, "Grass": 0.5, "Dragon": 0.5],
            "Grass": ["Water": 2, "Ground": 2, "Rock": 2,
                      "Fire": 0.5, "Grass": 0.5, "Poison": 0.5, "Flying": 0.5,
                      "Bug": 0.5, "Dragon": 0.5, "Steel": 0.5],
            "Electric": ["Water": 2, "Flying": 2,
                         "Grass": 0.5, "Electric": 0.5, "Dragon": 0.5,
                         "Ground": 0],
            "Psychic": ["Fighting": 2, "Poison": 2,
                        "Psychic": 0.5, "Steel": 0.5, "Dark": 0],
            "Fighting": ["Normal": 2, "Ice": 2, "Rock": 2, "Dark": 2, "Steel": 2,
                         "Poison": 0.5, "Flying": 0.5, "Psychic": 0.5, "Bug": 0.5,
                         "Fairy": 0.5, "Ghost": 0],
            "Dragon": ["Dragon": 2, "Fairy": 0],
            "Dark": ["Psychic": 2, "Ghost": 2,
                     "Fighting": 0.5, "Dark": 0.5, "Fairy": 0.5],
            "Ghost": ["Psychic": 2, "Ghost": 2,
                      "Dark": 0.5, "Normal": 0],
            "Fairy": ["Fighting": 2, "Dragon": 2, "Dark": 2,
                      "Fire": 0.5, "Poison": 0.5, "Steel": 0.5],
            "Ice": ["Grass": 2, "Ground": 2, "Flying": 2, "Dragon": 2,
                    "Fire": 0.5, "Water": 0.5, "Ice": 0.5, "Steel": 0.5],
            "Flying": ["Grass": 2, "Fighting": 2, "Bug": 2,
                       "Electric": 0.5, "Rock": 0.5, "Steel": 0.5],
            "Normal": ["Ghost": 0, "Rock": 0.5, "Steel": 0.5],
            "Poison": ["Grass": 2, "Fairy": 2,
                       "Poison": 0.5, "Ground": 0.5, "Rock": 0.5, "Ghost": 0.5,
                       "Steel": 0],
            "Ground": ["Fire": 2, "Electric": 2, "Poison": 2, "Rock": 2, "Steel": 2,
                       "Grass": 0.5, "Bug": 0.5, "Flying": 0],
            "Rock": ["Fire": 2, "Ice": 2, "Flying": 2, "Bug": 2,
                     "Fighting": 0.5, "Ground": 0.5, "Steel": 0.5],
            "Steel": ["Ice": 2, "Rock": 2, "Fairy": 2,
                      "Fire": 0.5, "Water": 0.5, "Electric": 0.5, "Steel": 0.5],
            "Bug": ["Grass": 2, "Psychic": 2, "Dark": 2,
                    "Fire": 0.5, "Fighting": 0.5, "Poison": 0.5, "Flying": 0.5,
                    "Ghost": 0.5, "Steel": 0.5, "Fairy": 0.5],
        ]

        return chart[attackType]?[defenderType] ?? 1.0
    }
}
```

- [ ] **Step 2: Build and commit**

```bash
cd ~/Developer/NotchPet && swift build
git add Sources/NotchPet/TypeChart.swift
git commit -m "feat: add type effectiveness chart"
```

---

### Task B3: Create Battle State Model

**Files:**
- Create: `Sources/NotchPet/BattleState.swift`

- [ ] **Step 1: Create BattleState.swift**

Create `Sources/NotchPet/BattleState.swift`:

```swift
import Foundation

/// Represents one Pokemon's state during a battle
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
        let calcStats = PokemonStats.statsAt(pokemonId: instance.pokemonId, level: instance.level)
            ?? CalculatedStats(maxHP: 50, attack: 20, defense: 20, spAttack: 20, spDefense: 20, speed: 20)
        self.stats = calcStats
        self.currentHP = calcStats.maxHP
    }
}

/// The result of executing one move
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

/// Full state of an ongoing battle
struct BattleState {
    var playerPokemon: BattlePokemon
    var opponentPokemon: BattlePokemon
    var playerTeam: [BattlePokemon]     // full team (including active)
    var opponentTeam: [BattlePokemon]   // full team (including active)
    var turnNumber: Int = 0
    var log: [MoveResult] = []
    var isOver: Bool = false
    var winner: BattleWinner?

    enum BattleWinner {
        case player
        case opponent
    }
}
```

- [ ] **Step 2: Build and commit**

```bash
cd ~/Developer/NotchPet && swift build
git add Sources/NotchPet/BattleState.swift
git commit -m "feat: add battle state model"
```

---

### Task B4: Create Battle Engine (Core Logic)

**Files:**
- Create: `Sources/NotchPet/BattleEngine.swift`

- [ ] **Step 1: Create BattleEngine.swift**

Create `Sources/NotchPet/BattleEngine.swift`:

```swift
import Foundation

final class BattleEngine {
    private(set) var state: BattleState
    var onMoveExecuted: ((MoveResult) -> Void)?
    var onBattleOver: ((BattleState.BattleWinner) -> Void)?
    var onSwitchNeeded: (() -> Void)?  // called when active Pokemon faints

    init(playerTeam: [PokemonInstance], opponentTeam: [PokemonInstance]) {
        let pTeam = playerTeam.map { BattlePokemon(from: $0) }
        let oTeam = opponentTeam.map { BattlePokemon(from: $0) }
        self.state = BattleState(
            playerPokemon: pTeam[0],
            opponentPokemon: oTeam[0],
            playerTeam: pTeam,
            opponentTeam: oTeam
        )
    }

    /// Execute a turn: player picks a move, opponent picks a move.
    /// Faster Pokemon goes first.
    func executeTurn(playerMoveIndex: Int, opponentMoveIndex: Int) {
        guard !state.isOver else { return }
        state.turnNumber += 1

        let playerMove = state.playerPokemon.moves[safe: playerMoveIndex] ?? "Tackle"
        let opponentMove = state.opponentPokemon.moves[safe: opponentMoveIndex] ?? "Tackle"

        let playerSpeed = state.playerPokemon.stats.speed
        let opponentSpeed = state.opponentPokemon.stats.speed

        // Faster goes first. Tie = coin flip.
        let playerFirst = playerSpeed > opponentSpeed || (playerSpeed == opponentSpeed && Bool.random())

        if playerFirst {
            let result1 = executeMove(attacker: &state.playerPokemon, defender: &state.opponentPokemon, moveName: playerMove)
            onMoveExecuted?(result1)
            if checkFaint(isOpponent: true) { return }

            let result2 = executeMove(attacker: &state.opponentPokemon, defender: &state.playerPokemon, moveName: opponentMove)
            onMoveExecuted?(result2)
            if checkFaint(isOpponent: false) { return }
        } else {
            let result1 = executeMove(attacker: &state.opponentPokemon, defender: &state.playerPokemon, moveName: opponentMove)
            onMoveExecuted?(result1)
            if checkFaint(isOpponent: false) { return }

            let result2 = executeMove(attacker: &state.playerPokemon, defender: &state.opponentPokemon, moveName: playerMove)
            onMoveExecuted?(result2)
            if checkFaint(isOpponent: true) { return }
        }
    }

    private func executeMove(attacker: inout BattlePokemon, defender: inout BattlePokemon, moveName: String) -> MoveResult {
        let move = MoveData.allMoves[moveName] ?? Move(name: moveName, type: "Normal")
        let defenderType = MoveData.pokemonTypes[defender.pokemonId] ?? "Normal"

        // Type effectiveness
        let typeMultiplier = TypeChart.effectiveness(attackType: move.type, defenderType: defenderType)

        // Determine if physical or special (simplified: use higher attacking stat)
        let isPhysical = attacker.stats.attack >= attacker.stats.spAttack
        let attackStat = isPhysical ? attacker.stats.attack : attacker.stats.spAttack
        let defenseStat = isPhysical ? defender.stats.defense : defender.stats.spDefense

        // Critical hit: 6.25% chance, 1.5x damage
        let isCrit = Double.random(in: 0..<1) < 0.0625
        let critMultiplier = isCrit ? 1.5 : 1.0

        // Base power: 60 for all moves (simplified — could vary later)
        let basePower = 60

        // Damage formula (simplified Pokemon formula):
        // ((2*level/5 + 2) * basePower * atk/def) / 50 + 2) * modifiers
        let level = Double(attacker.level)
        let rawDamage = ((2.0 * level / 5.0 + 2.0) * Double(basePower) * Double(attackStat) / Double(defenseStat)) / 50.0 + 2.0
        let finalDamage = Int(rawDamage * typeMultiplier * critMultiplier * Double.random(in: 0.85...1.0))

        // Apply damage
        let actualDamage = typeMultiplier == 0 ? 0 : max(1, finalDamage)
        defender.currentHP = max(0, defender.currentHP - actualDamage)

        let effectiveness: MoveResult.Effectiveness
        if typeMultiplier == 0 { effectiveness = .immune }
        else if typeMultiplier >= 2 { effectiveness = .superEffective }
        else if typeMultiplier < 1 { effectiveness = .notVeryEffective }
        else { effectiveness = .normal }

        let attackerName = PetCollection.entry(for: attacker.pokemonId)?.displayName ?? attacker.pokemonId
        let defenderName = PetCollection.entry(for: defender.pokemonId)?.displayName ?? defender.pokemonId

        return MoveResult(
            attackerName: attackerName,
            defenderName: defenderName,
            moveName: moveName,
            damage: actualDamage,
            effectiveness: effectiveness,
            isCrit: isCrit,
            defenderFainted: defender.currentHP <= 0
        )
    }

    /// Check if a fainted Pokemon needs to be replaced.
    /// Returns true if battle is over.
    @discardableResult
    private func checkFaint(isOpponent: Bool) -> Bool {
        if isOpponent && !state.opponentPokemon.isAlive {
            // Find next alive opponent
            if let next = state.opponentTeam.firstIndex(where: { $0.isAlive && $0.pokemonId != state.opponentPokemon.pokemonId }) {
                state.opponentPokemon = state.opponentTeam[next]
            } else {
                state.isOver = true
                state.winner = .player
                onBattleOver?(.player)
                return true
            }
        } else if !isOpponent && !state.playerPokemon.isAlive {
            // Find next alive player Pokemon
            if let next = state.playerTeam.firstIndex(where: { $0.isAlive && $0.pokemonId != state.playerPokemon.pokemonId }) {
                state.playerPokemon = state.playerTeam[next]
                onSwitchNeeded?()
            } else {
                state.isOver = true
                state.winner = .opponent
                onBattleOver?(.opponent)
                return true
            }
        }
        return false
    }

    /// Switch the player's active Pokemon.
    func switchPlayerPokemon(to index: Int) {
        guard index < state.playerTeam.count, state.playerTeam[index].isAlive else { return }
        state.playerPokemon = state.playerTeam[index]
    }
}

// MARK: - Array safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

- [ ] **Step 2: Build and commit**

```bash
cd ~/Developer/NotchPet && swift build
git add Sources/NotchPet/BattleEngine.swift
git commit -m "feat: add battle engine with damage formula and turn logic"
```

---

### Task B5: Create Battle AI

**Files:**
- Create: `Sources/NotchPet/BattleAI.swift`

- [ ] **Step 1: Create BattleAI.swift**

Simple AI that picks the best move based on type effectiveness:

```swift
import Foundation

enum BattleAI {
    /// Pick the best move for the AI opponent.
    /// Strategy: choose the move with the highest type effectiveness against the player's active Pokemon.
    static func pickMove(attacker: BattlePokemon, defender: BattlePokemon) -> Int {
        let defenderType = MoveData.pokemonTypes[defender.pokemonId] ?? "Normal"

        var bestIndex = 0
        var bestMultiplier = 0.0

        for (i, moveName) in attacker.moves.enumerated() {
            let move = MoveData.allMoves[moveName] ?? Move(name: moveName, type: "Normal")
            let multiplier = TypeChart.effectiveness(attackType: move.type, defenderType: defenderType)
            if multiplier > bestMultiplier {
                bestMultiplier = multiplier
                bestIndex = i
            }
        }

        // If all moves are equally effective, pick randomly
        if bestMultiplier <= 1.0 {
            return Int.random(in: 0..<max(1, attacker.moves.count))
        }

        return bestIndex
    }

    /// Generate an AI team from available Pokemon.
    /// Picks `count` random Pokemon at levels near the player's average level.
    static func generateTeam(playerParty: [PokemonInstance], count: Int = 3) -> [PokemonInstance] {
        let avgLevel = max(1, playerParty.map(\.level).reduce(0, +) / max(1, playerParty.count))
        let allPokemon = PetCollection.allPokemon.map(\.id)

        // Pick random Pokemon not in player's party
        let playerIds = Set(playerParty.map(\.pokemonId))
        var available = allPokemon.filter { !playerIds.contains($0) }
        available.shuffle()

        let picked = Array(available.prefix(count))
        return picked.map { id in
            // Level within +-2 of player average
            let level = max(1, avgLevel + Int.random(in: -2...2))
            var instance = PokemonInstance(pokemonId: id)
            instance.level = level
            // Give moves up to their level
            if let learnset = MoveData.learnsets[id] {
                for (learnLevel, moveName) in learnset where learnLevel <= level {
                    if instance.moves.count < 4 {
                        instance.moves.append(moveName)
                    }
                }
            }
            return instance
        }
    }
}
```

- [ ] **Step 2: Build and commit**

```bash
cd ~/Developer/NotchPet && swift build
git add Sources/NotchPet/BattleAI.swift
git commit -m "feat: add battle AI with type-aware move selection"
```

---

### Task B6: Create Battle UI Tab

**Files:**
- Create: `Sources/NotchPet/BattleTabView.swift`
- Modify: `Sources/NotchPet/DSTabView.swift`
- Modify: `Sources/NotchPet/PanelWindow.swift`
- Modify: `Sources/NotchPet/AppDelegate.swift`

This is the largest task. The battle UI lives in a new tab called "Battle" in the PanelWindow. It shows:
- Two Pokemon facing each other with HP bars
- Move buttons at the bottom
- Battle log text
- Win/loss screen

**This task is complex and should be broken into sub-steps during implementation.** The key pieces:

- [ ] **Step 1: Add .startBattle action to TabAction**

In `Sources/NotchPet/DSTabView.swift`, add:

```swift
case startBattle
case battleMove(index: Int)
```

- [ ] **Step 2: Create BattleTabView.swift**

This view has two modes: pre-battle (showing a "Start Battle" button) and in-battle (showing the battle field).

Create `Sources/NotchPet/BattleTabView.swift` — this is a large file (~300 lines). Key elements:

1. **Pre-battle state:** "Battle!" button centered, shows opponent preview
2. **Battle state:** Top half shows opponent Pokemon (sprite + HP bar), bottom half shows player Pokemon (sprite + HP bar)
3. **Move buttons:** 4 buttons at the very bottom showing the player's available moves
4. **Battle log:** Single line of scrolling text showing the last move result

The exact implementation should follow the existing DSTabView pattern (manual frame-based layout, hit regions for interaction).

- [ ] **Step 3: Wire BattleTabView into PanelWindow**

In `Sources/NotchPet/PanelWindow.swift`:
- Add "Battle" to the tab labels array (before "Apps")
- Create BattleTabView instance in setupTabs()
- Handle `.startBattle` and `.battleMove` actions in handleTabAction()

- [ ] **Step 4: Handle battle flow in PanelWindow**

When `.startBattle` is received:
1. Generate AI team using `BattleAI.generateTeam()`
2. Create `BattleEngine` with player's party and AI team
3. Wire engine callbacks to update the BattleTabView
4. Show the battle field

When `.battleMove(index:)` is received:
1. Get AI's move choice from `BattleAI.pickMove()`
2. Call `engine.executeTurn(playerMoveIndex:opponentMoveIndex:)`
3. Update the battle tab with results

- [ ] **Step 5: Add XP rewards after battle**

When battle ends with player victory:
- Award XP to participating Pokemon (100-300 XP based on opponent level)
- Show level-up animations if applicable
- Could award a cosmetic or achievement

- [ ] **Step 6: Build, test, commit**

```bash
cd ~/Developer/NotchPet && swift build
git add -A
git commit -m "feat: add battle tab with AI opponent and battle engine"
```

---

# SUB-PROJECT C: Supabase Multiplayer

> **Prerequisites:** Sub-Project B must be complete. You need a Supabase project created at supabase.com.

### Task C1: Set Up Supabase Project and Schema

**Files:**
- Create: `supabase/migrations/001_create_players.sql`
- Create: `supabase/migrations/002_create_battles.sql`

- [ ] **Step 1: Create Supabase project**

Go to supabase.com, create a new project. Note the:
- Project URL (e.g., `https://xxxxx.supabase.co`)
- Anon key (public key for client-side auth)
- Service role key (keep secret, for admin operations)

- [ ] **Step 2: Create players table**

Create `supabase/migrations/001_create_players.sql`:

```sql
-- Players table for matchmaking and leaderboard
CREATE TABLE players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    display_name TEXT NOT NULL,
    elo_rating INT NOT NULL DEFAULT 1000,
    wins INT NOT NULL DEFAULT 0,
    losses INT NOT NULL DEFAULT 0,
    -- Serialized party data (JSON array of {pokemonId, level, moves})
    party_snapshot JSONB NOT NULL DEFAULT '[]',
    last_active TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for matchmaking (find players with similar ELO)
CREATE INDEX idx_players_elo ON players(elo_rating);
CREATE INDEX idx_players_active ON players(last_active);
```

- [ ] **Step 3: Create battles table**

Create `supabase/migrations/002_create_battles.sql`:

```sql
-- Battle rooms for real-time multiplayer
CREATE TABLE battles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player1_id UUID REFERENCES players(id),
    player2_id UUID REFERENCES players(id),
    -- Battle state as JSON (serialized BattleState)
    state JSONB NOT NULL DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'waiting', -- waiting, active, finished
    winner_id UUID REFERENCES players(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at TIMESTAMPTZ
);

-- Matchmaking queue
CREATE TABLE matchmaking_queue (
    player_id UUID PRIMARY KEY REFERENCES players(id),
    elo_rating INT NOT NULL,
    party_snapshot JSONB NOT NULL,
    queued_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable Realtime for battles
ALTER PUBLICATION supabase_realtime ADD TABLE battles;
```

- [ ] **Step 4: Run migrations**

```bash
# Using Supabase CLI or paste SQL into the SQL editor at supabase.com
```

- [ ] **Step 5: Commit**

```bash
git add supabase/
git commit -m "feat: add Supabase schema for players, battles, matchmaking"
```

---

### Task C2: Add Supabase Swift SDK

**Files:**
- Modify: `Package.swift`
- Create: `Sources/NotchPet/SupabaseManager.swift`

- [ ] **Step 1: Add supabase-swift dependency**

In `Package.swift`, add:

```swift
dependencies: [
    .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
],
```

And in the target:

```swift
dependencies: [
    .product(name: "Supabase", package: "supabase-swift"),
],
```

- [ ] **Step 2: Create SupabaseManager.swift**

```swift
import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        // Store these in Preferences or environment — never hardcode in production
        let url = URL(string: "YOUR_SUPABASE_URL")!
        let key = "YOUR_SUPABASE_ANON_KEY"
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    // MARK: - Player Management

    /// Create or get the local player profile.
    /// Uses a device-specific UUID stored in Preferences.
    func getOrCreatePlayer(displayName: String, party: [PokemonInstance]) async throws -> Player {
        let playerId = Preferences.shared.playerId ?? UUID().uuidString
        Preferences.shared.playerId = playerId

        let partySnapshot = try JSONEncoder().encode(party.map { PartySnapshotEntry(from: $0) })

        // Upsert player
        let player: Player = try await client
            .from("players")
            .upsert([
                "id": playerId,
                "display_name": displayName,
                "party_snapshot": String(data: partySnapshot, encoding: .utf8) ?? "[]",
                "last_active": ISO8601DateFormatter().string(from: Date())
            ])
            .select()
            .single()
            .execute()
            .value

        return player
    }
}

struct Player: Codable {
    let id: String
    let displayName: String
    let eloRating: Int
    let wins: Int
    let losses: Int

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case eloRating = "elo_rating"
        case wins, losses
    }
}

struct PartySnapshotEntry: Codable {
    let pokemonId: String
    let level: Int
    let moves: [String]

    init(from instance: PokemonInstance) {
        self.pokemonId = instance.pokemonId
        self.level = instance.level
        self.moves = instance.moves
    }
}
```

- [ ] **Step 3: Add playerId to Preferences**

In `Preferences.swift`:

```swift
// In Keys:
static let playerId = "notchpet.playerId"

// Property:
var playerId: String? {
    get { defaults.string(forKey: Keys.playerId) }
    set { defaults.set(newValue, forKey: Keys.playerId) }
}
```

- [ ] **Step 4: Build and commit**

```bash
cd ~/Developer/NotchPet && swift build
git add -A
git commit -m "feat: add Supabase SDK and player management"
```

---

### Task C3: Create Matchmaking Manager

**Files:**
- Create: `Sources/NotchPet/MatchmakingManager.swift`

- [ ] **Step 1: Create MatchmakingManager.swift**

```swift
import Foundation
import Supabase

final class MatchmakingManager {
    private let supabase = SupabaseManager.shared

    /// Join the matchmaking queue. Returns when a match is found.
    func findMatch(player: Player, party: [PokemonInstance]) async throws -> MatchFound {
        let partySnapshot = try JSONEncoder().encode(party.map { PartySnapshotEntry(from: $0) })
        let partyJSON = String(data: partySnapshot, encoding: .utf8) ?? "[]"

        // Add to queue
        try await supabase.client
            .from("matchmaking_queue")
            .upsert([
                "player_id": player.id,
                "elo_rating": "\(player.eloRating)",
                "party_snapshot": partyJSON
            ])
            .execute()

        // Poll for a match (check every 2 seconds, up to 30 seconds)
        for _ in 0..<15 {
            try await Task.sleep(nanoseconds: 2_000_000_000)

            // Look for another player in queue with similar ELO (+-200)
            let candidates: [QueueEntry] = try await supabase.client
                .from("matchmaking_queue")
                .select()
                .neq("player_id", value: player.id)
                .gte("elo_rating", value: player.eloRating - 200)
                .lte("elo_rating", value: player.eloRating + 200)
                .order("queued_at")
                .limit(1)
                .execute()
                .value

            if let opponent = candidates.first {
                // Create battle room
                let battle = try await createBattle(player1Id: player.id, player2Id: opponent.playerId)

                // Remove both from queue
                try await supabase.client
                    .from("matchmaking_queue")
                    .delete()
                    .in("player_id", values: [player.id, opponent.playerId])
                    .execute()

                return MatchFound(battleId: battle.id, opponentId: opponent.playerId, opponentParty: opponent.partySnapshot)
            }
        }

        // Timeout — remove from queue
        try await supabase.client
            .from("matchmaking_queue")
            .delete()
            .eq("player_id", value: player.id)
            .execute()

        throw MatchmakingError.timeout
    }

    private func createBattle(player1Id: String, player2Id: String) async throws -> BattleRecord {
        let record: BattleRecord = try await supabase.client
            .from("battles")
            .insert([
                "player1_id": player1Id,
                "player2_id": player2Id,
                "status": "active"
            ])
            .select()
            .single()
            .execute()
            .value
        return record
    }

    func cancelSearch(playerId: String) async throws {
        try await supabase.client
            .from("matchmaking_queue")
            .delete()
            .eq("player_id", value: playerId)
            .execute()
    }
}

struct QueueEntry: Codable {
    let playerId: String
    let eloRating: Int
    let partySnapshot: String

    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case eloRating = "elo_rating"
        case partySnapshot = "party_snapshot"
    }
}

struct BattleRecord: Codable {
    let id: String
    let player1Id: String
    let player2Id: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case player1Id = "player1_id"
        case player2Id = "player2_id"
        case status
    }
}

struct MatchFound {
    let battleId: String
    let opponentId: String
    let opponentParty: String  // JSON array of PartySnapshotEntry
}

enum MatchmakingError: Error {
    case timeout
    case noOpponent
}
```

- [ ] **Step 2: Build and commit**

```bash
cd ~/Developer/NotchPet && swift build
git add Sources/NotchPet/MatchmakingManager.swift
git commit -m "feat: add matchmaking manager with ELO-based queue"
```

---

### Task C4: Create Multiplayer Battle Sync

**Files:**
- Create: `Sources/NotchPet/MultiplayerBattle.swift`

- [ ] **Step 1: Create MultiplayerBattle.swift**

This wraps BattleEngine with Supabase Realtime to sync moves between two players:

```swift
import Foundation
import Supabase

/// Syncs battle state between two players via Supabase Realtime.
final class MultiplayerBattle {
    let engine: BattleEngine
    let battleId: String
    let isPlayer1: Bool // determines which side this client controls
    private let supabase = SupabaseManager.shared
    private var channel: RealtimeChannelV2?

    var onOpponentMoved: ((Int) -> Void)?  // opponent's chosen move index
    var onBattleEnded: ((BattleState.BattleWinner) -> Void)?

    init(engine: BattleEngine, battleId: String, isPlayer1: Bool) {
        self.engine = engine
        self.battleId = battleId
        self.isPlayer1 = isPlayer1
    }

    /// Subscribe to the battle channel for real-time move exchange.
    func connect() async {
        let channel = supabase.client.realtimeV2.channel("battle:\(battleId)")

        channel.onBroadcast(event: "move") { [weak self] message in
            guard let self = self,
                  let payload = message.payload as? [String: Any],
                  let moveIndex = payload["moveIndex"] as? Int,
                  let fromPlayer1 = payload["isPlayer1"] as? Bool,
                  fromPlayer1 != self.isPlayer1 // only process opponent's moves
            else { return }

            self.onOpponentMoved?(moveIndex)
        }

        await channel.subscribe()
        self.channel = channel
    }

    /// Send our move choice to the opponent.
    func sendMove(index: Int) async throws {
        try await channel?.broadcast(
            event: "move",
            message: [
                "moveIndex": index,
                "isPlayer1": isPlayer1
            ]
        )
    }

    /// Update the battle record when finished.
    func reportResult(winnerId: String) async throws {
        try await supabase.client
            .from("battles")
            .update([
                "status": "finished",
                "winner_id": winnerId,
                "finished_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: battleId)
            .execute()
    }

    func disconnect() async {
        await channel?.unsubscribe()
    }
}
```

- [ ] **Step 2: Build and commit**

```bash
cd ~/Developer/NotchPet && swift build
git add Sources/NotchPet/MultiplayerBattle.swift
git commit -m "feat: add multiplayer battle sync via Supabase Realtime"
```

---

### Task C5: Wire Multiplayer into Battle Tab UI

**Files:**
- Modify: `Sources/NotchPet/BattleTabView.swift`
- Modify: `Sources/NotchPet/PanelWindow.swift`

- [ ] **Step 1: Add matchmaking UI to BattleTabView**

Update the pre-battle state to show two buttons:
- "Battle AI" → starts local AI battle (existing flow)
- "Battle Online" → starts matchmaking, shows "Searching..." spinner

- [ ] **Step 2: Wire matchmaking flow in PanelWindow**

When "Battle Online" is tapped:
1. Call `SupabaseManager.getOrCreatePlayer()` to ensure player exists
2. Call `MatchmakingManager.findMatch()` to enter queue
3. When match found, create `BattleEngine` with opponent's party
4. Create `MultiplayerBattle` for realtime sync
5. Connect and start the battle

- [ ] **Step 3: Handle multiplayer turn flow**

The turn flow differs from AI:
1. Player picks a move → `MultiplayerBattle.sendMove()`
2. Wait for `onOpponentMoved` callback
3. Once both moves are known, `engine.executeTurn()` runs on BOTH clients
4. Results are deterministic (same engine, same inputs) so state stays in sync

- [ ] **Step 4: Add ELO update after multiplayer battle**

When battle ends:
- Winner gains ELO: `newELO = oldELO + 32 * (1 - expectedScore)`
- Loser drops: `newELO = oldELO + 32 * (0 - expectedScore)`
- Update via Supabase

- [ ] **Step 5: Build, test, commit**

```bash
cd ~/Developer/NotchPet && swift build
git add -A
git commit -m "feat: wire multiplayer matchmaking and battle sync into UI"
```

---

## Summary of Dependencies

```
Sub-Project A (App Toggle)    → standalone, ship anytime
Sub-Project B (Local Battles) → standalone, ship anytime
Sub-Project C (Multiplayer)   → requires B complete + Supabase project created
```

## What Hayden Needs to Set Up

1. **Supabase Project** — Create at supabase.com, get URL + anon key
2. **Supabase Tables** — Run the SQL migrations (can paste into SQL editor)
3. **Supabase Realtime** — Enabled by default, just needs the `ALTER PUBLICATION` from migration
4. **No server code needed** — Supabase handles auth, database, and realtime out of the box

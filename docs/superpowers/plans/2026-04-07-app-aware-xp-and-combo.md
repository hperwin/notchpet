# App-Aware XP Multipliers & Deep Work Combo Counter — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add app-aware XP multipliers (3x deep work, 1x normal, 0x distraction — user-configurable) and a combo counter (escalating multiplier for sustained typing, shown as a badge on the lead Pokemon in the party strip).

**Architecture:** Two systems layered into existing `GameSystems`: (1) an app tier detector that polls `NSWorkspace` every 2s and exposes the current multiplier, (2) a combo tracker that escalates through stages based on sustained typing with a 30s timeout. Both multipliers feed into the existing `recordKeypress()` XP formula. Combo badge renders on the party strip's lead Pokemon window.

**Tech Stack:** Swift, AppKit, NSWorkspace, CoreAnimation

---

### Task 1: Add AppTier enum and persistence to PetState

**Files:**
- Modify: `Sources/NotchPet/PetState.swift`

- [ ] **Step 1: Add AppTier enum above PetState class**

Add after the `WeeklyChallenge` struct (around line 133):

```swift
// MARK: - App Tier

enum AppTier: Int, Codable, CaseIterable {
    case deepWork = 2
    case normal = 1
    case distraction = 0

    var multiplier: Double {
        switch self {
        case .deepWork: return 3.0
        case .normal: return 1.0
        case .distraction: return 0.0
        }
    }

    var name: String {
        switch self {
        case .deepWork: return "Deep Work"
        case .normal: return "Normal"
        case .distraction: return "Distraction"
        }
    }

    var color: (r: CGFloat, g: CGFloat, b: CGFloat) {
        switch self {
        case .deepWork: return (0.3, 0.8, 0.3)    // green
        case .normal: return (0.6, 0.6, 0.6)       // grey
        case .distraction: return (0.9, 0.3, 0.3)  // red
        }
    }
}
```

- [ ] **Step 2: Add app tier overrides to PetState**

Add inside the `PetState` class, after the `weeklyChallenge` property (around line 216):

```swift
    // App tiers
    var appTierOverrides: [String: AppTier] = [:]
```

- [ ] **Step 3: Add default tier list as a static on PetState**

Add as a static method on PetState, after the `ensureAllCosmetics()` method:

```swift
    // MARK: - Default App Tiers

    static let defaultDeepWorkBundleIDs: Set<String> = [
        "com.apple.dt.Xcode",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",  // Cursor
        "com.figma.Desktop",
        "com.apple.LogicPro",
        "com.apple.FinalCut",
        "net.kovidgoyal.kitty",
        "com.sublimetext.4",
        "com.jetbrains.intellij",
    ]

    static let defaultDistractionBundleIDs: Set<String> = [
        "com.twitter.twitter-mac",          // X/Twitter native
        "com.reddit.Reddit",
        "com.zhiliaoapp.musically",         // TikTok
        "com.burbn.instagram",              // Instagram
        "com.google.Chrome.app.youtube",    // YouTube PWA
        "com.hnc.Discord",
        "tv.twitch.TwitchDesktop",
    ]

    func appTier(for bundleID: String) -> AppTier {
        if let override = appTierOverrides[bundleID] {
            return override
        }
        if Self.defaultDeepWorkBundleIDs.contains(bundleID) { return .deepWork }
        if Self.defaultDistractionBundleIDs.contains(bundleID) { return .distraction }
        return .normal
    }
```

- [ ] **Step 4: Build and verify**

Run: `cd ~/Developer/NotchPet && swift build 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/NotchPet
git add Sources/NotchPet/PetState.swift
git commit -m "feat: add AppTier enum and tier persistence to PetState"
```

---

### Task 2: Add combo state and app polling to GameSystems

**Files:**
- Modify: `Sources/NotchPet/GameSystems.swift`

- [ ] **Step 1: Add combo stage enum and new properties**

Add the `ComboStage` enum inside `GameSystems`, right after the `GameEvent` enum (around line 31):

```swift
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
```

Add new GameEvent cases inside the existing `GameEvent` enum:

```swift
        case comboChanged(ComboStage)
        case appTierChanged(AppTier)
```

Add new instance properties after `keypressSinceLastSave` (around line 8):

```swift
    // Combo tracking (session-only, not persisted)
    private(set) var comboStage: ComboStage = .none
    private var comboStartTime: Date?
    private var lastComboKeypressTime: Date?
    private static let comboTimeout: TimeInterval = 30

    // App tier tracking
    private(set) var activeAppTier: AppTier = .normal
    private var pollTimer: Timer?
```

- [ ] **Step 2: Add startPolling/stopPolling methods**

Add after the `init` method:

```swift
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
        // Update active app tier
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            let newTier = state.appTier(for: bundleID)
            if newTier != activeAppTier {
                activeAppTier = newTier
                onEvent?(.appTierChanged(newTier))
            }
        }

        // Check combo timeout
        if let lastKeypress = lastComboKeypressTime {
            if Date().timeIntervalSince(lastKeypress) > Self.comboTimeout {
                resetCombo()
            } else {
                updateComboStage()
            }
        }
    }
```

- [ ] **Step 3: Add combo management methods**

Add after `pollTick()`:

```swift
    private func updateComboStage() {
        guard let start = comboStartTime else { return }
        let elapsed = Date().timeIntervalSince(start)
        let newStage: ComboStage
        if elapsed >= 1800 {       // 30 min
            newStage = .flow
        } else if elapsed >= 900 { // 15 min
            newStage = .deep
        } else if elapsed >= 300 { // 5 min
            newStage = .focused
        } else if elapsed >= 60 {  // 1 min
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
```

- [ ] **Step 4: Update recordKeypress() to use new multipliers and feed combo**

Replace the XP gain block in `recordKeypress()` (the `if state.totalKeysTyped % 10 == 0 { ... }` block, lines 43-60) with:

```swift
        // Feed combo timer
        let now = Date()
        if comboStartTime == nil {
            comboStartTime = now
        }
        lastComboKeypressTime = now

        // Every 10th keypress = XP to lead, every 20th = XP to rest of party
        if state.totalKeysTyped % 10 == 0 {
            let appMult = activeAppTier.multiplier
            let comboMult = comboStage.multiplier
            let baseGain = max(Int(1.0 * state.streakMultiplier * state.fatigueMultiplier * appMult * comboMult), 0)
            guard baseGain > 0 else { /* distraction app — no XP */ return }
            for (i, pokemonId) in state.party.enumerated() {
                guard var instance = state.pokemonInstances[pokemonId] else { continue }
                if i == 0 {
                    // Lead: XP every 10 keystrokes
                    let leveledUp = instance.addXP(baseGain)
                    state.pokemonInstances[pokemonId] = instance
                    if leveledUp { onEvent?(.levelUp(instance.level)) }
                } else if state.totalKeysTyped % 20 == 0 {
                    // Others: half rate (every 20 keystrokes)
                    let leveledUp = instance.addXP(baseGain)
                    state.pokemonInstances[pokemonId] = instance
                    if leveledUp { onEvent?(.levelUp(instance.level)) }
                }
            }
        }
```

Note: the `return` inside `guard baseGain > 0` would exit `recordKeypress()` early, skipping rest XP drain, streak updates, and save. That's intentional for distraction apps — but we still want the combo to stay alive. Since the combo feeding happens above this block, the combo survives distraction apps. However, we need to keep the rest of the function running. Replace the `return` approach:

```swift
        // Every 10th keypress = XP to lead, every 20th = XP to rest of party
        if state.totalKeysTyped % 10 == 0 {
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
                    } else if state.totalKeysTyped % 20 == 0 {
                        let leveledUp = instance.addXP(baseGain)
                        state.pokemonInstances[pokemonId] = instance
                        if leveledUp { onEvent?(.levelUp(instance.level)) }
                    }
                }
            }
        }
```

- [ ] **Step 5: Add `import AppKit` at the top of GameSystems.swift**

The file currently only imports Foundation. NSWorkspace requires AppKit:

```swift
import Foundation
import AppKit
```

- [ ] **Step 6: Handle the new GameEvent cases in the default switch**

No changes needed — the `default: break` in AppDelegate's `handleGameEvent` already handles unknown cases. We'll wire these up in Task 4.

- [ ] **Step 7: Build and verify**

Run: `cd ~/Developer/NotchPet && swift build 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 8: Commit**

```bash
cd ~/Developer/NotchPet
git add Sources/NotchPet/GameSystems.swift
git commit -m "feat: add combo tracker and app-aware XP multipliers to GameSystems"
```

---

### Task 3: Add combo badge to PartyStrip

**Files:**
- Modify: `Sources/NotchPet/PartyStrip.swift`

- [ ] **Step 1: Add combo badge state to PartyStrip**

Add new properties after `levelUpTimer` (around line 174):

```swift
    private var comboBadgeWindow: NSWindow?
    private var comboBadgeLabel: NSTextField?
    private var currentComboStage: GameSystems.ComboStage = .none
```

- [ ] **Step 2: Add updateCombo method**

Add after `showLevelUp`:

```swift
    // MARK: - Combo Badge

    func updateCombo(_ stage: GameSystems.ComboStage) {
        guard stage != currentComboStage else { return }
        let oldStage = currentComboStage
        currentComboStage = stage

        if stage == .none {
            hideCombo()
            return
        }

        guard let label = stage.label else { return }

        if comboBadgeWindow == nil {
            createComboBadge()
        }

        guard let badgeWin = comboBadgeWindow,
              let badgeLabel = comboBadgeLabel else { return }

        // Update text and color
        badgeLabel.stringValue = label
        let color = comboColor(for: stage)
        badgeWin.contentView?.layer?.backgroundColor = color.withAlphaComponent(0.85).cgColor
        badgeWin.contentView?.layer?.borderColor = color.cgColor

        if oldStage == .none {
            // Fade + scale in
            badgeWin.alphaValue = 0
            badgeWin.orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                badgeWin.animator().alphaValue = 1
            }
        }

        // Play a pulse on stage upgrade
        if stage > oldStage && oldStage != .none {
            let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
            pulse.values = [1.0, 1.3, 1.0]
            pulse.keyTimes = [0, 0.4, 1.0]
            pulse.duration = 0.3
            badgeWin.contentView?.layer?.add(pulse, forKey: "stagePulse")
        }

        // Flame particle at flow stage
        if stage == .flow {
            addFlameToLead()
        } else {
            removeFlameFromLead()
        }
    }

    private func createComboBadge() {
        // Position: right of the first (lead) Pokemon window
        guard let leadWin = pokemonWindows.first, leadWin.isVisible else { return }
        let leadFrame = leadWin.frame
        let badgeW: CGFloat = 32
        let badgeH: CGFloat = 16
        let badgeX = leadFrame.maxX + 2
        let badgeY = leadFrame.maxY - badgeH - 2

        let badgeFrame = NSRect(x: badgeX, y: badgeY, width: badgeW, height: badgeH)

        let bgView = NSView(frame: NSRect(origin: .zero, size: badgeFrame.size))
        bgView.wantsLayer = true
        bgView.layer?.cornerRadius = 4
        bgView.layer?.borderWidth = 1

        let label = NSTextField(labelWithString: "")
        label.font = NSFont.boldSystemFont(ofSize: 9)
        label.textColor = .white
        label.alignment = .center
        label.isBordered = false
        label.drawsBackground = false
        label.isEditable = false
        label.frame = NSRect(x: 0, y: 1, width: badgeW, height: badgeH - 2)
        bgView.addSubview(label)
        comboBadgeLabel = label

        let win = NSWindow(contentRect: badgeFrame, styleMask: .borderless, backing: .buffered, defer: false)
        win.level = .statusBar
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.ignoresMouseEvents = true
        win.contentView = bgView
        comboBadgeWindow = win
    }

    private func hideCombo() {
        guard let win = comboBadgeWindow else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            win.animator().alphaValue = 0
        }, completionHandler: {
            win.orderOut(nil)
        })
        removeFlameFromLead()
    }

    private func comboColor(for stage: GameSystems.ComboStage) -> NSColor {
        switch stage {
        case .none: return .clear
        case .warm: return NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)       // grey
        case .focused: return NSColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1)    // blue
        case .deep: return NSColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1)       // orange
        case .flow: return NSColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1)      // gold
        }
    }

    private func addFlameToLead() {
        guard let leadWin = pokemonWindows.first,
              let petView = leadWin.contentView as? GrassPetView else { return }
        // Subtle glow effect for flow state
        petView.layer?.shadowColor = NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1).cgColor
        petView.layer?.shadowRadius = 6
        petView.layer?.shadowOpacity = 0.8
        petView.layer?.shadowOffset = .zero
        let pulse = CABasicAnimation(keyPath: "shadowOpacity")
        pulse.fromValue = 0.5
        pulse.toValue = 1.0
        pulse.duration = 0.6
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        petView.layer?.add(pulse, forKey: "flowFlame")
    }

    private func removeFlameFromLead() {
        guard let leadWin = pokemonWindows.first,
              let petView = leadWin.contentView as? GrassPetView else { return }
        petView.layer?.removeAnimation(forKey: "flowFlame")
        petView.layer?.shadowOpacity = 0
    }
```

- [ ] **Step 3: Build and verify**

Run: `cd ~/Developer/NotchPet && swift build 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
cd ~/Developer/NotchPet
git add Sources/NotchPet/PartyStrip.swift
git commit -m "feat: add combo badge and flow flame to party strip"
```

---

### Task 4: Wire up AppDelegate and update StatsTabView

**Files:**
- Modify: `Sources/NotchPet/AppDelegate.swift`
- Modify: `Sources/NotchPet/StatsTabView.swift`

- [ ] **Step 1: Wire up GameSystems polling in AppDelegate**

In `applicationDidFinishLaunching`, after `gameSystems = GameSystems(state: petState)` and the `onEvent` setup (around line 25), add:

```swift
        gameSystems.startPolling()
```

- [ ] **Step 2: Handle new game events in AppDelegate**

In `handleGameEvent`, add cases before the `default:` (around line 246):

```swift
        case .comboChanged(let stage):
            partyStrip.updateCombo(stage)

        case .appTierChanged(let tier):
            NSLog("NotchPet: App tier changed to \(tier.name)")
```

- [ ] **Step 3: Stop polling on app termination**

In `applicationWillTerminate`, add after `tickTimer?.invalidate()`:

```swift
        gameSystems.stopPolling()
```

- [ ] **Step 4: Remove the separate panelRefreshTimer**

The GameSystems poll timer now handles the 2s cadence. In `applicationDidFinishLaunching`, remove the `panelRefreshTimer` block (lines 143-152) and the `panelRefreshNeeded` flag usage.

Replace the `panelRefreshTimer` block with nothing — remove these lines:

```swift
        // Throttled panel refresh — updates XP display every 2s while typing
        panelRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.panelRefreshNeeded else { return }
            self.panelRefreshNeeded = false
            if self.panelWindow.isOpen {
                self.panelWindow.refreshData(self.petState)
            }
            self.updatePartyStrip()
        }
```

Also remove `private var panelRefreshTimer: Timer?` and `private var panelRefreshNeeded: Bool = false` from the property declarations.

Remove `self?.panelRefreshNeeded = true` from the `onKeypress` callback (change it back to just `self?.gameSystems.recordKeypress()`).

Remove `panelRefreshTimer?.invalidate()` from `applicationWillTerminate`.

Instead, add panel refresh to the `appTierChanged` and `comboChanged` handlers:

```swift
        case .comboChanged(let stage):
            partyStrip.updateCombo(stage)
            if panelWindow.isOpen { panelWindow.refreshData(petState) }

        case .appTierChanged(let tier):
            NSLog("NotchPet: App tier changed to \(tier.name)")
            if panelWindow.isOpen { panelWindow.refreshData(petState) }
```

- [ ] **Step 5: Update StatsTabView to show app tier and combo**

In `StatsTabView.update(state:)`, add a new row after the Feeding card section (before the Party card). Insert after the `feedingCard` block (around line 137):

```swift
        // ── Row 1.5: Focus card (full width, compact) ──

        let focusY = pad + topCardH + gap
        let focusH: CGFloat = 32
        let focusCard = DS.makeCard(frame: NSRect(
            x: pad, y: focusY, width: contentW, height: focusH))
        addSubview(focusCard)

        // We need access to gameSystems for combo/tier info — pass via state
        // For now show static info from state
        let tierName = "Normal"  // Will be updated when we pass tier through
        let comboLabel = "x1"    // Will be updated when we pass combo through

        var focusPx: CGFloat = ip
        let focusTitle = placeLabel("Focus", in: focusCard, x: focusPx, y: 8,
                                     size: 10, bold: true, color: DS.gold)
        focusPx += focusTitle.frame.width + 10

        let tierPill = makePill("App: \(tierName)", in: focusCard, x: focusPx, y: 6)
        focusPx += tierPill + 6

        _ = makePill("Combo: \(comboLabel)", in: focusCard, x: focusPx, y: 6)
```

Then shift the party card down. Change `partyY`:

```swift
        let partyY = pad + topCardH + gap + focusH + gap
```

- [ ] **Step 6: Pass combo and tier info through PetState for display**

Add session-only display properties to PetState (not persisted — they use `CodingKeys` exclusion). Add after `var sessionKeysTyped`:

```swift
    // Session-only display state (not persisted)
    var currentAppTierName: String = "Normal"
    var currentComboLabel: String = "x1"
```

These need to be excluded from Codable. Add a `CodingKeys` enum inside PetState that lists all persisted properties. Actually, since PetState has many properties and adding CodingKeys for all would be verbose, instead use a simpler approach — update these from AppDelegate when events fire:

In AppDelegate's `handleGameEvent`:

```swift
        case .comboChanged(let stage):
            partyStrip.updateCombo(stage)
            petState.currentComboLabel = stage.label ?? "x1"
            if panelWindow.isOpen { panelWindow.refreshData(petState) }

        case .appTierChanged(let tier):
            NSLog("NotchPet: App tier changed to \(tier.name)")
            petState.currentAppTierName = tier.name
            if panelWindow.isOpen { panelWindow.refreshData(petState) }
```

And in StatsTabView, replace the hardcoded values:

```swift
        let tierName = state.currentAppTierName
        let comboLabel = state.currentComboLabel
```

For Codable, mark these as non-coded by providing default decoding. Add to PetState:

```swift
    enum CodingKeys: String, CodingKey {
        case xp, level, totalXPEarned, pokemonInstances
        case totalKeysTyped, totalWordsTyped, sessionKeysTyped, currentWPM
        case typingStreak, longestTypingStreak, loginStreak, longestLoginStreak
        case lastTypingDate, lastLoginDate
        case cosmetics, activeCosmetic, achievements
        case restXP, lastActiveTime, sessionActiveMinutes
        case party, useShiny, unlockedShinies
        case mutationColor, weeklyChallenge, appTierOverrides
    }
```

This excludes `currentAppTierName` and `currentComboLabel` from encoding/decoding.

- [ ] **Step 7: Build and verify**

Run: `cd ~/Developer/NotchPet && swift build 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 8: Commit**

```bash
cd ~/Developer/NotchPet
git add Sources/NotchPet/AppDelegate.swift Sources/NotchPet/StatsTabView.swift Sources/NotchPet/PetState.swift
git commit -m "feat: wire up combo and app tier in AppDelegate, show in stats"
```

---

### Task 5: Create AppSettingsTabView (5th panel tab)

**Files:**
- Create: `Sources/NotchPet/AppSettingsTabView.swift`
- Modify: `Sources/NotchPet/PanelWindow.swift`

- [ ] **Step 1: Create AppSettingsTabView**

Create `Sources/NotchPet/AppSettingsTabView.swift`:

```swift
import AppKit

final class AppSettingsTabView: DSTabView {

    override var isFlipped: Bool { true }

    private static let bgColor = NSColor(red: 0x0d/255.0, green: 0x0d/255.0, blue: 0x0d/255.0, alpha: 1)

    init() {
        super.init(backgroundColor: AppSettingsTabView.bgColor)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func update(state: PetState) {
        subviews.forEach { $0.removeFromSuperview() }
        clearHitRegions()
        needsDisplay = true

        let pad = DS.outerPad
        let gap = DS.cardGap
        let ip = DS.innerPad
        let contentW: CGFloat = 560

        // Title
        let title = DS.label("App Tiers", size: 14, bold: true, color: DS.gold)
        title.sizeToFit()
        title.frame.origin = NSPoint(x: pad + ip, y: pad)
        addSubview(title)

        let subtitle = DS.label("Tap an app to cycle: Deep Work → Normal → Distraction", size: 9, color: DS.textSecondary)
        subtitle.sizeToFit()
        subtitle.frame.origin = NSPoint(x: pad + ip, y: pad + 20)
        addSubview(subtitle)

        // Get running apps (with bundle IDs, excluding self and background daemons)
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }

        // Three columns
        let colW: CGFloat = (contentW - pad * 2 - gap * 2) / 3
        let columns: [(title: String, tier: AppTier, color: NSColor)] = [
            ("Deep Work (3x)", .deepWork, NSColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1)),
            ("Normal (1x)", .normal, DS.textSecondary),
            ("Distraction (0x)", .distraction, NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1)),
        ]

        for (colIdx, col) in columns.enumerated() {
            let colX = pad + CGFloat(colIdx) * (colW + gap)
            let headerY: CGFloat = pad + 44

            // Column header
            let header = DS.label(col.title, size: 10, bold: true, color: col.color)
            header.sizeToFit()
            header.frame.origin = NSPoint(x: colX + ip, y: headerY)
            addSubview(header)

            // Apps in this tier
            let appsInTier = runningApps.filter { app in
                guard let bid = app.bundleIdentifier else { return false }
                return state.appTier(for: bid) == col.tier
            }

            var rowY = headerY + 24
            for app in appsInTier {
                guard let bundleID = app.bundleIdentifier else { continue }
                let name = app.localizedName ?? bundleID

                // App icon
                if let icon = app.icon {
                    let iconView = NSImageView(frame: NSRect(x: colX + ip, y: rowY, width: 16, height: 16))
                    iconView.image = icon
                    iconView.imageScaling = .scaleProportionallyUpOrDown
                    addSubview(iconView)
                }

                // App name
                let nameLabel = DS.label(name, size: 10, color: DS.textPrimary)
                nameLabel.lineBreakMode = .byTruncatingTail
                nameLabel.frame = NSRect(x: colX + ip + 20, y: rowY, width: colW - ip * 2 - 20, height: 16)
                addSubview(nameLabel)

                // Hit region for cycling tier
                let regionRect = NSRect(x: colX, y: rowY - 2, width: colW, height: 20)
                addHitRegion(HitRegion(
                    id: "tier_\(bundleID)",
                    rect: regionRect,
                    action: .switchToTab(-1)  // placeholder — we handle via override
                ))

                rowY += 22
            }
        }
    }

    // Override mouse handling to cycle tiers
    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        for region in hitRegions where region.enabled {
            if region.rect.contains(loc) && region.id.hasPrefix("tier_") {
                let bundleID = String(region.id.dropFirst(5))
                cycleTier(bundleID: bundleID)
                return
            }
        }
        super.mouseDown(with: event)
    }

    private func cycleTier(bundleID: String) {
        // Get state from last update — we need a reference
        // Use onAction to signal the parent to handle this
        onAction?(.cycleTier(bundleID: bundleID))
    }
}
```

- [ ] **Step 2: Add cycleTier to TabAction enum**

In `DSTabView.swift`, add a new case to `TabAction`:

```swift
    case cycleTier(bundleID: String)
```

- [ ] **Step 3: Add the 5th tab in PanelWindow**

In `PanelWindow.swift`, update `setupTabs()` (line 190):

```swift
    private func setupTabs() {
        let party = PartyTabView()
        let collection = CollectionTabView()
        let stats = StatsTabView()
        let achievements = AchievementsTabView()
        let appSettings = AppSettingsTabView()

        tabs = [party, collection, stats, achievements, appSettings]

        for tab in tabs {
            tab.onAction = { [weak self] action in
                self?.handleTabAction(action)
            }
        }

        switchToTab(0)
    }
```

Update the tab bar labels in `buildTabBar()` (line 324):

```swift
        let labels = ["Party", "Box", "Stats", "Medals", "Apps"]
```

- [ ] **Step 4: Handle cycleTier action in PanelWindow**

In `handleTabAction` (around line 209), add a case:

```swift
        case .cycleTier(let bundleID):
            if let state = lastState {
                let current = state.appTier(for: bundleID)
                let next: AppTier
                switch current {
                case .deepWork: next = .normal
                case .normal: next = .distraction
                case .distraction: next = .deepWork
                }
                // If cycling to the default, remove the override; otherwise set it
                let defaultTier: AppTier
                if PetState.defaultDeepWorkBundleIDs.contains(bundleID) {
                    defaultTier = .deepWork
                } else if PetState.defaultDistractionBundleIDs.contains(bundleID) {
                    defaultTier = .distraction
                } else {
                    defaultTier = .normal
                }
                if next == defaultTier {
                    state.appTierOverrides.removeValue(forKey: bundleID)
                } else {
                    state.appTierOverrides[bundleID] = next
                }
                state.save()
                refreshData(state)
            }
```

- [ ] **Step 5: Build and verify**

Run: `cd ~/Developer/NotchPet && swift build 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 6: Commit**

```bash
cd ~/Developer/NotchPet
git add Sources/NotchPet/AppSettingsTabView.swift Sources/NotchPet/PanelWindow.swift Sources/NotchPet/DSTabView.swift
git commit -m "feat: add Apps tab for configuring app tier overrides"
```

---

### Task 6: Build, install, and verify end-to-end

**Files:**
- No code changes — build, install, and manual verification

- [ ] **Step 1: Full clean build**

```bash
cd ~/Developer/NotchPet && swift build -c release 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 2: Install to /Applications**

```bash
killall NotchPet 2>/dev/null
sleep 1
cp ~/Developer/NotchPet/.build/release/NotchPet /Applications/NotchPet.app/Contents/MacOS/NotchPet
cp -R ~/Developer/NotchPet/.build/release/NotchPet_NotchPet.bundle /Applications/NotchPet.app/Contents/MacOS/NotchPet_NotchPet.bundle
open /Applications/NotchPet.app
```

- [ ] **Step 3: Verify combo badge**

Type steadily for 60+ seconds. After 1 minute, a "x1.5" grey badge should appear next to the lead Pokemon. Stop typing for 30 seconds — badge should fade out.

- [ ] **Step 4: Verify app tier**

Open the panel, go to the "Apps" tab. Running apps should be listed in three columns. Tap an app to cycle its tier.

- [ ] **Step 5: Verify XP multiplier**

Open Xcode (deep work app), type — XP should gain at 3x rate. Switch to a distraction app — XP should not increase.

- [ ] **Step 6: Commit all remaining changes**

```bash
cd ~/Developer/NotchPet
git add -A
git commit -m "feat: app-aware XP multipliers and deep work combo counter"
```

# App-Aware XP Multipliers & Deep Work Combo Counter

## Overview

Two features that reward focused computer work with faster Pokemon XP gain. App-Aware XP detects what app you're using and adjusts XP rate. Combo Counter rewards sustained typing with escalating multipliers.

## App Tier System

### Data Model

Three tiers stored in PetState as `[String: AppTier]` keyed by bundle ID:

| Tier | Multiplier | Default Apps |
|------|-----------|--------------|
| Deep Work | 3x | Xcode, Terminal, iTerm2, VS Code, Cursor, Figma, Logic Pro, Final Cut Pro |
| Normal | 1x | Everything not in another tier (default) |
| Distraction | 0x | Twitter/X, Reddit, TikTok, Instagram, YouTube (web matched by browser URL is out of scope — matched by app bundle ID only), Discord, Twitch |

- `AppTier` enum: `.deepWork`, `.normal`, `.distraction`
- Unknown apps default to `.normal`
- Stored in PetState as `appTierOverrides: [String: AppTier]` (only non-normal entries stored)
- Default tier list is hardcoded; user overrides merge on top

### App Detection

- 2-second polling timer reads `NSWorkspace.shared.frontmostApplication?.bundleIdentifier`
- Caches current `activeAppTier: AppTier` on GameSystems
- Same timer checks combo expiry (see below)
- No extra permissions needed — NSWorkspace is public API

### Settings UI

- New "Apps" tab (5th tab) in the panel
- Three columns: Deep Work, Normal, Distraction
- Shows currently running apps (via `NSWorkspace.shared.runningApplications`) with icons
- Tap an app to cycle its tier
- Changes persist immediately to PetState

## Deep Work Combo Counter

### Combo Stages

Based on sustained typing — any gap under 30 seconds keeps the combo alive:

| Stage | Sustained For | Multiplier | Badge Color |
|-------|--------------|-----------|-------------|
| None | <1 min | x1 | (hidden) |
| Warm | 1 min | x1.5 | grey |
| Focused | 5 min | x2 | blue |
| Deep | 15 min | x3 | orange |
| Flow | 30 min | x4 | gold + flame |

### State

- `comboStartTime: Date?` — when the current combo started (nil = no combo)
- `lastComboKeypressTime: Date?` — last keypress timestamp for timeout check
- Session-only, not persisted (resets on app restart)

### Timeout

- If no keypress for 30 seconds, combo resets to None
- Checked by the same 2-second polling timer as app detection
- Combo timer runs regardless of active app (switching to Twitter for <30s doesn't break combo)

### Visual (Party Strip)

- Small pill badge anchored right of lead Pokemon sprite
- Hidden at x1 (no visual clutter when idle)
- Scale-in animation when combo starts
- Color shifts through stages: grey → blue → orange → gold
- At Flow stage: small flame particle on lead Pokemon
- Fades out on combo break

## XP Formula

In `recordKeypress()`:

```
finalGain = max(Int(1.0 * streakMultiplier * fatigueMultiplier * appTierMultiplier * comboMultiplier), 0)
```

- Distraction (0x) zeroes out all XP regardless of combo
- Max possible: streak 2x * fatigue 1x * deep work 3x * flow 4x = **24x**
- Every 10th keystroke for lead, every 20th for party (current "chill" rate with multipliers on top)

## Edge Cases

- Combo survives distraction apps (time-based, not app-based) but earns 0 XP there
- App tier config persists across sessions; combo does not
- If user quits and relaunches, combo starts fresh
- Running apps list in settings only shows apps with bundle IDs (filters out background daemons)

## Files Changed

- `PetState.swift` — AppTier enum, appTierOverrides dictionary, default tier list
- `GameSystems.swift` — App polling timer, combo tracking state, updated XP formula
- `PartyStrip.swift` — Combo badge rendering + flame particle
- `AppDelegate.swift` — Wire up polling timer
- `StatsTabView.swift` — Show current tier + combo stage
- `PanelWindow.swift` — Add 5th tab
- New: `AppSettingsTabView.swift` — Tier configuration UI

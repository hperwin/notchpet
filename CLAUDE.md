# NotchPet — Claude Code Instructions

## What This Is

A macOS menu bar app — Pokemon that live in your Mac's notch area. They gain XP as you type. Built with Swift and AppKit.

**Requirements:** macOS 14+, Mac with a notch (MacBook Pro/Air 2021+), Xcode command line tools.

## Quick Install

If someone asks you to install/set up NotchPet, run these two commands:

```bash
./Scripts/bundle.sh   # builds the app
./Scripts/install.sh  # installs to /Applications and launches
```

That's it. The user will need to grant **Accessibility permission** when prompted:
- System Settings → Privacy & Security → Accessibility → enable NotchPet

If NotchPet doesn't appear in the Accessibility list, click **+** and select `/Applications/NotchPet.app`.

### If Xcode Command Line Tools aren't installed

```bash
xcode-select --install
```

Wait for the install to complete, then run the build/install commands above.

### If keyboard tracking isn't working

The app needs Accessibility permission to detect keystrokes. If typing isn't being tracked:

1. Open System Settings → Privacy & Security → Accessibility
2. Find NotchPet in the list
3. Toggle it **OFF**, then **ON**
4. Restart NotchPet (quit from menu bar, then reopen from /Applications)

This is required because macOS ties accessibility to the binary signature.

## How It Works

Pokemon sprites sit in the menu bar next to the notch (3 left, 3 right). Click one to open the panel.

### XP from Typing
- Every 25 keystrokes = 1 XP to lead Pokemon
- Every 75 keystrokes = 1 XP to other party members
- XP needed per level: `100 × 1.15^(level-1)` (exponential curve)

### Multipliers
- **App tiers**: Deep Work apps (Xcode, Terminal, VS Code) = 3x XP. Distraction apps (Twitter, Discord) = 0x. Configurable in the Apps tab.
- **Combo**: Keep typing without a 60s gap → x1.5 (30s), x2 (2min), x3 (5min), x4 (10min)
- **Streaks**: Typing daily builds a streak multiplier (1x → 1.2x → 1.5x → 2x)

### Panel Tabs
- **Party** — Your active Pokemon (up to 6), drag to reorder
- **Box** — All available Pokemon, tap to see details, add to party
- **Stats** — Typing stats, feeding stats, current focus info
- **Medals** — Achievements
- **Apps** — Configure which apps are Deep Work / Normal / Distraction

### Food
- Berries spawn near the notch periodically
- Drag a berry onto a Pokemon to feed it (15-30 XP)

## Project Structure

```
├── Package.swift                 ← SwiftPM manifest
├── Resources/
│   ├── Info.plist               ← App bundle metadata
│   └── (sprites, frames, etc.)
├── Scripts/
│   ├── bundle.sh                ← Build + create .app bundle
│   └── install.sh               ← Install to /Applications + launch
├── Sources/NotchPet/
│   ├── main.swift               ← Entry point
│   ├── AppDelegate.swift        ← Main coordinator, wires everything together
│   ├── KeyboardMonitor.swift    ← CGEvent tap for keystroke tracking
│   ├── GameSystems.swift        ← XP formula, combo tracker, app tier polling
│   ├── PetState.swift           ← All persisted state (Codable + UserDefaults)
│   ├── PartyStrip.swift         ← Menu bar Pokemon sprites + combo badge
│   ├── PanelWindow.swift        ← Drop-down panel with tabs
│   ├── PetCollection.swift      ← Available Pokemon registry
│   ├── FoodSpawner.swift        ← Berry spawning + drag-to-feed
│   ├── DSTabView.swift          ← Base class for panel tabs
│   ├── DesignTokens.swift       ← DS color/layout constants
│   ├── PartyTabView.swift       ← Party tab
│   ├── CollectionTabView.swift  ← Box tab
│   ├── StatsTabView.swift       ← Stats tab
│   ├── AchievementsTabView.swift ← Medals tab
│   ├── AppSettingsTabView.swift ← Apps tier config tab
│   ├── PokemonDetailView.swift  ← Pokemon detail screen
│   ├── PetView.swift            ← Pet sprite rendering
│   ├── PetWindow.swift          ← Borderless window for pet
│   ├── PetInteraction.swift     ← Click/drag handling
│   ├── WalkController.swift     ← (disabled) walk animation
│   ├── MoveData.swift           ← Pokemon move database
│   └── Preferences.swift        ← Auto-launch preferences
└── docs/                        ← Design specs and plans
```

## Key Architecture

- **PetState** is the single source of truth, persisted via UserDefaults (`com.notchpet.app` domain)
- **GameSystems** owns all game logic (XP, combos, achievements) and a 2s poll timer for app detection
- **KeyboardMonitor** uses a CGEvent tap (requires Accessibility) with a watchdog that detects stale taps
- **PartyStrip** manages 6 borderless NSWindows for the menu bar sprites
- All UI is programmatic AppKit — no storyboards, no SwiftUI

## Important Notes

- **No tests** — test target is commented out in Package.swift
- **Accessibility is critical** — without it, no keyboard tracking, no XP. The app prompts on launch but macOS often requires manual toggling after binary updates.
- **UserDefaults domain** — the app reads `com.notchpet.app` when launched from the .app bundle. Running the bare binary outside a bundle uses a different domain and won't see saved data.
- **CodingKeys** — PetState uses a tolerant custom `init(from:)` decoder. New properties get defaults if missing from saved data. Never add a required property without a default.

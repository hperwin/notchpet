# NotchPet

Pokemon that live in your Mac's notch. They level up as you type.

<img width="600" alt="NotchPet screenshot" src="https://github.com/user-attachments/assets/placeholder">

## Install with Claude Code

The easiest way to install NotchPet is with [Claude Code](https://claude.ai/code). Just paste this:

```
Clone https://github.com/hperwin/notchpet and install it for me
```

Claude will build it, install it, and walk you through setup.

## Manual Install

**Requirements:** macOS 14+, MacBook with a notch, Xcode command line tools

```bash
# 1. Install Xcode command line tools (if you don't have them)
xcode-select --install

# 2. Clone and install
git clone https://github.com/hperwin/notchpet.git
cd notchpet
./Scripts/install.sh
```

**After install:** Grant accessibility permission when prompted (System Settings → Privacy & Security → Accessibility → enable NotchPet). This lets NotchPet detect your typing.

## How It Works

- **Type to earn XP** — your Pokemon gain experience as you type on your keyboard
- **Build a party** — collect up to 6 Pokemon, each levels up independently
- **App-aware** — earn 3x XP in coding apps, 0x in distraction apps (customizable)
- **Combo system** — sustained typing builds a multiplier (up to 4x)
- **Feed your Pokemon** — drag berries that appear near the notch
- **Achievements** — unlock medals for typing milestones, streaks, and more

## Features

- Party of up to 6 Pokemon in the menu bar
- Per-Pokemon leveling with moves learned at each level
- App-aware XP multipliers (Deep Work 3x, Normal 1x, Distraction 0x)
- Combo counter (x1.5 → x2 → x3 → x4 for sustained typing)
- Daily typing and login streaks with multiplier bonuses
- Berry feeding system (drag to feed)
- 15 achievements across 3 tiers
- Weekly challenges
- Cosmetics and mutations
- WPM tracking

## Troubleshooting

**NotchPet doesn't track my typing:**
1. Open System Settings → Privacy & Security → Accessibility
2. Find NotchPet, toggle it OFF then ON
3. Restart NotchPet

**I don't see any Pokemon:**
Make sure you have a Mac with a notch (MacBook Pro/Air 2021 or later).

**Build fails:**
Make sure Xcode command line tools are installed: `xcode-select --install`

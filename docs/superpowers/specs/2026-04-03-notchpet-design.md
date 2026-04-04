# NotchPet — Design Spec

## Overview

A lightweight macOS menu bar app that renders an animated pixel-art blob character to the left of the MacBook notch. The pet sits on an all-black background so it appears as a physical extension of the notch itself.

**Target hardware:** MacBook 14" with notch (M-series, macOS 14+)

## Window

- Borderless `NSWindow` with no title bar, no shadow
- `window.level = .statusBar` (above menu bar items, below alerts)
- All-black background — blends seamlessly with the menu bar's black strip
- Positioned immediately to the left of the notch
- Size: ~40x37pt (fits within the 37pt menu bar height with the pet sprite centered)
- `window.collectionBehavior = [.canJoinAllSpaces, .stationary]` — visible on all desktops
- `window.ignoresMouseEvents = false` — accepts clicks for interaction

## Notch Detection

- Use `NSScreen.main.auxiliaryTopLeftArea` or `NSScreen.main.safeAreaInsets` to detect the notch position and width
- Fallback: hardcode notch position for 14" MacBook (notch is centered, ~180pt wide)
- Position the window's right edge flush with the notch's left edge

## Pet Sprite

- Source image: `Generated Image April 03, 2026 - 5_14PM - Edited.png`
- White background removed at build time (or load as asset with transparency)
- Rendered via SpriteKit `SKSpriteNode` inside an `SKView` with transparent scene background, on top of the black window
- Scaled to ~32pt tall, aspect ratio preserved

## Idle Animations (all run concurrently, looping)

| Animation | Description | Timing |
|-----------|-------------|--------|
| Breathing | Scale pulse 1.0 to 1.05 to 1.0 | ~3s cycle, continuous |
| Blinking | Eyes close briefly (overlay a "closed eyes" shape or scale Y on eye region) | ~0.15s duration, every 4-6s (randomized) |
| Wiggle | Rotation -3 deg to +3 deg | ~5s cycle, continuous |

Since we have a single sprite (no sprite sheet), blinking will be simulated by briefly overlaying small black rectangles over the eye positions, or by a quick vertical squash of the sprite (scale Y to 0.95 and back). The breathing and wiggle use standard SpriteKit actions.

## Interactions

### Click (left-click)
- Squish: compress vertically (scaleY to 0.7), then spring back with slight overshoot (scaleY 1.1 to 1.0)
- Duration: ~0.3s total

### Right-click (context menu)
Native `NSMenu` with items:
- **Animation Speed** — submenu: Slow / Normal / Fast
- **Auto-Launch** — toggle checkmark (adds/removes from Login Items)
- **Quit NotchPet**

### Draggable
- The window can be repositioned horizontally along the menu bar by click-dragging
- Constrained to the top edge of the screen (y position locked)
- Position saved to `UserDefaults` and restored on launch

### Walking (occasional)
- Every 2-5 minutes (randomized), the pet walks a short distance (~30-50pt) left or right along the menu bar
- Walking animation: alternating slight left/right tilt + horizontal translation
- Returns to its home position (or the new position becomes home)
- Does NOT walk if the user has manually dragged the pet recently (cooldown: 1 minute)

## System Integration

### No Dock Icon
- `LSUIElement = true` in Info.plist — no Dock icon, no app switcher entry

### Auto-Launch
- Uses `SMAppService.mainApp` (macOS 13+) to register/unregister as a Login Item
- Enabled by default on first launch
- Toggleable via right-click menu

### Memory & Performance
- Target: <20MB RAM, <1% CPU idle
- SpriteKit renders at 30fps (no need for 60fps for subtle animations)
- No network access, no background tasks beyond animation

## Tech Stack

- **Language:** Swift 5.9+
- **UI:** AppKit (NSWindow) + SpriteKit (animations)
- **Build:** Xcode project or Swift Package (single target macOS app)
- **Minimum macOS:** 14.0 (Sonoma)
- **Repo:** `~/Developer/NotchPet`

## Asset Pipeline

1. Copy the source PNG into the Xcode asset catalog
2. Remove white background (either manually before adding, or programmatically at load time using CGImage color replacement)
3. Export as `blob.png` in the asset catalog with @2x variant for Retina

## File Structure

```
NotchPet/
  NotchPet.xcodeproj
  NotchPet/
    App.swift              -- @main, NSApplication delegate, window setup
    PetWindow.swift        -- NSWindow subclass (borderless, black, positioned)
    PetScene.swift         -- SKScene with sprite, animations, click handling
    MenuManager.swift      -- Right-click NSMenu (quit, speed, auto-launch)
    NotchDetector.swift    -- Finds notch position on screen
    WalkController.swift   -- Timer-based walking behavior
    Assets.xcassets/
      blob.imageset/       -- Pet sprite (transparent PNG)
    Info.plist             -- LSUIElement = true
  docs/
    superpowers/specs/
      2026-04-03-notchpet-design.md
```

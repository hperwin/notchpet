# UI Overhaul Implementation Plan

> **For agentic workers:** Dispatch 5 parallel agents, one per task. Each agent owns specific files and must not modify files owned by other agents.

**Goal:** Complete UI consistency pass — full retro Pokemon GBA/DS aesthetic across all panel tabs, fix all layout bugs, add hover states, establish consistent design tokens.

**Architecture:** Each tab view is rewritten to use shared design tokens from a new `DesignTokens.swift` file. Panel resized to 580×500pt. Bottom nav redesigned as retro DS buttons. All cards get consistent green borders, spacing, and hover states.

**Tech Stack:** Swift, AppKit, Core Animation

---

## Shared Design Tokens (used by ALL tasks)

```swift
// Sources/NotchPet/DesignTokens.swift
enum DS {
    // Spacing
    static let outerPad: CGFloat = 10
    static let cardGap: CGFloat = 8
    static let innerPad: CGFloat = 12
    
    // Cards
    static let cardBg = NSColor(red: 0x1a/255, green: 0x1a/255, blue: 0x1a/255, alpha: 1)
    static let cardRadius: CGFloat = 10
    static let cardBorderColor = NSColor(red: 0x28/255, green: 0x68/255, blue: 0x28/255, alpha: 1)
    static let cardBorderWidth: CGFloat = 1
    
    // Colors
    static let gold = NSColor(red: 0xF8/255, green: 0xA8/255, blue: 0x00/255, alpha: 1)
    static let textPrimary = NSColor.white
    static let textSecondary = NSColor(red: 0x88/255, green: 0x88/255, blue: 0x88/255, alpha: 1)
    static let greenFill = NSColor(red: 0x48/255, green: 0xD0/255, blue: 0x48/255, alpha: 1)
    static let barTrack = NSColor(red: 0x1a/255, green: 0x1a/255, blue: 0x1a/255, alpha: 1)
    
    // Party card greens
    static let cardGreenTop = NSColor(red: 0x48/255, green: 0xB0/255, blue: 0x48/255, alpha: 1)
    static let cardGreenBot = NSColor(red: 0x38/255, green: 0xA0/255, blue: 0x38/255, alpha: 1)
    static let cardGreenBorder = NSColor(red: 0x28/255, green: 0x68/255, blue: 0x28/255, alpha: 1)
    
    // DS blue (nav bar)
    static let navBlueTop = NSColor(red: 0x30/255, green: 0x58/255, blue: 0x90/255, alpha: 1)
    static let navBlueBot = NSColor(red: 0x20/255, green: 0x40/255, blue: 0x70/255, alpha: 1)
    static let navActiveGreenTop = NSColor(red: 0x48/255, green: 0xB0/255, blue: 0x48/255, alpha: 1)
    static let navActiveGreenBot = NSColor(red: 0x38/255, green: 0xA0/255, blue: 0x38/255, alpha: 1)
    static let navInactiveTop = NSColor(red: 0x40/255, green: 0x68/255, blue: 0x98/255, alpha: 1)
    static let navInactiveBot = NSColor(red: 0x30/255, green: 0x50/255, blue: 0x80/255, alpha: 1)
    
    // PC Box teal
    static let boxTealTop = NSColor(red: 0x2D/255, green: 0x8B/255, blue: 0x6E/255, alpha: 1)
    static let boxTealBot = NSColor(red: 0x1A/255, green: 0x6B/255, blue: 0x4A/255, alpha: 1)
    static let boxCellBg = NSColor(red: 0x1A/255, green: 0x4A/255, blue: 0x3A/255, alpha: 1)
    
    // Pill
    static let pillBg = NSColor(red: 0x1A/255, green: 0x3A/255, blue: 0x1A/255, alpha: 1)
    static let pillRadius: CGFloat = 6
    
    // Bars
    static let barHeight: CGFloat = 4
    static let barRadius: CGFloat = 2
    
    // Hover
    static let hoverColor = gold
    
    // DS text shadow
    static func dsShadow() -> NSShadow {
        let s = NSShadow()
        s.shadowColor = NSColor.black.withAlphaComponent(0.6)
        s.shadowOffset = NSSize(width: 1, height: -1)
        s.shadowBlurRadius = 0
        return s
    }
    
    // Helper: make a standard card view
    static func makeCard(frame: NSRect) -> NSView {
        let v = NSView(frame: frame)
        v.wantsLayer = true
        v.layer?.backgroundColor = cardBg.cgColor
        v.layer?.cornerRadius = cardRadius
        v.layer?.borderColor = cardBorderColor.cgColor
        v.layer?.borderWidth = cardBorderWidth
        return v
    }
    
    // Helper: make a label with DS shadow
    static func label(_ text: String, size: CGFloat, bold: Bool = false, color: NSColor = .white) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        l.textColor = color
        l.drawsBackground = false
        l.isBordered = false
        l.isEditable = false
        l.shadow = dsShadow()
        return l
    }
    
    // Helper: HP/XP bar
    static func makeBar(in parent: NSView, x: CGFloat, y: CGFloat, width: CGFloat, progress: Double) {
        let w = max(width, 20) // clamp minimum
        let track = NSView(frame: NSRect(x: x, y: y, width: w, height: barHeight))
        track.wantsLayer = true
        track.layer?.backgroundColor = barTrack.cgColor
        track.layer?.cornerRadius = barRadius
        parent.addSubview(track)
        let fillW = w * CGFloat(min(max(progress, 0), 1))
        if fillW > 0 {
            let fill = NSView(frame: NSRect(x: 0, y: 0, width: fillW, height: barHeight))
            fill.wantsLayer = true
            fill.layer?.backgroundColor = greenFill.cgColor
            fill.layer?.cornerRadius = barRadius
            track.addSubview(fill)
        }
    }
}
```

---

## Task 1: Design Tokens + Panel Resize + Retro Nav

**Files:**
- Create: `Sources/NotchPet/DesignTokens.swift`
- Modify: `Sources/NotchPet/PanelWindow.swift`

**What to do:**
1. Create `DesignTokens.swift` with all shared tokens above
2. In PanelWindow: change `panelMaxHeight` from 420 to 500, `panelWidth` from 520 to 580
3. Replace the SF Symbols TabBarButton with retro DS-style buttons:
   - Bar: DS blue gradient background (#305890 → #204070), 1pt light blue top border
   - Active button: green gradient (#48B048 → #38A038), dark text, bold 11pt
   - Inactive button: blue gradient (#406898 → #305080), white text, bold 11pt
   - No spacing between buttons, thin dark divider lines
   - Each button fills full height, full section width
   - Text has DS shadow
4. Remove the TabBarButton SF Symbol class entirely
5. Fix tab switching: use `frame = tabContentArea.bounds` + `autoresizingMask = [.width, .height]` (already done, just verify)

---

## Task 2: Party Tab Rewrite

**Files:**
- Modify: `Sources/NotchPet/PartyTabView.swift`

**What to do:**
1. Use `DS` tokens for all colors, spacing, corners
2. Background: sky blue gradient via CAGradientLayer (#78C8F0 → #60B0E0)
3. Layout: 2 columns × 3 rows, all cards SAME size
   - Available: 580 - 2*10 padding = 560pt wide, ~448pt tall (500 - 52 nav)
   - Card width: (560 - 8 gap) / 2 = 276pt
   - Card height: (420 - 8*2 gaps) / 3 = ~134pt (adjust to fit)
4. Each card: green gradient, 2pt green border, 10pt corners
   - Pokeball icon (12pt) top-left
   - Sprite (48pt) left-center
   - Name (12pt bold white, DS shadow) right of sprite
   - "Lv.X" (10pt white) below name
   - HP bar at bottom (green fill, dark track, DS.makeBar)
5. Card 0: small gold "LEAD" pill (DS.pillBg, 6pt corners) at top-right
6. Empty cards: dashed gray border, "Empty" centered
7. Register hit regions for all cards
8. `override var isFlipped: Bool { true }`

---

## Task 3: Collection Tab Rewrite

**Files:**
- Modify: `Sources/NotchPet/CollectionTabView.swift`

**What to do:**
1. Use `DS` tokens
2. Background: teal gradient via CAGradientLayer (DS.boxTealTop → DS.boxTealBot)
3. Header: "BOX 1" centered (14pt bold white, DS shadow)
4. Grid: 6 columns × 5 rows, cells are DS.boxCellBg (#1A4A3A), 8pt corners, 4pt gaps
   - Available width: 580 - 2*10 = 560pt. Cell: (560 - 5*4) / 6 = ~90pt
5. Each cell: sprite (52pt) centered, name (9pt white DS shadow) below
6. Party members: 2pt gold border
7. Per-pokemon level shown: "Lv.X" if instance exists
8. Scrollable (NSScrollView with FlippedView)
9. Fix hit detection: use `contentView.convert(event.locationInWindow, from: nil)`
10. `disableHoverTracking = true`, `isFlipped = true`

---

## Task 4: Stats Tab Rewrite

**Files:**
- Modify: `Sources/NotchPet/StatsTabView.swift`

**What to do:**
1. Use `DS` tokens — all cards use DS.makeCard with green border
2. Background: #0d0d0d
3. Cards have 1pt green border (DS.cardBorderColor) — retro touch
4. Layout for 580×448pt content area:
   - Top: two cards side by side (~280×140pt each)
   - Bottom: full-width party roster (~560×280pt)
5. Typing card: gold header, big word count centered, pills at bottom in dark green bg (DS.pillBg)
6. Feeding card: gold header, big berry count, compact per-pokemon summary
7. Party roster: 6 rows, each: sprite (24pt) + name + Lv.X + XP bar + xp/total + move name
   - XP bar width clamped: `max(barWidth, 20)`
8. `isFlipped = true`

---

## Task 5: Achievements Tab Rewrite + Detail View Fixes

**Files:**
- Modify: `Sources/NotchPet/AchievementsTabView.swift`
- Modify: `Sources/NotchPet/PokemonDetailView.swift`

**Achievements:**
1. Use `DS` tokens — cards with green border
2. Background: #0d0d0d
3. Header: "Achievements" + gold pill badge with count
4. Rows: DS.makeCard, 50pt height, 1pt green border
5. Unlocked icon: pokeball-style circle (red top, white bottom) 28pt — or simpler: tier-colored circle with white "✓"
6. Locked icon: dark gray circle (#252525) with gray "○"
7. Unlocked right: green "Done" pill
8. Locked right: green progress bar (DS.greenFill) + "X/Y" text
9. Scrollable
10. `isFlipped = true`, `disableHoverTracking = true`

**Detail View:**
1. Fix idle bounce timer: cancel on `removeFromSuperview` or use weak self properly
2. Add button disabled state: if party full and not in party, button grayed out with "Party Full" text
3. Type badge contrast: add 1pt dark border around light-colored type badges
4. Cards: use DS.cardBorderColor for consistency

---

## Execution: 5 Parallel Agents

| Agent | Task | Files Owned |
|-------|------|-------------|
| 1 | Design Tokens + Panel + Nav | `DesignTokens.swift`, `PanelWindow.swift` |
| 2 | Party Tab | `PartyTabView.swift` |
| 3 | Collection Tab | `CollectionTabView.swift` |
| 4 | Stats Tab | `StatsTabView.swift` |
| 5 | Achievements + Detail | `AchievementsTabView.swift`, `PokemonDetailView.swift` |

Agent 1 goes first (creates DesignTokens.swift). Agents 2-5 can run in parallel after — they all import DS tokens.

## Verification
1. `swift build` passes
2. Panel opens at 580×500pt
3. All 4 tabs render correctly with retro Pokemon aesthetic
4. Bottom nav: retro green/blue buttons, full height
5. All cards have consistent green borders
6. Hover shows gold outline on all clickable elements
7. Collection tab scrolls and clicks work properly
8. Stats XP bars don't overflow or go negative
9. Achievement progress bars show correct values
10. Detail view bounce timer doesn't leak

# NotchPet UI Overhaul — Full Retro Pokemon Design Spec

## Overview
Complete UI consistency pass across all panel tabs. Full commitment to retro Pokemon GBA/DS aesthetic. Fix all layout bugs, add hover states, establish consistent design tokens.

## Panel
- Size: 580×500pt (up from 520×420)
- Background: #0d0d0d
- Bottom nav: 52pt, DS dark blue gradient, 4 chunky retro buttons (full-height fills, green/gold active, blue inactive, pixel-style bold text)

## Design Tokens (applied everywhere)
- Outer padding: 10pt
- Card gaps: 8pt
- Card inner padding: 12pt
- Card bg: #1a1a1a
- Card corners: 10pt
- Card border: 1pt #286828 (green, retro unifier)
- Text primary: white
- Text secondary: #888888
- Text headers/accent: #F8A800 (gold)
- Text shadow: DS-style (1px right, 1px down, black 60%)
- Pill corners: 6pt
- XP/HP bars: #48D048 fill, #1a1a1a track, 4pt tall, 2pt corners
- Hover: gold outline #F8A800, pointer cursor, on ALL clickable elements

## Party Tab
- Background: sky blue gradient (#78C8F0 → #60B0E0)
- Layout: 2 columns × 3 rows, all 6 cards SAME size
- Cards: green gradient (#48B048 → #38A038), 2pt border #286828, 10pt corners
- Each card: pokeball icon (top-left), sprite (48pt), name (bold white DS shadow), "Lv.X", HP bar
- Card 0: small gold "LEAD" pill badge, same dimensions as others
- Empty: dashed gray border, "Empty" text

## Box/Collection Tab
- Background: DS PC Box teal/green gradient (#2D8B6E → #1A6B4A)
- Header: "BOX 1" centered, white DS shadow
- Grid: 6 cols × 5 rows, dark cells (#1A4A3A), 4pt gaps
- Sprites centered, name below (white DS shadow)
- Party members: 2pt gold border
- Scrollable

## Stats Tab
- Background: #0d0d0d
- Cards: #1a1a1a, 12pt corners, 1pt green border #286828
- Layout: two cards top (Typing + Feeding), full-width Party roster below
- Headers: gold, XP bars: green
- Pills: dark green bg #1A3A1A

## Achievements Tab
- Background: #0d0d0d
- Rows: #1a1a1a, 10pt corners, 1pt green border #286828
- Icons: pokeball-style circles (red/white unlocked, gray locked)
- Progress bars: green fill on dark track
- Scrollable

## Pokemon Detail View
- Keep environment backgrounds
- Fix: bounce timer cleanup, button disabled states, type badge contrast
- Cards: same green border treatment

## Bug Fixes
- XP bar width: clamp min 20pt
- Card layout: proper math, no overflow
- Tab switch: renders immediately (no blank)
- Scroll hit detection: proper coordinate conversion
- Button disabled state when party full
- Hover states on all clickable elements
- Consistent spacing throughout (no magic numbers)

## Bottom Nav (Retro DS Style)
- Height: 52pt
- Background: DS dark blue gradient (#305890 → #204070)
- Light blue top border accent (1pt)
- 4 buttons: full-height, fill entire section
- Active: green gradient (#48B048 → #38A038) with dark text
- Inactive: blue gradient (#406898 → #305080) with white text
- Bold 11pt text, DS shadow
- No spacing between buttons, thin dark divider lines

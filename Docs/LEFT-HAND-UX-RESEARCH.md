# Left-Hand One-Handed Mobile UX Research

**Date:** 2026-04-15
**Context:** Simpod podcast player — optimizing all button placement for left-handed, one-handed use on iPhone 15 Pro Max (6.7" screen)
**Sources:** Smashing Magazine, UX Movement, Scott Hurff, Steven Hoober, Josh Clark, Marco Arment (Overcast), Castro design reviews, Spotify Community forums, Samsung Community, AppleVis, Pocket Casts source code, AntennaPod issues, Apple HIG

---

## Key Statistics

- **49%** of users hold their phone with one hand (Hoober)
- **75%** of all interactions are thumb-driven (Clark)
- **33%** of one-handed use is LEFT thumb — 3x the left-handed population, because right-handers hold left while dominant hand is busy (commuting, carrying, eating)
- On a 6.7" phone, one-handed thumb reach covers only **40-50%** of the screen

---

## Left Thumb Zone Map (iPhone 15 Pro Max)

```
+---------------------------+
|                           |  DEAD ZONE
|     DEAD / UNREACHABLE    |  Top 25-30%
|   (top-right is worst)    |  Requires grip shift
|                           |  or Reachability
+---------------------------+
|           |               |  STRETCH ZONE
|  STRETCH  |  HARD         |  Middle 30-40%
|  (ok-ish) |  STRETCH      |  Reachable with effort
|           |               |
+---------------------------+
|           |               |  HOT ZONE
|   HOT     |  EASY         |  Bottom 30%
|  (best)   |               |  Natural thumb arc
+---------------------------+
  LEFT          RIGHT
```

**Hot zone:** Bottom-left quadrant. The left thumb's natural resting arc sweeps from bottom-left to bottom-center.

**Combined safe zone (both hands):** Bottom-center strip is the ONLY area comfortable for both left AND right thumbs. This is where the most critical controls must live.

---

## Conclusions for Podcast/Music Player Design

### 1. Playback Controls: Center-Bottom, Always

| Control | Placement | Rationale |
|---------|-----------|-----------|
| Play/Pause | Bottom-center, largest target | Universal expectation; hottest zone for both hands |
| Skip back | Left of play/pause | Natural arc for left thumb |
| Skip forward | Right of play/pause | Natural arc for right thumb |
| Next episode | Adjacent to skip-forward | Secondary action, still in hot zone |

**Anti-pattern:** Spotify moved play to far-left — users nearly dropped phones reaching across. Play MUST be centered.

**Tap targets:** Minimum 44x44pt (Apple HIG), prefer 48x48pt. Spacing: 12pt minimum between buttons to prevent mis-taps.

### 2. Mini Player: Bottom-Docked, Content-Aware

- Use `safeAreaInset(edge: .bottom)` — content pushes up automatically, no overlay
- Position above tab bar (standard iOS pattern, used by Pocket Casts, Overcast, Apple Music)
- Controls centered horizontally within the mini player bar
- Expand to full player via upward drag gesture (tap also works)

### 3. Tab Bar: Standard Bottom, 4-5 Tabs Max

- Tab bar sits in the natural thumb zone for both hands — never move it
- Most-used tabs toward center (reachable by both thumbs)
- iOS standard: leftmost tab is "home" (Inbox), rightmost is Settings
- Badge counts on tabs are glanceable without interaction

### 4. Inline Actions Over Modal Sheets

**Castro's tap-to-reveal** is the gold standard for podcast episode actions:
- Tap episode row -> action bar expands inline below (not a modal)
- Actions are discoverable (new users find them instantly)
- No overlay means no loss of context
- Dismisses by tapping again or tapping a different episode

**Why not sheets/modals:**
- Sheets require reaching the top of the screen to dismiss (dead zone)
- Sheets obscure the list context
- Extra animation step adds friction

### 5. Swipe Actions Are Hand-Agnostic

- Horizontal swipes work equally well with either hand
- Best for binary triage: swipe-right = positive (Queue), swipe-left = negative (Archive)
- Short swipe reveals buttons; full swipe triggers default action (Pocket Casts pattern)
- Keep swipe actions to 2-3 per edge maximum

### 6. Toolbar Items: Bottom, Not Top

- Move context actions from `.navigationBarTrailing` to `.toolbar { ToolbarItemGroup(placement: .bottomBar) }`
- Top-bar interactive elements are in the dead zone on 6.7" phones
- Navigation titles and search bars are decorative (read-only) — OK at top
- Use `.searchable` with pull-down activation so users don't reach up

### 7. Destructive Actions: Intentional Friction

- Place destructive actions (delete, unsubscribe) in stretch zones — middle or upper screen
- Require confirmation dialogs for irreversible actions
- Use swipe-to-delete (standard iOS) — the gesture itself provides friction
- Never place destructive actions adjacent to primary actions

### 8. Common User Workarounds (Design Should Eliminate These)

| Workaround | What It Tells Us |
|------------|-----------------|
| iOS Reachability (swipe down on home indicator) | Top controls are too high |
| Headphone/AirPods controls | Screen controls are too hard to reach |
| Apple Watch for playback | Phone UI has too much friction |
| Learning to use right hand | App doesn't accommodate left hand at all |
| PopSocket/ring grip | Phone is too big for native thumb reach |

**If users need these workarounds, the UI has failed.**

---

## Simpod-Specific Design Rules

### Mini Player
- Controls centered horizontally: `[<<15] [Play/Pause] [30>>] [Next]`
- 48pt tap targets with 12pt spacing
- Episode title + podcast name to the right of controls
- Tap anywhere on info area opens full NowPlayingView
- Docked at bottom via `safeAreaInset`, above tab bar

### Episode Row Actions (Inline Bar)
- Tap episode -> action icons expand below the row, pushing list content down
- Icons centered in the expanded area (bottom-center of viewport during interaction)
- Tap again or tap different episode to collapse
- No modal, no sheet, no overlay

### Inbox Swipe Actions
- Swipe right (trailing): Queue (blue) — positive triage
- Swipe left (leading): Archive (orange) — negative triage
- These are hand-agnostic by nature

### Queue Swipe Actions
- Swipe left: Remove from queue
- Reorder via drag handle (standard iOS List)

### Navigation
- Tab bar at bottom: Inbox | Queue | Reminders | Search | Settings
- Most-used (Inbox, Queue) on the left — favors left thumb
- Add Podcast (+) button: move from top-right toolbar to bottom toolbar or prominent position in Inbox empty state

### Full NowPlaying View
- Controls in bottom third of screen
- Progress scrubber in middle third (visual, not primary interaction)
- Artwork in top third (decorative, no interaction needed)
- Dismiss via swipe-down from anywhere (no corner X button)

---

## Reference Implementations

| App | Pattern | Why It Works |
|-----|---------|-------------|
| **Overcast** | Enlarged targets, card-based dismiss, bottom controls | Explicit one-handed design by Marco Arment |
| **Castro** | Tap-to-reveal inline toolbar, swipe triage | Gesture-heavy = hand-agnostic |
| **Pocket Casts** | `SwipeActionsHelper` centralizes all swipe logic, bottom mini player | Clean architecture, consistent gestures |
| **Apple Music** | `safeAreaInset` mini player, standard tab bar | Native iOS patterns, no surprises |

---

## Design Gate Checklist (for Simpod UI reviews)

Before any UI ships, verify against these left-hand criteria:

- [ ] All primary actions are in the bottom 40% of the screen
- [ ] Play/Pause is centered horizontally
- [ ] No interactive elements in the top-right corner (dead zone for left thumb)
- [ ] Tap targets are >= 44x44pt (prefer 48pt)
- [ ] Spacing between adjacent buttons >= 12pt
- [ ] Destructive actions are NOT adjacent to primary actions
- [ ] Modals/sheets dismiss via swipe-down (not corner X only)
- [ ] Tab bar is at the bottom with <= 5 tabs
- [ ] Swipe actions are used for binary choices (hand-agnostic)
- [ ] No controls require two-handed interaction

---

*This document should be referenced for all future UI decisions in Simpod and any project using the v6.2 framework.*

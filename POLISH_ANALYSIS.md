# Stakd: Polish Analysis & Improvement Plan

**Date:** 2026-02-06  
**Status:** MVP Built, Needs Polish  
**Goal:** Polished, ship-ready puzzle game

---

## Current State Assessment

### ✅ What's Built (Solid Foundation)
| Component | Status | Notes |
|-----------|--------|-------|
| Core game loop | ✅ Complete | Tap-to-select, move, clear mechanics |
| Level generator | ✅ Complete | Procedural, solvable verification |
| Game state | ✅ Complete | Undo, move history, win detection |
| Home screen | ✅ Complete | Logo, buttons, level indicator |
| Game screen | ✅ Complete | Board, top bar, bottom controls |
| Level select | ✅ Complete | Grid layout, locked/unlocked states |
| Settings | ✅ Complete | Sound, music, stats, about |
| Ad service | ✅ Skeleton | Test IDs, interstitial + rewarded |
| Audio service | ✅ Skeleton | API ready, no actual sounds |
| Storage service | ✅ Complete | SharedPreferences persistence |

### 🔴 Critical Missing (Must Fix Before Launch)
| Item | Priority | Impact |
|------|----------|--------|
| Sound effects (5 files) | P0 | Game feels dead without audio |
| Layer move animation | P0 | Movement is instant, jarring |
| Production AdMob IDs | P0 | Can't monetize with test IDs |
| App icon | P0 | Required for store |
| Privacy policy URL | P0 | Required for Play Store |

### 🟡 Important Missing (Should Have)
| Item | Priority | Impact |
|------|----------|--------|
| Particle effects on clear | P1 | Major juice factor |
| Tutorial/onboarding | P1 | First-time users confused |
| Screen shake on win | P1 | Celebration feels flat |
| Combo system | P1 | Adds depth, replay value |
| Better hint visualization | P1 | Current snackbar is weak |
| IAP (Remove Ads) | P1 | Additional revenue |
| Rate app prompt | P1 | Reviews drive downloads |

### 🟢 Nice to Have (Polish)
| Item | Priority | Impact |
|------|----------|--------|
| Daily challenge mode | P2 | Retention mechanic |
| Theme packs | P2 | Cosmetic IAP |
| Cloud save | P2 | Cross-device play |
| Leaderboards | P2 | Social competition |
| Achievements | P2 | Goals to chase |
| Share score | P2 | Organic growth |
| Colorblind mode | P2 | Accessibility |

---

## Deep Dive: Feature Requirements

### 1. Animation System
**Current:** Instant layer movement, basic selection bounce  
**Needed:**
- Smooth layer slide from source to destination (200-300ms)
- Arc trajectory for visual interest
- Squash & stretch on landing
- Stack jiggle when receiving layer
- Simultaneous multi-layer moves for efficiency

**Implementation:**
```dart
// AnimatedPositioned for layer movement
// Use TweenAnimationBuilder for arc path
// Add scale animation for squash/stretch
```

### 2. Particle Effects
**Current:** None  
**Needed:**
- Burst of colored particles on stack clear
- Confetti rain on level complete
- Sparkle trail during layer movement (optional)
- Screen-edge glow on win

**Implementation:**
- Use `flutter_animate` or custom `CustomPainter`
- Pre-render particle sprites for performance
- Pool particles to avoid GC stutters

### 3. Sound Design
**Required sounds (5 minimum):**
| Sound | Trigger | Character |
|-------|---------|-----------|
| tap.mp3 | Stack selection | Soft click, satisfying |
| slide.mp3 | Layer moving | Whoosh, quick |
| clear.mp3 | Stack completes | Sparkle chime |
| win.mp3 | Level complete | Triumphant fanfare |
| error.mp3 | Invalid move | Soft buzz/thunk |

**Nice to have:**
| Sound | Trigger |
|-------|---------|
| combo.mp3 | Multiple clears in sequence |
| unlock.mp3 | New level unlocked |
| music.mp3 | Background loop (chill/ambient) |

### 4. Tutorial System
**Flow:**
1. First launch → show tutorial overlay
2. Highlight first stack: "Tap to select"
3. Highlight valid destination: "Tap to move"
4. Show clear animation: "Match colors to clear!"
5. Point to undo: "Made a mistake? Undo here"
6. "You're ready! Have fun!"

**Implementation:**
- Coach marks with spotlight effect
- State machine: `TutorialStep.selectStack` → `TutorialStep.moveLayer` → etc.
- Store `tutorialCompleted` in SharedPreferences

### 5. Combo System
**Mechanics:**
- Track consecutive clears within X seconds
- 2x, 3x, 4x multiplier badges
- Bonus points (for potential leaderboard)
- Combo text popup with scale animation

**Visual:**
- "COMBO x2!" floating text
- Screen pulse on high combos
- Sound escalation (higher pitch per combo)

### 6. Hint System Upgrade
**Current:** Snackbar text "Move from stack 3 to 5"  
**Needed:**
- Animated arrow from source to destination
- Pulse glow on suggested stacks
- Optional: cost 1 hint (earn via rewarded ad)
- Hint counter in UI

### 7. IAP Implementation
**Products:**
| SKU | Price | Effect |
|-----|-------|--------|
| remove_ads | $3.99 | Disable interstitials forever |
| theme_neon | $0.99 | Neon color palette |
| theme_pastel | $0.99 | Soft pastel palette |
| hint_pack_10 | $1.99 | 10 hints |

**Implementation:**
- Use `in_app_purchase` package
- Verify purchases server-side (or use RevenueCat)
- Store entitlements in SharedPreferences + verify on launch

### 8. Review Prompt
**Trigger conditions (any):**
- Level 10 completed
- 5 sessions
- 50 total moves

**Flow:**
- "Enjoying Stakd?" → Yes/No
- Yes → Open store review
- No → Feedback form (optional)

---

## Visual Polish Checklist

### Home Screen
- [ ] Animated logo (stacks shuffle periodically)
- [ ] Particle background (subtle floating orbs)
- [ ] Button hover/press animations
- [ ] Daily challenge banner (when implemented)

### Game Screen
- [ ] Stack entrance animation (stagger from bottom)
- [ ] Layer slide animation with arc
- [ ] Clear burst particles
- [ ] Move counter increment animation
- [ ] Undo button shake when available

### Level Select
- [ ] Locked level shake on tap
- [ ] Star rating display (based on moves)
- [ ] Page indicator dots
- [ ] Smooth scroll physics

### Win Overlay
- [ ] Confetti rain
- [ ] Trophy/star animation
- [ ] Move count with "Best: X" comparison
- [ ] Share button
- [ ] Sound fanfare

---

## Technical Debt

1. **Type safety:** `dynamic` used for stack.layers in game_board.dart
2. **Error handling:** No try-catch around storage/audio operations
3. **Memory:** Celebration overlay doesn't dispose animations
4. **Testing:** Only 1 widget test, no unit tests for level generator
5. **Accessibility:** No Semantics labels
6. **Localization:** All strings hardcoded

---

## Asset Requirements

### Sound Files Needed
```
assets/sounds/
├── tap.mp3        (50ms, click)
├── slide.mp3      (200ms, whoosh)
├── clear.mp3      (300ms, sparkle)
├── win.mp3        (1s, fanfare)
├── error.mp3      (100ms, buzz)
└── music.mp3      (60s loop, ambient)
```

### Image Assets Needed
```
assets/images/
├── logo.png           (512x512, app icon source)
├── feature_graphic.png (1024x500, Play Store)
├── screenshot_1.png    (phone mockup)
├── screenshot_2.png
├── screenshot_3.png
└── particles/
    ├── sparkle.png
    └── confetti.png
```

### App Icon
- Foreground: Colorful stacked layers
- Background: Dark gradient matching app theme
- Sizes: 48, 72, 96, 144, 192, 512 (or use adaptive icon)

---

## Sprint Plan

### Sprint 1: Core Polish (Day 1-2)
- [ ] Create/source sound effects
- [ ] Implement layer slide animation
- [ ] Add stack clear particles
- [ ] Win screen confetti

### Sprint 2: UX Polish (Day 3-4)
- [ ] Tutorial system
- [ ] Better hint visualization
- [ ] Review prompt
- [ ] Combo system

### Sprint 3: Monetization (Day 5-6)
- [ ] Production AdMob IDs
- [ ] IAP integration
- [ ] Remove ads purchase flow

### Sprint 4: Store Prep (Day 7-8)
- [ ] App icon design
- [ ] Screenshots
- [ ] Feature graphic
- [ ] Privacy policy
- [ ] Store listing copy

---

## Success Metrics

### Minimum Viable Polish
- [ ] All P0 items complete
- [ ] Game feels "juicy" (satisfying feedback)
- [ ] No crashes in 10 consecutive plays
- [ ] Load time < 3 seconds
- [ ] Ads showing correctly

### Launch Ready
- [ ] All P0 + P1 items complete
- [ ] 4.0+ star potential (based on beta feedback)
- [ ] Store assets approved
- [ ] Privacy policy live
- [ ] AdMob account verified

---

*Analysis by Walt | 2026-02-06*

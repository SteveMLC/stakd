# Stakd: Color Sort Puzzle — Build Plan

**Status:** 🚧 IN PROGRESS  
**Started:** 2026-02-06 17:15 EST  
**Target:** MVP in 8-10 days  
**Owner:** Walt (autonomous build)

---

## Overview

**App Name:** Stakd: Color Sort Puzzle  
**Package:** com.go7studio.stakd  
**Platform:** Android (iOS later)  
**Tech Stack:** Flutter + Dart  

---

## Core Loop (10-20 seconds)

1. **See** — Grid of stacks with mixed-color layers
2. **Think** — Plan which layers to move
3. **Tap** — Select source stack, tap destination
4. **Clear** — Solid color stack clears with celebration
5. **Win** — Clear all stacks to complete level

---

## MVP Feature Set

### Must Have (v1.0)
- [ ] Core sorting mechanic
- [ ] Procedural level generator (100+ levels)
- [ ] 5-6 color palette
- [ ] Basic animations (layer slide, stack clear)
- [ ] Sound effects (tap, slide, clear, win)
- [ ] Level select screen
- [ ] Settings (sound toggle)
- [ ] Interstitial ads (every 3 levels)
- [ ] Rewarded video (undo, skip)
- [ ] Home screen
- [ ] Game screen
- [ ] Win/celebration overlay

### Nice to Have (v1.1)
- [ ] Daily challenge mode
- [ ] Remove ads IAP ($3.99)
- [ ] Theme packs ($0.99)
- [ ] Haptic feedback
- [ ] Particle effects
- [ ] Streak counter

---

## Architecture

```
stakd/
├── lib/
│   ├── main.dart                 # Entry point
│   ├── app.dart                  # App configuration
│   ├── screens/
│   │   ├── home_screen.dart      # Main menu
│   │   ├── game_screen.dart      # Gameplay
│   │   ├── level_select.dart     # Level picker
│   │   └── settings_screen.dart  # Settings
│   ├── widgets/
│   │   ├── stack_widget.dart     # Single stack display
│   │   ├── layer_widget.dart     # Single layer
│   │   ├── game_board.dart       # Full board
│   │   └── celebration.dart      # Win overlay
│   ├── models/
│   │   ├── game_state.dart       # Current game state
│   │   ├── stack_model.dart      # Stack data
│   │   ├── layer_model.dart      # Layer data
│   │   └── level_config.dart     # Level parameters
│   ├── services/
│   │   ├── level_generator.dart  # Procedural levels
│   │   ├── ad_service.dart       # AdMob integration
│   │   ├── audio_service.dart    # Sound effects
│   │   └── storage_service.dart  # Local persistence
│   └── utils/
│       ├── constants.dart        # Colors, sizes
│       └── extensions.dart       # Helpers
├── assets/
│   ├── sounds/
│   │   ├── tap.mp3
│   │   ├── slide.mp3
│   │   ├── clear.mp3
│   │   ├── win.mp3
│   │   └── error.mp3
│   └── images/
│       └── logo.png
├── pubspec.yaml
└── android/
    └── app/
        └── build.gradle          # AdMob app ID
```

---

## Color Palette

```dart
const gameColors = [
  Color(0xFFE53935), // Red
  Color(0xFF1E88E5), // Blue
  Color(0xFF43A047), // Green
  Color(0xFFFFB300), // Amber
  Color(0xFF8E24AA), // Purple
  Color(0xFF00ACC1), // Cyan
];
```

---

## Level Difficulty Progression

| Levels | Colors | Stacks | Empty Slots | Depth |
|--------|--------|--------|-------------|-------|
| 1-10   | 3      | 4      | 2           | 3     |
| 11-30  | 4      | 5      | 2           | 4     |
| 31-60  | 5      | 6      | 2           | 4     |
| 61-100 | 5      | 7      | 2           | 5     |
| 101+   | 6      | 7      | 1           | 5     |

---

## Procedural Level Generation Algorithm

1. Start with solved state (each stack = one color)
2. Make N random valid moves (in reverse)
3. Verify solvable via simulation
4. Store seed for reproducibility

---

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_mobile_ads: ^5.0.0
  audioplayers: ^6.0.0
  shared_preferences: ^2.2.0
  provider: ^6.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

---

## Build Tasks

### Phase 1: Core (Day 1-2)
1. [x] Create Flutter project
2. [ ] Implement models (Stack, Layer, GameState)
3. [ ] Implement level generator
4. [ ] Basic game screen UI

### Phase 2: Gameplay (Day 3-4)
5. [ ] Tap interaction logic
6. [ ] Move validation
7. [ ] Win condition detection
8. [ ] Level progression

### Phase 3: Polish (Day 5-6)
9. [ ] Animations (layer slide, clear burst)
10. [ ] Sound effects
11. [ ] Home screen
12. [ ] Level select

### Phase 4: Monetization (Day 7-8)
13. [ ] AdMob integration
14. [ ] Rewarded video for undo
15. [ ] Settings screen
16. [ ] Final testing

---

## Sound Effects Needed

| Sound | Description | Duration |
|-------|-------------|----------|
| tap.mp3 | Select stack click | 50ms |
| slide.mp3 | Layer moving | 200ms |
| clear.mp3 | Stack cleared sparkle | 300ms |
| win.mp3 | Level complete fanfare | 1s |
| error.mp3 | Invalid move buzz | 100ms |

---

## Milestones

- [ ] **M1:** Playable prototype (core loop works)
- [ ] **M2:** 100 levels generated
- [ ] **M3:** Full UI flow complete
- [ ] **M4:** Ads integrated
- [ ] **M5:** MVP ready for Play Store

---

## Git Repository

**Repo:** github.com/SteveMLC/stakd  
**Branch strategy:** main (stable), develop (WIP)

---

## Notes

- Keep it simple — resist feature creep
- Juice matters — satisfying feedback is key
- Test on real device before launch
- AdMob app ID needed from Steve

---

*Plan created by Walt | 2026-02-06*

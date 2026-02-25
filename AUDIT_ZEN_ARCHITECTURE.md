# Zen Mode Architecture Audit

## Problem Summary
The app has **two separate zen screen implementations** that are not properly connected. The home screen navigates to `ZenScreen` (the simple one), while `ZenModeScreen` (the feature-rich one) is **completely orphaned** — never navigated to from anywhere.

---

## Navigation Map

```
HomeScreen
  ├── Level Select → LevelSelectScreen → GameScreen
  ├── Zen Mode button → _showZenDifficultyPicker() → _startZen() → ZenScreen ✅ (ACTIVE)
  ├── Daily Challenge → DailyChallengeScreen
  ├── Settings → SettingsScreen
  ├── Leaderboards → LeaderboardScreen
  └── Theme Store → ThemeStoreScreen

NOT REACHABLE from any menu:
  ❌ ZenModeScreen (zen_mode_screen.dart)
  ❌ ZenGardenScreen (zen_garden_screen.dart)
```

---

## Feature Comparison: ZenScreen vs ZenModeScreen

| Feature | ZenScreen (ACTIVE) | ZenModeScreen (ORPHANED) |
|---|---|---|
| **Garden background** | ✅ (just added) | ✅ |
| **Completion overlay** | ❌ Auto-advances after 800ms | ✅ Shows stars, time, moves, personal bests |
| **Session summary** | ❌ None | ✅ ZenSessionSummary on exit |
| **Hint system** | ❌ None | ✅ 3 hints per puzzle with HintOverlay |
| **Restart puzzle** | ❌ None | ✅ Restart button |
| **Undo support** | ❌ No UI | ✅ Undo button with count |
| **Stats tracking** | ❌ No StatsService | ✅ Records moves, time, combos, personal bests |
| **Stats bar UI** | ❌ None | ✅ Streak, best moves, record time, total solved |
| **Difficulty selector** | ❌ Set once at start | ✅ In-game slider to change difficulty |
| **Garden view toggle** | ❌ None | ✅ Toggle button to view full garden |
| **Garden progress bar** | ❌ None | ✅ Shows stage name, progress to next stage |
| **Move counter** | ❌ None | ✅ Toggleable move counter |
| **Achievement integration** | ❌ None | ✅ AchievementService + toast overlay |
| **Haptic feedback** | ❌ None | ✅ Win pattern on completion |
| **Pre-generation** | ❌ None | ✅ Pre-generates next puzzle during celebration |
| **Adaptive difficulty** | Basic (bump/ease) | ✅ Granular per-puzzle progression |
| **Streak tracking** | ❌ None | ✅ Resets streak on abandon |
| **StorageService** | ❌ Not used | ✅ addZenPuzzle() on completion |
| **Win sound** | ❌ None | ✅ AudioService().playWin() |
| **Bottom bar** | ❌ None | ✅ Full action bar (undo, hint, restart, garden toggle) |

---

## Orphaned Files (never imported/navigated to)

| File | What it does | Should be... |
|---|---|---|
| `zen_mode_screen.dart` | Feature-rich zen mode with all UI | **Replace** ZenScreen with this |
| `zen_garden_screen.dart` | Standalone garden viewer | Connected from somewhere (settings? home?) |
| `models/garden_asset_registry.dart` | Asset metadata registry | Not imported by any file — dead code |

---

## Service Linkage Issues

### Services NOT used by ZenScreen (but used by ZenModeScreen):
- **StatsService** — Puzzle completion stats never recorded in zen mode
- **AchievementService** — Star achievements never checked
- **StorageService** — Zen puzzle count never saved
- **HapticService** — No haptic feedback on win

### Services properly connected:
- **GardenService** — ✅ `recordPuzzleSolved()` called in both
- **AudioService** — ✅ Tap/slide/clear sounds work
- **ZenAudioService** — ✅ Used by ZenGardenScene internally
- **ZenPuzzleIsolate** — ✅ Background puzzle generation works

### GardenAssetRegistry:
- Defined in `models/garden_asset_registry.dart` but **never imported by any file**
- `zen_garden_scene.dart` hardcodes asset paths instead of using the registry
- Could be useful for dynamic asset loading but currently dead code

---

## Recommended Action: Replace ZenScreen with ZenModeScreen

The simplest fix is to **swap the navigation** to use `ZenModeScreen` instead of `ZenScreen`:

### Changes needed:
1. **`home_screen.dart`**: Change import and navigation from `ZenScreen` to `ZenModeScreen`
2. **`zen_mode_screen.dart`**: Accept `difficulty` parameter (currently hardcoded to medium)
3. **`screens.dart`**: Update barrel export
4. **`zen_screen.dart`**: Can be deleted (or kept as legacy)
5. **`zen_garden_screen.dart`**: Connect from settings or home screen as a "View Garden" option

### Alternative: Port features INTO ZenScreen
This is more work and risks bugs. The ZenModeScreen already works and has all features.

---

## Other Issues Found

1. **`screens.dart` barrel file** missing exports for: `zen_mode_screen.dart`, `zen_garden_screen.dart`, `daily_challenge_screen.dart`
2. **`ZenStorageExtension`** in `zen_mode_screen.dart` has empty `addZenPuzzle()` — just a stub
3. **MediaPlayer spam** in logs — audio asset loading issues (separate problem)
4. **"Lost connection to device"** appearing frequently — may be related to audio service or ad service initialization

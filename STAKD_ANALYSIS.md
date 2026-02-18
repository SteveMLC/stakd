# STAKD ANALYSIS — Complete Codebase Audit
**Date:** February 18, 2026  
**Analyst:** OpenClaw AI  
**Branch:** main  
**Flutter analyze result:** 0 errors, 32 deprecation warnings (all `withOpacity` → `withValues`)

---

## 1. GAME COMPLETENESS AUDIT

### Rating Summary

| System | Rating | Notes |
|--------|--------|-------|
| Core puzzle gameplay | **8/10** | Fully functional, polished |
| Zen garden visual growth | **5/10** | Scene exists and is beautiful, but DISCONNECTED from home nav |
| Garden service / state management | **7/10** | Solid model, stage callbacks work, but bugs exist |
| Theme system | **4/10** | Only 1 theme built, no switching UI wired up |
| Audio system | **7/10** | All files present, dual service architecture, but ZenAudio has 1 bug |
| Achievements | **5/10** | Model + service exist, but not triggered during zen progression |
| Home screen / navigation | **6/10** | ZenModeScreen is DEAD CODE, home routes to old ZenScreen |
| Settings | **4/10** | Basic audio toggle only, no zen volume or garden preferences |

---

## 2. ZEN GARDEN DEEP DIVE

### 2.1 Does `garden_state.dart` properly track growth progression?

**YES — model is excellent.**

- 10 growth stages (0–9) with named milestones: Empty Canvas → Infinite
- `calculateStage(puzzles)` correctly maps: 0→0, 1-5→1, 6-15→2, 16-30→3, 31-50→4, 51-75→5, 76-100→6, 101-150→7, 151-200→8, 200+→9
- `progressToNextStage` (0.0–1.0) works correctly
- `puzzlesSolvedInStage` and `puzzlesNeededForNextStage` are properly calculated
- `stageIcon` and `stageName` are complete and correct
- `copyWith()`, `toJson()`, `fromJson()` are implemented correctly
- **Minor issue:** `thresholds` is defined as `static const` in the model but the `calculateStage` method uses hardcoded if/else chains that are subtly inconsistent (threshold array has 9 elements but stage 0 threshold = 0, not referenced in `calculateStage`)

### 2.2 Does visual growth actually render and progress based on gameplay?

**PARTIALLY — the scene is beautiful but the wrong screen is wired to the home button.**

The `ZenGardenScene` in `zen_mode_screen.dart` renders the garden as the game background. When puzzles are solved:
1. `GardenService.recordPuzzleSolved()` is called ✅  
2. Stage advances, unlocks update ✅  
3. `_gardenRebuildKey++` forces `KeyedSubtree` rebuild ✅  
4. `GardenElement` checks `SharedPreferences` to avoid re-animating ✅  
5. New elements animate in with their reveal type ✅  

**BUT:** The `HomeScreen._startZen()` navigates to `ZenScreen(difficulty: difficulty)` — the **old screen** with no garden background. `ZenModeScreen` (the new one with the garden) is **never reached from any navigation path**. It is dead code.

### 2.3 Are `garden_element.dart` and `growth_milestone.dart` properly integrated?

**garden_element.dart: YES with one concern**
- Properly wraps widgets with reveal animations
- `SharedPreferences` persistence of "has been revealed" prevents duplicate animations
- `GardenRevealType` enum with 4 types all implemented
- `GrowingTree` and `PondFillAnimation` special widgets are solid
- **Concern:** `_checkRevealState()` is `async` and uses `setState()` after await. If widget is disposed before async completes, `mounted` check is missing after the `await prefs.setBool(key, true)` call. This can cause a `setState() called after dispose()` exception.

**growth_milestone.dart: YES with 1 BUG**
```dart
// FILE: lib/widgets/garden/growth_milestone.dart, line ~97
Future<void> _playAnimation() async {
  ZenAudioService().playStageAdvance();
  
  _controller.forward();       // ← starts animation (no await)
  _particleController.forward();

  await _controller.forward(); // ← BUG: second forward() while already running
  
  widget.onComplete(); // ← called correctly after
}
```
The double `_controller.forward()` — first without await, second with — means the second call finds the controller already at value 1.0 from the first. In Flutter, calling `forward()` on an already-complete controller returns a completed future instantly. So `onComplete()` fires immediately. The animation plays correctly visually (first call does the work), but `onComplete()` is called too early (before the full 2.5s duration in some cases). This could cause milestone UI to disappear before the animation finishes.

### 2.4 Is `garden_service.dart` connecting game state to garden visuals correctly?

**YES for core logic, with 1 bug at stage 0.**

**Flow:**
```
puzzle solved → GardenService.recordPuzzleSolved() 
              → updates _state with new stage + unlocks
              → fires onStageAdvanced callback if stage advanced
              → ZenGardenScene receives callback → shows GrowthMilestone
              → gardenRebuildKey++ forces ZenGardenScene rebuild
              → GardenElement checks isUnlocked() → animates if newly unlocked
```

**Stage 0 baseline elements issue:**  
At session start, `_state.unlockedElements = []`. The `startFreshSession()` creates a fresh `GardenState()` with empty unlocks. Stage 0 elements (`ground`, `grass_base`, `grass_base_2`, `grass_base_3`, `ambient_particles`) are only added on the first `recordPuzzleSolved()` call, which bumps stage to 1. Stage 1's `_getUnlocksForStage(1)` correctly includes the `>= 0` check, so stage 0 elements unlock at the first puzzle solve. This means the garden is completely invisible until the first puzzle is solved — which is by design ("sand mandala") but the stage 0 elements defined in GardenService (`ground` etc.) are a hint they were meant to show something upfront.

**Element ID mismatches (service vs scene):**  
Several element IDs are unlocked by `GardenService` but never rendered in `ZenGardenScene`:
- `grass_3` — unlocked at stage 3 but no `GardenElement(elementId: 'grass_3')` exists in scene
- `tree_autumn` — unlocked at stage 6 but no autumn tree renderer
- `wind_chime` — unlocked at stage 6 but no visual in `_buildStructures()`
- `birds` — unlocked at stage 8 but no bird renderer
- `ambient_particles` — unlocked at stage 0 but the scene uses `_buildParticles()` without checking this element ID
- `small_stones` and `pebble_path` — unlocked at stage 1 but the GroundPainter draws stones at stage >= 1 directly, not via element unlock check

**Scene renders element IDs not in GardenService:**
- `grass_1_b` — rendered with `GardenElement(elementId: 'grass_1_b')` but `_getUnlocksForStage` never includes `grass_1_b`. It will never be visible.
- `grass_2_b` — same issue

### 2.5 What growth stages exist and are they visually distinct?

| Stage | Trigger | Visual Changes | Distinctness |
|-------|---------|---------------|--------------|
| 0 | Start | Dark earth, sparse base grass (after 1st solve) | ⚠️ Only base grass visible |
| 1 | 5 puzzles | Brighter grass patches, pebble path | ✅ Ground color changes |
| 2 | 15 puzzles | More grass, white/yellow flowers, small bush | ✅ Clear visual addition |
| 3 | 30 puzzles | Sapling tree, purple flowers | ✅ First tree! |
| 4 | 50 puzzles | Tree grows, pond appears (empty), bench, butterfly | ✅ Major additions |
| 5 | 75 puzzles | Pond fills with water + koi + lily pads, cherry blossom tree, lantern, petals | ✅ Beautiful |
| 6 | 100 puzzles | Night sky transition, torii gate, fireflies | ✅ Dramatic shift |
| 7 | 150 puzzles | Pagoda, stream, bridge, dragonflies | ✅ Japanese garden complete |
| 8 | 200 puzzles | Mountain, moon, clouds | ✅ Epic backdrop |
| 9 | 200+ puzzles | Infinite (no new visuals defined) | ⚠️ No new visuals |

Visual distinctness is **good** — each stage adds something meaningful. The night/day sky transition at stage 6 is particularly dramatic.

---

## 3. WHAT WORKS ✅

### Core Puzzle System
- ✅ Stack-based color sorting puzzle engine (game_state.dart) — robust and complete
- ✅ Layer stacking with depth (4-deep default, configurable)
- ✅ Move animation system with `AnimatingLayer` 
- ✅ Undo system with history (up to 10 moves, limited uses)
- ✅ Multi-grab mode (long press to grab matching top layers)
- ✅ Unstacking mechanic (pull top layers off temporarily)
- ✅ Win condition detection
- ✅ Hint system (finds valid moves)
- ✅ Par/star system (1-3 stars based on moves vs par)
- ✅ Combo tracking (rapid clears within 3-second window)
- ✅ Chain detection (multiple stacks cleared in 1 move)
- ✅ Locked blocks (decremented per move, must be moved normally)
- ✅ Power-ups: Color Bomb, Shuffle, Magnet, Hint (all implemented in game_state.dart)

### Zen Mode Puzzle Generation
- ✅ Adaptive difficulty (bumps when player is fast, eases when slow)
- ✅ Isolated puzzle generation via `compute()` (doesn't block UI)
- ✅ 4 difficulty levels: Easy, Medium, Hard, Ultra
- ✅ Fade animation between puzzles
- ✅ Session stats (puzzles solved, time, moves)

### Garden Visual System
- ✅ 8 layered visual elements (sky, mountains, ground, water, flora, structures, particles)
- ✅ Day/night sky transition at stage 6
- ✅ Animated ambient elements: swaying grass, flying petals, fireflies, dragonflies, koi fish
- ✅ 4 reveal animation types (fadeScale, growUp, bloomOut, rippleIn)
- ✅ Particle burst on element unlock
- ✅ Golden glow effect during reveal
- ✅ Pond fill animation with ripple effect
- ✅ Animated koi fish in figure-8 pattern
- ✅ Dragonfly with darting movement
- ✅ Firefly glow pulsing
- ✅ Cherry blossom petal falling
- ✅ Torii gate, pagoda, stream, bridge painters
- ✅ Sun (day, stage 3+) and moon (night, stage 8+)
- ✅ Twinkling star field (night mode)
- ✅ Stage milestone celebration overlay (GrowthMilestone)
- ✅ Garden progress indicator widget in ZenModeScreen

### Garden Service
- ✅ Session-only state (resets on new Zen session)
- ✅ `onStageAdvanced` callback for milestone notifications
- ✅ Stage calculation and element unlock logic
- ✅ `isUnlocked()` and `visibleElements` API

### Home Screen
- ✅ Animated starfield background
- ✅ Zen Mode as primary action with bottom sheet difficulty picker
- ✅ Daily Challenge button with streak badge and notification dot
- ✅ Level Challenge button with current level badge
- ✅ Leaderboard and Settings buttons
- ✅ Coin balance display with daily rewards popup

### Audio System (main)
- ✅ `AudioService` singleton with tap, slide, clear, win, error sounds
- ✅ Background music with looping
- ✅ Sound enabled/disabled toggle

### Zen Audio System
- ✅ 4-layer ambient audio: wind, birds (day), crickets (night), water (when pond unlocks)
- ✅ Day/night crossfade (2 second gradual transition)
- ✅ Water enable/disable with fade in/out
- ✅ Sound effects: bloom, wind chime, water drop, stage advance
- ✅ All 8 audio files present in `assets/sounds/zen/`

### ZenGardenScreen
- ✅ Full-screen garden view with back button
- ✅ "Your Garden" title overlay

---

## 4. WHAT'S BROKEN / INCOMPLETE ❌

### CRITICAL: Navigation Dead-End
**File:** `lib/screens/home_screen.dart`, line 518  
```dart
builder: (_) => ZenScreen(difficulty: difficulty),
// Should be: ZenModeScreen()
```
`HomeScreen._startZen()` pushes `ZenScreen` (old, dark background, no garden). `ZenModeScreen` — which has the beautiful garden background, difficulty picker in-screen, and full garden integration — is **never navigated to**. It's dead code.

Additionally, `ZenModeScreen` is not exported in `lib/screens/screens.dart`.

---

### CRITICAL: GrowthMilestone Double-Forward Bug
**File:** `lib/widgets/garden/growth_milestone.dart`, lines ~97-107  
```dart
Future<void> _playAnimation() async {
  ZenAudioService().playStageAdvance();
  
  _controller.forward();         // ← line 100: fires without await
  _particleController.forward(); // ← line 101

  await _controller.forward();   // ← line 104: BUG — controller already at 1.0
  
  widget.onComplete();           // ← fires immediately (not after 2.5s)
}
```
The `onComplete()` callback fires instantly after the milestone appears, causing it to disappear immediately. Players never see the full 2.5s celebration.

---

### CRITICAL: GardenElement Missing Mounted Check After Async
**File:** `lib/widgets/garden/garden_element.dart`, lines ~97-115
```dart
Future<void> _checkRevealState() async {
  _isUnlocked = GardenService.isUnlocked(widget.elementId);
  if (!_isUnlocked) return;

  final prefs = await SharedPreferences.getInstance(); // ← async gap
  final key = 'garden_revealed_${widget.elementId}';
  _hasBeenRevealed = prefs.getBool(key) ?? false;

  if (_hasBeenRevealed) {
    _controller.value = 1.0;
  } else {
    _triggerReveal();
    await prefs.setBool(key, true);  // ← another async gap
  }

  if (mounted) setState(() {});  // ← mounted check is here but controller
                                  //    operations above aren't guarded
}
```
Between the two `await` calls, the widget can be disposed. `_controller.value = 1.0` and `_triggerReveal()` and `await prefs.setBool()` are all called without checking `mounted`. This causes `setState() called after dispose` crashes.

---

### HIGH: `grass_1_b` and `grass_2_b` Never Visible
**Files:** `lib/widgets/themes/zen_garden_scene.dart` (lines ~603, 621), `lib/services/garden_service.dart`

These element IDs are used in `GardenElement(elementId: 'grass_1_b')` in the scene but `_getUnlocksForStage()` never includes `'grass_1_b'` or `'grass_2_b'`. `GardenService.isUnlocked('grass_1_b')` always returns false → `GardenElement` returns `SizedBox.shrink()` → they're permanently hidden.

---

### HIGH: Multiple Unlocked Elements Have No Visual
**File:** `lib/services/garden_service.dart` — elements unlocked with no scene rendering:

| Element ID | Stage | Missing Widget |
|-----------|-------|---------------|
| `grass_3` | 3 | No `GardenElement(elementId: 'grass_3')` in `_buildFlora` |
| `tree_autumn` | 6 | No autumn tree renderer in `_buildFlora` |
| `wind_chime` | 6 | No wind chime in `_buildStructures()` |
| `birds` | 8 | No bird renderer anywhere |
| `seasons` | 9 | No seasonal visual system |
| `rare_events` | 9 | No rare events system |

6 elements are unlocked but silently do nothing — they "unlock" in data but players see no change.

---

### HIGH: ZenModeScreen Garden Rebuild is Too Aggressive
**File:** `lib/screens/zen_mode_screen.dart`, lines 144, 244-246
```dart
setState(() => _gardenRebuildKey++);
// ...
KeyedSubtree(
  key: ValueKey(_gardenRebuildKey),
  child: const ZenGardenScene(showStats: false, interactive: false),
)
```
Incrementing `_gardenRebuildKey` destroys and recreates the entire `ZenGardenScene` widget tree, including all animation controllers. This causes:
- Brief visual flash/flicker when a puzzle is solved
- All ambient animations restart (grass sway resets, particles jump)
- Unnecessary `SharedPreferences` reads for all elements on each puzzle solve

---

### MEDIUM: ZenScreen has No Garden Rendering
**File:** `lib/screens/zen_screen.dart`

`ZenScreen` calls `GardenService.startFreshSession()` and `GardenService.recordPuzzleSolved()` but renders no garden. The garden data is tracked, but players using the old ZenScreen see no garden. The garden is an invisible background system only.

---

### MEDIUM: Stage 9 Has No New Visuals
**File:** `lib/services/garden_service.dart`, lines 76-78
```dart
if (stage >= 9) {
  unlocks.addAll(['seasons', 'rare_events']);
}
```
Reaching stage 9 (200+ puzzles) is a significant achievement but delivers no new visual content since both `seasons` and `rare_events` have no rendering implementations.

---

### MEDIUM: ZenAudio Not Connected to ZenScreen
**File:** `lib/screens/zen_screen.dart`

`ZenScreen` uses `GardenService` but never initializes or uses `ZenAudioService`. Players in the old Zen Mode get no ambient audio.

---

### MEDIUM: `addZenPuzzle()` is a Stub — No Persistence
**File:** `lib/screens/zen_mode_screen.dart`, lines ~460-470
```dart
extension ZenStorageExtension on StorageService {
  Future<void> addZenPuzzle() async {
    // Zen puzzles are tracked in session only for now
    // Could be persisted via SharedPreferences if needed
  }

  int getZenPuzzlesSolved() {
    return 0; // Session tracking only
  }
}
```
The lifetime Zen puzzle count is never persisted. Every session starts with garden at stage 0. This is by design ("sand mandala philosophy") but means there's no lifetime progression or achievement tracking for Zen Mode.

---

### MEDIUM: Settings Lacks ZenAudio Volume Controls
**File:** `lib/screens/settings_screen.dart`

Settings only controls main `AudioService` (music volume toggle). No controls for:
- Zen ambient volume
- Individual layer toggles (birds, water, wind)
- Milestone animations on/off
- Garden particle density

---

### LOW: Deprecation Warnings (32 instances)
All `withOpacity()` calls should be `withValues(alpha:)`. Not broken but shows as warnings. See flutter analyze output for full list across:
- `zen_mode_screen.dart` (2)
- `garden_element.dart` (4)
- `growth_milestone.dart` (8)
- `zen_garden_scene.dart` (18)

---

### LOW: `ZenModeScreen` Not Exported in `screens.dart`
**File:** `lib/screens/screens.dart`

```dart
// Missing:
export 'zen_mode_screen.dart';
```

---

### LOW: `AmbientParticlesPainter` Duplicated
Both `zen_screen.dart` and `zen_mode_screen.dart` define their own identical `AmbientParticlesPainter` class. Should be extracted to a shared file.

---

### LOW: GardenElement Particle Positions Use Unconstrained Stack
**File:** `lib/widgets/garden/garden_element.dart`, `_buildParticles()` method

Particles use `Positioned` with `left` and `top` computed from controller value, but the parent `Stack` has `clipBehavior: Clip.none`. This is correct for the effect but means particles can render outside the widget bounds and potentially overlap other UI elements.

---

## 5. IMPLEMENTATION PLAN

---

### TASK 1: Fix Navigation — Wire ZenModeScreen (30 min)
**Impact: CRITICAL — makes garden visible to players**

**File: `lib/screens/home_screen.dart`**

Step 1 — Add import:
```dart
import 'zen_mode_screen.dart';
```

Step 2 — Change `_startZen()` method (line ~510):
```dart
// BEFORE:
void _startZen(String difficulty) {
  Navigator.of(context).pop();
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ZenScreen(difficulty: difficulty),
    ),
  );
}

// AFTER:
void _startZen(String difficulty) {
  Navigator.of(context).pop();
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const ZenModeScreen(),
    ),
  );
}
```

Note: `ZenModeScreen` has its own difficulty picker UI built-in (the `_buildDifficultySlider()` widget). The pre-selection from the bottom sheet difficulty picker is not needed. Alternatively, add a `difficulty` parameter to `ZenModeScreen` and initialize `_difficulty` from it:

```dart
// In zen_mode_screen.dart, add optional difficulty param:
class ZenModeScreen extends StatefulWidget {
  final String? initialDifficulty;
  const ZenModeScreen({super.key, this.initialDifficulty});
  // ...
}

// In _ZenModeScreenState.initState():
@override
void initState() {
  super.initState();
  if (widget.initialDifficulty != null) {
    _difficulty = ZenDifficulty.values.firstWhere(
      (d) => d.name == widget.initialDifficulty,
      orElse: () => ZenDifficulty.medium,
    );
  }
  // rest of initState...
}
```

**File: `lib/screens/screens.dart`**
```dart
// Add:
export 'zen_mode_screen.dart';
```

---

### TASK 2: Fix GrowthMilestone Double-Forward Bug (15 min)
**Impact: CRITICAL — milestone celebration doesn't display properly**

**File: `lib/widgets/garden/growth_milestone.dart`**

```dart
// BEFORE:
Future<void> _playAnimation() async {
  ZenAudioService().playStageAdvance();
  
  _controller.forward();
  _particleController.forward();

  await _controller.forward();
  
  widget.onComplete();
}

// AFTER:
Future<void> _playAnimation() async {
  ZenAudioService().playStageAdvance();
  
  _particleController.forward();  // particles run simultaneously (no await needed)
  await _controller.forward();    // single await for main animation (2.5s)
  
  widget.onComplete();
}
```

---

### TASK 3: Fix GardenElement Mounted Guard (20 min)
**Impact: HIGH — prevents crash on dispose during async**

**File: `lib/widgets/garden/garden_element.dart`**

```dart
// BEFORE:
Future<void> _checkRevealState() async {
  _isUnlocked = GardenService.isUnlocked(widget.elementId);
  if (!_isUnlocked) return;

  final prefs = await SharedPreferences.getInstance();
  final key = 'garden_revealed_${widget.elementId}';
  _hasBeenRevealed = prefs.getBool(key) ?? false;

  if (_hasBeenRevealed) {
    _controller.value = 1.0;
  } else {
    _triggerReveal();
    await prefs.setBool(key, true);
  }

  if (mounted) setState(() {});
}

// AFTER:
Future<void> _checkRevealState() async {
  _isUnlocked = GardenService.isUnlocked(widget.elementId);
  if (!_isUnlocked) return;

  final prefs = await SharedPreferences.getInstance();
  if (!mounted) return;  // ← guard after first await
  
  final key = 'garden_revealed_${widget.elementId}';
  _hasBeenRevealed = prefs.getBool(key) ?? false;

  if (_hasBeenRevealed) {
    if (mounted) _controller.value = 1.0;
  } else {
    if (mounted) _triggerReveal();
    await prefs.setBool(key, true);
    if (!mounted) return;  // ← guard after second await
  }

  if (mounted) setState(() {});
}
```

---

### TASK 4: Fix grass_1_b and grass_2_b — Add to GardenService Unlocks (10 min)
**Impact: HIGH — two grass elements permanently hidden**

**File: `lib/services/garden_service.dart`**

```dart
// BEFORE stage >= 1 block:
if (stage >= 1) {
  unlocks.addAll(['pebble_path', 'small_stones', 'grass_1']);
}
if (stage >= 2) {
  unlocks.addAll(['grass_2', 'flowers_white', 'flowers_yellow', 'bush_small']);
}

// AFTER:
if (stage >= 1) {
  unlocks.addAll(['pebble_path', 'small_stones', 'grass_1', 'grass_1_b']);  // ← add grass_1_b
}
if (stage >= 2) {
  unlocks.addAll(['grass_2', 'grass_2_b', 'flowers_white', 'flowers_yellow', 'bush_small']);  // ← add grass_2_b
}
```

---

### TASK 5: Add Missing Visual Elements (90 min)
**Impact: HIGH — 6 unlocked elements have no visual**

#### 5a. Add grass_3 to flora renderer
**File: `lib/widgets/themes/zen_garden_scene.dart`**, in `_buildFlora()`:

```dart
// After stage >= 2 block, in stage >= 3 block:
if (stage >= 3) {
  elements.add(
    GardenElement(
      elementId: 'grass_3',
      revealType: GardenRevealType.growUp,
      child: _grass(left: 200, size: 44, swayPhase: 0.4),
    ),
  );
  elements.add(
    GardenElement(
      elementId: 'sapling',
      // ... existing code
```

#### 5b. Add autumn tree to flora renderer
**File: `lib/widgets/themes/zen_garden_scene.dart`**, in `_buildFlora()`:

```dart
// Add after the cherry blossom block:
if (stage >= 6) {
  elements.add(
    GardenElement(
      elementId: 'tree_autumn',
      revealType: GardenRevealType.growUp,
      revealDuration: const Duration(milliseconds: 2000),
      child: _tree(left: 240, stage: stage, isAutumn: true),
    ),
  );
}
```

Then update `_tree()` to accept `isAutumn`:
```dart
Widget _tree({double? left, double? right, required int stage, bool isCherry = false, bool isAutumn = false}) {
  final height = 80.0 + (stage - 3) * 28;
  final scale = height / 140;

  return Positioned(
    bottom: 100,
    left: left,
    right: right,
    child: AnimatedBuilder(
      animation: _ambientController,
      builder: (context, child) {
        final sway = math.sin(_ambientController.value * 2 * math.pi) * 0.015;
        return Transform.rotate(
          angle: sway,
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
      child: SizedBox(
        width: 120 * scale,
        height: 160 * scale,
        child: CustomPaint(
          painter: TreePainter(
            isCherry: isCherry,
            isAutumn: isAutumn,  // ← pass through
            scale: scale,
          ),
        ),
      ),
    ),
  );
}
```

Update `TreePainter` to support autumn:
```dart
class TreePainter extends CustomPainter {
  final bool isCherry;
  final bool isAutumn;  // ← add this
  final double scale;

  TreePainter({this.isCherry = false, this.isAutumn = false, this.scale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    // ... existing trunk code ...
    
    // Foliage colors
    final baseColor = isAutumn 
        ? const Color(0xFFD4522A)  // Autumn orange
        : isCherry 
            ? const Color(0xFFFFB7C5) 
            : const Color(0xFF2E7D32);
    final midColor = isAutumn 
        ? const Color(0xFFE87D2A)  // Autumn amber
        : isCherry 
            ? const Color(0xFFFF8FAA) 
            : const Color(0xFF43A047);
    final highlightColor = isAutumn 
        ? const Color(0xFFFFB347)  // Autumn gold
        : isCherry 
            ? const Color(0xFFFFCDD2) 
            : const Color(0xFF66BB6A);
    // ... rest of foliage drawing unchanged ...
  }

  @override
  bool shouldRepaint(covariant TreePainter oldDelegate) =>
      oldDelegate.isCherry != isCherry || 
      oldDelegate.isAutumn != isAutumn ||  // ← add this
      oldDelegate.scale != scale;
}
```

#### 5c. Add wind chime to structures
**File: `lib/widgets/themes/zen_garden_scene.dart`**, in `_buildStructures()`:

```dart
if (isUnlocked('wind_chime')) {
  elements.add(
    GardenElement(
      elementId: 'wind_chime',
      revealType: GardenRevealType.growUp,
      child: Positioned(
        bottom: 160,
        right: 80,
        child: AnimatedBuilder(
          animation: _ambientController,
          builder: (context, child) {
            final sway = math.sin(_ambientController.value * 2 * math.pi * 1.5) * 0.05;
            return Transform.rotate(
              angle: sway,
              child: SizedBox(
                width: 20,
                height: 40,
                child: CustomPaint(painter: WindChimePainter()),
              ),
            );
          },
        ),
      ),
    ),
  );
}
```

Add the painter:
```dart
class WindChimePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..style = PaintingStyle.fill;
    
    // Top bar
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.1),
      paint,
    );
    
    // 3 hanging tubes
    for (int i = 0; i < 3; i++) {
      final x = size.width * (0.2 + i * 0.3);
      final tubeHeight = size.height * (0.4 + i * 0.1);
      canvas.drawRect(
        Rect.fromLTWH(x - 2, size.height * 0.1, 4, tubeHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

#### 5d. Add birds for stage 8
**File: `lib/widgets/themes/zen_garden_scene.dart`**, in `_buildParticles()`:

```dart
// Add at the end of _buildParticles():
if (isUnlocked('birds')) {
  particles.add(
    GardenElement(
      elementId: 'birds',
      revealType: GardenRevealType.fadeScale,
      showParticles: false,
      child: _buildBirdFlock(),
    ),
  );
}
```

Add the `_buildBirdFlock()` method:
```dart
Widget _buildBirdFlock() {
  return AnimatedBuilder(
    animation: _ambientController,
    builder: (context, _) {
      final t = _ambientController.value;
      return Stack(
        children: List.generate(5, (i) {
          // Birds fly across in a V formation
          final baseX = -50.0 + (t * (MediaQuery.of(context).size.width + 100)) + i * 15;
          final baseY = 60.0 + i * 8 + math.sin(t * 2 * math.pi + i) * 5;
          final x = baseX % (MediaQuery.of(context).size.width + 100) - 50;
          
          return Positioned(
            left: x,
            top: baseY,
            child: Opacity(
              opacity: 0.7,
              child: SizedBox(
                width: 16,
                height: 8,
                child: CustomPaint(painter: BirdPainter()),
              ),
            ),
          );
        }),
      );
    },
  );
}

class BirdPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF546E7A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    // Simple M-shape bird silhouette
    final path = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.25, 0, size.width * 0.5, size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.75, 0, size.width, size.height * 0.5);
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

---

### TASK 6: Fix ZenModeScreen Garden Rebuild Strategy (45 min)
**Impact: HIGH — eliminates visual flicker and animation reset**

Instead of using `KeyedSubtree` to force-rebuild the entire scene, use a `ChangeNotifier` or `ValueNotifier` to push state updates.

**File: `lib/services/garden_service.dart`**

```dart
// Add a ValueNotifier for rebuild triggers:
class GardenService {
  static GardenState _state = GardenState();
  static Function(int newStage, String stageName)? onStageAdvanced;
  static final ValueNotifier<int> rebuildNotifier = ValueNotifier(0);  // ← ADD

  // ... existing code ...

  static bool recordPuzzleSolved() {
    // ... existing logic ...
    
    // At the end, before return:
    rebuildNotifier.value++;  // ← ADD: trigger listeners
    
    return stageAdvanced;
  }
}
```

**File: `lib/widgets/themes/zen_garden_scene.dart`**

Modify `_ZenGardenSceneState` to listen to the notifier instead of being rebuilt externally:

```dart
@override
void initState() {
  super.initState();
  // ... existing code ...
  GardenService.rebuildNotifier.addListener(_onGardenUpdate);  // ← ADD
}

void _onGardenUpdate() {
  if (mounted) setState(() {});  // ← gentle rebuild, preserves animations
}

@override
void dispose() {
  GardenService.rebuildNotifier.removeListener(_onGardenUpdate);  // ← ADD
  _ambientController.dispose();
  // ... rest of dispose
}
```

**File: `lib/screens/zen_mode_screen.dart`**

Remove the `_gardenRebuildKey` approach:
```dart
// REMOVE these:
int _gardenRebuildKey = 0;
setState(() => _gardenRebuildKey++);

// REMOVE the KeyedSubtree wrapper, replace with:
const ZenGardenScene(showStats: false, interactive: false),
```

---

### TASK 7: Add ZenAudio to ZenScreen (20 min)
**Impact: MEDIUM — old zen screen users get ambient audio**

**File: `lib/screens/zen_screen.dart`**

```dart
// Add import:
import '../services/zen_audio_service.dart';

// In _ZenScreenState.initState():
@override
void initState() {
  super.initState();
  GardenService.startFreshSession();
  _initZenAudio();  // ← ADD
  // ... rest of initState
}

Future<void> _initZenAudio() async {
  final audio = ZenAudioService();
  await audio.init();
  await audio.startAmbience(isNight: false, hasWater: false);
}

// In dispose():
@override
void dispose() {
  ZenAudioService().stopAmbience();  // ← ADD
  _sessionTicker?.cancel();
  // ... rest of dispose
}
```

---

### TASK 8: Fix withOpacity → withValues (20 min, automated)
**Impact: LOW — eliminates all 32 deprecation warnings**

Run this sed command from project root:
```bash
cd /Users/venomspike/.openclaw/workspace/projects/stakd
# Find and replace in garden files:
find lib/widgets/garden lib/screens/zen_mode_screen.dart lib/widgets/themes/zen_garden_scene.dart \
  -name "*.dart" -exec \
  
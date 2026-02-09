# Codex Sprint: Zen Garden Integration + Multi-Theme System

## Overview
Integrate the Zen Garden as the live background during puzzle gameplay, and build a theme system that allows seamless switching between different visual styles.

## Architecture

### Theme System
```
lib/
├── models/
│   └── theme_state.dart          # Theme preferences + unlocks
├── services/
│   └── theme_service.dart        # Theme management + persistence
├── widgets/
│   └── themes/
│       ├── base_theme_scene.dart # Abstract base class
│       ├── zen_garden_scene.dart # Japanese garden (existing, move here)
│       ├── forest_grove_scene.dart
│       ├── ocean_cove_scene.dart
│       └── theme_selector.dart   # UI for picking themes
```

### Themes (5 total)
1. **Zen Garden** (default, free) - Japanese aesthetic, cherry blossoms, koi pond
2. **Forest Grove** - Woodland, mushrooms, fireflies, deer silhouettes
3. **Ocean Cove** - Beach, waves, seashells, sunset/sunrise
4. **Mountain Peak** - Alpine, snow, eagles, aurora borealis
5. **Night Sky** - Celestial, stars form constellations as you solve

### Growth Mechanics (same across themes)
- Stage 0: Empty/minimal
- Stage 1-3: Basic elements appear
- Stage 4-6: Mid-tier elements, animations
- Stage 7-9: Full beauty, rare events
- Stage 10: "Infinite" - subtle variations

---

## Phase 1: Core Integration (DO THIS FIRST)

### Task 1.1: Move and refactor ZenGardenScene
Move `lib/widgets/garden/zen_garden_scene.dart` to `lib/widgets/themes/zen_garden_scene.dart`

Create base class `lib/widgets/themes/base_theme_scene.dart`:
```dart
import 'package:flutter/material.dart';
import '../../services/garden_service.dart';

/// Base class for all theme scenes
/// Each theme implements its own visual style but uses shared GardenService for progression
abstract class BaseThemeScene extends StatefulWidget {
  final bool showStats;
  final bool interactive; // false when used as background
  
  const BaseThemeScene({
    super.key, 
    this.showStats = false,
    this.interactive = false,
  });
}

abstract class BaseThemeSceneState<T extends BaseThemeScene> extends State<T>
    with TickerProviderStateMixin {
  
  int get currentStage => GardenService.state.currentStage;
  int get puzzlesSolved => GardenService.state.totalPuzzlesSolved;
  List<String> get unlockedElements => GardenService.visibleElements;
  
  /// Override in subclasses to provide theme-specific colors
  List<Color> get skyGradientColors;
  
  /// Override to build theme-specific layers
  Widget buildSkyLayer();
  Widget buildDistantLayer();
  Widget buildGroundLayer();
  Widget buildWaterLayer();
  Widget buildFloraLayer();
  Widget buildStructureLayer();
  Widget buildParticleLayer(Animation<double> animation);
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        buildSkyLayer(),
        buildDistantLayer(),
        buildGroundLayer(),
        buildWaterLayer(),
        buildFloraLayer(),
        buildStructureLayer(),
        // Particle layer handled by subclass with its own animation
      ],
    );
  }
}
```

### Task 1.2: Update ZenGardenScene to extend BaseThemeScene
Refactor existing zen_garden_scene.dart to use the base class pattern.

### Task 1.3: Integrate into ZenModeScreen
In `lib/screens/zen_mode_screen.dart`, replace the gradient background:

```dart
// BEFORE (lines ~237-249):
Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(...),
  ),
  child: Stack(...)
)

// AFTER:
Stack(
  children: [
    // Theme scene as background
    Positioned.fill(
      child: ZenGardenScene(
        showStats: false,
        interactive: false,
      ),
    ),
    // Rest of UI on top
    SafeArea(
      child: Column(...)
    ),
  ],
)
```

### Task 1.4: Add rebuild trigger on puzzle solve
The garden needs to rebuild when a puzzle is solved. Add a simple state trigger:

```dart
// In zen_mode_screen.dart state:
int _gardenRebuildKey = 0;

// In _onPuzzleComplete():
GardenService.recordPuzzleSolved();
setState(() => _gardenRebuildKey++);

// In build, wrap the scene:
KeyedSubtree(
  key: ValueKey(_gardenRebuildKey),
  child: ZenGardenScene(...),
),
```

---

## Phase 2: Theme Service + Persistence

### Task 2.1: Create ThemeState model
`lib/models/theme_state.dart`:
```dart
enum GameTheme {
  zenGarden('Zen Garden', 'Japanese tranquility', true),
  forestGrove('Forest Grove', 'Woodland serenity', false),
  oceanCove('Ocean Cove', 'Coastal calm', false),
  mountainPeak('Mountain Peak', 'Alpine majesty', false),
  nightSky('Night Sky', 'Celestial wonder', false);
  
  final String displayName;
  final String description;
  final bool isFree;
  
  const GameTheme(this.displayName, this.description, this.isFree);
}

class ThemeState {
  final GameTheme activeTheme;
  final Set<GameTheme> unlockedThemes;
  
  const ThemeState({
    this.activeTheme = GameTheme.zenGarden,
    this.unlockedThemes = const {GameTheme.zenGarden},
  });
  
  ThemeState copyWith({
    GameTheme? activeTheme,
    Set<GameTheme>? unlockedThemes,
  }) {
    return ThemeState(
      activeTheme: activeTheme ?? this.activeTheme,
      unlockedThemes: unlockedThemes ?? this.unlockedThemes,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'activeTheme': activeTheme.name,
    'unlockedThemes': unlockedThemes.map((t) => t.name).toList(),
  };
  
  factory ThemeState.fromJson(Map<String, dynamic> json) {
    return ThemeState(
      activeTheme: GameTheme.values.firstWhere(
        (t) => t.name == json['activeTheme'],
        orElse: () => GameTheme.zenGarden,
      ),
      unlockedThemes: (json['unlockedThemes'] as List?)
          ?.map((n) => GameTheme.values.firstWhere((t) => t.name == n))
          .toSet() ?? {GameTheme.zenGarden},
    );
  }
}
```

### Task 2.2: Create ThemeService
`lib/services/theme_service.dart`:
```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/theme_state.dart';

class ThemeService {
  static const String _storageKey = 'stakd_theme_state';
  static ThemeState _state = const ThemeState();
  
  static ThemeState get state => _state;
  static GameTheme get activeTheme => _state.activeTheme;
  
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_storageKey);
    if (json != null) {
      try {
        _state = ThemeState.fromJson(jsonDecode(json));
      } catch (_) {}
    }
  }
  
  static Future<void> setActiveTheme(GameTheme theme) async {
    if (!_state.unlockedThemes.contains(theme)) return;
    _state = _state.copyWith(activeTheme: theme);
    await _save();
  }
  
  static Future<void> unlockTheme(GameTheme theme) async {
    _state = _state.copyWith(
      unlockedThemes: {..._state.unlockedThemes, theme},
    );
    await _save();
  }
  
  static bool isUnlocked(GameTheme theme) => _state.unlockedThemes.contains(theme);
  
  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_state.toJson()));
  }
}
```

---

## Phase 3: Additional Themes (one at a time)

### Task 3.1: Forest Grove Theme
`lib/widgets/themes/forest_grove_scene.dart`

Elements by stage:
- Stage 1: Grass, small mushrooms, fallen leaves
- Stage 2: Ferns, wildflowers, rabbit silhouette
- Stage 3: Young trees, berry bushes, squirrel
- Stage 4: Mature oaks, hollow log, owl
- Stage 5: Canopy coverage, deer, stream
- Stage 6: Fireflies, moonbeams through trees
- Stage 7: Ancient tree, fox den, mist
- Stage 8: Full forest, birds, dappled light
- Stage 9: Rare events (aurora, snow, etc.)

### Task 3.2: Ocean Cove Theme
Elements: Sand, tide pools, seashells, crabs, starfish, waves, seagulls, lighthouse, sunset/sunrise cycles, dolphins, whale tail in distance

### Task 3.3: Mountain Peak Theme  
Elements: Rocks, alpine flowers, snow patches, mountain goat, eagles, clouds, peaks, aurora borealis, stars

### Task 3.4: Night Sky Theme
Elements: Stars appear and form constellations as you solve. Shooting stars on fast solves. Moon phases. Nebulae. Planets visible at high stages.

---

## Phase 4: Theme Selector UI

### Task 4.1: Theme Selector Widget
`lib/widgets/themes/theme_selector.dart`

Bottom sheet or modal that shows:
- Grid of theme previews (small animated thumbnails)
- Lock icon on locked themes
- "Active" badge on current theme
- Unlock requirements for locked themes

### Task 4.2: Integration Points
- Settings screen: Theme selector button
- Zen Mode screen: Small theme icon in corner to quick-switch
- After X puzzles solved: "New theme unlocked!" celebration

---

## Unlock Criteria (for non-free themes)

| Theme | Unlock Requirement |
|-------|-------------------|
| Zen Garden | Free (default) |
| Forest Grove | Solve 50 Zen puzzles total |
| Ocean Cove | Solve 100 Zen puzzles total |
| Mountain Peak | Reach Stage 7 in single session |
| Night Sky | Premium purchase OR 500 total puzzles |

---

## Implementation Order

1. **Phase 1** (Core Integration) - Get garden visible during gameplay
2. **Phase 2** (Theme Service) - Persistence and switching infrastructure  
3. **Phase 4** (Theme Selector UI) - Let users see/pick themes
4. **Phase 3** (Additional Themes) - Build out one at a time

---

## Codex Prompt for Phase 1

```
You are working on Stakd, a Flutter puzzle game. Your task is to integrate the Zen Garden as a live background during Zen Mode gameplay.

CURRENT STATE:
- lib/widgets/garden/zen_garden_scene.dart exists (562 lines) - beautiful layered garden
- lib/services/garden_service.dart tracks puzzle progress and unlocks
- lib/screens/zen_mode_screen.dart has boring gradient background
- GardenService.recordPuzzleSolved() is already called on puzzle complete

YOUR TASKS:

1. Create lib/widgets/themes/base_theme_scene.dart with abstract base class for theme scenes

2. Move lib/widgets/garden/zen_garden_scene.dart to lib/widgets/themes/zen_garden_scene.dart
   - Update to extend BaseThemeScene pattern
   - Keep all existing visual logic
   - Add showStats and interactive parameters

3. Update lib/screens/zen_mode_screen.dart:
   - Import the new zen_garden_scene.dart location
   - Replace the gradient Container background with ZenGardenScene widget
   - Add _gardenRebuildKey state variable
   - Increment key in _onPuzzleComplete() after recordPuzzleSolved()
   - Wrap ZenGardenScene in KeyedSubtree for rebuild
   - Ensure puzzle UI renders on TOP of the garden (proper Stack order)

4. Update any imports that reference the old garden location

5. Test that:
   - Garden is visible behind the puzzle
   - Garden updates when puzzles are solved
   - UI remains readable (may need slight opacity/blur on garden)

STYLE NOTES:
- Garden should be subtle, not distracting
- Consider adding slight blur or reduced opacity so puzzle pieces are clear
- Dark overlay gradient at top/bottom for text readability

Run flutter analyze before committing. Commit with message: "feat: Integrate Zen Garden as live background in Zen Mode"
```

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/garden_state.dart';

/// Garden state is PERSISTENT. Garden grows as you solve puzzles across ALL sessions.
/// The garden accumulates progress from both main game and zen mode completions.
class GardenService {
  static GardenState _state = GardenState();
  static Function(int newStage, String stageName)? onStageAdvanced;

  /// Notifier incremented after every puzzle solve so ZenGardenScene can
  /// rebuild itself without a full KeyedSubtree teardown.
  static final ValueNotifier<int> rebuildNotifier = ValueNotifier(0);

  static GardenState get state => _state;

  /// Load persisted garden state
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('garden_state');
    if (json != null) {
      _state = GardenState.fromJson(jsonDecode(json));
    } else {
      // First time: retroactively count existing puzzle progress
      // Check how many levels the player has already completed
      final existingProgress = prefs.getInt('highest_level') ?? 1;
      final retroactivePuzzles = (existingProgress - 1).clamp(0, 999);
      
      final stage = GardenState.calculateStage(retroactivePuzzles);
      final allUnlocks = _getUnlocksForStage(stage);
      
      _state = GardenState(
        totalPuzzlesSolved: retroactivePuzzles,
        currentStage: stage,
        unlockedElements: allUnlocks,
      );
      await _save();
    }
    
    // Always ensure current stage unlocks are applied (handles new elements added in updates)
    final currentUnlocks = _getUnlocksForStage(_state.currentStage);
    final missing = currentUnlocks.where((e) => !_state.unlockedElements.contains(e)).toList();
    if (missing.isNotEmpty) {
      _state = _state.copyWith(
        unlockedElements: [..._state.unlockedElements, ...missing],
      );
      await _save();
    }
  }

  /// Save garden state to disk
  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('garden_state', jsonEncode(_state.toJson()));
  }

  /// Record a puzzle completion (persisted!)
  /// Returns true if stage advanced
  static Future<bool> recordPuzzleSolved() async {
    final oldStage = _state.currentStage;
    final newTotal = _state.totalPuzzlesSolved + 1;
    final newStage = GardenState.calculateStage(newTotal);

    // Check for new unlocks
    final newUnlocks = _getUnlocksForStage(newStage)
        .where((e) => !_state.unlockedElements.contains(e))
        .toList();

    _state = _state.copyWith(
      totalPuzzlesSolved: newTotal,
      currentStage: newStage,
      lastPlayedAt: DateTime.now(),
      unlockedElements: [..._state.unlockedElements, ...newUnlocks],
    );

    await _save();

    // Notify if stage advanced
    final stageAdvanced = newStage > oldStage;
    if (stageAdvanced && onStageAdvanced != null) {
      onStageAdvanced!(newStage, _state.stageName);
    }

    // Signal ZenGardenScene to do a gentle setState (preserves animation controllers)
    rebuildNotifier.value++;

    return stageAdvanced;
  }

  /// Get elements that should be unlocked at a given stage
  static List<String> _getUnlocksForStage(int stage) {
    final unlocks = <String>[];

    // Stage 0: Always show baseline elements so garden isn't completely empty
    if (stage >= 0) {
      unlocks.addAll(['ground', 'ground_raked', 'grass_base', 'grass_base_2', 'grass_base_3', 'ambient_particles']);
    }

    if (stage >= 1) {
      unlocks.addAll(['pebble_path', 'small_stones', 'grass_1', 'grass_1_b']);
    }
    if (stage >= 2) {
      unlocks.addAll(['grass_2', 'grass_2_b', 'flowers_white', 'flowers_yellow', 'bush_small', 'zen_sand_swirl']);
    }
    if (stage >= 3) {
      unlocks.addAll(['grass_3', 'sapling', 'zen_bamboo', 'pond_empty', 'flowers_purple']);
    }
    if (stage >= 4) {
      unlocks.addAll(['tree_young', 'pond_full', 'lily_pads', 'bench', 'butterfly']);
    }
    if (stage >= 5) {
      unlocks.addAll(['tree_cherry', 'zen_blossoms_b', 'koi_fish', 'lantern', 'petals']);
    }
    if (stage >= 6) {
      unlocks.addAll(['torii_gate', 'zen_bonsai', 'tree_autumn', 'fireflies', 'wind_chime']);
    }
    if (stage >= 7) {
      unlocks.addAll(['pagoda', 'stream', 'bridge', 'dragonflies']);
    }
    if (stage >= 8) {
      unlocks.addAll(['mountain', 'moon', 'clouds', 'birds', 'mist_overlay']);
    }
    if (stage >= 9) {
      unlocks.addAll(['seasons', 'rare_events']);
    }

    return unlocks;
  }

  /// Check if an element is unlocked
  static bool isUnlocked(String element) {
    return _state.unlockedElements.contains(element);
  }

  /// Get all elements that should be visible
  static List<String> get visibleElements => _state.unlockedElements;
}

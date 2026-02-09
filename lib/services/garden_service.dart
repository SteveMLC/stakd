import '../models/garden_state.dart';

/// Garden state is SESSION-ONLY. Each Zen Mode session starts fresh.
/// The garden grows as you solve puzzles, then fades when you leave.
/// Like a sand mandala - beautiful, impermanent.
class GardenService {
  static GardenState _state = GardenState();
  static Function(int newStage, String stageName)? onStageAdvanced;

  static GardenState get state => _state;

  /// Reset garden to empty state (call when entering Zen Mode)
  static void startFreshSession() {
    _state = GardenState();
  }

  /// Record a puzzle completion in Zen Mode (session only, not persisted)
  /// Returns true if stage advanced
  static bool recordPuzzleSolved() {
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

    // Notify if stage advanced
    final stageAdvanced = newStage > oldStage;
    if (stageAdvanced && onStageAdvanced != null) {
      onStageAdvanced!(newStage, _state.stageName);
    }

    return stageAdvanced;
  }

  /// Get elements that should be unlocked at a given stage
  static List<String> _getUnlocksForStage(int stage) {
    final unlocks = <String>[];

    // Stage 0: Always show baseline elements so garden isn't completely empty
    if (stage >= 0) {
      unlocks.addAll(['ground', 'grass_base', 'grass_base_2', 'grass_base_3', 'ambient_particles']);
    }

    if (stage >= 1) {
      unlocks.addAll(['pebble_path', 'small_stones', 'grass_1']);
    }
    if (stage >= 2) {
      unlocks.addAll(['grass_2', 'flowers_white', 'flowers_yellow', 'bush_small']);
    }
    if (stage >= 3) {
      unlocks.addAll(['grass_3', 'sapling', 'pond_empty', 'flowers_purple']);
    }
    if (stage >= 4) {
      unlocks.addAll(['tree_young', 'pond_full', 'lily_pads', 'bench', 'butterfly']);
    }
    if (stage >= 5) {
      unlocks.addAll(['tree_cherry', 'koi_fish', 'lantern', 'petals']);
    }
    if (stage >= 6) {
      unlocks.addAll(['torii_gate', 'tree_autumn', 'fireflies', 'wind_chime']);
    }
    if (stage >= 7) {
      unlocks.addAll(['pagoda', 'stream', 'bridge', 'dragonflies']);
    }
    if (stage >= 8) {
      unlocks.addAll(['mountain', 'moon', 'clouds', 'birds']);
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

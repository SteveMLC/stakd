import 'dart:math';

import '../models/layer_model.dart';
import '../models/stack_model.dart';

/// Post-seed wrinkle layerer.
///
/// Phase G of the conveyor-mechanic overhaul. The clean
/// `ConveyorSeed.generateBays` output knows nothing about wrinkles —
/// just colors / depth / scramble moves. This layerer takes that
/// clean state plus a per-level wrinkle list from
/// `ConveyorLevelConfig.wrinkles` and applies the existing crate
/// modifiers (frozen / locked / fragile / priority / time-bomb /
/// double-color) on TOP of each delivery's bay state.
///
/// `gravity-flip` is a per-level board behavior, not a per-crate
/// modifier — it's handled separately via `GameState._gravityFlipActive`
/// and stays out of this layerer.
///
/// Spawn caps match the original `LevelGenerator.applySpecialBlocks`
/// per-puzzle limits, applied per-bay here:
///   - max 1 locked per bay (bottom of pure-color stack)
///   - max 1 frozen per bay
///   - max 1 fragile per bay (top of mixed stack)
///   - max 1 priority per bay (top of mixed stack, can't co-spawn w/ fragile)
///   - max 1 time-bomb per bay (top of mixed stack, can't co-spawn w/ priority)
///   - max 1 double-color per bay (any mixed-stack position)
///
/// Phase H deletes the legacy `applySpecialBlocks` once everything
/// routes through here.
class WrinkleLayerer {
  /// Apply post-seed wrinkle additives to [bay] per the [wrinkles]
  /// list. Returns a new bay with the same layer count but some
  /// layers replaced by their wrinkle-flagged equivalents. Uses
  /// [rng] for all randomness so callers can drive determinism for
  /// daily challenges + replays.
  ///
  /// Wrinkle priority within a single layer:
  ///   1. locked (bottom of pure-color stack only)
  ///   2. frozen
  ///   3. fragile / priority / time-bomb (mutually exclusive, top of mixed)
  ///   4. double-color (any position in mixed)
  /// At most ONE wrinkle is applied per layer — the first matching
  /// branch wins, and the layer is left alone if no wrinkle qualifies.
  static GameStack applyToBay(
    GameStack bay,
    List<String> wrinkles, {
    required Random rng,
  }) {
    if (bay.isEmpty) return bay;
    if (wrinkles.isEmpty) return bay;

    final layers = bay.layers;
    final colors = layers.map((l) => l.colorIndex).toSet();
    final isMixed = colors.length > 1;

    // Probabilities scale with wrinkle list participation — if a
    // wrinkle isn't in the list, its prob is 0.
    final lockedProb = wrinkles.contains('locked') ? 0.10 : 0.0;
    final frozenProb = wrinkles.contains('frozen') ? 0.12 : 0.0;
    final fragileProb = wrinkles.contains('fragile') ? 0.14 : 0.0;
    final priorityProb = wrinkles.contains('priority') ? 0.12 : 0.0;
    final timeBombProb = wrinkles.contains('time-bomb') ? 0.08 : 0.0;
    final doubleColorProb = wrinkles.contains('double-color') ? 0.10 : 0.0;

    bool lockedDone = false;
    bool frozenDone = false;
    bool fragileDone = false;
    bool priorityDone = false;
    bool timeBombDone = false;
    bool doubleColorDone = false;

    final newLayers = <Layer>[];
    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i];
      final isBottom = i == 0;
      final isTop = i == layers.length - 1;

      Layer? wrinkled;

      // 1. Locked — bottom of pure-color stack only (so unlocking
      //    isn't trivially solved by skipping; player has to wait
      //    out the countdown to reach it).
      if (!lockedDone &&
          isBottom &&
          !isMixed &&
          rng.nextDouble() < lockedProb) {
        final lockedFor = (rng.nextInt(3) + 1).clamp(1, 3);
        wrinkled = Layer.locked(
          colorIndex: layer.colorIndex,
          lockedFor: lockedFor,
        );
        lockedDone = true;
      }
      // 2. Frozen — any position.
      else if (!frozenDone && rng.nextDouble() < frozenProb) {
        wrinkled = Layer.frozen(colorIndex: layer.colorIndex);
        frozenDone = true;
      }
      // 3a. Fragile — top of mixed stack.
      else if (!fragileDone &&
          !priorityDone &&
          !timeBombDone &&
          isTop &&
          isMixed &&
          rng.nextDouble() < fragileProb) {
        wrinkled = Layer.fragile(colorIndex: layer.colorIndex);
        fragileDone = true;
      }
      // 3b. Priority — top of mixed stack, mutually exclusive w/
      //     fragile + time-bomb so the player can tell at a glance
      //     which urgent crate is which.
      else if (!fragileDone &&
          !priorityDone &&
          !timeBombDone &&
          isTop &&
          isMixed &&
          rng.nextDouble() < priorityProb) {
        wrinkled = Layer.priority(
          colorIndex: layer.colorIndex,
          deadline: 8,
        );
        priorityDone = true;
      }
      // 3c. Time-bomb — top of mixed stack, tighter deadline +
      //     bigger penalty than priority.
      else if (!fragileDone &&
          !priorityDone &&
          !timeBombDone &&
          isTop &&
          isMixed &&
          rng.nextDouble() < timeBombProb) {
        wrinkled = Layer.timeBomb(
          colorIndex: layer.colorIndex,
          deadline: 6,
        );
        timeBombDone = true;
      }
      // 4. Double-color — any position in a mixed stack. Picks a
      //    second color from the layer's neighbors so the
      //    multi-color matches realistic gameplay options.
      else if (!doubleColorDone &&
          isMixed &&
          rng.nextDouble() < doubleColorProb) {
        // Second color: pick a different color present in the bay.
        final otherColors =
            colors.where((c) => c != layer.colorIndex).toList();
        if (otherColors.isNotEmpty) {
          final second = otherColors[rng.nextInt(otherColors.length)];
          wrinkled = Layer.multiColor(
            colors: [layer.colorIndex, second],
          );
          doubleColorDone = true;
        }
      }

      newLayers.add(wrinkled ?? layer);
    }

    return GameStack(
      layers: newLayers,
      maxDepth: bay.maxDepth,
      id: bay.id,
    );
  }

  /// Apply wrinkles to every bay in [bays] using the shared [rng].
  /// Used at level-load time to layer wrinkles across the full
  /// initial visible set; pending-delivery bays can apply wrinkles
  /// later via the same per-bay method as they slide in.
  static List<GameStack> applyToBays(
    List<GameStack> bays,
    List<String> wrinkles, {
    required Random rng,
  }) {
    return bays
        .map((b) => applyToBay(b, wrinkles, rng: rng))
        .toList(growable: false);
  }
}

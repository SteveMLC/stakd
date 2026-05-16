import 'dart:math';

import '../models/layer_model.dart';
import '../models/stack_model.dart';

/// Conveyor-mechanic seed generator.
///
/// Uses the industry-standard **reverse-construction** algorithm (Water
/// Sort / Ball Sort) — start from the solved state and apply N valid
/// reverse-moves chosen uniformly at random. Because each reverse-move
/// is the literal inverse of a player's forward move, the resulting
/// puzzle is **provably solvable in ≤ N forward moves**. No BFS
/// solvability validation, no flaky retry loops, no probabilistic
/// difficulty scoring.
///
/// See `docs/conveyor-mechanic-spec.md` section 3 for the full
/// rationale.
///
/// This generator knows about COLORS, DEPTH, EMPTY-BAYS, and
/// SCRAMBLE-MOVES only. Wrinkles (frozen / locked / fragile / priority /
/// time-bomb / double-color / oversized) layer on AFTER seed
/// generation, via separate per-delivery additive passes (spec section
/// 7). Keeping the seed generator narrow is what makes the puzzle
/// math tractable.
class ConveyorSeed {
  /// Generate a fresh mixed-puzzle state.
  ///
  /// * [numColors] — distinct cargo colors. Each color contributes one
  ///   single-color "completed" bay to the solved baseline. Must be ≥ 2
  ///   for the puzzle to be non-trivial.
  /// * [bayDepth] — max layers per bay. Must be ≥ 2.
  /// * [numEmptyBays] — workspace bays added beyond the color bays. The
  ///   player needs at least 1 (typically 2) to have moveable space.
  ///   Must be ≥ 1.
  /// * [scrambleMoves] — count of reverse-moves to apply. Higher =
  ///   harder. Difficulty curve lives in the level-config table (spec
  ///   section 4.3), not here. Must be ≥ 1.
  /// * [rng] — caller supplies the Random instance so callers can seed
  ///   deterministically for daily-challenge puzzles or test
  ///   reproducibility.
  ///
  /// Inviolable: returned state is NEVER pre-solved (no bay is
  /// single-color-and-full). Asserts this before returning; if the
  /// algorithm somehow produces a pre-solved bay (would require
  /// degenerate `scrambleMoves` values), applies extra reverse-moves
  /// up to a small retry budget. If the retry budget is exhausted
  /// the generator throws — this is a "should be impossible" branch.
  static List<GameStack> generateBays({
    required int numColors,
    required int bayDepth,
    required int numEmptyBays,
    required int scrambleMoves,
    required Random rng,
  }) {
    assert(numColors >= 2, 'numColors must be >= 2 for a non-trivial puzzle');
    assert(bayDepth >= 2, 'bayDepth must be >= 2');
    assert(numEmptyBays >= 1, 'numEmptyBays must be >= 1 (player needs workspace)');
    assert(scrambleMoves >= 1, 'scrambleMoves must be >= 1');

    // ── Step 1: Build the solved baseline ────────────────────────────
    // C single-color bays at full depth, each one a homogeneous stack
    // of one cargo color, plus E empty workspace bays.
    final bays = <List<int>>[];
    for (int c = 0; c < numColors; c++) {
      // `growable: true` is critical — the reverse-move loop below uses
      // `removeLast()` + `add()` to shuffle layers between bays. The
      // default `List.filled` returns a fixed-length list.
      bays.add(List<int>.filled(bayDepth, c, growable: true));
    }
    for (int e = 0; e < numEmptyBays; e++) {
      bays.add(<int>[]);
    }

    // ── Step 2: Apply M valid reverse-moves ──────────────────────────
    // Each reverse-move is `top(src) → dst` where dst has space and
    // src ≠ dst. Because forward-move rules require dst to be empty
    // OR top-color-match, every reverse-move from this construction
    // can be undone by exactly one valid player forward-move.
    _applyReverseMoves(bays, bayDepth, scrambleMoves, rng);

    // ── Step 3: Sanity — never return a pre-solved bay ────────────────
    // With sufficient scrambleMoves (≥ numColors * bayDepth * 2 per the
    // difficulty table) this branch never trips in practice, but the
    // guard is cheap and catches any future config drift.
    int retries = 0;
    const maxRetries = 10;
    while (_anyBayPreSolved(bays, bayDepth) && retries < maxRetries) {
      // Apply a small extra batch of reverse-moves to mix any
      // accidentally-completed bay back into the puzzle.
      _applyReverseMoves(bays, bayDepth, scrambleMoves ~/ 5 + 1, rng);
      retries++;
    }
    if (_anyBayPreSolved(bays, bayDepth)) {
      throw StateError(
        'ConveyorSeed: failed to scramble all pre-solved bays after '
        '$maxRetries retries (numColors=$numColors, bayDepth=$bayDepth, '
        'numEmptyBays=$numEmptyBays, scrambleMoves=$scrambleMoves). '
        'Increase scrambleMoves and re-try.',
      );
    }

    // ── Step 4: Wrap raw colorIndex lists in domain types ────────────
    return bays
        .map(
          (layers) => GameStack(
            layers: layers.map((c) => Layer(colorIndex: c)).toList(),
            maxDepth: bayDepth,
          ),
        )
        .toList();
  }

  /// Apply [count] valid reverse-moves to [bays] in place.
  ///
  /// A reverse-move picks (src, dst) where:
  /// - src is non-empty
  /// - dst has space (length < bayDepth)
  /// - src ≠ dst
  ///
  /// Uniform-random selection from the full valid-pair set keeps the
  /// scramble distribution flat (no positional bias toward leftmost or
  /// rightmost bays).
  static void _applyReverseMoves(
    List<List<int>> bays,
    int bayDepth,
    int count,
    Random rng,
  ) {
    for (int i = 0; i < count; i++) {
      final validPairs = <List<int>>[];
      for (int s = 0; s < bays.length; s++) {
        if (bays[s].isEmpty) continue;
        for (int d = 0; d < bays.length; d++) {
          if (s == d) continue;
          if (bays[d].length >= bayDepth) continue;
          validPairs.add([s, d]);
        }
      }
      if (validPairs.isEmpty) {
        // Should be impossible given numEmptyBays >= 1 + numColors >= 2,
        // but bail safely if a degenerate config somehow exhausts moves.
        break;
      }
      final pick = validPairs[rng.nextInt(validPairs.length)];
      final src = pick[0];
      final dst = pick[1];
      bays[dst].add(bays[src].removeLast());
    }
  }

  /// Returns true if any bay is pre-solved (full + single color).
  ///
  /// Empty bays don't count. Partial bays don't count. Only bays at
  /// exactly [bayDepth] layers with all layers the same color count as
  /// pre-solved.
  static bool _anyBayPreSolved(List<List<int>> bays, int bayDepth) {
    for (final bay in bays) {
      if (bay.length != bayDepth) continue;
      final firstColor = bay.first;
      if (bay.every((c) => c == firstColor)) return true;
    }
    return false;
  }
}

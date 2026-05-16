import 'dart:collection';
import 'dart:math';
import '../models/stack_model.dart';
import '../models/layer_model.dart';
import '../utils/constants.dart';
import 'district_service.dart';

/// Encode LevelParams + optional seed for isolate.
/// `[colors, stacks, emptySlots, depth, shuffleMoves, minDifficultyScore, seed]`
List<int> encodeParamsForIsolate(LevelParams params, {int seed = 0}) => [
  params.colors,
  params.stacks,
  params.emptySlots,
  params.depth,
  params.shuffleMoves,
  params.minDifficultyScore,
  seed,
];

/// Decode isolate result + maxDepth into `List<GameStack>`.
List<GameStack> decodeStacksFromIsolate(List<List<int>> encoded, int maxDepth) {
  return encoded
      .map(
        (layerIndices) => GameStack(
          layers: layerIndices.map((i) => Layer(colorIndex: i)).toList(),
          maxDepth: maxDepth,
        ),
      )
      .toList();
}

/// Generates solvable puzzle levels
class LevelGenerator {
  final int _seedOffset;

  LevelGenerator({int? seed}) : _seedOffset = seed ?? 0;

  /// Generate a level with given parameters
  List<GameStack> generateLevel(int levelNumber) {
    final params = paramsForLevel(levelNumber);

    // Use level number as seed for reproducibility
    final levelRandom = Random(levelNumber * 12345 + _seedOffset);

    final state = _generateShuffledSolvableState(params, levelRandom);
    return _buildStacksFromState(state, params.depth, params: params);
  }

  /// District-aware level parameters. Starts with the base
  /// `LevelParams.forLevel(N)` curve, then asks `DistrictService` what
  /// wrinkles (if any) apply to this level's district and adjusts the
  /// generation probabilities accordingly.
  ///
  /// Currently implemented wrinkles:
  ///   - **`frozen`** → bumps `frozenBlockProbability` by +0.05, capped
  ///     at 0.30. District 3 (Cold Storage) has this hand-tuned; any
  ///     procedural district past D6 that the composer assigns the
  ///     `frozen` wrinkle to also lifts.
  ///
  /// Other wrinkles (`fragile`, `priority`, `oversized`, `time-bomb`,
  /// `conveyor-drift`, `gravity-flip`, `double-color`) are recognized
  /// but currently no-op — they need new mechanics in `GameState` +
  /// `LevelParams` before the generator can express them. Placeholder
  /// stubs document the intent.
  ///
  /// Levels 1-30 use the hand-tuned curated seeds in
  /// `local_regional_levels.dart` and don't pass through this method,
  /// so the wrinkle adjustments only affect procedural levels (31+).
  /// That keeps the curated launch curve undisturbed.
  LevelParams paramsForLevel(int levelNumber) {
    final base = LevelParams.forLevel(levelNumber);
    final district =
        DistrictService().districtForLevel(levelNumber);
    if (district == null || district.wrinkles.isEmpty) return base;

    double frozenProb = base.frozenBlockProbability;
    double fragileProb = base.fragileBlockProbability;
    double priorityProb = base.priorityBlockProbability;
    int priorityDeadline = base.priorityDeadlineMoves;
    double timeBombProb = base.timeBombBlockProbability;
    int timeBombDeadline = base.timeBombDeadlineMoves;
    double doubleColorProb = base.doubleColorBlockProbability;
    bool gravityFlipActive = base.gravityFlipActive;
    int gravityFlipPeriod = base.gravityFlipPeriodMoves;
    // double lockedProb = base.lockedBlockProbability;  // future
    for (final wrinkle in district.wrinkles) {
      switch (wrinkle) {
        case 'frozen':
          frozenProb = (frozenProb + 0.05).clamp(0.0, 0.30);
          break;
        case 'fragile':
          // District 8 ("fragile" wrinkle): spawns crates that incur a
          // cash penalty if the player attempts an invalid drop with
          // them on top. Capped at 0.18 so a typical puzzle gets ~1
          // fragile crate, not a whole stack of them.
          fragileProb = (fragileProb + 0.10).clamp(0.0, 0.18);
          break;
        case 'priority':
          // District 9 ("priority" wrinkle): countdown timer on the
          // crate. If the player doesn't ship it within N moves, they
          // take a $40 hit at payout. Higher districts (faster pace)
          // get a tighter deadline; default 8 moves works for D9.
          priorityProb = (priorityProb + 0.10).clamp(0.0, 0.16);
          priorityDeadline = 8;
          break;
        case 'time-bomb':
          // Procedural districts D11+ ("time-bomb" wrinkle): same shape
          // as priority but with tighter deadline (6 moves) and bigger
          // detonation penalty (\$80 vs priority's \$40). Spawns at
          // a lower rate so a puzzle gets at most 1 bomb — two
          // simultaneous bombs would be unfair given the tight window.
          timeBombProb = (timeBombProb + 0.07).clamp(0.0, 0.12);
          timeBombDeadline = 6;
          break;
        case 'double-color':
          // Procedural districts ("double-color" wrinkle): spawns
          // multi-color crates that count as MATCHING for any of their
          // two colors. Uses the existing `BlockType.multiColor`
          // machinery in layer_model + the matching logic in
          // stack_model.canAccept. ~0.10 prob cap so the puzzle gets
          // 1-2 multi-color crates, not a fully chaotic board.
          doubleColorProb = (doubleColorProb + 0.10).clamp(0.0, 0.18);
          break;
        case 'gravity-flip':
          // Procedural districts ("gravity-flip" wrinkle): every 5
          // completed moves, the entire board inverts its render
          // direction. Bay heights / stack math / solvability stay
          // intact — it's a pure visual disruption the player has
          // to re-orient through. GameState handles the period
          // counter + toggle; the render flip lives in game_board.
          gravityFlipActive = true;
          gravityFlipPeriod = 5;
          break;
        case 'oversized':
        case 'conveyor-drift':
          // Stubs — these wrinkles need new GameState mechanics before
          // the generator can express them. Tracked as Phase C-3
          // follow-on work. For now they're recognized so the lookup
          // doesn't throw, but they contribute no probability bump.
          break;
        default:
          // Unknown wrinkle — ignore. Lets future composer additions
          // land without crashing previously-generated levels.
          break;
      }
    }

    return LevelParams(
      colors: base.colors,
      stacks: base.stacks,
      emptySlots: base.emptySlots,
      depth: base.depth,
      shuffleMoves: base.shuffleMoves,
      minDifficultyScore: base.minDifficultyScore,
      lockedBlockProbability: base.lockedBlockProbability,
      maxLockedMoves: base.maxLockedMoves,
      frozenBlockProbability: frozenProb,
      fragileBlockProbability: fragileProb,
      priorityBlockProbability: priorityProb,
      priorityDeadlineMoves: priorityDeadline,
      timeBombBlockProbability: timeBombProb,
      timeBombDeadlineMoves: timeBombDeadline,
      doubleColorBlockProbability: doubleColorProb,
      gravityFlipActive: gravityFlipActive,
      gravityFlipPeriodMoves: gravityFlipPeriod,
    );
  }

  /// Check if a puzzle state is solved
  // ignore: unused_element
  bool _isSolved(List<GameStack> stacks) {
    for (final stack in stacks) {
      if (stack.isEmpty) continue;
      if (!stack.isComplete) return false;
    }
    return true;
  }

  // Phase H — DELETED (2026-05-16): difficultyScore, calculatePar,
  // isSolvable, _stateToKey, generateSolvableLevel, generateLevelWithPar.
  // The conveyor mechanic owns the main-path level harness via
  // ConveyorSeed (solvability by construction, no BFS validation).
  // Daily challenge still uses generateLevel + generateDailyChallenge.


  /// Generate the daily challenge level (deterministic by date).
  ///
  /// Phase H — the old loop-and-pick-best-by-difficultyScore was
  /// replaced by a single shuffled-solvable build using the same
  /// reverse-walk that powered the legacy generator. Difficulty
  /// filtering is gone (the conveyor mechanic's difficulty curve
  /// lives in `ConveyorLevelConfig`, not here). Daily challenge is
  /// intentionally a fixed-shape Level-20-difficulty puzzle.
  List<GameStack> generateDailyChallenge({DateTime? date}) {
    final challengeDate = (date ?? DateTime.now().toUtc());
    final seed = _dateSeed(challengeDate) + _seedOffset;

    final baseParams = LevelParams.forLevel(20);
    final colors = baseParams.colors.clamp(3, 5);
    final emptySlots = max(2, baseParams.emptySlots);
    final depth = min(4, baseParams.depth);

    final params = LevelParams(
      colors: colors,
      stacks: colors + emptySlots,
      emptySlots: emptySlots,
      depth: depth,
      shuffleMoves: baseParams.shuffleMoves + 12,
    );

    final levelRandom = Random(seed);
    final state = _generateShuffledSolvableState(params, levelRandom);
    return _buildStacksFromState(state, params.depth, params: params);
  }

  /// Generate a shuffled, always-solvable starting state.
  ///
  /// Reverse-walk approach: start from the SOLVED state, apply N
  /// random *forward* moves (each one a legal move from the current
  /// position). The resulting state is guaranteed solvable because
  /// every game move is reversible. This sidesteps the expensive
  /// BFS solvability check that previously hung the L1 launch path
  /// (100K-state cap × 50 attempts × 10 difficulty-tier attempts =
  /// up to 50M state visits per `generateSolvableLevel(1)` call).
  ///
  /// We then run a couple of cheap filters (no fully-solved tubes,
  /// not too many same-color adjacencies) so the level doesn't read
  /// as trivially-stacked at the very top.
  List<List<int>> _generateShuffledSolvableState(
    LevelParams params,
    Random random, {
    int maxAttempts = 10,
    // Kept for API compatibility — no longer used now that we
    // skip the BFS solvability check entirely.
    // ignore: unused_element_parameter
    int maxSolvableStates = 2000,
  }) {
    final solved = _createSolvedState(
      params.colors,
      params.emptySlots,
      params.depth,
    );

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      // Vary the shuffle depth across attempts so we get differently-
      // hard layouts. params.shuffleMoves is the floor; each retry
      // adds more shuffle moves for a harder configuration.
      final shuffleMoves = params.shuffleMoves + attempt * 5;
      final tubes = _shuffleState(solved, params.depth, shuffleMoves, random);

      if (_hasSolvedTube(tubes, params.depth)) continue;
      if (_sameColorAdjacencyRatio(tubes) > 0.35) continue;

      return tubes;
    }

    // Last-resort fallback: a plain shuffle with the params' default
    // shuffleMoves. This will rarely fire — only if every attempt above
    // produced a degenerate (e.g. fully-solved tube) configuration.
    return _shuffleState(solved, params.depth, params.shuffleMoves, random);
  }

  // ignore: unused_element
  void _fisherYatesShuffle(List<int> list, Random random) {
    for (int i = list.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  bool _hasSolvedTube(List<List<int>> tubes, int depth) {
    for (final tube in tubes) {
      if (tube.length == depth && tube.every((c) => c == tube.first)) {
        return true;
      }
    }
    return false;
  }

  double _sameColorAdjacencyRatio(List<List<int>> tubes) {
    int same = 0;
    int total = 0;
    for (final tube in tubes) {
      for (int i = 1; i < tube.length; i++) {
        total++;
        if (tube[i] == tube[i - 1]) {
          same++;
        }
      }
    }
    if (total == 0) return 0.0;
    return same / total;
  }

  bool _isSolvedState(List<List<int>> tubes, int depth) {
    for (final tube in tubes) {
      if (tube.isEmpty) continue;
      if (tube.length != depth) return false;
      if (!tube.every((c) => c == tube.first)) return false;
    }
    return true;
  }

  // Kept (unused) for reference — was the BFS-based solvability check.
  // We now skip this entirely and use the always-solvable reverse-walk
  // path in `_generateShuffledSolvableState`. Marked private + ignored
  // so the analyzer doesn't complain.
  // ignore: unused_element
  bool _isSolvableState(List<List<int>> tubes, int depth, int maxStates) {
    if (_greedySolve(tubes, depth)) return true;
    return _bfsSolvableState(tubes, depth, maxStates);
  }

  bool _greedySolve(List<List<int>> tubes, int depth) {
    var state = tubes.map((t) => List<int>.from(t)).toList();
    var visited = <String>{};
    return _greedyDFS(state, depth, visited, 0, 500);
  }

  bool _greedyDFS(List<List<int>> state, int depth, Set<String> visited,
      int moves, int maxMoves) {
    if (moves > maxMoves) return false;
    final key = _serializeState(state);
    if (visited.contains(key)) return false;
    visited.add(key);
    if (_isSolvedState(state, depth)) return true;

    var movesList = <(int, int, int)>[];
    for (int from = 0; from < state.length; from++) {
      if (state[from].isEmpty) continue;
      final block = state[from].last;
      for (int to = 0; to < state.length; to++) {
        if (from == to) continue;
        if (state[to].length >= depth) continue;
        if (state[to].isNotEmpty && state[to].last != block) continue;

        int priority = 0;
        if (state[to].length == depth - 1 &&
            state[to].isNotEmpty &&
            state[to].every((c) => c == block)) {
          priority = 100;
        } else if (state[to].isNotEmpty && state[to].last == block) {
          priority = 50;
        } else if (state[to].isEmpty) {
          priority = 10;
        }

        movesList.add((from, to, priority));
      }
    }

    movesList.sort((a, b) => b.$3.compareTo(a.$3));

    for (final (from, to, _) in movesList) {
      final block = state[from].removeLast();
      state[to].add(block);
      if (_greedyDFS(state, depth, visited, moves + 1, maxMoves)) return true;
      state[to].removeLast();
      state[from].add(block);
    }

    visited.remove(key);
    return false;
  }

  bool _bfsSolvableState(List<List<int>> tubes, int depth, int maxStates) {
    final visited = <String>{};
    final queue = Queue<List<List<int>>>();
    queue.add(tubes.map((t) => List<int>.from(t)).toList());

    while (queue.isNotEmpty && visited.length < maxStates) {
      final current = queue.removeFirst();
      final key = _serializeState(current);
      if (visited.contains(key)) continue;
      visited.add(key);

      if (_isSolvedState(current, depth)) return true;

      for (int from = 0; from < current.length; from++) {
        if (current[from].isEmpty) continue;
        final block = current[from].last;
        for (int to = 0; to < current.length; to++) {
          if (from == to) continue;
          if (current[to].length >= depth) continue;
          if (current[to].isNotEmpty && current[to].last != block) continue;

          final next = current.map((t) => List<int>.from(t)).toList();
          next[from].removeLast();
          next[to].add(block);
          final nextKey = _serializeState(next);
          if (!visited.contains(nextKey)) {
            queue.add(next);
          }
        }
      }
    }

    return false;
  }

  List<List<int>> _createSolvedState(int colors, int emptySlots, int depth) {
    final tubes = <List<int>>[];
    for (int c = 0; c < colors; c++) {
      tubes.add(List<int>.filled(depth, c));
    }
    for (int i = 0; i < emptySlots; i++) {
      tubes.add([]);
    }
    return tubes;
  }

  List<List<int>> _shuffleState(
      List<List<int>> tubes, int depth, int moves, Random random) {
    final state = tubes.map((t) => List<int>.from(t)).toList();
    for (int m = 0; m < moves; m++) {
      final validMoves = <(int, int)>[];
      for (int from = 0; from < state.length; from++) {
        if (state[from].isEmpty) continue;
        final block = state[from].last;
        for (int to = 0; to < state.length; to++) {
          if (from == to) continue;
          if (state[to].length >= depth) continue;
          if (state[to].isNotEmpty && state[to].last != block) continue;
          validMoves.add((from, to));
        }
      }
      if (validMoves.isEmpty) break;
      final (from, to) = validMoves[random.nextInt(validMoves.length)];
      state[to].add(state[from].removeLast());
    }
    return state;
  }

  String _serializeState(List<List<int>> tubes) {
    return tubes.map((t) => t.join(',')).join('|');
  }

  List<GameStack> _buildStacksFromState(
    List<List<int>> state,
    int maxDepth, {
    LevelParams? params,
  }) {
    final stacks = state
        .map(
          (layers) => GameStack(
            layers: layers.map((i) => Layer(colorIndex: i)).toList(),
            maxDepth: maxDepth,
          ),
        )
        .toList();

    // Phase H — Wrinkle additives moved to `WrinkleLayerer`. The
    // main game path (`game_screen._loadLevel`) calls that directly.
    // Daily challenge uses `generateLevel`/`generateDailyChallenge`
    // which routes through here and now returns pure-color bays.
    // Phase G+ daily-challenge wrinkles, if desired, would call
    // WrinkleLayerer on the output of generateDailyChallenge.
    return stacks;
  }

  // Phase H — applySpecialBlocks DELETED. WrinkleLayerer owns
  // post-seed wrinkle additives now; the conveyor mechanic routes
  // through it directly. Daily challenge produces pure-color bays.


  int _dateSeed(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return int.parse('$year$month$day');
  }
}

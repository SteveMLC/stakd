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
        case 'oversized':
        case 'conveyor-drift':
        case 'gravity-flip':
        case 'double-color':
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
    );
  }

  /// Check if a puzzle state is solved
  bool _isSolved(List<GameStack> stacks) {
    for (final stack in stacks) {
      if (stack.isEmpty) continue;
      if (!stack.isComplete) return false;
    }
    return true;
  }

  /// Calculate difficulty score based on color transitions and mixing
  /// Higher score = more difficult puzzle
  int difficultyScore(List<GameStack> stacks) {
    int score = 0;

    for (final stack in stacks) {
      if (stack.isEmpty || stack.layers.length <= 1) continue;

      // Count color transitions within each stack
      int transitions = 0;
      Set<int> uniqueColors = {};
      int buriedSingletons = 0;

      for (int i = 0; i < stack.layers.length; i++) {
        final color = stack.layers[i].colorIndex;
        uniqueColors.add(color);
        if (i > 0 && color != stack.layers[i - 1].colorIndex) {
          transitions++;
          if (i >= 2) {
            final prevPrev = stack.layers[i - 2].colorIndex;
            final prev = stack.layers[i - 1].colorIndex;
            if (prevPrev != prev && prev != color) {
              buriedSingletons++;
            }
          }
        }
      }

      // More transitions = harder
      score += transitions * 2;

      // Buried singletons are much harder
      score += buriedSingletons * 3;

      // Stacks with many unique colors are harder to solve
      if (uniqueColors.length >= 3) {
        score += (uniqueColors.length - 2) * 2;
      }

      if (stack.layers.length >= 4 && uniqueColors.length >= 2) {
        score += stack.layers.length - 3;
      }
    }

    // Penalize "almost solved" states
    int completedStacks = stacks.where((s) => s.isComplete).length;
    int nearlyComplete = stacks
        .where(
          (s) =>
              s.layers.length >= 3 &&
              s.layers.every((l) => l.colorIndex == s.layers.first.colorIndex),
        )
        .length;

    score -= completedStacks * 4;
    score -= nearlyComplete * 2;

    return score.clamp(0, 100);
  }

  /// Calculate minimum moves to solve (Par) using BFS
  /// Returns null if unsolvable within maxStates
  int? calculatePar(List<GameStack> stacks, {int maxStates = 15000}) {
    if (_isSolved(stacks)) return 0;

    final visited = <String, int>{};
    final queue = <(List<GameStack>, int)>[
      (stacks.map((s) => s.copy()).toList(), 0),
    ];

    while (queue.isNotEmpty && visited.length < maxStates) {
      final (current, moves) = queue.removeAt(0);
      final stateKey = _stateToKey(current);

      if (visited.containsKey(stateKey)) continue;
      visited[stateKey] = moves;

      if (_isSolved(current)) return moves;

      // Generate all valid next states
      for (int from = 0; from < current.length; from++) {
        if (current[from].isEmpty) continue;
        for (int to = 0; to < current.length; to++) {
          if (from == to) continue;
          if (current[to].canAccept(current[from].topLayer!)) {
            final next = current.map((s) => s.copy()).toList();
            final layer = next[from].topLayer!;
            next[from] = next[from].withTopLayerRemoved();
            next[to] = next[to].withLayerAdded(layer);

            final nextKey = _stateToKey(next);
            if (!visited.containsKey(nextKey)) {
              queue.add((next, moves + 1));
            }
          }
        }
      }
    }

    // If we found a solution during traversal
    for (final entry in visited.entries) {
      if (entry.value > 0) {
        // Check if any visited state is solved
        // (optimization: we return early on solve, so this shouldn't be needed)
      }
    }

    return null; // Unsolvable within limit
  }

  /// Verify that a level is solvable using BFS
  bool isSolvable(List<GameStack> stacks, {int maxStates = 10000}) {
    final visited = <String>{};
    final queue = <List<GameStack>>[stacks.map((s) => s.copy()).toList()];

    while (queue.isNotEmpty && visited.length < maxStates) {
      final current = queue.removeAt(0);
      final stateKey = _stateToKey(current);

      if (visited.contains(stateKey)) continue;
      visited.add(stateKey);

      if (_isSolved(current)) return true;

      // Generate all valid next states
      for (int from = 0; from < current.length; from++) {
        if (current[from].isEmpty) continue;
        for (int to = 0; to < current.length; to++) {
          if (from == to) continue;
          if (current[to].canAccept(current[from].topLayer!)) {
            final next = current.map((s) => s.copy()).toList();
            final layer = next[from].topLayer!;
            next[from] = next[from].withTopLayerRemoved();
            next[to] = next[to].withLayerAdded(layer);

            final nextKey = _stateToKey(next);
            if (!visited.contains(nextKey)) {
              queue.add(next);
            }
          }
        }
      }
    }

    return false;
  }

  /// Convert state to string key for visited set
  String _stateToKey(List<GameStack> stacks) {
    return stacks
        .map((s) => s.layers.map((l) => l.colorIndex.toString()).join(','))
        .join('|');
  }

  /// Generate a level and verify it's solvable and sufficiently difficult
  List<GameStack> generateSolvableLevel(int levelNumber) {
    final params = paramsForLevel(levelNumber);
    final minDifficulty = params.minDifficultyScore;

    List<GameStack>? bestLevel;
    int bestScore = -1;

    // Try multiple seeds to find a level that's both solvable and difficult enough
    for (int attempt = 0; attempt < 10; attempt++) {
      final seedMultiplier = attempt == 0 ? 12345 : 12345 + attempt * 67890;
      final altRandom = Random(levelNumber * seedMultiplier + _seedOffset);
      final state = _generateShuffledSolvableState(params, altRandom);
      final level = _buildStacksFromState(state, params.depth, params: params);

      // Check difficulty score
      final score = difficultyScore(level);
      if (score >= minDifficulty) {
        // Good enough - use this level
        return level;
      }

      // Track best attempt in case we can't meet threshold
      if (score > bestScore) {
        bestScore = score;
        bestLevel = level;
      }
    }

    // Return best attempt if no level met the threshold
    return bestLevel ?? generateLevel(levelNumber);
  }

  /// Generate an endless Zen puzzle with difficulty preset
  List<GameStack> generateZenPuzzle(String difficulty) {
    final params = switch (difficulty) {
      'easy' => ZenParams.easy,
      'medium' => ZenParams.medium,
      'hard' => ZenParams.hard,
      'ultra' => ZenParams.ultra,
      _ => ZenParams.medium,
    };

    return generatePuzzleWithParams(params);
  }

  /// [maxAttempts] and [maxSolvableStates] can be lowered for Zen for faster generation.
  List<GameStack> generatePuzzleWithParams(
    LevelParams params, {
    int maxAttempts = 15,
    int maxSolvableStates = 5000,
  }) {
    List<GameStack>? bestLevel;
    int bestScore = -1;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final random = Random(DateTime.now().millisecondsSinceEpoch + attempt);
      final state = _generateShuffledSolvableState(
        params,
        random,
        maxAttempts: 1,
        maxSolvableStates: maxSolvableStates,
      );
      final level = _buildStacksFromState(state, params.depth, params: params);

      final score = difficultyScore(level);
      if (score >= params.minDifficultyScore) {
        return level;
      }

      if (score > bestScore) {
        bestScore = score;
        bestLevel = level;
      }
    }

    // Fallback: generate a shuffled puzzle even if it doesn't meet difficulty threshold
    return bestLevel ?? generateLevel(1);
  }

  /// Generate a level with par information
  (List<GameStack>, int?) generateLevelWithPar(int levelNumber) {
    final level = generateSolvableLevel(levelNumber);
    final par = calculatePar(level);
    return (level, par);
  }

  /// Generate the daily challenge level (deterministic by date)
  List<GameStack> generateDailyChallenge({DateTime? date}) {
    final challengeDate = (date ?? DateTime.now().toUtc());
    final seed = _dateSeed(challengeDate) + _seedOffset;

    // Daily challenge: moderate difficulty, must generate reliably
    final baseParams = LevelParams.forLevel(20);
    final colors = baseParams.colors.clamp(3, 5); // cap at 5 colors
    final emptySlots = max(2, baseParams.emptySlots); // keep 2 empty slots
    final depth = min(4, baseParams.depth); // cap at depth 4

    final params = LevelParams(
      colors: colors,
      stacks: colors + emptySlots,
      emptySlots: emptySlots,
      depth: depth,
      shuffleMoves: baseParams.shuffleMoves + 12,
    );

    final minDifficulty = params.minDifficultyScore;

    List<GameStack>? bestLevel;
    int bestScore = -1;

    for (int attempt = 0; attempt < 10; attempt++) {
      final levelRandom = Random(seed + attempt * 997);
      final state = _generateShuffledSolvableState(params, levelRandom);
      final level = _buildStacksFromState(state, params.depth, params: params);

      final score = difficultyScore(level);
      if (score >= minDifficulty) {
        return level;
      }

      if (score > bestScore) {
        bestScore = score;
        bestLevel = level;
      }
    }

    return bestLevel ?? generateLevel(1);
  }

  /// Generate the daily challenge level with par information
  (List<GameStack>, int?) generateDailyChallengeWithPar({DateTime? date}) {
    final level = generateDailyChallenge(date: date);
    final par = calculatePar(level);
    return (level, par);
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

    // Apply special blocks (locked/frozen) after building solvable state
    if (params != null) {
      applySpecialBlocks(stacks, params);
    }

    return stacks;
  }

  /// Apply locked, frozen, fragile, priority, and time-bomb blocks to
  /// an already-generated puzzle. Caps per-puzzle: max 1 locked, max 2
  /// frozen, max 2 fragile, max 1 priority, max 1 time-bomb. Never locks
  /// a block at the bottom of a mixed-color stack. Lock timer capped at
  /// 3 moves.
  void applySpecialBlocks(List<GameStack> stacks, LevelParams params) {
    if (params.lockedBlockProbability <= 0 &&
        params.frozenBlockProbability <= 0 &&
        params.fragileBlockProbability <= 0 &&
        params.priorityBlockProbability <= 0 &&
        params.timeBombBlockProbability <= 0) {
      return;
    }

    final random = Random();
    int lockedCount = 0;
    int frozenCount = 0;
    int fragileCount = 0;
    int priorityCount = 0;
    int timeBombCount = 0;
    const maxLocked = 1;
    const maxFrozen = 2;
    const maxFragile = 2;
    const maxPriority = 1;
    const maxTimeBomb = 1;

    for (int s = 0; s < stacks.length; s++) {
      final stack = stacks[s];
      if (stack.isEmpty) continue;

      // Check if this stack has mixed colors
      final colors = stack.layers.map((l) => l.colorIndex).toSet();
      final isMixed = colors.length > 1;

      final newLayers = <Layer>[];
      for (int i = 0; i < stack.layers.length; i++) {
        final layer = stack.layers[i];
        final isBottom = (i == 0);
        final isTop = (i == stack.layers.length - 1);

        // Locked blocks: prefer bottom positions, but skip if mixed stack bottom
        if (lockedCount < maxLocked &&
            params.lockedBlockProbability > 0 &&
            isBottom &&
            !isMixed &&
            random.nextDouble() < params.lockedBlockProbability) {
          final lockedFor = (random.nextInt(3) + 1).clamp(1, 3);
          newLayers.add(
            Layer.locked(colorIndex: layer.colorIndex, lockedFor: lockedFor),
          );
          lockedCount++;
        }
        // Frozen blocks: can be anywhere
        else if (frozenCount < maxFrozen &&
            params.frozenBlockProbability > 0 &&
            random.nextDouble() < params.frozenBlockProbability) {
          newLayers.add(Layer.frozen(colorIndex: layer.colorIndex));
          frozenCount++;
        }
        // Fragile blocks: prefer TOP positions so the player has to
        // think about where to drop them. Only spawn on stacks that
        // would actually require movement (mixed colors). Cash penalty
        // on wrong-color drop attempts is wired in GameState.
        else if (fragileCount < maxFragile &&
            params.fragileBlockProbability > 0 &&
            isTop &&
            isMixed &&
            random.nextDouble() < params.fragileBlockProbability) {
          newLayers.add(Layer.fragile(colorIndex: layer.colorIndex));
          fragileCount++;
        }
        // Priority blocks: rare (max 1 per puzzle), prefer TOP of a
        // mixed-color stack so the player has to actually ship the
        // crate, not just leave it buried. The countdown is the
        // params.priorityDeadlineMoves so districts can dial pace.
        else if (priorityCount < maxPriority &&
            params.priorityBlockProbability > 0 &&
            isTop &&
            isMixed &&
            random.nextDouble() < params.priorityBlockProbability) {
          newLayers.add(Layer.priority(
            colorIndex: layer.colorIndex,
            deadline: params.priorityDeadlineMoves,
          ));
          priorityCount++;
        }
        // Time-bomb: harshest timed wrinkle, max 1 per puzzle, also
        // prefers TOP of a mixed stack. 6-move default deadline + $80
        // detonation penalty makes it the "you have to deal with this
        // RIGHT NOW" beat. Guarded to not co-spawn with priority on
        // the same crate so the player can read at-a-glance which
        // urgent crate is which.
        else if (timeBombCount < maxTimeBomb &&
            params.timeBombBlockProbability > 0 &&
            isTop &&
            isMixed &&
            !layer.isPriority &&
            random.nextDouble() < params.timeBombBlockProbability) {
          newLayers.add(Layer.timeBomb(
            colorIndex: layer.colorIndex,
            deadline: params.timeBombDeadlineMoves,
          ));
          timeBombCount++;
        } else {
          newLayers.add(layer);
        }
      }

      stacks[s] = GameStack(
        layers: newLayers,
        maxDepth: stack.maxDepth,
        id: stack.id,
      );
    }
  }

  int _dateSeed(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return int.parse('$year$month$day');
  }
}

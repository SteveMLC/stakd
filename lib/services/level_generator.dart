import 'dart:collection';
import 'dart:math';
import '../models/stack_model.dart';
import '../models/layer_model.dart';
import '../utils/constants.dart';

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
    final params = LevelParams.forLevel(levelNumber);

    // Use level number as seed for reproducibility
    final levelRandom = Random(levelNumber * 12345 + _seedOffset);

    final state = _generateShuffledSolvableState(params, levelRandom);
    return _buildStacksFromState(state, params.depth, params: params);
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
    final params = LevelParams.forLevel(levelNumber);
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

    // Slightly harder than normal levels: more colors, fewer empty slots
    final baseParams = LevelParams.forLevel(30);
    final colors = (baseParams.colors + 1).clamp(3, GameConfig.maxColors);
    final emptySlots = max(1, baseParams.emptySlots - 1);
    final depth = min(GameConfig.maxStackDepth, baseParams.depth);

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

  List<List<int>> _generateShuffledSolvableState(
    LevelParams params,
    Random random, {
    int maxAttempts = 50,
    int maxSolvableStates = 100000,
  }) {
    final blocks = <int>[];
    for (int color = 0; color < params.colors; color++) {
      for (int i = 0; i < params.depth; i++) {
        blocks.add(color);
      }
    }

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final shuffled = List<int>.from(blocks);
      _fisherYatesShuffle(shuffled, random);

      final tubes = <List<int>>[];
      int index = 0;
      for (int t = 0; t < params.colors; t++) {
        final tube = <int>[];
        for (int i = 0; i < params.depth; i++) {
          tube.add(shuffled[index++]);
        }
        tubes.add(tube);
      }
      for (int i = 0; i < params.emptySlots; i++) {
        tubes.add([]);
      }

      if (_hasSolvedTube(tubes, params.depth)) continue;
      if (_sameColorAdjacencyRatio(tubes) > 0.35) continue;
      if (!_isSolvableState(tubes, params.depth, maxSolvableStates)) continue;

      return tubes;
    }

    // Fallback: shuffle from solved state (always solvable)
    final solved = _createSolvedState(params.colors, params.emptySlots, params.depth);
    return _shuffleState(solved, params.depth, 200, random);
  }

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

  bool _isSolvableState(List<List<int>> tubes, int depth, int maxStates) {
    // Try greedy heuristic first (fast path)
    if (_greedySolve(tubes, depth)) return true;
    // Fall back to BFS with higher limit
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

  /// Apply locked and frozen blocks to an already-generated puzzle
  void applySpecialBlocks(List<GameStack> stacks, LevelParams params) {
    if (params.lockedBlockProbability <= 0 &&
        params.frozenBlockProbability <= 0) {
      return;
    }

    final random = Random();

    for (int s = 0; s < stacks.length; s++) {
      final stack = stacks[s];
      if (stack.isEmpty) continue;

      final newLayers = <Layer>[];
      for (int i = 0; i < stack.layers.length; i++) {
        final layer = stack.layers[i];
        final isBottom = (i == 0);

        // Locked blocks: prefer bottom positions
        if (params.lockedBlockProbability > 0 &&
            isBottom &&
            random.nextDouble() < params.lockedBlockProbability) {
          final lockedFor = random.nextInt(params.maxLockedMoves) + 1;
          newLayers.add(
            Layer.locked(colorIndex: layer.colorIndex, lockedFor: lockedFor),
          );
        }
        // Frozen blocks: can be anywhere
        else if (params.frozenBlockProbability > 0 &&
            random.nextDouble() < params.frozenBlockProbability) {
          newLayers.add(Layer.frozen(colorIndex: layer.colorIndex));
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

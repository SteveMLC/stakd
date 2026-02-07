import 'dart:math';
import '../models/stack_model.dart';
import '../models/layer_model.dart';
import '../utils/constants.dart';

/// Generates solvable puzzle levels
class LevelGenerator {
  final int _seedOffset;

  LevelGenerator({int? seed}) : _seedOffset = seed ?? 0;

  /// Generate a level with given parameters
  List<GameStack> generateLevel(int levelNumber) {
    final params = LevelParams.forLevel(levelNumber);

    // Use level number as seed for reproducibility
    final levelRandom = Random(levelNumber * 12345 + _seedOffset);

    // Create solved state first
    List<GameStack> stacks = _createSolvedState(params, levelRandom);

    // Shuffle by making valid moves in reverse
    stacks = _shuffleLevel(stacks, params.shuffleMoves, levelRandom);

    return stacks;
  }

  /// Create a solved puzzle state
  List<GameStack> _createSolvedState(LevelParams params, Random random) {
    final stacks = <GameStack>[];

    // Create color stacks (filled with one color each)
    for (int colorIndex = 0; colorIndex < params.colors; colorIndex++) {
      final layers = List.generate(
        params.depth,
        (i) => Layer(colorIndex: colorIndex),
      );
      stacks.add(GameStack(layers: layers, maxDepth: params.depth));
    }

    // Add empty stacks
    for (int i = 0; i < params.emptySlots; i++) {
      stacks.add(GameStack(layers: [], maxDepth: params.depth));
    }

    return stacks;
  }

  /// Shuffle the level by making random valid reverse moves
  List<GameStack> _shuffleLevel(
    List<GameStack> stacks,
    int moves,
    Random random,
  ) {
    var current = stacks.map((s) => s.copy()).toList();

    int movesRemaining = moves;
    int attempts = 0;
    int maxAttempts = moves * 10;

    while (movesRemaining > 0 && attempts < maxAttempts) {
      attempts++;

      // Find all valid moves
      final validMoves = <(int, int)>[];
      for (int from = 0; from < current.length; from++) {
        if (current[from].isEmpty) continue;
        for (int to = 0; to < current.length; to++) {
          if (from == to) continue;
          if (current[to].canAccept(current[from].topLayer!)) {
            validMoves.add((from, to));
          }
        }
      }

      if (validMoves.isEmpty) break;

      // Pick a random valid move
      final move = validMoves[random.nextInt(validMoves.length)];
      final fromStack = current[move.$1];
      final toStack = current[move.$2];

      final layer = fromStack.topLayer!;
      current[move.$1] = fromStack.withTopLayerRemoved();
      current[move.$2] = toStack.withLayerAdded(layer);

      movesRemaining--;
    }

    // Verify the result isn't already solved
    if (_isSolved(current)) {
      // Do a few more shuffles
      return _shuffleLevel(current, 10, random);
    }

    return current;
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

      for (int i = 0; i < stack.layers.length; i++) {
        uniqueColors.add(stack.layers[i].colorIndex);
        if (i > 0 &&
            stack.layers[i].colorIndex != stack.layers[i - 1].colorIndex) {
          transitions++;
        }
      }

      // More transitions = harder
      score += transitions;

      // Stacks with many unique colors are harder to solve
      if (uniqueColors.length >= 3) {
        score += uniqueColors.length - 2;
      }
    }

    // Penalize "almost solved" states where stacks are mostly sorted
    int completedStacks = stacks.where((s) => s.isComplete).length;
    if (completedStacks > 0) {
      score -= completedStacks * 2;
    }

    return score;
  }

  /// Calculate minimum moves to solve (Par) using BFS
  /// Returns null if unsolvable within maxStates
  int? calculatePar(List<GameStack> stacks, {int maxStates = 15000}) {
    if (_isSolved(stacks)) return 0;

    final visited = <String, int>{};
    final queue = <(List<GameStack>, int)>[
      (stacks.map((s) => s.copy()).toList(), 0)
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
      var level = _createSolvedState(params, altRandom);
      level = _shuffleLevel(level, params.shuffleMoves, altRandom);

      // Check solvability first
      if (!isSolvable(level, maxStates: 5000)) continue;

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
    final shuffleMoves = baseParams.shuffleMoves + 12;

    final params = LevelParams(
      colors: colors,
      stacks: colors + emptySlots,
      emptySlots: emptySlots,
      depth: depth,
      shuffleMoves: shuffleMoves,
    );

    var levelRandom = Random(seed);
    var level = _createSolvedState(params, levelRandom);
    level = _shuffleLevel(level, params.shuffleMoves, levelRandom);

    if (!isSolvable(level, maxStates: 5000)) {
      // Deterministic retries based on the same date seed
      for (int attempt = 1; attempt <= 5; attempt++) {
        levelRandom = Random(seed + attempt * 997);
        level = _createSolvedState(params, levelRandom);
        level = _shuffleLevel(level, params.shuffleMoves, levelRandom);
        if (isSolvable(level, maxStates: 5000)) break;
      }
    }

    return level;
  }

  int _dateSeed(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return int.parse('$year$month$day');
  }
}

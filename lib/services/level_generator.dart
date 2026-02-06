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

  /// Generate a level and verify it's solvable
  List<GameStack> generateSolvableLevel(int levelNumber) {
    var level = generateLevel(levelNumber);

    // Quick solvability check (limited states for performance)
    if (!isSolvable(level, maxStates: 5000)) {
      // Try regenerating with different seed
      for (int attempt = 1; attempt <= 5; attempt++) {
        final altRandom =
            Random(levelNumber * 12345 + _seedOffset + attempt * 67890);
        final params = LevelParams.forLevel(levelNumber);
        level = _createSolvedState(params, altRandom);
        level = _shuffleLevel(level, params.shuffleMoves, altRandom);

        if (isSolvable(level, maxStates: 5000)) break;
      }
    }

    return level;
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

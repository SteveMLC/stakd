// Pure Dart – NO Flutter imports. Safe to run in a background isolate.
// State: List<List<int>> = list of stacks, each stack = list of color indices (bottom to top).

import 'dart:math';

/// Args: `[colors, stacks, emptySlots, depth, shuffleMoves, minDifficultyScore, seed]`.
/// Returns encoded stacks: `List<List<int>>` for decodeStacksFromIsolate on main.
List<List<int>> generateZenPuzzleInIsolate(List<int> args) {
  if (args.length < 6) throw ArgumentError('Need at least 6 params');
  final colors = args[0];
  final emptySlots = args[2];
  final depth = args[3];
  final seed = args.length > 6 ? args[6] : 0;
  final random = seed == 0 ? Random() : Random(seed);

  const maxAttempts = 50;
  const maxSolvableStates = 100000;

  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    final blocks = <int>[];
    for (int color = 0; color < colors; color++) {
      for (int i = 0; i < depth; i++) {
        blocks.add(color);
      }
    }

    _fisherYatesShuffle(blocks, random);

    final tubes = <List<int>>[];
    int index = 0;
    for (int t = 0; t < colors; t++) {
      final tube = <int>[];
      for (int i = 0; i < depth; i++) {
        tube.add(blocks[index++]);
      }
      tubes.add(tube);
    }
    for (int i = 0; i < emptySlots; i++) {
      tubes.add([]);
    }

    if (_hasSolvedTube(tubes, depth)) continue;
    if (_sameColorAdjacencyRatio(tubes) > 0.35) continue;
    if (!_isSolvable(tubes, depth, maxSolvableStates)) continue;

    return tubes;
  }

  // Fallback: shuffle from solved state (always solvable)
  final solved = _createSolved(colors, emptySlots, depth, random);
  return _shuffle(solved, depth, 200, random);
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

bool _isSolvable(List<List<int>> tubes, int depth, int maxStates) {
  // Try greedy heuristic first (fast path)
  if (_greedySolve(tubes, depth)) return true;
  // Fall back to BFS with higher limit
  return _bfsSolvable(tubes, depth, maxStates);
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

  // Generate moves sorted by priority
  var movesList = <(int, int, int)>[];
  for (int from = 0; from < state.length; from++) {
    if (state[from].isEmpty) continue;
    final block = state[from].last;
    for (int to = 0; to < state.length; to++) {
      if (from == to) continue;
      if (state[to].length >= depth) continue;

      int priority = 0;
      // Completing a tube = highest priority
      if (state[to].length == depth - 1 &&
          state[to].isNotEmpty &&
          state[to].every((c) => c == block)) {
        priority = 100;
      }
      // Growing matching group
      else if (state[to].isNotEmpty && state[to].last == block) {
        priority = 50;
      }
      // Empty tube = low priority
      else if (state[to].isEmpty) {
        priority = 10;
      }

      movesList.add((from, to, priority));
    }
  }

  // Sort by priority descending
  movesList.sort((a, b) => b.$3.compareTo(a.$3));

  for (final (from, to, _) in movesList) {
    final block = state[from].removeLast();
    state[to].add(block);
    if (_greedyDFS(state, depth, visited, moves + 1, maxMoves)) return true;
    state[to].removeLast();
    state[from].add(block);
  }

  visited.remove(key); // Allow revisiting via different paths
  return false;
}

bool _bfsSolvable(List<List<int>> tubes, int depth, int maxStates) {
  final visited = <String>{};
  final queue = <List<List<int>>>[tubes.map((t) => List<int>.from(t)).toList()];

  while (queue.isNotEmpty && visited.length < maxStates) {
    final current = queue.removeAt(0);
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

String _serializeState(List<List<int>> tubes) {
  return tubes.map((t) => t.join(',')).join('|');
}

/// Create a solved state with each tube containing one color.
List<List<int>> _createSolved(
    int colors, int emptySlots, int depth, Random random) {
  final tubes = <List<int>>[];
  for (int c = 0; c < colors; c++) {
    tubes.add(List<int>.filled(depth, c));
  }
  for (int i = 0; i < emptySlots; i++) {
    tubes.add([]);
  }
  return tubes;
}

/// Shuffle a solved state by performing random valid moves.
List<List<int>> _shuffle(
    List<List<int>> tubes, int depth, int moves, Random random) {
  final state = tubes.map((t) => List<int>.from(t)).toList();
  for (int m = 0; m < moves; m++) {
    // Collect all valid moves
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

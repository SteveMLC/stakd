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
  const maxSolvableStates = 10000;

  List<List<int>>? lastCandidate;
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

    lastCandidate = tubes;
    if (_hasSolvedTube(tubes, depth)) continue;
    if (_sameColorAdjacencyRatio(tubes) > 0.6) continue;
    if (!_isSolvable(tubes, depth, maxSolvableStates)) continue;

    return tubes;
  }

  return lastCandidate ?? [];
}

List<List<int>> _createSolved(int colors, int emptySlots, int depth, Random r) {
  final state = <List<int>>[];
  for (int c = 0; c < colors; c++) {
    state.add(List.filled(depth, c));
  }
  for (int i = 0; i < emptySlots; i++) {
    state.add([]);
  }
  return state;
}

String _stateKey(List<List<int>> s) {
  return s.map((stack) => stack.join(',')).join('|');
}

bool _stackCanAccept(List<int> stack, int color, int depth) {
  if (stack.length >= depth) return false;
  if (stack.isEmpty) return true;
  return stack.last == color;
}

List<List<int>> _shuffle(
  List<List<int>> state,
  int depth,
  int moves,
  Random random,
) {
  state = state.map((s) => s.toList()).toList();
  int remaining = moves;
  int attempts = 0;
  final maxAttempts = moves * 15;
  final recentFrom = <int>[];
  final recentTo = <int>[];

  while (remaining > 0 && attempts < maxAttempts) {
    attempts++;
    final validMoves = <(int, int, int)>[];

    for (int from = 0; from < state.length; from++) {
      if (state[from].isEmpty) continue;
      final topColor = state[from].last;
      for (int to = 0; to < state.length; to++) {
        if (from == to) continue;
        if (!_stackCanAccept(state[to], topColor, depth)) continue;

        int priority = 10;
        if (recentFrom.contains(from)) priority -= 3;
        if (recentTo.contains(to)) priority -= 3;
        if (state[to].isNotEmpty && state[to].last != topColor) priority += 5;
        if (state[to].isEmpty && state[from].length > 1) priority += 3;
        validMoves.add((from, to, priority));
      }
    }

    if (validMoves.isEmpty) break;

    validMoves.sort((a, b) => b.$3.compareTo(a.$3));
    final top = validMoves.take(3).toList();
    final move = top[random.nextInt(top.length)];
    final from = move.$1;
    final to = move.$2;
    final color = state[from].removeLast();
    state[to].add(color);

    recentFrom.add(from);
    recentTo.add(to);
    if (recentFrom.length > 3) recentFrom.removeAt(0);
    if (recentTo.length > 3) recentTo.removeAt(0);
    remaining--;
  }

  return state;
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

String _serializeState(List<List<int>> tubes) {
  return tubes.map((t) => t.join(',')).join('|');
}

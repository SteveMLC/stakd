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
  final shuffleMoves = args[4];
  final minDifficultyScore = args[5];
  final seed = args.length > 6 ? args[6] : 0;

  const maxAttempts = 5;
  const maxSolvableStates = 2000;

  List<List<int>>? bestLevel;
  int bestScore = -1;

  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    final r = Random(
      (seed == 0 ? DateTime.now().millisecondsSinceEpoch : seed) + attempt,
    );
    var state = _createSolved(colors, emptySlots, depth, r);
    state = _shuffle(state, depth, shuffleMoves, r);

    if (!_isSolvable(state, depth, maxSolvableStates)) continue;
    if (_isTooEasy(state, depth)) continue;

    final score = _difficultyScore(state, depth);
    if (score >= minDifficultyScore) return state;

    if (score > bestScore) {
      bestScore = score;
      bestLevel = state.map((s) => s.toList()).toList();
    }
  }

  // Fallback: shuffle a solved state rather than returning it solved
  if (bestLevel != null) return bestLevel;
  final fallbackR = seed == 0 ? Random() : Random(seed);
  var fallback = _createSolved(colors, emptySlots, depth, fallbackR);
  fallback = _shuffle(fallback, depth, shuffleMoves, fallbackR);
  return fallback;
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

/// Check if puzzle has too many pre-sorted columns (> 1 single-color stack)
bool _isTooEasy(List<List<int>> state, int depth) {
  int singleColorStacks = 0;
  for (final stack in state) {
    if (stack.length < 2) continue;
    if (stack.every((c) => c == stack.first)) singleColorStacks++;
  }
  return singleColorStacks > 1;
}

bool _isSolved(List<List<int>> state, int depth) {
  for (final stack in state) {
    if (stack.isEmpty) continue;
    if (stack.length != depth) return false;
    final c = stack.first;
    if (!stack.every((x) => x == c)) return false;
  }
  return true;
}

bool _isSolvable(List<List<int>> state, int depth, int maxStates) {
  final visited = <String>{};
  final queue = <List<List<int>>>[_deepCopy(state)];

  while (queue.isNotEmpty && visited.length < maxStates) {
    final current = queue.removeAt(0);
    final key = _stateKey(current);
    if (visited.contains(key)) continue;
    visited.add(key);

    if (_isSolved(current, depth)) return true;

    for (int from = 0; from < current.length; from++) {
      if (current[from].isEmpty) continue;
      final topColor = current[from].last;
      for (int to = 0; to < current.length; to++) {
        if (from == to) continue;
        if (!_stackCanAccept(current[to], topColor, depth)) continue;

        final next = _deepCopy(current);
        next[from].removeLast();
        next[to].add(topColor);
        final nextKey = _stateKey(next);
        if (!visited.contains(nextKey)) queue.add(next);
      }
    }
  }
  return false;
}

List<List<int>> _deepCopy(List<List<int>> s) {
  return s.map((stack) => stack.toList()).toList();
}

int _difficultyScore(List<List<int>> state, int depth) {
  int score = 0;

  for (final stack in state) {
    if (stack.isEmpty || stack.length <= 1) continue;

    int transitions = 0;
    final uniqueColors = <int>{};
    int buriedSingletons = 0;

    for (int i = 0; i < stack.length; i++) {
      final color = stack[i];
      uniqueColors.add(color);
      if (i > 0 && color != stack[i - 1]) {
        transitions++;
        if (i >= 2 && stack[i - 2] != stack[i - 1] && stack[i - 1] != color) {
          buriedSingletons++;
        }
      }
    }

    score += transitions * 2;
    score += buriedSingletons * 3;
    if (uniqueColors.length >= 3) {
      score += (uniqueColors.length - 2) * 2;
    }
    if (stack.length >= 4 && uniqueColors.length >= 2) {
      score += stack.length - 3;
    }
  }

  int completed = 0;
  int nearlyComplete = 0;
  for (final stack in state) {
    if (stack.length == depth && stack.every((c) => c == stack.first)) {
      completed++;
    }
    if (stack.length >= 3 && stack.every((c) => c == stack.first)) {
      nearlyComplete++;
    }
  }
  score -= completed * 4;
  score -= nearlyComplete * 2;

  return score.clamp(0, 100);
}

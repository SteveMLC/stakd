# STAKD Difficulty Engine Overhaul

## 🎯 Mission
CRITICAL FIX: Puzzles are way too easy. Players solve them instantly with no thinking. We need REAL challenge - puzzles that require planning and multiple attempts.

## The Problem (from gameplay video)
- Zen Mode Medium: Solves in 4-7 moves / 10-20 seconds
- No need to think - just mechanical motion
- "Hard" barely harder than Medium
- NO PROGRESSION even in endless mode

## The Goal
- Easy: 30-60 seconds, 8-15 moves (actually relaxing but requires thought)
- Medium: 1-3 minutes, 15-25 moves (focused puzzling)
- Hard: 3-6 minutes, 25-40 moves (real challenge, some restarts)

---

## Phase 1: Rewrite LevelParams in constants.dart

```dart
// NEW DIFFICULTY TIERS - Much harder than before!

class LevelParams {
  final int colors;
  final int depth;
  final int stacks; // Total stacks including empty
  final int emptySlots;
  final int shuffleMoves;
  final int minDifficultyScore;

  const LevelParams({
    required this.colors,
    required this.depth,
    required this.stacks,
    required this.emptySlots,
    required this.shuffleMoves,
    this.minDifficultyScore = 0,
  });

  // ZEN MODE DIFFICULTIES (the real fix)
  static const zenEasy = LevelParams(
    colors: 4,
    depth: 4,
    stacks: 6,  // 4 colors + 2 empty
    emptySlots: 2,
    shuffleMoves: 35,
    minDifficultyScore: 6,
  );

  static const zenMedium = LevelParams(
    colors: 5,
    depth: 5,
    stacks: 7,  // 5 colors + 2 empty (but harder puzzles)
    emptySlots: 2, 
    shuffleMoves: 55,
    minDifficultyScore: 10,
  );

  static const zenHard = LevelParams(
    colors: 6,
    depth: 5,
    stacks: 8,  // 6 colors + 2 empty
    emptySlots: 2,
    shuffleMoves: 80,
    minDifficultyScore: 15,
  );
  
  // ULTRA - for masochists
  static const zenUltra = LevelParams(
    colors: 7,
    depth: 6,
    stacks: 9,  // 7 colors + 2 empty
    emptySlots: 2,
    shuffleMoves: 120,
    minDifficultyScore: 22,
  );

  // LEVEL MODE - Progressive difficulty
  static LevelParams forLevel(int level) {
    // Levels 1-10: Learning (4 colors, 4 depth, 2 empty)
    if (level <= 10) {
      return LevelParams(
        colors: 4,
        depth: 4,
        stacks: 6,
        emptySlots: 2,
        shuffleMoves: 15 + (level * 3),
        minDifficultyScore: level,
      );
    }
    
    // Levels 11-25: Intermediate (5 colors)
    if (level <= 25) {
      return LevelParams(
        colors: 5,
        depth: 4,
        stacks: 7,
        emptySlots: 2,
        shuffleMoves: 30 + ((level - 10) * 2),
        minDifficultyScore: 4 + (level - 10),
      );
    }
    
    // Levels 26-50: Advanced (5-6 colors, deeper)
    if (level <= 50) {
      final colors = level <= 35 ? 5 : 6;
      return LevelParams(
        colors: colors,
        depth: 5,
        stacks: colors + 2,
        emptySlots: 2,
        shuffleMoves: 45 + ((level - 25) * 2),
        minDifficultyScore: 8 + (level - 25),
      );
    }
    
    // Levels 51-100: Expert (6 colors, 1 empty slot!)
    if (level <= 100) {
      return LevelParams(
        colors: 6,
        depth: 5,
        stacks: 7,  // 6 colors + 1 empty = HARD
        emptySlots: 1,
        shuffleMoves: 60 + ((level - 50)),
        minDifficultyScore: 15 + ((level - 50) ~/ 5),
      );
    }
    
    // Levels 100+: Master (6-7 colors, 1 empty, deep)
    final extraColors = ((level - 100) ~/ 25).clamp(0, 1);
    return LevelParams(
      colors: 6 + extraColors,
      depth: 6,
      stacks: 7 + extraColors,
      emptySlots: 1,
      shuffleMoves: 80 + ((level - 100) ~/ 2),
      minDifficultyScore: 25,
    );
  }
}
```

---

## Phase 2: Smarter Difficulty Scoring in level_generator.dart

Current scoring is too simple. Improve it:

```dart
/// Calculate difficulty score - IMPROVED VERSION
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
        
        // Check for "buried singletons" - single layers buried under different colors
        // These are VERY hard to solve efficiently
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

    // Buried singletons = MUCH harder
    score += buriedSingletons * 3;

    // Stacks with many unique colors are harder to solve
    if (uniqueColors.length >= 3) {
      score += (uniqueColors.length - 2) * 2;
    }
    
    // Deep stacks with multiple colors = harder
    if (stack.layers.length >= 4 && uniqueColors.length >= 2) {
      score += stack.layers.length - 3;
    }
  }

  // Penalize "almost solved" states
  int completedStacks = stacks.where((s) => s.isComplete).length;
  int nearlyComplete = stacks.where((s) => 
      s.layers.length >= 3 && 
      s.layers.every((l) => l.colorIndex == s.layers.first.colorIndex)
  ).length;
  
  score -= completedStacks * 4;
  score -= nearlyComplete * 2;

  return score.clamp(0, 100);
}
```

---

## Phase 3: Better Shuffle Algorithm

Current shuffle just makes random valid moves. Improve:

```dart
/// Shuffle the level - IMPROVED VERSION
/// Creates more complex interleaving that requires planning
List<GameStack> _shuffleLevel(
  List<GameStack> stacks,
  int moves,
  Random random,
) {
  var current = stacks.map((s) => s.copy()).toList();

  int movesRemaining = moves;
  int attempts = 0;
  int maxAttempts = moves * 15;
  
  // Track which stacks we've touched recently to spread out moves
  final recentSourceStacks = <int>[];
  final recentDestStacks = <int>[];

  while (movesRemaining > 0 && attempts < maxAttempts) {
    attempts++;

    // Find all valid moves
    final validMoves = <(int, int, int)>[]; // (from, to, priority)
    
    for (int from = 0; from < current.length; from++) {
      if (current[from].isEmpty) continue;
      
      for (int to = 0; to < current.length; to++) {
        if (from == to) continue;
        if (!current[to].canAccept(current[from].topLayer!)) continue;
        
        // Calculate priority - prefer moves that:
        // 1. Don't use recently used stacks
        // 2. Create color mixing
        // 3. Spread layers across stacks
        int priority = 10;
        
        // Penalty for using same stacks repeatedly
        if (recentSourceStacks.contains(from)) priority -= 3;
        if (recentDestStacks.contains(to)) priority -= 3;
        
        // Bonus for mixing colors
        final destTopColor = current[to].isEmpty 
            ? -1 
            : current[to].topLayer!.colorIndex;
        final srcTopColor = current[from].topLayer!.colorIndex;
        if (destTopColor != -1 && destTopColor != srcTopColor) {
          priority += 5; // Creates color mixing
        }
        
        // Bonus for filling empty stacks
        if (current[to].isEmpty && current[from].layers.length > 1) {
          priority += 3;
        }
        
        validMoves.add((from, to, priority));
      }
    }

    if (validMoves.isEmpty) break;

    // Pick move weighted by priority
    validMoves.sort((a, b) => b.$3.compareTo(a.$3));
    final topMoves = validMoves.take(3).toList();
    final move = topMoves[random.nextInt(topMoves.length)];
    
    final fromStack = current[move.$1];
    final toStack = current[move.$2];
    final layer = fromStack.topLayer!;
    
    current[move.$1] = fromStack.withTopLayerRemoved();
    current[move.$2] = toStack.withLayerAdded(layer);

    // Track recent stacks
    recentSourceStacks.add(move.$1);
    recentDestStacks.add(move.$2);
    if (recentSourceStacks.length > 3) recentSourceStacks.removeAt(0);
    if (recentDestStacks.length > 3) recentDestStacks.removeAt(0);
    
    movesRemaining--;
  }

  // Verify complexity
  if (_isSolved(current) || difficultyScore(current) < 4) {
    // Too easy, reshuffle
    return _shuffleLevel(stacks, moves + 10, random);
  }

  return current;
}
```

---

## Phase 4: Zen Mode Adaptive Difficulty

Make Zen mode get progressively harder as player succeeds:

```dart
// In zen_screen.dart or zen game state

class ZenGameState {
  String baseDifficulty; // 'easy', 'medium', 'hard'
  int puzzlesSolved = 0;
  int consecutiveFastSolves = 0; // Solved in < 30 seconds
  int consecutiveSlowSolves = 0; // Took > 3 minutes
  
  /// Get adjusted difficulty based on performance
  LevelParams getAdaptiveDifficulty() {
    final base = _getBaseDifficulty();
    
    // If player is crushing it, bump difficulty
    if (consecutiveFastSolves >= 3) {
      return _bumpDifficulty(base);
    }
    
    // If player is struggling, ease up
    if (consecutiveSlowSolves >= 2) {
      return _easeDifficulty(base);
    }
    
    return base;
  }
  
  LevelParams _getBaseDifficulty() {
    return switch (baseDifficulty) {
      'easy' => LevelParams.zenEasy,
      'medium' => LevelParams.zenMedium,
      'hard' => LevelParams.zenHard,
      _ => LevelParams.zenMedium,
    };
  }
  
  LevelParams _bumpDifficulty(LevelParams base) {
    return LevelParams(
      colors: (base.colors + 1).clamp(4, 7),
      depth: base.depth,
      stacks: base.stacks + 1,
      emptySlots: base.emptySlots,
      shuffleMoves: base.shuffleMoves + 15,
      minDifficultyScore: base.minDifficultyScore + 3,
    );
  }
  
  LevelParams _easeDifficulty(LevelParams base) {
    return LevelParams(
      colors: (base.colors - 1).clamp(4, 7),
      depth: base.depth,
      stacks: base.stacks,
      emptySlots: (base.emptySlots + 1).clamp(1, 3),
      shuffleMoves: (base.shuffleMoves - 10).clamp(20, 200),
      minDifficultyScore: (base.minDifficultyScore - 2).clamp(3, 50),
    );
  }
  
  void onPuzzleSolved(Duration solveTime) {
    puzzlesSolved++;
    
    if (solveTime.inSeconds < 30) {
      consecutiveFastSolves++;
      consecutiveSlowSolves = 0;
    } else if (solveTime.inMinutes >= 3) {
      consecutiveSlowSolves++;
      consecutiveFastSolves = 0;
    } else {
      consecutiveFastSolves = 0;
      consecutiveSlowSolves = 0;
    }
  }
}
```

---

## Phase 5: Add "ULTRA" Difficulty

For players who want REAL challenge:

```dart
// In zen difficulty selector, add ULTRA option

// ULTRA mode: 7 colors, 6 depth, minimal empty slots
// These puzzles should take 5-10 minutes and require multiple attempts
```

---

## Testing Checklist

After implementation, test each difficulty:

- [ ] **Easy**: Takes 30-60 seconds, feels relaxing but requires some thought
- [ ] **Medium**: Takes 1-3 minutes, requires planning ahead 2-3 moves
- [ ] **Hard**: Takes 3-6 minutes, may require restarts, feels challenging
- [ ] **ULTRA**: Takes 5-10+ minutes, definitely requires restarts

If you can solve ANY difficulty in under 10 seconds, the difficulty is WRONG.

---

## Git

```bash
git add -A && git commit -m "feat: difficulty overhaul - much harder puzzles" && git push origin main
```

## When Complete

```bash
openclaw gateway wake --text "Done: Stakd difficulty engine overhauled - puzzles are now actually challenging" --mode now
```

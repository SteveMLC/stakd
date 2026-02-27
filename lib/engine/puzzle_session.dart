import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/layer_model.dart';
import '../models/stack_model.dart';
import '../services/level_generator.dart';
import '../services/zen_puzzle_isolate.dart';
import '../utils/constants.dart';

/// Zen Mode difficulty levels
enum ZenDifficulty {
  easy(3, 2, 3, 'Easy'),
  medium(4, 2, 4, 'Medium'),
  hard(5, 1, 4, 'Hard'),
  ultra(6, 1, 5, 'Ultra');

  final int colors;
  final int emptySlots;
  final int depth;
  final String label;

  const ZenDifficulty(this.colors, this.emptySlots, this.depth, this.label);
}

/// Manages puzzle generation, pre-generation, difficulty ramping, and session state.
/// Reusable across different game modes/screens.
class PuzzleSession {
  ZenDifficulty difficulty;
  int puzzlesSolved = 0;
  int puzzleSeed;
  DateTime? puzzleStart;
  DateTime? sessionStart;
  Duration sessionDuration = Duration.zero;
  
  // Pre-generated next puzzle
  List<GameStack>? preGeneratedStacks;
  bool isPreGenerating = false;
  
  // Loading state
  bool isLoading = false;
  Timer? loadingTimeout;
  
  // Initial stacks for restart
  List<GameStack>? initialStacks;
  
  // Par calculation
  int? currentPar;
  
  // Session timer
  Timer? sessionTimer;

  PuzzleSession({
    required this.difficulty,
    int? seed,
  }) : puzzleSeed = seed ?? DateTime.now().millisecondsSinceEpoch {
    sessionStart = DateTime.now();
  }

  void dispose() {
    sessionTimer?.cancel();
    loadingTimeout?.cancel();
  }

  /// Start the session timer that updates sessionDuration every second.
  /// [onTick] is called each second for UI updates.
  void startSessionTimer(VoidCallback onTick) {
    sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (sessionStart != null) {
        sessionDuration = DateTime.now().difference(sessionStart!);
        onTick();
      }
    });
  }

  /// Get adaptive difficulty parameters for current puzzle number.
  LevelParams getAdaptiveDifficulty() {
    return getAdaptiveDifficultyFor(puzzlesSolved, difficulty);
  }

  /// Get adaptive difficulty for a specific puzzle number and difficulty level.
  LevelParams getAdaptiveDifficultyFor(int puzzleNumber, ZenDifficulty diff) {
    switch (diff) {
      case ZenDifficulty.easy:
        if (puzzleNumber <= 2) {
          return const LevelParams(colors: 2, depth: 3, stacks: 4, emptySlots: 2, shuffleMoves: 25);
        } else if (puzzleNumber <= 5) {
          return const LevelParams(colors: 3, depth: 3, stacks: 5, emptySlots: 2, shuffleMoves: 35);
        } else if (puzzleNumber <= 8) {
          return const LevelParams(colors: 3, depth: 4, stacks: 5, emptySlots: 2, shuffleMoves: 40);
        } else {
          return ZenParams.easy;
        }

      case ZenDifficulty.medium:
        if (puzzleNumber <= 2) {
          return const LevelParams(colors: 3, depth: 3, stacks: 5, emptySlots: 2, shuffleMoves: 30);
        } else if (puzzleNumber <= 4) {
          return const LevelParams(colors: 3, depth: 4, stacks: 5, emptySlots: 2, shuffleMoves: 40, lockedBlockProbability: 0.06);
        } else if (puzzleNumber <= 7) {
          return const LevelParams(colors: 4, depth: 4, stacks: 6, emptySlots: 2, shuffleMoves: 45, lockedBlockProbability: 0.06);
        } else if (puzzleNumber <= 10) {
          return const LevelParams(colors: 4, depth: 4, stacks: 6, emptySlots: 2, shuffleMoves: 50, lockedBlockProbability: 0.06);
        } else if (puzzleNumber <= 15) {
          return const LevelParams(colors: 4, depth: 5, stacks: 6, emptySlots: 2, shuffleMoves: 55, lockedBlockProbability: 0.06);
        } else if (puzzleNumber <= 25) {
          return const LevelParams(colors: 4, depth: 5, stacks: 6, emptySlots: 2, shuffleMoves: 60, lockedBlockProbability: 0.06);
        } else if (puzzleNumber <= 40) {
          return const LevelParams(colors: 5, depth: 4, stacks: 7, emptySlots: 2, shuffleMoves: 65, lockedBlockProbability: 0.06);
        } else {
          return ZenParams.medium;
        }

      case ZenDifficulty.hard:
        if (puzzleNumber <= 1) {
          return const LevelParams(colors: 4, depth: 4, stacks: 6, emptySlots: 2, shuffleMoves: 50, lockedBlockProbability: 0.08);
        } else if (puzzleNumber <= 3) {
          return const LevelParams(colors: 5, depth: 4, stacks: 7, emptySlots: 2, shuffleMoves: 60, lockedBlockProbability: 0.08, frozenBlockProbability: 0.04);
        } else if (puzzleNumber <= 5) {
          return const LevelParams(colors: 5, depth: 5, stacks: 7, emptySlots: 2, shuffleMoves: 70, lockedBlockProbability: 0.08, frozenBlockProbability: 0.04);
        } else if (puzzleNumber <= 10) {
          return const LevelParams(colors: 5, depth: 5, stacks: 7, emptySlots: 2, shuffleMoves: 75, lockedBlockProbability: 0.08, frozenBlockProbability: 0.04);
        } else {
          return ZenParams.hard;
        }

      case ZenDifficulty.ultra:
        return ZenParams.ultra;
    }
  }

  /// Generate a puzzle synchronously using shuffle-from-solved (always instant).
  /// Returns the generated stacks. Caller must call initZenGame on GameState.
  List<GameStack> generateSyncFallback(LevelParams params) {
    loadingTimeout?.cancel();
    final seed = puzzleSeed;
    final random = seed == 0 ? Random() : Random(seed);
    final colors = params.colors;
    final depth = params.depth;
    final emptySlots = params.emptySlots;
    final tubes = <List<int>>[];
    for (int c = 0; c < colors; c++) {
      tubes.add(List<int>.filled(depth, c, growable: true));
    }
    for (int i = 0; i < emptySlots; i++) {
      tubes.add([]);
    }
    for (int m = 0; m < 200; m++) {
      final validMoves = <(int, int)>[];
      for (int from = 0; from < tubes.length; from++) {
        if (tubes[from].isEmpty) continue;
        final block = tubes[from].last;
        for (int to = 0; to < tubes.length; to++) {
          if (from == to) continue;
          if (tubes[to].length >= depth) continue;
          if (tubes[to].isNotEmpty && tubes[to].last != block) continue;
          validMoves.add((from, to));
        }
      }
      if (validMoves.isEmpty) break;
      final (from, to) = validMoves[random.nextInt(validMoves.length)];
      tubes[to].add(tubes[from].removeLast());
    }
    final stacks = tubes.map((t) => GameStack(
      layers: t.map((colorIndex) => Layer(colorIndex: colorIndex)).toList(),
      maxDepth: depth,
    )).toList();
    currentPar = (colors * depth * 1.2).ceil();
    return stacks;
  }

  /// Clone a list of stacks (deep copy for restart).
  static List<GameStack> cloneStacks(List<GameStack> stacks) {
    return stacks.map((s) => GameStack(
      layers: s.layers.map((l) => Layer(
        colorIndex: l.colorIndex,
        type: l.type,
        colors: l.colors,
        lockedUntil: l.lockedUntil,
        isFrozen: l.isFrozen,
      )).toList(),
      maxDepth: s.maxDepth,
    )).toList();
  }

  /// Load a new puzzle using isolate generation with sync fallback.
  /// [context] must have a GameState provider.
  /// [onLoaded] is called when the puzzle is ready (for setState).
  /// [onCheckOnboarding] is called after puzzle loads for first-time hints.
  void loadNewPuzzle(
    BuildContext context, {
    required VoidCallback onStateChanged,
    VoidCallback? onCheckOnboarding,
  }) {
    // Guard: never trigger if player is actively playing an incomplete puzzle
    try {
      final gameState = context.read<GameState>();
      if (gameState.moveCount > 0 && !gameState.isComplete) {
        debugPrint('BLOCKED: loadNewPuzzle() called during active gameplay (${gameState.moveCount} moves)');
        return;
      }
    } catch (_) {
      // GameState not yet available (first load) — proceed
    }

    puzzleStart = DateTime.now();
    loadingTimeout?.cancel();
    final params = getAdaptiveDifficulty();
    final seed = puzzleSeed;
    isLoading = true;
    onStateChanged();

    // Safety timeout: if loading takes >5s, force sync fallback
    loadingTimeout = Timer(const Duration(seconds: 5), () {
      if (isLoading) {
        debugPrint('EMERGENCY: Loading timeout hit, using sync fallback');
        final fallbackParams = LevelParams(
          colors: params.colors,
          depth: 3,
          stacks: params.colors + 2,
          emptySlots: 2,
          shuffleMoves: 30,
          minDifficultyScore: 0,
        );
        _applySyncFallback(context, fallbackParams, onStateChanged, onCheckOnboarding);
      }
    });

    final encoded = encodeParamsForIsolate(params, seed: seed);

    compute<List<int>, List<List<int>>>(generateZenPuzzleInIsolate, encoded)
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('Puzzle gen timeout after 3s, using sync fallback');
            final fallbackParams = LevelParams(
              colors: params.colors,
              depth: 3,
              stacks: params.colors + 2,
              emptySlots: 2,
              shuffleMoves: 30,
              minDifficultyScore: 0,
            );
            _applySyncFallback(context, fallbackParams, onStateChanged, onCheckOnboarding);
            return <List<int>>[];
          },
        )
        .then((encodedStacks) {
          if (!isLoading) return; // sync fallback already handled
          if (encodedStacks.isEmpty) return;
          loadingTimeout?.cancel();
          final stacks = decodeStacksFromIsolate(encodedStacks, params.depth);
          try {
            LevelGenerator().applySpecialBlocks(stacks, params);
          } catch (e) {
            debugPrint('applySpecialBlocks failed: $e');
          }
          initialStacks = cloneStacks(stacks);
          try {
            context.read<GameState>().initZenGame(stacks);
          } catch (_) {
            return;
          }
          currentPar = (params.colors * params.depth * 1.2).ceil();
          isLoading = false;
          puzzleSeed++;
          onStateChanged();
          onCheckOnboarding?.call();
        })
        .catchError((e, st) {
          loadingTimeout?.cancel();
          debugPrint('Puzzle gen error: $e, using sync fallback');
          if (isLoading) {
            _applySyncFallback(context, params, onStateChanged, onCheckOnboarding);
          }
        });
  }

  void _applySyncFallback(
    BuildContext context,
    LevelParams params,
    VoidCallback onStateChanged,
    VoidCallback? onCheckOnboarding,
  ) {
    final stacks = generateSyncFallback(params);
    initialStacks = cloneStacks(stacks);
    try {
      context.read<GameState>().initZenGame(stacks);
    } catch (_) {
      return;
    }
    isLoading = false;
    puzzleSeed++;
    onStateChanged();
    onCheckOnboarding?.call();
  }

  /// Pre-generate the next puzzle in background.
  void preGenerateNextPuzzle() {
    if (isPreGenerating) return;
    isPreGenerating = true;
    final nextPuzzleNumber = puzzlesSolved + 1;
    final savedDifficulty = difficulty;
    final savedSeed = puzzleSeed;

    final params = getAdaptiveDifficultyFor(nextPuzzleNumber, savedDifficulty);
    final encoded = encodeParamsForIsolate(params, seed: savedSeed);

    bool usedSyncFallback = false;

    compute<List<int>, List<List<int>>>(generateZenPuzzleInIsolate, encoded)
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('Pre-gen timeout, generating sync fallback');
            usedSyncFallback = true;
            final depth = params.depth;
            final colors = params.colors;
            final emptySlots = params.emptySlots;
            final random = savedSeed == 0 ? Random() : Random(savedSeed);
            final tubes = <List<int>>[];
            for (int c = 0; c < colors; c++) {
              tubes.add(List<int>.filled(depth, c));
            }
            for (int i = 0; i < emptySlots; i++) {
              tubes.add([]);
            }
            for (int m = 0; m < 200; m++) {
              final validMoves = <(int, int)>[];
              for (int from = 0; from < tubes.length; from++) {
                if (tubes[from].isEmpty) continue;
                final block = tubes[from].last;
                for (int to = 0; to < tubes.length; to++) {
                  if (from == to) continue;
                  if (tubes[to].length >= depth) continue;
                  if (tubes[to].isNotEmpty && tubes[to].last != block) continue;
                  validMoves.add((from, to));
                }
              }
              if (validMoves.isEmpty) break;
              final (from, to) = validMoves[random.nextInt(validMoves.length)];
              tubes[to].add(tubes[from].removeLast());
            }
            return tubes;
          },
        )
        .then((resultStacks) {
          List<GameStack> stacks;
          if (usedSyncFallback) {
            stacks = resultStacks.map((t) => GameStack(
              layers: t.map((colorIndex) => Layer(colorIndex: colorIndex)).toList(),
              maxDepth: params.depth,
            )).toList();
          } else {
            stacks = decodeStacksFromIsolate(resultStacks, params.depth);
            try {
              LevelGenerator().applySpecialBlocks(stacks, params);
            } catch (e) {
              debugPrint('applySpecialBlocks (pre-gen) failed: $e');
            }
          }
          preGeneratedStacks = stacks;
          isPreGenerating = false;
        })
        .catchError((e, st) {
          isPreGenerating = false;
        });
  }
}

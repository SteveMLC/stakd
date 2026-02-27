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
import '../services/audio_service.dart';
import '../services/zen_audio_service.dart';
import '../services/haptic_service.dart';
import '../services/storage_service.dart';
import '../services/garden_service.dart';
import '../utils/constants.dart';
import '../widgets/game_board.dart';
import '../widgets/hint_overlay.dart';
import '../widgets/loading_text.dart';
import '../widgets/themes/zen_garden_scene.dart';
import '../widgets/achievement_toast_overlay.dart';
import '../widgets/completion_overlay.dart';
import '../widgets/zen_session_summary.dart';
import '../widgets/atmospheric_overlay.dart';
import '../widgets/garden_mini_footer.dart';
import '../services/achievement_service.dart';
import '../services/stats_service.dart';
import '../services/score_service.dart';
import '../services/progression_service.dart';
import '../services/currency_service.dart';
import '../widgets/rank_up_overlay.dart';
import '../widgets/achievement_toast.dart';

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

/// Zen Mode - Infinite relaxing puzzle experience
class ZenModeScreen extends StatefulWidget {
  final String difficulty;

  const ZenModeScreen({super.key, this.difficulty = 'medium'});

  @override
  State<ZenModeScreen> createState() => _ZenModeScreenState();
}

class _ZenModeScreenState extends State<ZenModeScreen>
    with TickerProviderStateMixin, AchievementToastMixin {
  final Map<int, GlobalKey> _stackKeys = {};

  bool _showingHint = false;
  int _hintSourceIndex = -1;
  int _hintDestIndex = -1;
  int _hintsRemaining = 3;

  bool _showCompletionOverlay = false;
  Duration _completionDuration = Duration.zero;
  int _completionMoves = 0;
  int _completionStars = 0;
  int _coinsEarned = 0;
  bool _completionUndoUsed = false;

  late ZenDifficulty _difficulty;
  int _puzzlesSolved = 0;
  DateTime? _puzzleStart;
  DateTime? _sessionStart;
  Timer? _sessionTimer;
  Timer? _liveTimerUpdater;
  Duration _sessionDuration = Duration.zero;
  bool _showMoveCounter = true;
  final Stopwatch _liveStopwatch = Stopwatch();
  bool _isTransitioning = false;
  bool _isLoading = false;
  bool _showGardenView = false;
  int _puzzleSeed = 0;
  List<GameStack>? _initialStacks; // For restart

  // Pre-generated next puzzle (generated during completion celebration)
  List<GameStack>? _preGeneratedStacks;
  bool _isPreGenerating = false;

  // Stats tracking
  bool _isNewMoveBest = false;
  bool _isNewTimeBest = false;
  bool _showSessionSummary = false;

  // Onboarding hint
  bool _showOnboardingHint = false;
  bool _hasCheckedOnboarding = false;

  // Garden footer celebration
  bool _justSolvedPuzzle = false;

  // Par calculation for star system
  int? _currentPar;

  // Progression system
  PuzzleScore? _lastScore;
  RankUpResult? _pendingRankUp; // queued, shown after completion dismissed
  List<AchievementDef> _pendingAchievements = []; // queued achievements
  AchievementDef? _currentAchievementToast; // currently showing toast
  bool _showRankUp = false;

  // Fade animation for puzzle transitions
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Particle animation controller
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _difficulty = ZenDifficulty.values.firstWhere(
      (d) => d.label.toLowerCase() == widget.difficulty.toLowerCase(),
      orElse: () => ZenDifficulty.medium,
    );
    GameColors.setUltraPalette(_difficulty == ZenDifficulty.ultra);
    _sessionStart = DateTime.now();
    _puzzleSeed = DateTime.now().millisecondsSinceEpoch;
    
    // Initialize StatsService to load persisted data
    StatsService().init();

    // Setup fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.value = 1.0;

    // Setup particle animation
    _particleController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Start session timer
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sessionStart != null) {
        setState(() {
          _sessionDuration = DateTime.now().difference(_sessionStart!);
        });
      }
    });

    // Load first puzzle after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNewPuzzle());
  }

  @override
  void dispose() {
    GameColors.setUltraPalette(false);
    _sessionTimer?.cancel();
    _liveTimerUpdater?.cancel();
    _liveStopwatch.stop();
    _fadeController.dispose();
    _particleController.dispose();
    
    // Reset streak if player exits without completing current puzzle
    final gameState = context.read<GameState>();
    if (!gameState.isComplete && gameState.moveCount > 0) {
      StatsService().resetStreak();
    }
    
    super.dispose();
  }

  void _showHint() {
    if (_hintsRemaining <= 0) {
      // Offer paid hint
      _offerPaidHint();
      return;
    }

    final gameState = context.read<GameState>();
    final hint = gameState.getHint();

    if (hint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid moves right now.')),
      );
      return;
    }

    setState(() {
      _showingHint = true;
      _hintSourceIndex = hint.$1;
      _hintDestIndex = hint.$2;
      _hintsRemaining--;
    });
    AudioService().playTap();
  }

  void _offerPaidHint() async {
    final coins = await CurrencyService().getCoins();
    if (!mounted) return;
    if (coins < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins for a hint (50 coins needed)')),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GameColors.surface,
        title: Text('Use Hint?', style: TextStyle(color: GameColors.text)),
        content: Text('Spend 50 coins for an extra hint?\n\nBalance: $coins 🪙',
            style: TextStyle(color: GameColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: GameColors.accent),
            child: const Text('Use Hint (50 🪙)'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final spent = await CurrencyService().spendCoins(50);
      if (spent) {
        final gameState = context.read<GameState>();
        final hint = gameState.getHint();
        if (hint != null) {
          setState(() {
            _showingHint = true;
            _hintSourceIndex = hint.$1;
            _hintDestIndex = hint.$2;
          });
          AudioService().playTap();
        }
      }
    }
  }

  void _dismissHint() {
    setState(() {
      _showingHint = false;
    });
  }

  void _restartPuzzle() {
    if (_initialStacks == null) return;
    final fresh = _initialStacks!.map((s) => GameStack(
      layers: s.layers.map((l) => Layer(colorIndex: l.colorIndex, type: l.type, colors: l.colors, lockedUntil: l.lockedUntil, isFrozen: l.isFrozen)).toList(),
      maxDepth: s.maxDepth,
    )).toList();
    context.read<GameState>().initZenGame(fresh);
    setState(() {
      _stackKeys.clear();
      _hintsRemaining = 3;
      _showingHint = false;
      _showCompletionOverlay = false;
      _currentAchievementToast = null;
      _pendingAchievements.clear();
      _showRankUp = false;
      _pendingRankUp = null;
    });
    _puzzleStart = DateTime.now();
    // Reset live timer
    _liveStopwatch.reset();
    _liveTimerUpdater?.cancel();
  }

  void _loadNewPuzzle() {
    _puzzleStart = DateTime.now();
    // Force-dismiss all overlays on puzzle transition
    _currentAchievementToast = null;
    _pendingAchievements.clear();
    _showRankUp = false;
    _pendingRankUp = null;
    // Reset live timer for new puzzle
    _liveStopwatch.reset();
    _liveTimerUpdater?.cancel();
    final params = _getAdaptiveDifficulty();
    final seed = _puzzleSeed;
    setState(() => _isLoading = true);
    // Reset live timer display before showing loading
    _liveStopwatch.reset();
    
    final encoded = encodeParamsForIsolate(params, seed: seed);
    
    // Store params for decode (fallback may use different params)
    LevelParams activeParams = params;
    
    // Add timeout to prevent infinite generation
    final genTimer = Stopwatch()..start();
    compute<List<int>, List<List<int>>>(generateZenPuzzleInIsolate, encoded)
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            // Fallback: same colors/depth but no difficulty threshold, no special blocks
            final fallbackParams = LevelParams(
              colors: params.colors,
              depth: params.depth,
              stacks: params.colors + params.emptySlots,
              emptySlots: params.emptySlots,
              shuffleMoves: 50,
              minDifficultyScore: 0,
            );
            activeParams = fallbackParams;
            final fallbackEncoded = encodeParamsForIsolate(fallbackParams, seed: seed);
            return compute<List<int>, List<List<int>>>(
              generateZenPuzzleInIsolate, 
              fallbackEncoded,
            );
          },
        )
        .then((encodedStacks) {
          if (!mounted) return;
          debugPrint('Puzzle gen took ${genTimer.elapsedMilliseconds}ms (${params.colors}c ${params.depth}d)');
          final stacks = decodeStacksFromIsolate(encodedStacks, activeParams.depth);
          // Apply special blocks (locked/frozen) based on difficulty params
          try {
            LevelGenerator().applySpecialBlocks(stacks, params);
          } catch (e) {
            debugPrint('applySpecialBlocks failed: $e');
            // Continue without special blocks rather than crash
          }
          _initialStacks = stacks.map((s) => GameStack(
            layers: s.layers.map((l) => Layer(colorIndex: l.colorIndex, type: l.type, colors: l.colors, lockedUntil: l.lockedUntil, isFrozen: l.isFrozen)).toList(),
            maxDepth: s.maxDepth,
          )).toList();
          context.read<GameState>().initZenGame(stacks);
          
          // Formula-based par: deterministic, scales with puzzle complexity, zero computation
          _currentPar = (params.colors * params.depth * 1.2).ceil();
          
          setState(() {
            _isLoading = false;
            _stackKeys.clear();
            _puzzleSeed++;
            _hintsRemaining = 3;
            _showingHint = false;
            _showCompletionOverlay = false;
          });
          
          // Check and show onboarding hint on first puzzle load
          _checkOnboarding();
        })
        .catchError((e, st) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to generate puzzle. Please try again.')),
            );
          }
        });
  }

  void _checkOnboarding() async {
    if (_hasCheckedOnboarding) return;
    _hasCheckedOnboarding = true;
    
    final shown = StorageService().getOnboardingShown();
    if (!shown) {
      // Show onboarding hint after a brief delay
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _showOnboardingHint = true;
        });
        
        // Auto-dismiss after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _dismissOnboarding();
          }
        });
      }
    }
  }

  void _dismissOnboarding() {
    if (!_showOnboardingHint) return;
    setState(() {
      _showOnboardingHint = false;
    });
    StorageService().setOnboardingShown();
  }

  void _preGenerateNextPuzzle() {
    if (_isPreGenerating) return;
    _isPreGenerating = true;
    // Use puzzlesSolved + 1 since we'll increment on advance
    final nextPuzzleNumber = _puzzlesSolved + 1;
    final savedDifficulty = _difficulty;
    final savedSeed = _puzzleSeed;

    // Calculate params for the NEXT puzzle
    final params = _getAdaptiveDifficultyFor(nextPuzzleNumber, savedDifficulty);
    final encoded = encodeParamsForIsolate(params, seed: savedSeed);
    
    // Store params for decode (fallback may use different params)
    LevelParams activeParams = params;
    
    // Add timeout to pre-generation too
    compute<List<int>, List<List<int>>>(generateZenPuzzleInIsolate, encoded)
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            // Fallback: same colors/depth but no difficulty threshold
            final fallbackParams = LevelParams(
              colors: params.colors,
              depth: params.depth,
              stacks: params.colors + params.emptySlots,
              emptySlots: params.emptySlots,
              shuffleMoves: 50,
              minDifficultyScore: 0,
            );
            activeParams = fallbackParams;
            final fallbackEncoded = encodeParamsForIsolate(fallbackParams, seed: savedSeed);
            return compute<List<int>, List<List<int>>>(
              generateZenPuzzleInIsolate,
              fallbackEncoded,
            );
          },
        )
        .then((encodedStacks) {
          if (!mounted) return;
          final stacks = decodeStacksFromIsolate(encodedStacks, activeParams.depth);
          // Apply special blocks (locked/frozen) based on difficulty params
          try {
            LevelGenerator().applySpecialBlocks(stacks, params);
          } catch (e) {
            debugPrint('applySpecialBlocks (pre-gen) failed: $e');
          }
          _preGeneratedStacks = stacks;
          _isPreGenerating = false;
        })
        .catchError((e, st) {
          _isPreGenerating = false;
        });
  }

  /// Get adaptive difficulty for a specific puzzle number and difficulty level
  LevelParams _getAdaptiveDifficultyFor(int puzzleNumber, ZenDifficulty difficulty) {
    switch (difficulty) {
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
          return const LevelParams(colors: 4, depth: 4, stacks: 6, emptySlots: 2, shuffleMoves: 45, lockedBlockProbability: 0.08);
        } else if (puzzleNumber <= 10) {
          return const LevelParams(colors: 4, depth: 4, stacks: 6, emptySlots: 2, shuffleMoves: 50, lockedBlockProbability: 0.1);
        } else if (puzzleNumber <= 15) {
          return const LevelParams(colors: 4, depth: 5, stacks: 6, emptySlots: 2, shuffleMoves: 55, lockedBlockProbability: 0.1);
        } else {
          return ZenParams.medium;
        }

      case ZenDifficulty.hard:
        if (puzzleNumber <= 1) {
          return const LevelParams(colors: 4, depth: 4, stacks: 6, emptySlots: 2, shuffleMoves: 50, lockedBlockProbability: 0.08);
        } else if (puzzleNumber <= 3) {
          return const LevelParams(colors: 5, depth: 4, stacks: 7, emptySlots: 2, shuffleMoves: 60, lockedBlockProbability: 0.10, frozenBlockProbability: 0.06);
        } else if (puzzleNumber <= 5) {
          return const LevelParams(colors: 5, depth: 5, stacks: 7, emptySlots: 2, shuffleMoves: 70, lockedBlockProbability: 0.12, frozenBlockProbability: 0.08);
        } else if (puzzleNumber <= 10) {
          return const LevelParams(colors: 5, depth: 5, stacks: 7, emptySlots: 2, shuffleMoves: 75, lockedBlockProbability: 0.12, frozenBlockProbability: 0.08);
        } else {
          return ZenParams.hard;
        }

      case ZenDifficulty.ultra:
        return ZenParams.ultra;
    }
  }

  void _onMove() {
    // Start live timer on first move
    if (!_liveStopwatch.isRunning) {
      _liveStopwatch.start();
      // Update UI every second
      _liveTimerUpdater = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _liveStopwatch.isRunning) {
          setState(() {});
        }
      });
      // Start pre-generating the next puzzle early (during gameplay)
      if (_preGeneratedStacks == null && !_isPreGenerating) {
        _preGenerateNextPuzzle();
      }
    }
    AudioService().playSlide();
  }

  void _showCompletion(GameState gameState) {
    if (_showCompletionOverlay) return;
    if (_isTransitioning) return;
    if (_isLoading) return;
    if (gameState.moveCount == 0) return; // Don't trigger on fresh puzzle load
    
    // Stop live timer
    _liveStopwatch.stop();
    _liveTimerUpdater?.cancel();
    
    // Clear any active combo/chain overlays BEFORE showing completion modal
    GameBoard.clearOverlays(context);
    
    final start = _puzzleStart;
    final duration = start != null
        ? DateTime.now().difference(start)
        : Duration.zero;

    final statsService = StatsService();
    final difficulty = _difficulty.label;
    
    // Check for new personal bests before recording
    _isNewMoveBest = statsService.isNewMoveBest(difficulty, gameState.moveCount);
    _isNewTimeBest = statsService.isNewTimeBest(difficulty, duration);
    
    // Record puzzle completion in stats
    statsService.recordPuzzleComplete(
      difficulty: difficulty,
      moves: gameState.moveCount,
      time: duration,
      combos: gameState.currentCombo,
    );

    // Calculate stars based on par
    final undoUsed = gameState.undosRemaining < 3;
    int stars = 1; // 1 star for completing
    if (_currentPar != null && _currentPar! > 0) {
      final par = _currentPar!;
      final threeStarTarget = (par * 0.7).ceil();
      if (gameState.moveCount <= par) {
        stars = 2; // 2 stars for at or under par (undo OK)
      }
      if (gameState.moveCount <= threeStarTarget && !undoUsed) {
        stars = 3; // 3 stars for under 70% of par with no undos
      }
    }

    // 1. Calculate score
    final scoreResult = ScoreService().calculateScore(
      difficulty: difficulty,
      stars: stars,
      moves: gameState.moveCount,
      parMoves: _currentPar ?? 14,
      time: duration,
      undosUsed: 3 - gameState.undosRemaining,
      maxUndos: 3,
      comboCount: gameState.currentCombo,
      lockedCleared: 0, // TODO: track these later
      frozenCleared: 0,
      isDailyChallenge: false,
    );

    // 2. Award XP and check for rank up
    ProgressionService().addXP(scoreResult.xpEarned).then((rankUp) {
      if (mounted && rankUp != null) {
        setState(() {
          _pendingRankUp = rankUp;
        });
      }
    });
    ProgressionService().addScore(scoreResult.totalScore);

    // 3. Award coins
    CurrencyService().addCoins(scoreResult.coinsEarned);

    // 4. Check achievements
    final newAchievements = AchievementService().checkPuzzleComplete(
      difficulty: difficulty,
      stars: stars,
      moves: gameState.moveCount,
      parMoves: _currentPar ?? 14,
      time: duration,
      undosUsed: 3 - gameState.undosRemaining,
      streak: _puzzlesSolved,
      totalSolved: statsService.totalPuzzlesSolved,
      score: scoreResult.totalScore,
    );

    setState(() {
      _completionDuration = duration;
      _completionMoves = gameState.moveCount;
      _completionStars = stars;
      _coinsEarned = scoreResult.coinsEarned;
      _completionUndoUsed = undoUsed;
      _lastScore = scoreResult;
      _pendingAchievements = newAchievements;
      _currentAchievementToast = null;
      _showRankUp = false;
      _showCompletionOverlay = true;
      _justSolvedPuzzle = true; // Trigger garden footer celebration
    });

    // Reset the celebration flag after animation completes
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _justSolvedPuzzle = false;
        });
      }
    });

    AudioService().playWin();
    HapticService.instance.levelWinPattern();

    // Pre-generate the next puzzle while the player celebrates
    _preGenerateNextPuzzle();
  }

  /// Called when "Next Puzzle" is tapped on completion overlay.
  /// Sequences: Completion → Achievement toasts → Rank Up → advance.
  void _advanceAfterCompletion() async {
    if (_isTransitioning) return;

    // Step 1: Dismiss completion overlay
    setState(() {
      _showCompletionOverlay = false;
    });

    // Step 2: Show achievement toasts one at a time
    while (_pendingAchievements.isNotEmpty) {
      final achievement = _pendingAchievements.removeAt(0);
      setState(() {
        _currentAchievementToast = achievement;
      });
      // Wait for toast animation (slide in 0.4s + hold 2s + slide out 0.4s)
      await Future.delayed(const Duration(milliseconds: 2800));
      if (!mounted) return;
      setState(() {
        _currentAchievementToast = null;
      });
      // Brief gap between toasts
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
    }

    // Step 3: Show rank up if pending (holds until tap)
    if (_pendingRankUp != null) {
      setState(() {
        _showRankUp = true;
      });
      // Wait until user dismisses rank up (handled by _dismissRankUp)
      while (_showRankUp && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (!mounted) return;
    }

    // Step 4: Actually advance to next puzzle
    _isTransitioning = true;

    setState(() {
      _puzzlesSolved++;
    });

    // Save progress
    StorageService().addZenPuzzle();
    await GardenService.recordPuzzleSolved();
    AchievementService().checkStarAchievements();

    if (_preGeneratedStacks != null) {
      // Use the pre-generated puzzle — no loading screen!
      final nextParams = _getAdaptiveDifficulty();
      _currentPar = (nextParams.colors * nextParams.depth * 1.2).ceil();
      _fadeController.animateTo(0.0).then((_) {
        if (!mounted) return;
        _initialStacks = _preGeneratedStacks!.map((s) => GameStack(
          layers: s.layers.map((l) => Layer(colorIndex: l.colorIndex, type: l.type, colors: l.colors, lockedUntil: l.lockedUntil, isFrozen: l.isFrozen)).toList(),
          maxDepth: s.maxDepth,
        )).toList();
        context.read<GameState>().initZenGame(_preGeneratedStacks!);
        setState(() {
          _stackKeys.clear();
          _puzzleSeed++;
          _hintsRemaining = 3;
          _showingHint = false;
          _preGeneratedStacks = null;
        });
        _puzzleStart = DateTime.now();
        _fadeController.animateTo(1.0).then((_) {
          _isTransitioning = false;
        });
      });
    } else {
      // Fallback: pre-generation not ready yet, load normally
      _fadeController.animateTo(0.0).then((_) {
        if (!mounted) return;
        _loadNewPuzzle();
        _fadeController.animateTo(1.0).then((_) {
          _isTransitioning = false;
        });
      });
    }
  }

  void _setDifficulty(ZenDifficulty difficulty) {
    if (_difficulty == difficulty) return;
    if (_isLoading) return; // Prevent switching while generating
    setState(() {
      _difficulty = difficulty;
    });
    GameColors.setUltraPalette(_difficulty == ZenDifficulty.ultra);
    // Load new puzzle with new difficulty
    _loadNewPuzzle();
  }

  void _toggleMoveCounter() {
    setState(() {
      _showMoveCounter = !_showMoveCounter;
    });
  }

  void _showSessionSummaryOverlay() {
    if (_puzzlesSolved == 0) {
      // If no puzzles solved, exit directly
      Navigator.of(context).pop();
      return;
    }
    
    setState(() {
      _showSessionSummary = true;
    });
  }

  LevelParams _getAdaptiveDifficulty() {
    return _getAdaptiveDifficultyFor(_puzzlesSolved, _difficulty);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1622),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: slate texture for puzzle (no garden background when in garden view to avoid duplicate)
          if (!_showGardenView)
            Image.asset(
              'assets/images/backgrounds/slate_bg.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),

          // Atmospheric overlay (behind puzzle UI)
          if (!_showGardenView)
            AtmosphericOverlay(
              gardenStage: GardenService.state.currentStage,
            ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top bar (hidden in garden view)
                if (!_showGardenView) _buildTopBar(),

                // Rank indicator + Difficulty slider (hidden in garden view)
                if (!_showGardenView) _buildRankAndDifficulty(),

                // Stats bar
                if (!_showGardenView) _buildStatsBar(),

                // Game board or Garden view (with fade animation)
                Expanded(
                  child: _showGardenView
                      ? _buildGardenFullView()
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: Consumer<GameState>(
                            builder: (context, gameState, child) {
                              // Check for puzzle completion
                              if (gameState.isComplete &&
                                  !_isTransitioning &&
                                  !_showCompletionOverlay) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  _showCompletion(gameState);
                                });
                              }

                              return GameBoard(
                                gameState: gameState,
                                stackKeys: _stackKeys,
                                onTap: () => AudioService().playTap(),
                                onMove: _onMove,
                                onClear: () => AudioService().playClear(),
                              );
                            },
                          ),
                        ),
                ),

                // Garden footer (in flow, not positioned)
                if (!_showGardenView)
                  GardenMiniFooter(
                    gardenStage: GardenService.state.currentStage,
                    progress: GardenService.state.progressToNextStage,
                    stageName: GardenService.state.stageName,
                    justSolved: _justSolvedPuzzle,
                    puzzlesSolvedInStage: GardenService.state.puzzlesSolvedInStage,
                    puzzlesNeededForNextStage: GardenService.state.puzzlesNeededForNextStage,
                  ),

                // Move counter (always visible during gameplay)
                if (!_showGardenView) _buildMoveCounter(),

                // Bottom bar: stats + action buttons (hidden during modals)
                if (!_showCompletionOverlay && !_showSessionSummary && _lastRankUp == null)
                  _buildBottomBar(),
              ],
            ),
          ),

          // (Garden progress and session stats moved into Column flow)
          // Hint overlay
          if (_showingHint &&
              _stackKeys.containsKey(_hintSourceIndex) &&
              _stackKeys.containsKey(_hintDestIndex))
            Positioned.fill(
              child: HintOverlay(
                sourceIndex: _hintSourceIndex,
                destIndex: _hintDestIndex,
                sourceKey: _stackKeys[_hintSourceIndex]!,
                destKey: _stackKeys[_hintDestIndex]!,
                onDismiss: _dismissHint,
              ),
            ),
          if (_showCompletionOverlay)
            Positioned.fill(
              child: CompletionOverlay(
                moves: _completionMoves,
                time: _completionDuration,
                par: _currentPar,
                stars: _completionStars,
                coinsEarned: _coinsEarned,
                isNewRecord: _isNewMoveBest || _isNewTimeBest,
                onNextPuzzle: _advanceAfterCompletion,
                onHome: () => Navigator.of(context).pop(),
                onReplay: _restartPuzzle,
                isNewMoveBest: _isNewMoveBest,
                isNewTimeBest: _isNewTimeBest,
                currentStreak: StatsService().currentStreak,
                score: _lastScore?.totalScore ?? 0,
                xpEarned: _lastScore?.xpEarned ?? 0,
                undoUsed: _completionUndoUsed,
              ),
            ),
          // Rank-up overlay (sequenced after achievements)
          if (_showRankUp && _pendingRankUp != null)
            Positioned.fill(
              child: RankUpOverlay(
                newRank: _pendingRankUp!.newRank,
                newTitle: _pendingRankUp!.newRankDef.title,
                tierEmoji: _pendingRankUp!.newRankDef.emoji,
                tier: _pendingRankUp!.newRankDef.tier,
                onDismiss: () => setState(() {
                  _showRankUp = false;
                  _pendingRankUp = null;
                }),
              ),
            ),
          // Single achievement toast (sequenced one at a time)
          if (_currentAchievementToast != null)
            Positioned(
              top: 40.0,
              left: 0,
              right: 0,
              child: AchievementToast(
                key: ValueKey(_currentAchievementToast!.id),
                achievementName: _currentAchievementToast!.name,
                xpReward: _currentAchievementToast!.xpReward,
                coinReward: _currentAchievementToast!.coinReward,
                onDismiss: () {
                  setState(() {
                    _currentAchievementToast = null;
                  });
                },
              ),
            ),
          if (_showSessionSummary)
            Positioned.fill(
              child: ZenSessionSummary(
                puzzlesSolved: _puzzlesSolved,
                sessionDuration: _sessionDuration,
                bestMoves: StatsService().getBestMoves(_difficulty.label),
                difficulty: _difficulty.label,
                totalStars: StatsService().totalPuzzlesSolved,
                bestStreak: StatsService().bestStreak,
                onContinue: () => Navigator.of(context).pop(),
              ),
            ),
          if (_showOnboardingHint)
            Positioned.fill(
              child: GestureDetector(
                onTap: _dismissOnboarding,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: GameColors.surface.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: GameColors.zen.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pan_tool_outlined,
                            size: 48,
                            color: GameColors.zen.withValues(alpha: 0.8),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Drag blocks between stacks\nto sort by color',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: GameColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap anywhere to continue',
                            style: TextStyle(
                              color: GameColors.textMuted.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: GameColors.zen),
                      SizedBox(height: 16),
                      LoadingText(),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Exit Zen button (subtle)
          _ZenIconButton(
            icon: Icons.close,
            onPressed: _showSessionSummaryOverlay,
            tooltip: 'Exit Zen',
          ),

          const Spacer(),

          // Zen Mode title + puzzle number
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ZEN MODE',
                style: TextStyle(
                  color: GameColors.textMuted.withValues(alpha: 0.6),
                  fontSize: 12,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Puzzle #${_puzzlesSolved + 1}',
                style: TextStyle(
                  color: GameColors.textMuted.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Toggle move counter visibility
          _ZenIconButton(
            icon: _showMoveCounter ? Icons.visibility : Icons.visibility_off,
            onPressed: _toggleMoveCounter,
            tooltip: 'Show/hide move counter',
            isActive: _showMoveCounter,
          ),
        ],
      ),
    );
  }

  Widget _buildRankAndDifficulty() {
    final ps = ProgressionService();
    return Column(
      children: [
        // Small rank indicator
        Padding(
          padding: const EdgeInsets.only(left: 40, right: 40, bottom: 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${ps.tierEmoji} ${ps.rankTitle}',
              style: TextStyle(
                color: GameColors.textMuted.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        _buildDifficultySlider(),
      ],
    );
  }

  Widget _buildDifficultySlider() {
    return Consumer<GameState>(
      builder: (context, gameState, _) {
        final isLocked = gameState.moveCount > 0;
        return IgnorePointer(
          ignoring: isLocked || _isLoading,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: Opacity(
              opacity: (isLocked || _isLoading) ? 0.5 : 1.0, // Dim when locked or loading
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: GameColors.surface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ZenDifficulty.values.map((diff) {
                    final isSelected = _difficulty == diff;
                    // Color coding per difficulty
                    final diffColor = switch (diff) {
                      ZenDifficulty.easy => const Color(0xFF4CAF50),
                      ZenDifficulty.medium => const Color(0xFFFFB74D),
                      ZenDifficulty.hard => const Color(0xFFFF9800),
                      ZenDifficulty.ultra => const Color(0xFFE74C3C),
                    };
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _setDifficulty(diff),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? diffColor.withValues(alpha: 0.3)
                                : GameColors.surface.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            diff.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected
                                  ? diffColor
                                  : GameColors.textMuted.withValues(alpha: 0.6),
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsBar() {
    final statsService = StatsService();
    final difficulty = _difficulty.label;
    
    // Format live timer as mm:ss
    String formatLiveTime() {
      final elapsed = _liveStopwatch.elapsed;
      final minutes = elapsed.inMinutes;
      final seconds = elapsed.inSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatChip(
            icon: Icons.local_fire_department, 
            value: '${statsService.currentStreak}', 
            label: 'Streak'
          ),
          _StatChip(
            icon: Icons.tag, 
            value: '${_puzzlesSolved + 1}', 
            label: 'Puzzle'
          ),
          _StatChip(
            icon: Icons.timer, 
            value: _liveStopwatch.isRunning || _liveStopwatch.elapsed.inSeconds > 0
                ? formatLiveTime()
                : statsService.formatTime(statsService.getBestTime(difficulty)), 
            label: 'Time'
          ),
          _StatChip(
            icon: Icons.stars, 
            value: '${statsService.getSolvedCount(difficulty)}', 
            label: 'Solved'
          ),
        ],
      ),
    );
  }

  Widget _buildMoveCounter() {
    return Consumer<GameState>(
      builder: (context, gameState, _) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: GameColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: GameColors.zen.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.touch_app,
                  size: 20,
                  color: GameColors.zen.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Text(
                  '${gameState.moveCount}',
                  style: TextStyle(
                    color: GameColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'moves',
                  style: TextStyle(
                    color: GameColors.textMuted.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGardenFullView() {
    final state = GardenService.state;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full interactive garden scene
        const ZenGardenScene(showStats: true, interactive: true),
        // Stage info overlay at top
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: GameColors.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${state.stageIcon} ${state.stageName}  •  ${state.totalPuzzlesSolved} puzzles solved',
                style: TextStyle(
                  color: GameColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Consumer<GameState>(
      builder: (context, gameState, _) {
        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: GameColors.surface.withValues(alpha: 0.6),
            border: Border(
              top: BorderSide(
                color: GameColors.zen.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Action buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // In garden view: only show Puzzle button
                  // In puzzle view: show all buttons
                  if (!_showGardenView) ...[
                    _ZenActionButton(
                      icon: Icons.undo,
                      label: gameState.undosRemaining > 0
                          ? 'Undo (${gameState.undosRemaining})'
                          : 'Undo (25🪙)',
                      enabled: !_isLoading && gameState.canUndo,
                      onPressed: !_isLoading && gameState.canUndo ? () => gameState.undo() : null,
                      countText: gameState.undosRemaining > 0
                          ? '×${gameState.undosRemaining}'
                          : null,
                      isExhausted: gameState.undosRemaining <= 0,
                    ),
                    _ZenActionButton(
                      icon: Icons.lightbulb_outline,
                      label: _hintsRemaining > 0
                          ? 'Hint (${_hintsRemaining})'
                          : 'Hint (25🪙)',
                      enabled: !_isLoading && _hintsRemaining > 0,
                      onPressed: !_isLoading && _hintsRemaining > 0 ? _showHint : null,
                      countText: _hintsRemaining > 0
                          ? '×${_hintsRemaining}'
                          : null,
                      isExhausted: _hintsRemaining <= 0,
                    ),
                    _ZenActionButton(
                      icon: Icons.refresh,
                      label: 'Restart',
                      enabled: !_isLoading && _initialStacks != null && gameState.moveCount > 0,
                      onPressed: !_isLoading && _initialStacks != null && gameState.moveCount > 0 ? _restartPuzzle : null,
                    ),
                  ],
                  _ZenActionButton(
                    icon: _showGardenView ? Icons.grid_view : Icons.park_outlined,
                    label: _showGardenView ? 'Puzzle' : 'Garden',
                    enabled: !_isLoading,
                    onPressed: !_isLoading ? () {
                      setState(() {
                        _showGardenView = !_showGardenView;
                        // Stop garden audio when leaving garden view
                        if (!_showGardenView) {
                          ZenAudioService().stopAmbience();
                        }
                      });
                    } : null,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

}

/// Action button for the bottom bar (undo, garden, hint)
class _ZenActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;
  final String? countText;
  final bool isExhausted;

  const _ZenActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    this.onPressed,
    this.countText,
    this.isExhausted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? GameColors.text
        : GameColors.textMuted.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: enabled
              ? GameColors.surface.withValues(alpha: 0.5)
              : GameColors.surface.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? GameColors.zen.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            if (countText != null)
              Text(
                countText!,
                style: TextStyle(
                  color: GameColors.zen,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
            else if (isExhausted)
              Text(
                '25🪙',
                style: TextStyle(
                  color: GameColors.textMuted.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact stat chip for the stats bar
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: GameColors.zen.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 21,
            color: GameColors.zen.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: GameColors.textMuted.withValues(alpha: 0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle icon button for Zen mode UI
class _ZenIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool isActive;
  final String? label;

  const _ZenIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.isActive = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive
                ? GameColors.surface.withValues(alpha: 0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: GameColors.textMuted.withValues(alpha: isActive ? 0.8 : 0.5),
                size: 22,
              ),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(
                  label!,
                  style: TextStyle(
                    color: GameColors.textMuted.withValues(alpha: isActive ? 0.7 : 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ambient floating particles for zen atmosphere
class AmbientParticlesPainter extends CustomPainter {
  final double progress;
  final int seed;

  AmbientParticlesPainter({required this.progress, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final particleCount = 30;

    for (int i = 0; i < particleCount; i++) {
      // Each particle has its own parameters
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final radius = 1.5 + random.nextDouble() * 2.5;
      final speed = 0.3 + random.nextDouble() * 0.7;
      final phase = random.nextDouble() * 2 * pi;

      // Gentle floating motion
      final animPhase = progress * 2 * pi * speed + phase;
      final xOffset = sin(animPhase) * 20;
      final yOffset = cos(animPhase * 0.7) * 15;

      final x = (baseX + xOffset) % size.width;
      final y = (baseY + yOffset + progress * size.height * 0.1) % size.height;

      // Subtle opacity pulsing
      final opacity = 0.15 + sin(animPhase * 2) * 0.1;

      // Pick a color from the palette with low saturation
      final colorIndex = i % GameColors.palette.length;
      final baseColor = GameColors.palette[colorIndex];

      // Desaturate and dim the color for ambient effect
      final color = Color.lerp(
        baseColor.withValues(alpha: opacity),
        Colors.white.withValues(alpha: opacity * 0.5),
        0.4,
      )!;

      final paint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(AmbientParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.seed != seed;
  }
}

// Extension to storage service for zen mode stats
extension ZenStorageExtension on StorageService {
  Future<void> addZenPuzzle() async {
    // Zen puzzles are tracked in session only for now
    // Could be persisted via SharedPreferences if needed
  }

  int getZenPuzzlesSolved() {
    // Session tracking only
    return 0;
  }
}

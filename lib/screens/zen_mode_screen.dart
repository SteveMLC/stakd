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

  late ZenDifficulty _difficulty;
  int _puzzlesSolved = 0;
  DateTime? _puzzleStart;
  DateTime? _sessionStart;
  Timer? _sessionTimer;
  Duration _sessionDuration = Duration.zero;
  bool _showMoveCounter = true;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hints remaining for this puzzle.')),
      );
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
    });
    _puzzleStart = DateTime.now();
  }

  void _loadNewPuzzle() {
    _puzzleStart = DateTime.now();
    final params = _getAdaptiveDifficulty();
    final seed = _puzzleSeed;
    setState(() => _isLoading = true);
    final encoded = encodeParamsForIsolate(params, seed: seed);
    
    // Add timeout to prevent infinite generation
    compute<List<int>, List<List<int>>>(generateZenPuzzleInIsolate, encoded)
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            // Fallback: use simpler params that will generate quickly
            final fallbackParams = LevelParams(
              colors: params.colors,
              depth: params.depth,
              stacks: params.colors + params.emptySlots,
              emptySlots: params.emptySlots,
              shuffleMoves: 50, // Reduced shuffle for faster generation
              minDifficultyScore: 0,
            );
            final fallbackEncoded = encodeParamsForIsolate(fallbackParams, seed: seed);
            return compute<List<int>, List<List<int>>>(
              generateZenPuzzleInIsolate, 
              fallbackEncoded,
            );
          },
        )
        .then((encodedStacks) {
          if (!mounted) return;
          final stacks = decodeStacksFromIsolate(encodedStacks, params.depth);
          _initialStacks = stacks.map((s) => GameStack(
            layers: s.layers.map((l) => Layer(colorIndex: l.colorIndex, type: l.type, colors: l.colors, lockedUntil: l.lockedUntil, isFrozen: l.isFrozen)).toList(),
            maxDepth: s.maxDepth,
          )).toList();
          context.read<GameState>().initZenGame(stacks);
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
    
    // Add timeout to pre-generation too
    compute<List<int>, List<List<int>>>(generateZenPuzzleInIsolate, encoded)
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            // Fallback for pre-generation
            final fallbackParams = LevelParams(
              colors: params.colors,
              depth: params.depth,
              stacks: params.colors + params.emptySlots,
              emptySlots: params.emptySlots,
              shuffleMoves: 50,
              minDifficultyScore: 0,
            );
            final fallbackEncoded = encodeParamsForIsolate(fallbackParams, seed: savedSeed);
            return compute<List<int>, List<List<int>>>(
              generateZenPuzzleInIsolate,
              fallbackEncoded,
            );
          },
        )
        .then((encodedStacks) {
          if (!mounted) return;
          final stacks = decodeStacksFromIsolate(encodedStacks, params.depth);
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
          return const LevelParams(colors: 3, depth: 4, stacks: 5, emptySlots: 2, shuffleMoves: 40);
        } else if (puzzleNumber <= 7) {
          return const LevelParams(colors: 4, depth: 4, stacks: 6, emptySlots: 2, shuffleMoves: 45);
        } else {
          return ZenParams.medium;
        }

      case ZenDifficulty.hard:
        if (puzzleNumber <= 2) {
          return const LevelParams(colors: 3, depth: 4, stacks: 5, emptySlots: 2, shuffleMoves: 40);
        } else if (puzzleNumber <= 5) {
          return const LevelParams(colors: 4, depth: 4, stacks: 6, emptySlots: 2, shuffleMoves: 50);
        } else {
          return ZenParams.hard;
        }

      case ZenDifficulty.ultra:
        return ZenParams.ultra;
    }
  }

  void _showCompletion(GameState gameState) {
    if (_showCompletionOverlay) return;
    
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

    setState(() {
      _completionDuration = duration;
      _completionMoves = gameState.moveCount;
      _completionStars = gameState.calculateStars();
      _coinsEarned = 0;
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

  void _advanceAfterCompletion() async {
    if (_isTransitioning) return;
    _isTransitioning = true;

    setState(() {
      _puzzlesSolved++;
      _showCompletionOverlay = false;
    });

    // Save progress
    StorageService().addZenPuzzle();
    await GardenService.recordPuzzleSolved();
    AchievementService().checkStarAchievements();

    if (_preGeneratedStacks != null) {
      // Use the pre-generated puzzle — no loading screen!
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
      backgroundColor: Colors.transparent,
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

                // Difficulty slider (hidden in garden view)
                if (!_showGardenView) _buildDifficultySlider(),

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
                                onMove: () => AudioService().playSlide(),
                                onClear: () => AudioService().playClear(),
                              );
                            },
                          ),
                        ),
                ),

                // Move counter (always visible during gameplay)
                if (!_showGardenView) _buildMoveCounter(),

                // Bottom bar: stats + action buttons
                _buildBottomBar(),
              ],
            ),
          ),

          // Garden mini-footer (between puzzle and bottom toolbar)
          if (!_showGardenView)
            Positioned(
              bottom: 80, // above the bottom toolbar
              left: 0,
              right: 0,
              child: GardenMiniFooter(
                gardenStage: GardenService.state.currentStage,
                progress: GardenService.state.progressToNextStage,
                stageName: GardenService.state.stageName,
                justSolved: _justSolvedPuzzle,
                puzzlesSolvedInStage: GardenService.state.puzzlesSolvedInStage,
                puzzlesNeededForNextStage: GardenService.state.puzzlesNeededForNextStage,
              ),
            ),

          // (Garden progress and session stats moved into bottom bar)
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
                par: null,
                stars: _completionStars,
                coinsEarned: _coinsEarned,
                isNewRecord: _isNewMoveBest || _isNewTimeBest,
                onNextPuzzle: _advanceAfterCompletion,
                onHome: () => Navigator.of(context).pop(),
                onReplay: _restartPuzzle,
                isNewMoveBest: _isNewMoveBest,
                isNewTimeBest: _isNewTimeBest,
                currentStreak: StatsService().currentStreak,
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

          // Toggle move counter
          _ZenIconButton(
            icon: _showMoveCounter ? Icons.visibility : Icons.visibility_off,
            onPressed: _toggleMoveCounter,
            tooltip: 'Toggle moves',
            isActive: _showMoveCounter,
          ),
        ],
      ),
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
                                ? GameColors.accent.withValues(alpha: 0.3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            diff.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected
                                  ? GameColors.text
                                  : GameColors.textMuted,
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
            icon: Icons.emoji_events, 
            value: statsService.getBestMoves(difficulty) == 999999 
                ? '--' 
                : '${statsService.getBestMoves(difficulty)}', 
            label: 'Best Moves'
          ),
          _StatChip(
            icon: Icons.timer, 
            value: statsService.formatTime(statsService.getBestTime(difficulty)), 
            label: 'Best Time'
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
                      label: 'Undo',
                      badgeCount: gameState.undosRemaining,
                      enabled: !_isLoading && gameState.canUndo,
                      onPressed: !_isLoading && gameState.canUndo ? () => gameState.undo() : null,
                    ),
                    _ZenActionButton(
                      icon: Icons.lightbulb_outline,
                      label: 'Hint',
                      badgeCount: _hintsRemaining,
                      enabled: !_isLoading && _hintsRemaining > 0,
                      onPressed: !_isLoading && _hintsRemaining > 0 ? _showHint : null,
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
  final int? badgeCount;
  final bool enabled;
  final VoidCallback? onPressed;

  const _ZenActionButton({
    required this.icon,
    required this.label,
    this.badgeCount,
    required this.enabled,
    this.onPressed,
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
            Badge(
              isLabelVisible: badgeCount != null && badgeCount! > 0,
              label: badgeCount != null ? Text('$badgeCount') : null,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
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
            size: 16,
            color: GameColors.zen.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: GameColors.text,
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

  const _ZenIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.isActive = false,
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
          child: Icon(
            icon,
            color: GameColors.textMuted.withValues(alpha: isActive ? 0.8 : 0.5),
            size: 22,
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

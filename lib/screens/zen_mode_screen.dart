import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/stack_model.dart';
import '../services/level_generator.dart';
import '../services/zen_puzzle_isolate.dart';
import '../services/audio_service.dart';
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
import '../services/achievement_service.dart';

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
  const ZenModeScreen({super.key});

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

  ZenDifficulty _difficulty = ZenDifficulty.medium;
  int _puzzlesSolved = 0;
  DateTime? _puzzleStart;
  DateTime? _sessionStart;
  Timer? _sessionTimer;
  Duration _sessionDuration = Duration.zero;
  bool _showMoveCounter = false;
  bool _isTransitioning = false;
  bool _isLoading = false;
  bool _showGardenView = false;
  int _puzzleSeed = 0;

  // Pre-generated next puzzle (generated during completion celebration)
  List<GameStack>? _preGeneratedStacks;
  bool _isPreGenerating = false;

  // Fade animation for puzzle transitions
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Particle animation controller
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    GardenService.startFreshSession();
    GameColors.setUltraPalette(_difficulty == ZenDifficulty.ultra);
    _sessionStart = DateTime.now();
    _puzzleSeed = DateTime.now().millisecondsSinceEpoch;

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

  void _loadNewPuzzle() {
    _puzzleStart = DateTime.now();
    final params = _getAdaptiveDifficulty();
    final seed = _puzzleSeed;
    setState(() => _isLoading = true);
    final encoded = encodeParamsForIsolate(params, seed: seed);
    compute<List<int>, List<List<int>>>(generateZenPuzzleInIsolate, encoded)
        .then((encodedStacks) {
          if (!mounted) return;
          final stacks = decodeStacksFromIsolate(encodedStacks, params.depth);
          context.read<GameState>().initZenGame(stacks);
          setState(() {
            _isLoading = false;
            _stackKeys.clear();
            _puzzleSeed++;
            _hintsRemaining = 3;
            _showingHint = false;
            _showCompletionOverlay = false;
          });
        })
        .catchError((e, st) {
          if (mounted) setState(() => _isLoading = false);
        });
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
    compute<List<int>, List<List<int>>>(generateZenPuzzleInIsolate, encoded)
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
        if (puzzleNumber <= 2)
          return const LevelParams(colors: 2, depth: 3, stacks: 4, emptySlots: 2, shuffleMoves: 25);
        else if (puzzleNumber <= 5)
          return const LevelParams(colors: 3, depth: 3, stacks: 5, emptySlots: 2, shuffleMoves: 35);
        else if (puzzleNumber <= 8)
          return const LevelParams(colors: 3, depth: 4, stacks: 5, emptySlots: 2, shuffleMoves: 40);
        else
          return ZenParams.easy;

      case ZenDifficulty.medium:
        if (puzzleNumber <= 2)
          return const LevelParams(colors: 3, depth: 3, stacks: 5, emptySlots: 2, shuffleMoves: 30);
        else if (puzzleNumber <= 4)
          return const LevelParams(colors: 3, depth: 4, stacks: 5, emptySlots: 2, shuffleMoves: 40);
        else if (puzzleNumber <= 7)
          return const LevelParams(colors: 4, depth: 4, stacks: 6, emptySlots: 2, shuffleMoves: 45);
        else
          return ZenParams.medium;

      case ZenDifficulty.hard:
        if (puzzleNumber <= 2)
          return const LevelParams(colors: 3, depth: 4, stacks: 5, emptySlots: 2, shuffleMoves: 40);
        else if (puzzleNumber <= 5)
          return const LevelParams(colors: 4, depth: 4, stacks: 6, emptySlots: 2, shuffleMoves: 50);
        else
          return ZenParams.hard;

      case ZenDifficulty.ultra:
        return ZenParams.ultra;
    }
  }

  void _showCompletion(GameState gameState) {
    if (_showCompletionOverlay) return;
    final start = _puzzleStart;
    final duration = start != null
        ? DateTime.now().difference(start)
        : Duration.zero;

    setState(() {
      _completionDuration = duration;
      _completionMoves = gameState.moveCount;
      _completionStars = gameState.calculateStars();
      _coinsEarned = 0;
      _showCompletionOverlay = true;
    });

    AudioService().playWin();
    HapticService.instance.levelWinPattern();

    // Pre-generate the next puzzle while the player celebrates
    _preGenerateNextPuzzle();
  }

  void _advanceAfterCompletion() {
    if (_isTransitioning) return;
    _isTransitioning = true;

    setState(() {
      _puzzlesSolved++;
      _showCompletionOverlay = false;
    });

    // Save progress
    StorageService().addZenPuzzle();
    GardenService.recordPuzzleSolved();
    AchievementService().checkStarAchievements();

    if (_preGeneratedStacks != null) {
      // Use the pre-generated puzzle — no loading screen!
      _fadeController.animateTo(0.0).then((_) {
        if (!mounted) return;
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  LevelParams _getAdaptiveDifficulty() {
    return _getAdaptiveDifficultyFor(_puzzlesSolved, _difficulty);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ZenGardenScene(showStats: false, interactive: false),

          // Ambient particles background (hidden in garden view)
          if (!_showGardenView)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, _) => CustomPaint(
                  painter: AmbientParticlesPainter(
                    progress: _particleController.value,
                    seed: _puzzleSeed,
                  ),
                ),
              ),
            ),

          // Subtle overlay for readability (hidden when garden view is active)
          if (!_showGardenView)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(
                        0xFF0B0F14,
                      ).withValues(alpha: 0.15),
                      Colors.transparent,
                      const Color(
                        0xFF0B0F14,
                      ).withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),
            ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top bar
                _buildTopBar(),

                // Difficulty slider
                _buildDifficultySlider(),

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

                // Optional move counter
                if (_showMoveCounter && !_showGardenView) _buildMoveCounter(),

                // Bottom bar: stats + action buttons
                _buildBottomBar(),
              ],
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
                isNewRecord: false,
                onNextPuzzle: _advanceAfterCompletion,
                onHome: () => Navigator.of(context).pop(),
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
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Exit Zen',
          ),

          const Spacer(),

          // Zen Mode title (subtle)
          Text(
            'ZEN MODE',
            style: TextStyle(
              color: GameColors.textMuted.withValues(alpha: 0.6),
              fontSize: 12,
              letterSpacing: 3,
              fontWeight: FontWeight.w300,
            ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
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
    );
  }

  Widget _buildMoveCounter() {
    return Consumer<GameState>(
      builder: (context, gameState, _) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: GameColors.surface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.touch_app,
                  size: 16,
                  color: GameColors.textMuted.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  '${gameState.moveCount}',
                  style: TextStyle(
                    color: GameColors.textMuted.withValues(alpha: 0.6),
                    fontSize: 14,
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
              // Stats row: garden progress | session stats
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    _buildGardenProgress(),
                    const Spacer(),
                    _buildSessionStats(),
                  ],
                ),
              ),
              // Action buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ZenActionButton(
                    icon: Icons.undo,
                    label: 'Undo',
                    badgeCount: gameState.undosRemaining,
                    enabled: gameState.canUndo,
                    onPressed: gameState.canUndo ? () => gameState.undo() : null,
                  ),
                  _ZenActionButton(
                    icon: _showGardenView ? Icons.grid_view : Icons.park_outlined,
                    label: _showGardenView ? 'Puzzle' : 'Garden',
                    enabled: true,
                    onPressed: () {
                      setState(() {
                        _showGardenView = !_showGardenView;
                      });
                    },
                  ),
                  _ZenActionButton(
                    icon: Icons.lightbulb_outline,
                    label: 'Hint',
                    badgeCount: _hintsRemaining,
                    enabled: _hintsRemaining > 0,
                    onPressed: _hintsRemaining > 0 ? _showHint : null,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.spa_outlined,
                size: 14,
                color: GameColors.textMuted.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Text(
                '$_puzzlesSolved',
                style: TextStyle(
                  color: GameColors.textMuted.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatDuration(_sessionDuration),
            style: TextStyle(
              color: GameColors.textMuted.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Build garden progress indicator showing stage and progress to next
  Widget _buildGardenProgress() {
    final state = GardenService.state;
    final progress = state.progressToNextStage;
    final puzzlesInStage = state.puzzlesSolvedInStage;
    final puzzlesNeeded = state.puzzlesNeededForNextStage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: GameColors.zen.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stage name with icon
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.stageIcon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                state.stageName,
                style: TextStyle(
                  color: GameColors.text.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Progress bar
          SizedBox(
            width: 120,
            child: Stack(
              children: [
                // Background
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: GameColors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // Progress fill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  height: 6,
                  width: 120 * progress,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        GameColors.zen.withValues(alpha: 0.7),
                        GameColors.zen,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: GameColors.zen.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Progress text
          Text(
            state.currentStage >= 9
                ? '∞ Infinite'
                : '$puzzlesInStage / $puzzlesNeeded to next',
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

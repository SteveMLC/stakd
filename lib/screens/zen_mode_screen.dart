import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../services/level_generator.dart';
import '../services/zen_puzzle_isolate.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../services/garden_service.dart';
import '../utils/constants.dart';
import '../widgets/game_board.dart';
import '../widgets/loading_text.dart';
import '../widgets/themes/zen_garden_scene.dart';

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
    with TickerProviderStateMixin {
  final Map<int, GlobalKey> _stackKeys = {};

  ZenDifficulty _difficulty = ZenDifficulty.medium;
  int _puzzlesSolved = 0;
  int _consecutiveFastSolves = 0;
  int _consecutiveSlowSolves = 0;
  DateTime? _puzzleStart;
  DateTime? _sessionStart;
  Timer? _sessionTimer;
  Duration _sessionDuration = Duration.zero;
  bool _showMoveCounter = false;
  bool _isTransitioning = false;
  bool _isLoading = false;
  int _puzzleSeed = 0;

  // Fade animation for puzzle transitions
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Particle animation controller
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    GardenService.startFreshSession();
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
    _sessionTimer?.cancel();
    _fadeController.dispose();
    _particleController.dispose();
    super.dispose();
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
      context.read<GameState>().initGame(stacks, 0); // Level 0 = zen mode
      setState(() {
        _isLoading = false;
        _stackKeys.clear();
        _puzzleSeed++;
      });
    }).catchError((e, st) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _onPuzzleComplete() async {
    if (_isTransitioning) return;
    _isTransitioning = true;

    setState(() {
      _puzzlesSolved++;
    });
    _recordSolveTime();

    // Save progress
    final storage = StorageService();
    await storage.addZenPuzzle();
    GardenService.recordPuzzleSolved();

    // Fade out current puzzle
    await _fadeController.animateTo(0.0);

    // Load new puzzle
    _loadNewPuzzle();

    // Fade in new puzzle
    await _fadeController.animateTo(1.0);

    _isTransitioning = false;
  }

  void _setDifficulty(ZenDifficulty difficulty) {
    if (_difficulty == difficulty) return;
    setState(() {
      _difficulty = difficulty;
    });
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
    final base = _getBaseDifficulty();
    if (_consecutiveFastSolves >= 3) {
      return _bumpDifficulty(base);
    }
    if (_consecutiveSlowSolves >= 2) {
      return _easeDifficulty(base);
    }
    return base;
  }

  LevelParams _getBaseDifficulty() {
    return switch (_difficulty) {
      ZenDifficulty.easy => ZenParams.easy,
      ZenDifficulty.medium => ZenParams.medium,
      ZenDifficulty.hard => ZenParams.hard,
      ZenDifficulty.ultra => ZenParams.ultra,
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

  void _recordSolveTime() {
    final start = _puzzleStart;
    if (start == null) return;
    final solveTime = DateTime.now().difference(start);

    if (solveTime.inSeconds < 30) {
      _consecutiveFastSolves++;
      _consecutiveSlowSolves = 0;
    } else if (solveTime.inMinutes >= 3) {
      _consecutiveSlowSolves++;
      _consecutiveFastSolves = 0;
    } else {
      _consecutiveFastSolves = 0;
      _consecutiveSlowSolves = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ZenGardenScene(showStats: false, interactive: false),

          // Ambient particles background
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

          // Subtle overlay for readability (reduced opacity so garden is visible)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0B0F14).withValues(alpha: 0.15),  // Much lighter
                    Colors.transparent,                         // Middle is clear
                    const Color(0xFF0B0F14).withValues(alpha: 0.15),  // Much lighter
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

                // Game board (with fade animation)
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Consumer<GameState>(
                      builder: (context, gameState, child) {
                        // Check for puzzle completion
                        if (gameState.isComplete && !_isTransitioning) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _onPuzzleComplete();
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
                if (_showMoveCounter) _buildMoveCounter(),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // Garden progress indicator (bottom left)
          Positioned(
            bottom: 32,
            left: 16,
            child: _buildGardenProgress(),
          ),

          // Session stats overlay (bottom right)
          Positioned(
            bottom: 32,
            right: 16,
            child: _buildSessionStats(),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
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
              Text(
                state.stageIcon,
                style: const TextStyle(fontSize: 14),
              ),
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

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../services/level_generator.dart';
import '../services/zen_puzzle_isolate.dart';
import '../services/audio_service.dart';
import '../services/garden_service.dart';
import '../utils/constants.dart';
import '../widgets/game_board.dart';
import '../widgets/loading_text.dart';

class ZenScreen extends StatefulWidget {
  final String difficulty; // 'easy' | 'medium' | 'hard'

  const ZenScreen({super.key, required this.difficulty});

  @override
  State<ZenScreen> createState() => _ZenScreenState();
}

class _ZenScreenState extends State<ZenScreen> with TickerProviderStateMixin {
  final Map<int, GlobalKey> _stackKeys = {};

  int _puzzlesSolved = 0;
  int _totalMoves = 0;
  int _consecutiveFastSolves = 0;
  int _consecutiveSlowSolves = 0;
  DateTime? _puzzleStart;
  bool _showStats = false;
  bool _isTransitioning = false;
  bool _isLoading = false;
  int _particleSeed = 0;

  late Stopwatch _sessionTimer;
  Timer? _sessionTicker;
  Duration _sessionDuration = Duration.zero;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    GameColors.setUltraPalette(widget.difficulty == 'ultra');
    _sessionTimer = Stopwatch()..start();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.value = 1.0;

    _particleController = AnimationController(
      duration: const Duration(seconds: 18),
      vsync: this,
    )..repeat();

    _sessionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _sessionDuration = _sessionTimer.elapsed;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNewPuzzle());
  }

  @override
  void dispose() {
    GameColors.setUltraPalette(false);
    _sessionTicker?.cancel();
    _fadeController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _loadNewPuzzle() {
    _puzzleStart = DateTime.now();
    final params = _getAdaptiveDifficulty();
    setState(() => _isLoading = true);
    final encoded = encodeParamsForIsolate(params);
    compute<List<int>, List<List<int>>>(generateZenPuzzleInIsolate, encoded)
        .then((encodedStacks) {
          if (!mounted) return;
          final stacks = decodeStacksFromIsolate(encodedStacks, params.depth);
          context.read<GameState>().initZenGame(stacks);
          setState(() {
            _isLoading = false;
            _stackKeys.clear();
            _particleSeed++;
          });
        })
        .catchError((e, st) {
          if (mounted) setState(() => _isLoading = false);
        });
  }

  Future<void> _onPuzzleSolved() async {
    if (_isTransitioning) return;
    _isTransitioning = true;

    setState(() {
      _puzzlesSolved++;
      _totalMoves += context.read<GameState>().moveCount;
    });
    _recordSolveTime();
    GardenService.recordPuzzleSolved();

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    await _fadeController.animateTo(0.0);
    if (!mounted) return;

    _loadNewPuzzle();
    await _fadeController.animateTo(1.0);

    _isTransitioning = false;
  }

  void _toggleStats() {
    setState(() {
      _showStats = !_showStats;
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
    return switch (widget.difficulty) {
      'easy' => ZenParams.easy,
      'medium' => ZenParams.medium,
      'hard' => ZenParams.hard,
      'ultra' => ZenParams.ultra,
      _ => ZenParams.medium,
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1117), Color(0xFF161B22), Color(0xFF1A1F26)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, _) => CustomPaint(
                  painter: AmbientParticlesPainter(
                    progress: _particleController.value,
                    seed: _particleSeed,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Consumer<GameState>(
                        builder: (context, gameState, _) {
                          if (gameState.isComplete && !_isTransitioning) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _onPuzzleSolved();
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
                  const SizedBox(height: 12),
                ],
              ),
            ),
            if (_showStats)
              Positioned(bottom: 28, right: 16, child: _buildSessionStats()),
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
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _ZenIconButton(
            icon: Icons.close,
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Exit Zen',
          ),
          const Spacer(),
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
          _ZenIconButton(
            icon: _showStats ? Icons.settings : Icons.settings_outlined,
            onPressed: _toggleStats,
            tooltip: 'Toggle session stats',
            isActive: _showStats,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
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
                color: GameColors.textMuted.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                '$_puzzlesSolved',
                style: TextStyle(
                  color: GameColors.textMuted.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Moves: $_totalMoves',
            style: TextStyle(
              color: GameColors.textMuted.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDuration(_sessionDuration),
            style: TextStyle(
              color: GameColors.textMuted.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

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

class AmbientParticlesPainter extends CustomPainter {
  final double progress;
  final int seed;

  AmbientParticlesPainter({required this.progress, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    const particleCount = 30;

    for (int i = 0; i < particleCount; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final radius = 1.5 + random.nextDouble() * 2.5;
      final speed = 0.3 + random.nextDouble() * 0.7;
      final phase = random.nextDouble() * 2 * pi;

      final animPhase = progress * 2 * pi * speed + phase;
      final xOffset = sin(animPhase) * 20;
      final yOffset = cos(animPhase * 0.7) * 15;

      final x = (baseX + xOffset) % size.width;
      final y = (baseY + yOffset + progress * size.height * 0.1) % size.height;

      final opacity = 0.15 + sin(animPhase * 2) * 0.1;
      final colorIndex = i % GameColors.palette.length;
      final baseColor = GameColors.palette[colorIndex];

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

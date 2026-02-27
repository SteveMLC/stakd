import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';

class CompletionOverlay extends StatefulWidget {
  final int moves;
  final Duration time;
  final int? par;
  final int stars;
  final int coinsEarned;
  final bool isNewRecord;
  final VoidCallback onNextPuzzle;
  final VoidCallback onHome;
  final VoidCallback? onReplay;
  final bool isNewMoveBest;
  final bool isNewTimeBest;
  final int currentStreak;
  final int score;
  final int xpEarned;
  final bool undoUsed;

  const CompletionOverlay({
    super.key,
    required this.moves,
    required this.time,
    this.par,
    required this.stars,
    this.coinsEarned = 0,
    this.isNewRecord = false,
    required this.onNextPuzzle,
    required this.onHome,
    this.onReplay,
    this.isNewMoveBest = false,
    this.isNewTimeBest = false,
    this.currentStreak = 0,
    this.score = 0,
    this.xpEarned = 0,
    this.undoUsed = false,
  });

  @override
  State<CompletionOverlay> createState() => _CompletionOverlayState();
}

class _CompletionOverlayState extends State<CompletionOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  late List<AnimationController> _starControllers;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late List<Animation<double>> _starAnimations;

  final List<_ConfettiParticle> _confetti = [];
  final Random _random = Random();

  static const int maxStars = 3; // Always show exactly 3 stars
  static const Color starGold = Color(0xFFFFD700);
  static const Color starEmpty = Color(0xFF3A3A4A);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Create controllers for each star animation (pop effect)
    _starControllers = List.generate(
      maxStars,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Create pop animations for each star
    _starAnimations = _starControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.elasticOut),
      );
    }).toList();

    _generateConfetti();

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      _scaleController.forward();
      _confettiController.forward();
      haptics.levelWinPattern();
      
      // Animate stars in sequence
      _animateStars();
    });
  }

  void _animateStars() async {
    for (int i = 0; i < widget.stars && i < maxStars; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _starControllers[i].forward();
        // Light haptic for each star
        haptics.lightTap();
      }
    }
  }

  void _generateConfetti() {
    // 2x particles for 3-star completions
    final count = widget.stars >= 3 ? 100 : 50;
    final shapes = [0, 1, 2]; // rect, circle, star
    for (int i = 0; i < count; i++) {
      _confetti.add(_ConfettiParticle(
        x: _random.nextDouble(),
        delay: _random.nextDouble() * 0.3,
        speed: 0.3 + _random.nextDouble() * 0.5,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.15,
        color: GameColors.palette[_random.nextInt(GameColors.palette.length)],
        size: 8 + _random.nextDouble() * 8,
        shape: shapes[_random.nextInt(shapes.length)],
      ));
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _confettiController.dispose();
    for (final controller in _starControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxStars, (index) {
        final isFilled = index < widget.stars;
        return AnimatedBuilder(
          animation: _starAnimations[index],
          builder: (context, child) {
            final scale = isFilled ? _starAnimations[index].value : 1.0;
            return Transform.scale(
              scale: scale,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  isFilled ? Icons.star : Icons.star_border,
                  size: 48,
                  color: isFilled ? starGold : starEmpty,
                  shadows: isFilled
                      ? [
                          Shadow(
                            color: starGold.withValues(alpha: 0.6),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          },
        );
      }),
    );
  }


  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Modal barrier with blur + dark overlay to hide board behind
            Positioned.fill(
              child: GestureDetector(
                onTap: () {}, // Absorb taps
                behavior: HitTestBehavior.opaque,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 10 * _fadeAnimation.value,
                    sigmaY: 10 * _fadeAnimation.value,
                  ),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.6 * _fadeAnimation.value),
                  ),
                ),
              ),
            ),
            // Content stack
            Stack(
              children: [
                AnimatedBuilder(
                  animation: _confettiController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _ConfettiPainter(
                        particles: _confetti,
                        progress: _confettiController.value,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
                Center(
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: GameColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: GameColors.accent.withValues(alpha: 0.3),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Top: Stars
                            _buildStarRating(),
                            // Record badges (compact inline)
                            if (widget.isNewMoveBest || widget.isNewTimeBest)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Wrap(
                                  spacing: 12,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    if (widget.isNewMoveBest)
                                      Text('\u{1f3c6} Best Moves!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: starGold)),
                                    if (widget.isNewTimeBest)
                                      Text('\u26a1 Best Time!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: starGold)),
                                  ],
                                ),
                              ),
                            // Middle: Score + rewards (ONE line, TWO currencies)
                            if (widget.score > 0) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Score: ${widget.score}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '+${widget.xpEarned} XP  \u2022  +${widget.coinsEarned} \u{1fa99}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: GameColors.textMuted.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                            // Expandable details section
                            const SizedBox(height: 8),
                            _ExpandableDetails(
                              moves: widget.moves,
                              par: widget.par,
                              time: widget.time,
                              currentStreak: widget.currentStreak,
                            ),
                            const SizedBox(height: 20),
                            // Bottom: Next Puzzle (primary pink)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  AudioService().playTap();
                                  widget.onNextPuzzle();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: GameColors.accent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text(
                                  'Next Puzzle',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Home (secondary outline)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  AudioService().playTap();
                                  widget.onHome();
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  side: BorderSide(
                                    color: GameColors.textMuted.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Text(
                                  'Home',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ExpandableDetails extends StatefulWidget {
  final int moves;
  final int? par;
  final Duration time;
  final int currentStreak;

  const _ExpandableDetails({
    required this.moves,
    this.par,
    required this.time,
    required this.currentStreak,
  });

  @override
  State<_ExpandableDetails> createState() => _ExpandableDetailsState();
}

class _ExpandableDetailsState extends State<_ExpandableDetails> {
  bool _expanded = false;

  String _fmtTime(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return minutes > 0
        ? '$minutes:${seconds.toString().padLeft(2, '0')}'
        : '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: GameColors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatChip(icon: Icons.touch_app, label: '${widget.moves}', subtitle: widget.par != null ? 'moves (par ${widget.par})' : 'moves'),
                const SizedBox(width: 24),
                _StatChip(icon: Icons.timer, label: _fmtTime(widget.time), subtitle: 'time'),
              ],
            ),
            if (_expanded && widget.currentStreak > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_fire_department, size: 16, color: Color(0xFFFF6B44)),
                  const SizedBox(width: 4),
                  Text(
                    'Streak: ${widget.currentStreak}',
                    style: TextStyle(fontSize: 12, color: GameColors.text),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: GameColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: GameColors.textMuted, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: GameColors.text,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: GameColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _ConfettiParticle {
  final double x;
  final double delay;
  final double speed;
  final double rotation;
  final double rotationSpeed;
  final Color color;
  final double size;
  final int shape; // 0=rect, 1=circle, 2=star

  _ConfettiParticle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.rotation,
    this.rotationSpeed = 0.0,
    required this.color,
    required this.size,
    this.shape = 0,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final effectiveProgress =
          ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (effectiveProgress <= 0) continue;

      final x = p.x * size.width;
      final y = effectiveProgress * size.height * p.speed;
      final opacity = 1.0 - effectiveProgress;
      final rotation = p.rotation + effectiveProgress * 4 + effectiveProgress * p.rotationSpeed * 20;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      switch (p.shape) {
        case 1: // circle
          canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
          break;
        case 2: // star
          _drawStar(canvas, paint, p.size * 0.5);
          break;
        default: // rectangle
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
            paint,
          );
      }
      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double radius) {
    final path = Path();
    final innerRadius = radius * 0.4;
    for (int i = 0; i < 10; i++) {
      final r = i.isEven ? radius : innerRadius;
      final angle = (i * pi / 5) - pi / 2;
      final x = r * cos(angle);
      final y = r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

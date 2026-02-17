import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';

class CompletionOverlay extends StatefulWidget {
  final int moves;
  final Duration time;
  final int? par;
  final int stars;
  final bool isNewRecord;
  final VoidCallback onNextPuzzle;
  final VoidCallback onHome;

  const CompletionOverlay({
    super.key,
    required this.moves,
    required this.time,
    this.par,
    required this.stars,
    this.isNewRecord = false,
    required this.onNextPuzzle,
    required this.onHome,
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
      3,
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
    for (int i = 0; i < widget.stars && i < 3; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _starControllers[i].forward();
        // Light haptic for each star
        haptics.lightTap();
      }
    }
  }

  void _generateConfetti() {
    for (int i = 0; i < 50; i++) {
      _confetti.add(_ConfettiParticle(
        x: _random.nextDouble(),
        delay: _random.nextDouble() * 0.3,
        speed: 0.3 + _random.nextDouble() * 0.5,
        rotation: _random.nextDouble() * 2 * pi,
        color: GameColors.palette[_random.nextInt(GameColors.palette.length)],
        size: 8 + _random.nextDouble() * 8,
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

  String _formatTime(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return minutes > 0
        ? '$minutes:${seconds.toString().padLeft(2, '0')}'
        : '${seconds}s';
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
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
        return Container(
          color: GameColors.backgroundDark.withValues(alpha: 0.85 * _fadeAnimation.value),
          child: Stack(
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
                            Text(
                              'PUZZLE COMPLETE!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: GameColors.text,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Star rating
                            _buildStarRating(),
                            // New Record badge
                            if (widget.isNewRecord)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: starGold.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: starGold.withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '⭐ NEW RECORD! ⭐',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: starGold,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _StatChip(
                                  icon: Icons.touch_app,
                                  label: '${widget.moves}',
                                  subtitle: widget.par != null
                                      ? 'moves (par ${widget.par})'
                                      : 'moves',
                                ),
                                const SizedBox(width: 24),
                                _StatChip(
                                  icon: Icons.timer,
                                  label: _formatTime(widget.time),
                                  subtitle: 'time',
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    AudioService().playTap();
                                    widget.onHome();
                                  },
                                  child: const Text('Home'),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
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
                              ],
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
        );
      },
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
  final Color color;
  final double size;

  _ConfettiParticle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.rotation,
    required this.color,
    required this.size,
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
      final rotation = p.rotation + effectiveProgress * 4;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

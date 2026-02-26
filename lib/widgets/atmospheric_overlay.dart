import 'dart:math';
import 'package:flutter/material.dart';

/// Ultra-subtle atmospheric effects layered behind puzzle UI
/// All movement slower than conscious awareness, <5% visual dominance
class AtmosphericOverlay extends StatefulWidget {
  final int gardenStage;

  const AtmosphericOverlay({
    super.key,
    required this.gardenStage,
  });

  @override
  State<AtmosphericOverlay> createState() => _AtmosphericOverlayState();
}

class _AtmosphericOverlayState extends State<AtmosphericOverlay>
    with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _fireflyController1;
  late AnimationController _fireflyController2;

  @override
  void initState() {
    super.initState();

    // Shared breathing controller for gradient + dust (12s cycle)
    _breathingController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat(reverse: true);

    // Firefly controllers (5s fade cycle each, offset phases)
    _fireflyController1 = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);

    _fireflyController2 = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    // Offset firefly 2 by half cycle
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _fireflyController2.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _fireflyController1.dispose();
    _fireflyController2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: Gradient Breathing (Foundation)
        _BreathingGradient(controller: _breathingController),

        // Layer 2: Sparse Dust Motes (2-4 particles)
        _DustMotes(controller: _breathingController),

        // Layer 3: Depth Mist (Stage 3+)
        if (widget.gardenStage >= 3)
          _DepthMist(controller: _breathingController),

        // Layer 4: Fireflies (Stage 6+, unlocked via GardenService)
        if (widget.gardenStage >= 6) ...[
          _Firefly(
            controller: _fireflyController1,
            position: const Offset(0.15, 0.3),
          ),
          _Firefly(
            controller: _fireflyController2,
            position: const Offset(0.85, 0.7),
          ),
        ],

        // Layer 5: Radial Vignette (Grounding)
        const _RadialVignette(),
      ],
    );
  }
}

/// Layer 1: Slow breathing radial gradient overlay
class _BreathingGradient extends StatelessWidget {
  final AnimationController controller;

  const _BreathingGradient({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // 2-3% opacity shift (0.02 → 0.04)
        final centerOpacity = 0.02 + (controller.value * 0.02);
        final edgeOpacity = 0.01 + (controller.value * 0.01);

        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                Colors.white.withValues(alpha: centerOpacity),
                Colors.black.withValues(alpha: edgeOpacity),
              ],
              stops: const [0.3, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Layer 2: Sparse dust motes (2-4 particles, outer edges only)
class _DustMotes extends StatelessWidget {
  final AnimationController controller;

  const _DustMotes({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _DustMotesPainter(
            progress: controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _DustMotesPainter extends CustomPainter {
  final double progress;
  static final Random _random = Random(42); // Fixed seed for consistency
  static final List<_Particle> _particles = _generateParticles();

  _DustMotesPainter({required this.progress});

  static List<_Particle> _generateParticles() {
    // Generate 3 particles in outer margins
    return List.generate(3, (i) {
      final isLeft = i % 2 == 0;
      return _Particle(
        // Keep in left 20% or right 20% (never center)
        x: isLeft ? _random.nextDouble() * 0.2 : 0.8 + _random.nextDouble() * 0.2,
        startY: 0.2 + _random.nextDouble() * 0.6, // Start position
        size: 2.0 + _random.nextDouble() * 2.0, // 2-4px
        speed: 0.025 + _random.nextDouble() * 0.01, // Very slow (30-40s to cross)
        opacity: 0.08 + _random.nextDouble() * 0.04, // 8-12%
        phase: _random.nextDouble(), // Stagger spawn
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in _particles) {
      // Calculate current Y position (30-40 seconds to cross full screen)
      final cycleProgress = (progress + particle.phase) % 1.0;
      final y = (particle.startY + cycleProgress * particle.speed * 40) % 1.0;

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: particle.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawCircle(
        Offset(particle.x * size.width, y * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DustMotesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _Particle {
  final double x;
  final double startY;
  final double size;
  final double speed;
  final double opacity;
  final double phase;

  _Particle({
    required this.x,
    required this.startY,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.phase,
  });
}

/// Layer 3: Depth mist (horizontal band, stage 3+)
class _DepthMist extends StatelessWidget {
  final AnimationController controller;

  const _DepthMist({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Very slow horizontal drift (20 seconds for full cycle)
        final driftOffset = (controller.value * 2 - 1) * 30; // ±30px drift

        return Positioned(
          left: 0,
          right: 0,
          top: MediaQuery.of(context).size.height * 0.7,
          child: Transform.translate(
            offset: Offset(driftOffset, 0),
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFE8F4F8).withValues(alpha: 0.0),
                    const Color(0xFFE8F4F8).withValues(alpha: 0.05),
                    const Color(0xFFE8F4F8).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Layer 4: Individual firefly (stage 6+)
class _Firefly extends StatelessWidget {
  final AnimationController controller;
  final Offset position; // Relative position (0-1, 0-1)

  const _Firefly({
    required this.controller,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final screenSize = MediaQuery.of(context).size;

        return Positioned(
          left: position.dx * screenSize.width,
          top: position.dy * screenSize.height,
          child: Opacity(
            opacity: controller.value,
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFAE6),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFFAE6).withValues(alpha: 0.6 * controller.value),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Layer 5: Static radial vignette (grounding)
class _RadialVignette extends StatelessWidget {
  const _RadialVignette();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.18),
          ],
          stops: const [0.4, 1.0],
        ),
      ),
    );
  }
}

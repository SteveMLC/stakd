import 'dart:math';
import 'package:flutter/material.dart';

/// A single particle in the burst effect
class Particle {
  Offset position;
  final Offset velocity;
  final Color color;
  final double startTime;
  final double lifetime;
  double scale = 1.0;
  double opacity = 1.0;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.startTime,
    required this.lifetime,
  });

  void update(double currentTime) {
    final elapsed = currentTime - startTime;
    final progress = (elapsed / lifetime).clamp(0.0, 1.0);

    // Update position
    position = position + velocity;

    // Fade out and scale down over time
    opacity = 1.0 - progress;
    scale = 1.0 - (progress * 0.6); // Scale to 40% of original
  }

  bool get isDead => opacity <= 0;
}

/// Widget that displays a particle burst effect
class ParticleBurst extends StatefulWidget {
  final Offset center;
  final Color color;
  final int particleCount;
  final double minSpeed;
  final double maxSpeed;
  final Duration lifetime;
  final VoidCallback? onComplete;

  const ParticleBurst({
    super.key,
    required this.center,
    required this.color,
    this.particleCount = 18,
    this.minSpeed = 2.0,
    this.maxSpeed = 5.0,
    this.lifetime = const Duration(milliseconds: 500),
    this.onComplete,
  });

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<ParticleBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();
  late double _startTime;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.lifetime);

    _startTime = 0;
    _initializeParticles();

    _controller.addListener(_updateParticles);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    _controller.forward();
  }

  void _initializeParticles() {
    for (int i = 0; i < widget.particleCount; i++) {
      final angle =
          (i / widget.particleCount) * 2 * pi +
          (_random.nextDouble() - 0.5) * 0.5; // Add some randomness
      final speed =
          widget.minSpeed +
          _random.nextDouble() * (widget.maxSpeed - widget.minSpeed);

      final velocity = Offset(cos(angle) * speed, sin(angle) * speed);

      // Add color variation for more visual interest
      final hslColor = HSLColor.fromColor(widget.color);
      final variedColor = hslColor.withLightness(
        (hslColor.lightness + (_random.nextDouble() * 0.2 - 0.1)).clamp(0.0, 1.0)
      ).toColor();

      _particles.add(
        Particle(
          position: widget.center,
          velocity: velocity,
          color: variedColor,
          startTime: _startTime,
          lifetime: widget.lifetime.inMilliseconds.toDouble(),
        ),
      );
    }
  }

  void _updateParticles() {
    final currentTime = _controller.value * widget.lifetime.inMilliseconds;
    for (final particle in _particles) {
      particle.update(currentTime);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlePainter(particles: _particles),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  _ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      if (particle.isDead) continue;

      // Draw glow effect
      final glowPaint = Paint()
        ..color = particle.color.withValues(alpha: particle.opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(particle.position, 6.0 * particle.scale, glowPaint);

      // Draw solid particle
      final paint = Paint()
        ..color = particle.color.withValues(alpha: particle.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(particle.position, 4.0 * particle.scale, paint);

      // Draw bright core
      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: particle.opacity * 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(particle.position, 2.0 * particle.scale, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

/// Overlay that manages multiple particle bursts
class ParticleBurstOverlay extends StatefulWidget {
  final List<ParticleBurstData> bursts;
  final VoidCallback? onAllComplete;

  const ParticleBurstOverlay({
    super.key,
    required this.bursts,
    this.onAllComplete,
  });

  @override
  State<ParticleBurstOverlay> createState() => _ParticleBurstOverlayState();
}

class _ParticleBurstOverlayState extends State<ParticleBurstOverlay> {
  final Set<int> _completedBursts = {};

  void _onBurstComplete(int index) {
    _completedBursts.add(index);
    if (_completedBursts.length == widget.bursts.length) {
      widget.onAllComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (int i = 0; i < widget.bursts.length; i++)
          ParticleBurst(
            center: widget.bursts[i].center,
            color: widget.bursts[i].color,
            particleCount: widget.bursts[i].particleCount,
            lifetime: widget.bursts[i].lifetime,
            onComplete: () => _onBurstComplete(i),
          ),
      ],
    );
  }
}

/// Data for a single particle burst
class ParticleBurstData {
  final Offset center;
  final Color color;
  final int particleCount;
  final Duration lifetime;

  const ParticleBurstData({
    required this.center,
    required this.color,
    this.particleCount = 18,
    this.lifetime = const Duration(milliseconds: 500),
  });
}

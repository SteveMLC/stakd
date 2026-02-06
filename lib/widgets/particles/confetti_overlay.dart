import 'dart:math';
import 'package:flutter/material.dart';

/// A single confetti piece
class Confetto {
  Offset position;
  final Offset velocity;
  final Color color;
  final double rotationSpeed;
  final Size size;
  double rotation = 0;
  double opacity = 1.0;

  Confetto({
    required this.position,
    required this.velocity,
    required this.color,
    required this.rotationSpeed,
    required this.size,
  });

  void update() {
    // Update position with drift
    position = position + velocity;
    rotation += rotationSpeed;

    // Slow horizontal drift
    position = Offset(position.dx + sin(rotation * 0.1) * 0.3, position.dy);
  }

  bool isOffScreen(double screenHeight) => position.dy > screenHeight + 20;
}

/// Custom confetti overlay widget for level win
class ConfettiOverlay extends StatefulWidget {
  final Duration duration;
  final List<Color> colors;
  final int confettiCount;

  const ConfettiOverlay({
    super.key,
    this.duration = const Duration(seconds: 3),
    required this.colors,
    this.confettiCount = 40,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Confetto> _confetti = [];
  final Random _random = Random();
  late double _screenWidth;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.duration);

    _controller.addListener(_updateConfetti);
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    _screenWidth = size.width;

    if (_confetti.isEmpty) {
      _initializeConfetti();
    }
  }

  void _initializeConfetti() {
    for (int i = 0; i < widget.confettiCount; i++) {
      // Random starting X position
      final x = _random.nextDouble() * _screenWidth;

      // Start above screen, stagger the spawn
      final y = -20.0 - (_random.nextDouble() * 100);

      // Fall speed with slight variation
      final fallSpeed = 1.5 + _random.nextDouble() * 1.0;

      // Random horizontal drift
      final driftSpeed = (_random.nextDouble() - 0.5) * 0.5;

      // Random rotation speed
      final rotationSpeed = (_random.nextDouble() - 0.5) * 0.15;

      // Random size for rectangles
      final width = 6.0 + _random.nextDouble() * 4.0;
      final height = 10.0 + _random.nextDouble() * 6.0;

      _confetti.add(
        Confetto(
          position: Offset(x, y - (i * 8)), // Stagger vertically
          velocity: Offset(driftSpeed, fallSpeed),
          color: widget.colors[_random.nextInt(widget.colors.length)],
          rotationSpeed: rotationSpeed,
          size: Size(width, height),
        ),
      );
    }
  }

  void _updateConfetti() {
    for (final confetto in _confetti) {
      confetto.update();

      // Wrap around horizontally
      if (confetto.position.dx < -20) {
        confetto.position = Offset(_screenWidth + 10, confetto.position.dy);
      } else if (confetto.position.dx > _screenWidth + 20) {
        confetto.position = Offset(-10, confetto.position.dy);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _ConfettiPainter(
              confetti: _confetti,
              progress: _controller.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<Confetto> confetti;
  final double progress;

  _ConfettiPainter({required this.confetti, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final confetto in confetti) {
      // Skip if off screen
      if (confetto.position.dy < -50 || confetto.isOffScreen(size.height)) {
        continue;
      }

      final paint = Paint()
        ..color = confetto.color.withValues(alpha: confetto.opacity)
        ..style = PaintingStyle.fill;

      canvas.save();

      // Translate to confetto position
      canvas.translate(confetto.position.dx, confetto.position.dy);

      // Rotate around center
      canvas.rotate(confetto.rotation);

      // Draw rectangle
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: confetto.size.width,
        height: confetto.size.height,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

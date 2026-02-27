import 'dart:math';
import 'package:flutter/material.dart';

/// Shape types for confetti pieces
enum ConfettiShape { rectangle, circle, star }

/// A single confetti piece
class Confetto {
  Offset position;
  final Offset velocity;
  final Color color;
  final double rotationSpeed;
  final Size size;
  final ConfettiShape shape;
  double rotation = 0;
  double opacity = 1.0;

  Confetto({
    required this.position,
    required this.velocity,
    required this.color,
    required this.rotationSpeed,
    required this.size,
    required this.shape,
  });

  void update() {
    position = position + velocity;
    rotation += rotationSpeed;
    position = Offset(position.dx + sin(rotation * 0.1) * 0.3, position.dy);
  }

  bool isOffScreen(double screenHeight) => position.dy > screenHeight + 20;
}

/// Custom confetti overlay widget for level win
class ConfettiOverlay extends StatefulWidget {
  final Duration duration;
  final List<Color> colors;
  final int confettiCount;
  final int stars;

  const ConfettiOverlay({
    super.key,
    this.duration = const Duration(seconds: 3),
    required this.colors,
    this.confettiCount = 40,
    this.stars = 1,
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
    // 2x particles for 3-star completions
    final count = widget.stars >= 3
        ? widget.confettiCount * 2
        : widget.confettiCount;
    
    final shapes = ConfettiShape.values;

    for (int i = 0; i < count; i++) {
      final x = _random.nextDouble() * _screenWidth;
      final y = -20.0 - (_random.nextDouble() * 100);
      final fallSpeed = 1.5 + _random.nextDouble() * 1.0;
      final driftSpeed = (_random.nextDouble() - 0.5) * 0.5;
      final rotationSpeed = (_random.nextDouble() - 0.5) * 0.2;
      final width = 6.0 + _random.nextDouble() * 4.0;
      final height = 10.0 + _random.nextDouble() * 6.0;
      final shape = shapes[_random.nextInt(shapes.length)];

      _confetti.add(
        Confetto(
          position: Offset(x, y - (i * 6)),
          velocity: Offset(driftSpeed, fallSpeed),
          color: widget.colors[_random.nextInt(widget.colors.length)],
          rotationSpeed: rotationSpeed,
          size: Size(width, height),
          shape: shape,
        ),
      );
    }
  }

  void _updateConfetti() {
    for (final confetto in _confetti) {
      confetto.update();
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
      if (confetto.position.dy < -50 || confetto.isOffScreen(size.height)) {
        continue;
      }

      final paint = Paint()
        ..color = confetto.color.withValues(alpha: confetto.opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(confetto.position.dx, confetto.position.dy);
      canvas.rotate(confetto.rotation);

      switch (confetto.shape) {
        case ConfettiShape.rectangle:
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: confetto.size.width,
            height: confetto.size.height,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(1)),
            paint,
          );
          break;
        case ConfettiShape.circle:
          canvas.drawCircle(
            Offset.zero,
            confetto.size.width * 0.5,
            paint,
          );
          break;
        case ConfettiShape.star:
          _drawStar(canvas, paint, confetto.size.width * 0.6);
          break;
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double radius) {
    final path = Path();
    const points = 5;
    final innerRadius = radius * 0.4;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : innerRadius;
      final angle = (i * pi / points) - pi / 2;
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
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

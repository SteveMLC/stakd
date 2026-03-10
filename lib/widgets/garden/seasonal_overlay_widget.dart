import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/seasonal_overlay.dart';

/// Renders a lightweight seasonal particle overlay on the zen garden.
/// This is optional eye-candy — it does not affect garden state.
class SeasonalOverlayWidget extends StatelessWidget {
  final Animation<double> animation;

  const SeasonalOverlayWidget({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          painter: _SeasonalPainter(
            type: SeasonalOverlay.current,
            progress: animation.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _SeasonalPainter extends CustomPainter {
  final SeasonalOverlayType type;
  final double progress;

  _SeasonalPainter({required this.type, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(77);
    switch (type) {
      case SeasonalOverlayType.springCherryBlossoms:
        _paintBlossoms(canvas, size, rng);
        break;
      case SeasonalOverlayType.summerFireflyBoost:
        _paintExtraFireflies(canvas, size, rng);
        break;
      case SeasonalOverlayType.autumnLeaves:
        _paintAutumnLeaves(canvas, size, rng);
        break;
      case SeasonalOverlayType.winterFrost:
        _paintFrost(canvas, size, rng);
        break;
    }
  }

  void _paintBlossoms(Canvas canvas, Size size, math.Random rng) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 12; i++) {
      final baseX = rng.nextDouble() * size.width;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final phase = rng.nextDouble() * math.pi * 2;
      final y = ((progress * speed + rng.nextDouble()) % 1.0) * size.height;
      final x = baseX + math.sin(progress * 2 * math.pi + phase) * 20;
      final opacity = 0.3 + rng.nextDouble() * 0.4;
      paint.color = const Color(0xFFFFB7C5).withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), 3 + rng.nextDouble() * 3, paint);
    }
  }

  void _paintExtraFireflies(Canvas canvas, Size size, math.Random rng) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 10; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = size.height * (0.3 + rng.nextDouble() * 0.5);
      final t = progress * 2 * math.pi;
      final x = baseX + math.sin(t + i * 0.7) * 30;
      final y = baseY + math.cos(t + i * 1.1) * 20;
      final pulse = (math.sin(t * 2 + i * 1.5) + 1) / 2;
      final opacity = 0.3 + pulse * 0.5;
      paint.color = const Color(0xFFFFEB3B).withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), 3, paint);
      // glow
      paint.color = const Color(0xFFFFEB3B).withValues(alpha: opacity * 0.3);
      canvas.drawCircle(Offset(x, y), 6 + pulse * 4, paint);
    }
  }

  void _paintAutumnLeaves(Canvas canvas, Size size, math.Random rng) {
    final colors = [
      const Color(0xFFE67E22),
      const Color(0xFFC0392B),
      const Color(0xFFF39C12),
      const Color(0xFFD35400),
    ];
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 10; i++) {
      final baseX = rng.nextDouble() * size.width;
      final speed = 0.2 + rng.nextDouble() * 0.5;
      final y = ((progress * speed + rng.nextDouble()) % 1.0) * size.height;
      final sway = math.sin(progress * 2 * math.pi + i) * 25;
      final x = baseX + sway;
      final opacity = 0.35 + rng.nextDouble() * 0.35;
      paint.color = colors[i % colors.length].withValues(alpha: opacity);
      final leafSize = 4.0 + rng.nextDouble() * 4;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 2 * math.pi * 0.3 + i);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: leafSize, height: leafSize * 1.6),
        paint,
      );
      canvas.restore();
    }
  }

  void _paintFrost(Canvas canvas, Size size, math.Random rng) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 15; i++) {
      final baseX = rng.nextDouble() * size.width;
      final speed = 0.15 + rng.nextDouble() * 0.35;
      final y = ((progress * speed + rng.nextDouble()) % 1.0) * size.height;
      final drift = math.sin(progress * 2 * math.pi + i * 0.5) * 15;
      final x = baseX + drift;
      final opacity = 0.2 + rng.nextDouble() * 0.4;
      paint.color = Colors.white.withValues(alpha: opacity);
      final r = 1.5 + rng.nextDouble() * 2.5;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SeasonalPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.type != type;
}

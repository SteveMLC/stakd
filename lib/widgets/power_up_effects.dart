import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Color Bomb explosion effect
class ColorBombEffect extends StatefulWidget {
  final List<Offset> blockPositions;
  final Color explosionColor;
  final VoidCallback onComplete;

  const ColorBombEffect({
    super.key,
    required this.blockPositions,
    required this.explosionColor,
    required this.onComplete,
  });

  @override
  State<ColorBombEffect> createState() => _ColorBombEffectState();
}

class _ColorBombEffectState extends State<ColorBombEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _explosion;
  late Animation<double> _fade;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _explosion = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _fade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    // Generate particles for each block position
    final random = math.Random();
    for (final pos in widget.blockPositions) {
      for (int i = 0; i < 8; i++) {
        _particles.add(_Particle(
          center: pos,
          angle: (i * math.pi / 4) + random.nextDouble() * 0.5,
          speed: 50 + random.nextDouble() * 100,
          size: 4 + random.nextDouble() * 6,
        ));
      }
    }

    _controller.forward().then((_) => widget.onComplete());
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
          painter: _ColorBombPainter(
            particles: _particles,
            color: widget.explosionColor,
            progress: _explosion.value,
            opacity: _fade.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  final Offset center;
  final double angle;
  final double speed;
  final double size;

  _Particle({
    required this.center,
    required this.angle,
    required this.speed,
    required this.size,
  });

  Offset getPosition(double progress) {
    final distance = speed * progress;
    return Offset(
      center.dx + math.cos(angle) * distance,
      center.dy + math.sin(angle) * distance,
    );
  }
}

class _ColorBombPainter extends CustomPainter {
  final List<_Particle> particles;
  final Color color;
  final double progress;
  final double opacity;

  _ColorBombPainter({
    required this.particles,
    required this.color,
    required this.progress,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    for (final particle in particles) {
      final pos = particle.getPosition(progress);
      final particleSize = particle.size * (1 - progress * 0.5);
      
      // Draw glow
      canvas.drawCircle(pos, particleSize * 1.5, glowPaint);
      // Draw particle
      canvas.drawCircle(pos, particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(_ColorBombPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
  }
}

/// Shuffle effect - blocks fly up, swirl, and land
class ShuffleEffect extends StatefulWidget {
  final List<Offset> blockPositions;
  final List<Color> blockColors;
  final VoidCallback onComplete;

  const ShuffleEffect({
    super.key,
    required this.blockPositions,
    required this.blockColors,
    required this.onComplete,
  });

  @override
  State<ShuffleEffect> createState() => _ShuffleEffectState();
}

class _ShuffleEffectState extends State<ShuffleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rise;
  late Animation<double> _swirl;
  late Animation<double> _fall;
  final List<_ShuffleBlock> _blocks = [];

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _rise = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );

    _swirl = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.7, curve: Curves.easeInOut),
    );

    _fall = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.bounceOut),
    );

    // Create shuffling blocks
    final random = math.Random();
    for (int i = 0; i < widget.blockPositions.length && i < widget.blockColors.length; i++) {
      _blocks.add(_ShuffleBlock(
        startPos: widget.blockPositions[i],
        color: widget.blockColors[i],
        riseOffset: -150 - random.nextDouble() * 100,
        swirlRadius: 30 + random.nextDouble() * 40,
        swirlAngle: random.nextDouble() * math.pi * 2,
      ));
    }

    _controller.forward().then((_) => widget.onComplete());
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
          painter: _ShufflePainter(
            blocks: _blocks,
            riseProgress: _rise.value,
            swirlProgress: _swirl.value,
            fallProgress: _fall.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ShuffleBlock {
  final Offset startPos;
  final Color color;
  final double riseOffset;
  final double swirlRadius;
  final double swirlAngle;

  _ShuffleBlock({
    required this.startPos,
    required this.color,
    required this.riseOffset,
    required this.swirlRadius,
    required this.swirlAngle,
  });

  Offset getPosition(double rise, double swirl, double fall) {
    // Rise phase
    final riseY = startPos.dy + riseOffset * rise;
    
    // Swirl phase
    final swirlX = startPos.dx + math.cos(swirlAngle + swirl * math.pi * 2) * swirlRadius * swirl;
    final swirlY = riseY + math.sin(swirlAngle + swirl * math.pi * 2) * swirlRadius * 0.5 * swirl;
    
    // Fall phase (return to start with some randomization)
    final fallY = swirlY - riseOffset * rise * fall;
    
    return Offset(swirlX, fallY);
  }
}

class _ShufflePainter extends CustomPainter {
  final List<_ShuffleBlock> blocks;
  final double riseProgress;
  final double swirlProgress;
  final double fallProgress;

  _ShufflePainter({
    required this.blocks,
    required this.riseProgress,
    required this.swirlProgress,
    required this.fallProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final block in blocks) {
      final pos = block.getPosition(riseProgress, swirlProgress, fallProgress);
      
      final paint = Paint()
        ..color = block.color
        ..style = PaintingStyle.fill;

      final shadowPaint = Paint()
        ..color = block.color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      // Draw shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: pos, width: 50, height: 35),
          const Radius.circular(6),
        ),
        shadowPaint,
      );

      // Draw block
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: pos, width: 50, height: 35),
          const Radius.circular(6),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ShufflePainter oldDelegate) {
    return oldDelegate.riseProgress != riseProgress ||
           oldDelegate.swirlProgress != swirlProgress ||
           oldDelegate.fallProgress != fallProgress;
  }
}

/// Magnet pull effect - draws magnetic field lines and pulls block
class MagnetEffect extends StatefulWidget {
  final Offset sourcePos;
  final Offset targetPos;
  final Color blockColor;
  final VoidCallback onComplete;

  const MagnetEffect({
    super.key,
    required this.sourcePos,
    required this.targetPos,
    required this.blockColor,
    required this.onComplete,
  });

  @override
  State<MagnetEffect> createState() => _MagnetEffectState();
}

class _MagnetEffectState extends State<MagnetEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pull;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pull = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInQuart,
    );

    _fade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward().then((_) => widget.onComplete());
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
        final currentPos = Offset.lerp(
          widget.sourcePos,
          widget.targetPos,
          _pull.value,
        )!;

        return CustomPaint(
          painter: _MagnetPainter(
            sourcePos: widget.sourcePos,
            targetPos: widget.targetPos,
            currentPos: currentPos,
            blockColor: widget.blockColor,
            progress: _pull.value,
            opacity: _fade.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _MagnetPainter extends CustomPainter {
  final Offset sourcePos;
  final Offset targetPos;
  final Offset currentPos;
  final Color blockColor;
  final double progress;
  final double opacity;

  _MagnetPainter({
    required this.sourcePos,
    required this.targetPos,
    required this.currentPos,
    required this.blockColor,
    required this.progress,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw magnetic field lines
    final linePaint = Paint()
      ..color = GameColors.zen.withValues(alpha: 0.4 * opacity * (1 - progress))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 5; i++) {
      final offset = (i - 2) * 15.0;
      final path = Path();
      path.moveTo(sourcePos.dx + offset, sourcePos.dy);
      path.quadraticBezierTo(
        (sourcePos.dx + targetPos.dx) / 2 + offset,
        (sourcePos.dy + targetPos.dy) / 2 - 30,
        targetPos.dx + offset,
        targetPos.dy,
      );
      canvas.drawPath(path, linePaint);
    }

    // Draw moving block
    final blockPaint = Paint()
      ..color = blockColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = GameColors.zen.withValues(alpha: 0.5 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    // Draw glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: currentPos, width: 55, height: 40),
        const Radius.circular(8),
      ),
      glowPaint,
    );

    // Draw block
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: currentPos, width: 50, height: 35),
        const Radius.circular(6),
      ),
      blockPaint,
    );
  }

  @override
  bool shouldRepaint(_MagnetPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
  }
}

/// Enhanced hint effect with animated arrow
class EnhancedHintEffect extends StatefulWidget {
  final Offset sourcePos;
  final Offset destPos;
  final VoidCallback onComplete;
  final Duration duration;

  const EnhancedHintEffect({
    super.key,
    required this.sourcePos,
    required this.destPos,
    required this.onComplete,
    this.duration = const Duration(seconds: 5),
  });

  @override
  State<EnhancedHintEffect> createState() => _EnhancedHintEffectState();
}

class _EnhancedHintEffectState extends State<EnhancedHintEffect>
    with TickerProviderStateMixin {
  late AnimationController _drawController;
  late AnimationController _pulseController;
  late Animation<double> _draw;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    
    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _draw = CurvedAnimation(
      parent: _drawController,
      curve: Curves.easeInOut,
    );

    _pulse = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _drawController.forward().then((_) {
      _pulseController.repeat(reverse: true);
    });

    // Auto-dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _drawController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onComplete,
      behavior: HitTestBehavior.translucent,
      child: AnimatedBuilder(
        animation: Listenable.merge([_drawController, _pulseController]),
        builder: (context, child) {
          return CustomPaint(
            painter: _EnhancedHintPainter(
              sourcePos: widget.sourcePos,
              destPos: widget.destPos,
              drawProgress: _draw.value,
              pulseScale: _pulseController.isAnimating ? _pulse.value : 1.0,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _EnhancedHintPainter extends CustomPainter {
  final Offset sourcePos;
  final Offset destPos;
  final double drawProgress;
  final double pulseScale;

  _EnhancedHintPainter({
    required this.sourcePos,
    required this.destPos,
    required this.drawProgress,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw pulsing glow on source
    _drawPulsingGlow(canvas, sourcePos, GameColors.accent);
    
    // Draw pulsing glow on destination
    _drawPulsingGlow(canvas, destPos, GameColors.successGlow);

    // Draw animated arrow path
    if (drawProgress > 0) {
      _drawArrowPath(canvas);
    }
  }

  void _drawPulsingGlow(Canvas canvas, Offset pos, Color color) {
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * pulseScale);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: pos,
          width: GameSizes.stackWidth * pulseScale,
          height: GameSizes.stackHeight * 0.3 * pulseScale,
        ),
        Radius.circular(8 * pulseScale),
      ),
      glowPaint,
    );
  }

  void _drawArrowPath(Canvas canvas) {
    // Calculate arc
    final midX = (sourcePos.dx + destPos.dx) / 2;
    final midY = (sourcePos.dy + destPos.dy) / 2;
    final dx = destPos.dx - sourcePos.dx;
    final dy = destPos.dy - sourcePos.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    
    final arcHeight = (length * 0.25).clamp(50.0, 100.0);
    final perpX = -dy / length;
    final perpY = dx / length;
    final controlPoint = Offset(
      midX + perpX * arcHeight,
      midY + perpY * arcHeight,
    );

    final path = Path();
    path.moveTo(sourcePos.dx, sourcePos.dy);
    path.quadraticBezierTo(
      controlPoint.dx,
      controlPoint.dy,
      destPos.dx,
      destPos.dy,
    );

    // Extract partial path
    final pathMetric = path.computeMetrics().first;
    final partialPath = pathMetric.extractPath(0, pathMetric.length * drawProgress);

    // Draw glow
    final glowPaint = Paint()
      ..color = GameColors.accent.withValues(alpha: 0.4)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(partialPath, glowPaint);

    // Draw main line
    final linePaint = Paint()
      ..color = GameColors.accent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(partialPath, linePaint);

    // Draw arrowhead
    if (drawProgress > 0.8) {
      _drawArrowhead(canvas, linePaint);
    }
  }

  void _drawArrowhead(Canvas canvas, Paint paint) {
    final dx = destPos.dx - sourcePos.dx;
    final dy = destPos.dy - sourcePos.dy;
    final angle = math.atan2(dy, dx);
    final arrowLength = 20.0;

    final left = Offset(
      destPos.dx - arrowLength * math.cos(angle - math.pi / 6),
      destPos.dy - arrowLength * math.sin(angle - math.pi / 6),
    );
    final right = Offset(
      destPos.dx - arrowLength * math.cos(angle + math.pi / 6),
      destPos.dy - arrowLength * math.sin(angle + math.pi / 6),
    );

    final arrowPaint = Paint()
      ..color = GameColors.accent
      ..style = PaintingStyle.fill;

    final arrowPath = Path()
      ..moveTo(destPos.dx, destPos.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(_EnhancedHintPainter oldDelegate) {
    return oldDelegate.drawProgress != drawProgress ||
           oldDelegate.pulseScale != pulseScale;
  }
}

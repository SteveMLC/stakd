import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Animated hint overlay showing an arrow from source to destination stack
class HintOverlay extends StatefulWidget {
  final int sourceIndex;
  final int destIndex;
  final GlobalKey sourceKey;
  final GlobalKey destKey;
  final VoidCallback onDismiss;

  const HintOverlay({
    super.key,
    required this.sourceIndex,
    required this.destIndex,
    required this.sourceKey,
    required this.destKey,
    required this.onDismiss,
  });

  @override
  State<HintOverlay> createState() => _HintOverlayState();
}

class _HintOverlayState extends State<HintOverlay>
    with TickerProviderStateMixin {
  late AnimationController _arrowController;
  late AnimationController _glowController;
  late Animation<double> _drawProgress;
  late Animation<double> _glowPulse;

  Offset _startPos = Offset.zero;
  Offset _endPos = Offset.zero;
  double _arcHeight = 60.0;
  bool _positionsCalculated = false;

  @override
  void initState() {
    super.initState();

    // Arrow drawing animation (progressive draw)
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _drawProgress = CurvedAnimation(
      parent: _arrowController,
      curve: Curves.easeInOut,
    );

    // Glow pulse animation (2 cycles per second)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _glowPulse = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Calculate positions and start animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculatePositions();
      _arrowController.forward();

      // Auto-dismiss after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          widget.onDismiss();
        }
      });
    });
  }

  void _calculatePositions() {
    final fromBox =
        widget.sourceKey.currentContext?.findRenderObject() as RenderBox?;
    final toBox =
        widget.destKey.currentContext?.findRenderObject() as RenderBox?;

    if (fromBox == null || toBox == null) {
      widget.onDismiss();
      return;
    }

    // Get global positions - center of each stack
    final fromGlobal = fromBox.localToGlobal(Offset.zero);
    final toGlobal = toBox.localToGlobal(Offset.zero);

    final fromCenter = Offset(
      fromGlobal.dx + GameSizes.stackWidth / 2,
      fromGlobal.dy + GameSizes.stackHeight / 2,
    );

    final toCenter = Offset(
      toGlobal.dx + GameSizes.stackWidth / 2,
      toGlobal.dy + GameSizes.stackHeight / 2,
    );

    setState(() {
      _startPos = fromCenter;
      _endPos = toCenter;

      // Arc height based on distance
      final distance = (_endPos - _startPos).distance;
      _arcHeight = (distance * 0.25).clamp(50.0, 100.0);
      _positionsCalculated = true;
    });
  }

  @override
  void dispose() {
    _arrowController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_positionsCalculated) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.onDismiss,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // Pulsing glow on source stack
          _buildStackGlow(widget.sourceKey),

          // Pulsing glow on destination stack
          _buildStackGlow(widget.destKey),

          // Animated arrow
          AnimatedBuilder(
            animation: _arrowController,
            builder: (context, child) {
              return CustomPaint(
                painter: _HintArrowPainter(
                  startPos: _startPos,
                  endPos: _endPos,
                  arcHeight: _arcHeight,
                  progress: _drawProgress.value,
                  color: GameColors.accent,
                ),
                size: Size.infinite,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStackGlow(GlobalKey stackKey) {
    final box = stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return const SizedBox.shrink();

    final pos = box.localToGlobal(Offset.zero);

    return AnimatedBuilder(
      animation: _glowPulse,
      builder: (context, child) {
        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: IgnorePointer(
            child: Container(
              width: GameSizes.stackWidth,
              height: GameSizes.stackHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  GameSizes.stackBorderRadius,
                ),
                boxShadow: [
                  BoxShadow(
                    color: GameColors.accent.withValues(
                      alpha: 0.5 * _glowPulse.value,
                    ),
                    blurRadius: 20 * _glowPulse.value,
                    spreadRadius: 4 * _glowPulse.value,
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

/// Custom painter for the animated hint arrow
class _HintArrowPainter extends CustomPainter {
  final Offset startPos;
  final Offset endPos;
  final double arcHeight;
  final double progress;
  final Color color;

  _HintArrowPainter({
    required this.startPos,
    required this.endPos,
    required this.arcHeight,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Shadow paint for glow effect
    final shadowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Create path for the arc
    final path = _createArcPath();

    // Measure the path to draw partial progress
    final pathMetric = path.computeMetrics().first;
    final partialPath = pathMetric.extractPath(0, pathMetric.length * progress);

    // Draw shadow/glow
    canvas.drawPath(partialPath, shadowPaint);

    // Draw main arrow path
    canvas.drawPath(partialPath, paint);

    // Draw arrowhead at the end (only when fully drawn)
    if (progress > 0.8) {
      final arrowheadProgress = ((progress - 0.8) / 0.2).clamp(0.0, 1.0);
      _drawArrowhead(canvas, paint, arrowheadProgress);
    }
  }

  Path _createArcPath() {
    final path = Path();
    path.moveTo(startPos.dx, startPos.dy);

    // Calculate control point for quadratic bezier (arc)
    final midX = (startPos.dx + endPos.dx) / 2;
    final midY = (startPos.dy + endPos.dy) / 2;

    // Offset the control point perpendicular to the line
    final dx = endPos.dx - startPos.dx;
    final dy = endPos.dy - startPos.dy;
    final length = math.sqrt(dx * dx + dy * dy);

    if (length > 0) {
      // Perpendicular vector (rotated 90 degrees)
      final perpX = -dy / length;
      final perpY = dx / length;

      final controlPoint = Offset(
        midX + perpX * arcHeight,
        midY + perpY * arcHeight,
      );

      path.quadraticBezierTo(
        controlPoint.dx,
        controlPoint.dy,
        endPos.dx,
        endPos.dy,
      );
    } else {
      path.lineTo(endPos.dx, endPos.dy);
    }

    return path;
  }

  void _drawArrowhead(Canvas canvas, Paint paint, double progress) {
    // Calculate direction at the end of the path
    final dx = endPos.dx - startPos.dx;
    final dy = endPos.dy - startPos.dy;
    final angle = math.atan2(dy, dx);

    // Arrowhead dimensions
    final arrowLength = 20.0 * progress;

    // Calculate arrowhead points
    final tip = endPos;
    final left = Offset(
      tip.dx - arrowLength * math.cos(angle - math.pi / 6),
      tip.dy - arrowLength * math.sin(angle - math.pi / 6),
    );
    final right = Offset(
      tip.dx - arrowLength * math.cos(angle + math.pi / 6),
      tip.dy - arrowLength * math.sin(angle + math.pi / 6),
    );

    // Draw filled arrowhead
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final arrowPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    // Draw shadow
    final arrowShadow = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawPath(arrowPath, arrowShadow);
    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(_HintArrowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.startPos != startPos ||
        oldDelegate.endPos != endPos;
  }
}

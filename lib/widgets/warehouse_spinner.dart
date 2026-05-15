import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/crate_assets.dart';

/// Warehouse-themed loading spinner — replaces the stock Material
/// `CircularProgressIndicator` used at leaderboard / daily challenge
/// / IAP-loading gates. Rotates through the 8 color-crate decals
/// (one frame each, ~120ms per frame) so the loading moment feels
/// like "crates being inventoried" rather than "Material loading."
///
/// API mirrors `CircularProgressIndicator` enough to be a drop-in:
///
///     // Was:
///     CircularProgressIndicator(color: GameColors.accent)
///     // Now:
///     const WarehouseSpinner()
class WarehouseSpinner extends StatefulWidget {
  /// Outer diameter in dp. The crate art is rendered inside a square
  /// of this size with a small accent ring orbiting it.
  final double size;

  /// Override the orbit ring's tint. Defaults to accent yellow.
  final Color? color;

  const WarehouseSpinner({super.key, this.size = 56, this.color});

  @override
  State<WarehouseSpinner> createState() => _WarehouseSpinnerState();
}

class _WarehouseSpinnerState extends State<WarehouseSpinner>
    with TickerProviderStateMixin {
  late final AnimationController _frameController;
  late final AnimationController _ringController;

  static const int _frameCount = 8;

  @override
  void initState() {
    super.initState();
    _frameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 960), // 120ms × 8 frames
    )..repeat();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _frameController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? GameColors.accent;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating accent ring (the "spinner" element).
          AnimatedBuilder(
            animation: _ringController,
            builder: (context, _) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RingPainter(
                  progress: _ringController.value,
                  color: color,
                ),
              );
            },
          ),
          // Crate-frame cycler (the warehouse vocabulary).
          AnimatedBuilder(
            animation: _frameController,
            builder: (context, _) {
              final frame = (_frameController.value * _frameCount).floor() %
                  _frameCount;
              return Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  CrateAssets.assetForColorIndex(frame),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final radius = size.width / 2 - 1.5;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    // 240° arc rotating around the center
    const sweep = 4.0; // ~230° in radians
    final start = progress * 6.283; // 2π
    canvas.drawArc(rect, start, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

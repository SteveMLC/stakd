import 'package:flutter/material.dart';
import '../models/layer_model.dart';
import '../utils/constants.dart';
import '../utils/theme_colors.dart';
import '../services/storage_service.dart';

/// Calculates optimal stacks per row given total stacks and available width.
int getStacksPerRow(int total, double maxWidth) {
  final stackWidth = GameSizes.stackWidth + GameSizes.stackSpacing;
  final maxFit = (maxWidth / stackWidth).floor();

  if (total <= 4) return total;
  if (total <= 6) return 3;
  if (total <= 9) return 5;
  return maxFit.clamp(4, 6);
}

/// Returns the flash color for a given chain level.
Color getChainFlashColor(int chainLevel) {
  switch (chainLevel) {
    case 2:
      return const Color(0xFFFFD700);
    case 3:
      return const Color(0xFFFF8C00);
    case 4:
      return const Color(0xFFFF4500);
    default:
      if (chainLevel >= 5) {
        return const Color(0xFF9400D3);
      }
      return ThemeColors.accentColor;
  }
}

/// Builds the layer widgets inside a stack (the colored blocks).
Widget buildStackLayers({
  required List<Layer> layers,
  required bool isMultiGrabActive,
  required int topGroupSize,
  required double multiGrabPulse,
}) {
  if (layers.isEmpty) {
    return const SizedBox.expand();
  }

  return Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: layers.asMap().entries.toList().reversed.map<Widget>((entry) {
      final index = entry.key;
      final layer = entry.value;
      final gradientColors = ThemeColors.getGradient(layer.colorIndex);

      final isInGrabZone = isMultiGrabActive && index >= layers.length - topGroupSize;

      final grabZoneDecoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(4),
        border: isInGrabZone
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.6 + multiGrabPulse * 0.4),
                width: 2,
              )
            : null,
        boxShadow: isInGrabZone
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.3 + multiGrabPulse * 0.2),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      );

      return Transform.translate(
        offset: isInGrabZone ? Offset(0, -2.0 * multiGrabPulse) : Offset.zero,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: GameSizes.layerHeight,
          margin: const EdgeInsets.only(bottom: 2),
          decoration: grabZoneDecoration,
          child: Stack(
            children: [
              Positioned(
                top: 2,
                left: 4,
                right: 4,
                height: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Positioned(
                bottom: 1,
                left: 3,
                right: 3,
                height: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (GameColors.isUltraMode || StorageService().getColorblindMode())
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CustomPaint(
                      painter: ColorblindPatternPainter(patternIndex: layer.colorIndex),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList(),
  );
}

/// Colorblind pattern painter for game board blocks
class ColorblindPatternPainter extends CustomPainter {
  final int patternIndex;

  const ColorblindPatternPainter({required this.patternIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    switch (patternIndex % 6) {
      case 0:
        const spacing = 5.0;
        for (double y = spacing / 2; y < size.height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        break;
      case 1:
        const spacing = 7.0;
        for (double i = -size.height; i < size.width + size.height; i += spacing) {
          canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
        }
        break;
      case 2:
        final dotPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.fill;
        const spacing = 7.0;
        for (double x = spacing / 2; x < size.width; x += spacing) {
          for (double y = spacing / 2; y < size.height; y += spacing) {
            canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
          }
        }
        break;
      case 3:
        const spacing = 7.0;
        for (double i = -size.height; i < size.width + size.height; i += spacing) {
          canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
          canvas.drawLine(Offset(i, size.height), Offset(i + size.height, 0), paint);
        }
        break;
      case 4:
        const spacing = 9.0;
        for (double x = spacing / 2; x < size.width; x += spacing) {
          for (double y = spacing / 2; y < size.height; y += spacing) {
            canvas.drawCircle(Offset(x, y), 3, paint);
          }
        }
        break;
      case 5:
        const spacing = 9.0;
        const half = spacing / 2;
        for (double x = 0; x < size.width + spacing; x += spacing) {
          for (double y = 0; y < size.height + spacing; y += spacing) {
            final path = Path()
              ..moveTo(x, y - half)
              ..lineTo(x + half, y)
              ..lineTo(x, y + half)
              ..lineTo(x - half, y)
              ..close();
            canvas.drawPath(path, paint);
          }
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant ColorblindPatternPainter oldDelegate) {
    return oldDelegate.patternIndex != patternIndex;
  }
}

/// Custom painter for dashed border on dragged blocks
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;

  const DashedBorderPainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.dashLength = 8.0,
    this.gapLength = 4.0,
    this.borderRadius = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2,
                     size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final pathMetrics = path.computeMetrics();

    for (final metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double length = dashLength.clamp(0, metric.length - distance);
        canvas.drawPath(
          metric.extractPath(distance, distance + length),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
           oldDelegate.strokeWidth != strokeWidth ||
           oldDelegate.dashLength != dashLength ||
           oldDelegate.gapLength != gapLength;
  }
}

import 'package:flutter/material.dart';
import '../models/layer_model.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/theme_colors.dart';

/// Displays a single colored layer
class LayerWidget extends StatelessWidget {
  final Layer layer;
  final bool isTop;
  final double width;
  final double height;
  final bool glowEffect;

  const LayerWidget({
    super.key,
    required this.layer,
    this.isTop = false,
    this.width = GameSizes.stackWidth - 8,
    this.height = GameSizes.layerHeight,
    this.glowEffect = false,
  });

  @override
  Widget build(BuildContext context) {
    // Choose gradient/colors based on block type (use theme-aware colors)
    final gradientColors = ThemeColors.getGradient(layer.colorIndex);
    
    // Apply frost effect to locked or frozen blocks
    final isLocked = layer.isLocked;
    final isFrozen = layer.isFrozen;
    final shadowColor = isLocked 
        ? Colors.blue.withValues(alpha: 0.3) 
        : isFrozen
        ? const Color(0xFF0288D1).withValues(alpha: 0.3)
        : gradientColors.last;
    
    // Check if theme has block glow enabled
    final useGlow = glowEffect || ThemeColors.hasBlockGlow;
    
    // Enhanced shadow with glow effect
    final shadows = useGlow ? [
      BoxShadow(
        color: shadowColor.withValues(alpha: 0.7),
        blurRadius: 12,
        spreadRadius: 2,
        offset: const Offset(0, 2),
      ),
      BoxShadow(
        color: shadowColor.withValues(alpha: 0.4),
        blurRadius: 20,
        spreadRadius: 4,
      ),
    ] : [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ];
    
    // Check if gradients are enabled
    final useGradient = StorageService().getGradientBlocks();
    final blockGradient = useGradient ? _buildBlockGradient() : null;
    final blockColor = useGradient ? null : _getFlatColor();
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: blockColor,
        gradient: blockGradient,
        borderRadius: BorderRadius.circular(ThemeColors.blockBorderRadius),
        boxShadow: shadows,
      ),
      child: Stack(
        children: [
          // Subtle bevel highlight
          Positioned(
            top: 3,
            left: 6,
            right: 6,
            height: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: glowEffect ? 0.35 : 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Bottom shadow line for depth
          Positioned(
            bottom: 2,
            left: 4,
            right: 4,
            height: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Soft sheen overlay
          Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GameSizes.stackBorderRadius - 2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: glowEffect ? 0.35 : 0.25),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.12),
                ],
              ),
            ),
          ),
          // Locked block frost overlay
          if (isLocked)
            Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GameSizes.stackBorderRadius - 2),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.4),
                    Colors.blue.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          // Pattern overlay on blocks (enabled by default, toggled in settings)
          if ((StorageService().getTextureSkinsEnabled() || StorageService().getColorblindMode()) && !isLocked)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ThemeColors.blockBorderRadius),
                child: CustomPaint(
                  painter: _BlockPatternPainter(
                    patternIndex: layer.colorIndex,
                  ),
                ),
              ),
            ),
          // Lock icon and counter overlay
          if (isLocked)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${layer.lockedUntil}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Frozen block ice overlay
          if (isFrozen)
            Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GameSizes.stackBorderRadius - 2),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x660288D1),
                    Color(0x4481D4FA),
                    Color(0x660288D1),
                  ],
                ),
              ),
            ),
          // Frozen block ice crystal lines + snowflake icon
          if (isFrozen)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(GameSizes.stackBorderRadius - 2),
                child: CustomPaint(
                  painter: _IceCrystalPainter(),
                ),
              ),
            ),
          if (isFrozen)
            const Center(
              child: Icon(
                Icons.ac_unit,
                color: Colors.white,
                size: 14,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
        ],
      ),
    );
  }

  /// Build the appropriate gradient based on block type
  Gradient _buildBlockGradient() {
    // Multi-color block: diagonal stripes
    if (layer.isMultiColor) {
      final colors = layer.allColors;
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _expandColorsForStripes(colors),
        stops: _createStripeStops(colors.length),
      );
    }
    
    // Standard or locked block: vertical gradient (use theme-aware colors)
    final gradientColors = ThemeColors.getGradient(layer.colorIndex);
    
    // Apply desaturation to locked blocks
    if (layer.isLocked) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: gradientColors.map((c) => _desaturate(c, 0.5)).toList(),
      );
    }

    // Slightly darken frozen blocks
    if (layer.isFrozen) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: gradientColors.map((c) => _desaturate(c, 0.2)).toList(),
      );
    }
    
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: gradientColors,
    );
  }

  /// Expand colors for smooth diagonal stripes
  List<Color> _expandColorsForStripes(List<Color> colors) {
    if (colors.length == 2) {
      return [
        colors[0],
        colors[0],
        colors[1],
        colors[1],
      ];
    } else if (colors.length == 3) {
      return [
        colors[0],
        colors[0],
        colors[1],
        colors[1],
        colors[2],
        colors[2],
      ];
    }
    return colors;
  }

  /// Create gradient stops for stripe effect
  List<double> _createStripeStops(int colorCount) {
    if (colorCount == 2) {
      return [0.0, 0.45, 0.55, 1.0];
    } else if (colorCount == 3) {
      return [0.0, 0.3, 0.35, 0.65, 0.7, 1.0];
    }
    return [0.0, 1.0];
  }

  /// Desaturate a color by a given amount (0.0 = no change, 1.0 = grayscale)
  Color _desaturate(Color color, double amount) {
    final hslColor = HSLColor.fromColor(color);
    final desaturated = hslColor.withSaturation(
      (hslColor.saturation * (1 - amount)).clamp(0.0, 1.0),
    );
    return desaturated.toColor();
  }

  /// Get flat color for non-gradient blocks
  Color _getFlatColor() {
    // Multi-color blocks: use first color
    if (layer.isMultiColor) {
      final colors = layer.allColors;
      return colors.isNotEmpty ? colors[0] : ThemeColors.getGradient(layer.colorIndex)[1];
    }
    
    // Use the middle color from the gradient (main color)
    final gradientColors = ThemeColors.getGradient(layer.colorIndex);
    Color baseColor = gradientColors[1]; // Middle color
    
    // Apply desaturation to locked blocks
    if (layer.isLocked) {
      return _desaturate(baseColor, 0.5);
    }

    // Slightly darken frozen blocks
    if (layer.isFrozen) {
      return _desaturate(baseColor, 0.2);
    }
    
    return baseColor;
  }
}

/// Animated layer that can move between stacks
class AnimatedLayerWidget extends StatelessWidget {
  final Layer layer;
  final bool isMoving;
  final Offset offset;
  final VoidCallback? onMoveComplete;

  const AnimatedLayerWidget({
    super.key,
    required this.layer,
    this.isMoving = false,
    this.offset = Offset.zero,
    this.onMoveComplete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: GameDurations.layerMove,
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(offset.dx, offset.dy, 0),
      onEnd: onMoveComplete,
      child: LayerWidget(layer: layer),
    );
  }
}

/// Paints ice crystal lines on frozen blocks
class _IceCrystalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Angular ice crystal lines
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Line 1: diagonal top-left
    canvas.drawLine(Offset(cx - 12, cy - 8), Offset(cx - 4, cy - 2), paint);
    // Line 2: diagonal top-right
    canvas.drawLine(Offset(cx + 12, cy - 8), Offset(cx + 4, cy - 2), paint);
    // Line 3: diagonal bottom-left
    canvas.drawLine(Offset(cx - 10, cy + 6), Offset(cx - 3, cy + 1), paint);
    // Line 4: diagonal bottom-right
    canvas.drawLine(Offset(cx + 10, cy + 6), Offset(cx + 3, cy + 1), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints subtle pattern overlays on blocks for colorblind accessibility.
/// Each color index gets a unique pattern so blocks are distinguishable
/// even without color perception.
class _BlockPatternPainter extends CustomPainter {
  final int patternIndex;

  const _BlockPatternPainter({required this.patternIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    switch (patternIndex % 8) {
      case 0: // Diagonal stripes (top-left to bottom-right)
        _drawDiagonalStripes(canvas, size, paint, 1);
        break;
      case 1: // Dots
        _drawDots(canvas, size, paint);
        break;
      case 2: // Crosshatch
        _drawCrosshatch(canvas, size, paint);
        break;
      case 3: // Horizontal stripes
        _drawHorizontalStripes(canvas, size, paint);
        break;
      case 4: // Diagonal stripes (top-right to bottom-left)
        _drawDiagonalStripes(canvas, size, paint, -1);
        break;
      case 5: // Small circles
        _drawSmallCircles(canvas, size, paint);
        break;
      case 6: // Vertical stripes
        _drawVerticalStripes(canvas, size, paint);
        break;
      case 7: // Diamond pattern
        _drawDiamonds(canvas, size, paint);
        break;
    }
  }

  void _drawDiagonalStripes(Canvas canvas, Size size, Paint paint, int dir) {
    const spacing = 8.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, dir == 1 ? 0 : size.height),
        Offset(i + size.height * dir, dir == 1 ? size.height : 0),
        paint,
      );
    }
  }

  void _drawDots(Canvas canvas, Size size, Paint paint) {
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    const spacing = 8.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  void _drawCrosshatch(Canvas canvas, Size size, Paint paint) {
    const spacing = 8.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
      canvas.drawLine(Offset(i, size.height), Offset(i + size.height, 0), paint);
    }
  }

  void _drawHorizontalStripes(Canvas canvas, Size size, Paint paint) {
    const spacing = 6.0;
    for (double y = spacing / 2; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawSmallCircles(Canvas canvas, Size size, Paint paint) {
    const spacing = 10.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 3, paint);
      }
    }
  }

  void _drawVerticalStripes(Canvas canvas, Size size, Paint paint) {
    const spacing = 6.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  void _drawDiamonds(Canvas canvas, Size size, Paint paint) {
    const spacing = 10.0;
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
  }

  @override
  bool shouldRepaint(covariant _BlockPatternPainter oldDelegate) {
    return oldDelegate.patternIndex != patternIndex;
  }
}

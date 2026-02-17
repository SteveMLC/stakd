import 'package:flutter/material.dart';
import '../models/layer_model.dart';
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
    
    // Apply frost effect to locked blocks
    final isLocked = layer.isLocked;
    final shadowColor = isLocked 
        ? Colors.blue.withValues(alpha: 0.3) 
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
        color: shadowColor.withValues(alpha: 0.45),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: _buildBlockGradient(),
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

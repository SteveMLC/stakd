import 'package:flutter/material.dart';
import '../models/layer_model.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/theme_colors.dart';
// `warehouse_decorations.dart` import dropped 2026-05-15 with the
// per-layer HazardStripe / CorrugatedCardboardPainter removal — clean
// standalone crates now, no per-layer noise.

/// Displays a single colored layer
class LayerWidget extends StatelessWidget {
  final Layer layer;
  final bool isTop;
  final double width;
  final double height;
  final bool glowEffect;

  /// Optional custom "active face" art for the topmost layer of a stack.
  /// When non-null AND `isTop` is true AND the layer is not in a modifier
  /// state (locked/frozen), the procedural cardboard/tape/stamp/plank
  /// painters are suppressed and this asset is overlaid as the visual
  /// identity of the layer — typically the matching color crate from
  /// `CrateAssets.assetForColorIndex(layer.colorIndex)`.
  ///
  /// Underlying layers stay procedural so the stack still reads as a
  /// pile of color rectangles; only the "active face" gets the burst-
  /// of-cargo illustration.
  final String? topFaceAsset;

  const LayerWidget({
    super.key,
    required this.layer,
    this.isTop = false,
    this.width = GameSizes.stackWidth - 8,
    this.height = GameSizes.layerHeight,
    this.glowEffect = false,
    this.topFaceAsset,
  });

  /// True when the topmost-layer "active face" rendering path is active.
  /// Gates the procedural cardboard/tape/stamp/edge-plank painters so
  /// only one visual identity wins.
  bool get _showCrateFace =>
      isTop &&
      topFaceAsset != null &&
      !layer.isLocked &&
      !layer.isFrozen;

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
          // 2026-05-15: Removed the per-layer procedural detail stack
          // (corrugated cardboard texture + yellow hazard tape strip +
          // center tape + shipping stamp + edge planks). Each crate is
          // now a CLEAN standalone object — the color-crate decal IS
          // the identity. Block-type styling (frozen/locked) still
          // overlays below; the noise floor that was competing with
          // every decal is gone.
          //
          // The CorrugatedCardboardPainter + ShippingStampPainter +
          // edge-plank Positioneds lived here in commits prior to
          // f9eabeb. If you need them back as an opt-in modifier
          // (e.g. "cardboard skin" cosmetic), git blame this comment.
          if (!isLocked && !isFrozen) ...[
            // intentional no-op placeholder — keeps the conditional
            // shape so future modifier overlays slot in here cleanly.
            const SizedBox.shrink(),
          ],
          // Topmost layer's "active-face" decal — illustrated color
          // crate sticker on top of the existing procedural
          // cardboard/tape/plank vocabulary. The decal is the
          // PERSONALITY layer (FLUX-generated `crate_<color>_<cargo>`);
          // the procedural block underneath is the GAMEPLAY layer
          // (uniform geometry that drives the puzzle reading).
          //
          // 2026-05-15 iter 2: bumped size from 78%×88% to 96%×96% so
          // the decal actually reads at the 60×40 layer dimensions.
          // At smaller scales the cargo burst was too tiny to see.
          // Kept Padding(2) so the procedural bevel + colored gradient
          // still bleed through at the layer edges, preserving the
          // block's silhouette + colour identity.
          // 2026-05-15 (audit iter 2): top-crate decal was extending
          // above the bay outline visually (Steve mistook the
          // top-edge poke-out for a glitched "2" badge in his
          // screenshot). Wrap in ClipRRect with the same radius as
          // the layer geometry so the decal can't bleed past the
          // procedural block silhouette.
          if (_showCrateFace)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    ThemeColors.blockBorderRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: Image.asset(
                      topFaceAsset!,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
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
          // Fragile block — cracked-glass crackle overlay + small
          // warning glyph. New as of D8 ("fragile" wrinkle) when the
          // player should be visually warned that this crate carries
          // a wrong-drop penalty.
          if (layer.isFragile)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(GameSizes.stackBorderRadius - 2),
                  child: CustomPaint(
                    painter: _FragileCrackPainter(),
                  ),
                ),
              ),
            ),
          if (layer.isFragile)
            const Positioned(
              top: 2,
              right: 4,
              child: Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFFE08A),
                size: 14,
                shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
              ),
            ),
          // Priority block — orange ribbon overlay + countdown badge.
          // Active priority (countdown > 0): orange tint + N badge.
          // Expired priority (countdown == 0): red tint + ✕ marker.
          if (layer.isPriority)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      GameSizes.stackBorderRadius - 2,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: layer.isPriorityExpired
                          ? const [
                              Color(0x66E53935), // red, low alpha
                              Color(0x33B71C1C),
                            ]
                          : const [
                              Color(0x55FF8A1E), // orange tint
                              Color(0x33CC5A00),
                            ],
                    ),
                  ),
                ),
              ),
            ),
          if (layer.isPriority)
            Positioned(
              top: 2,
              right: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: layer.isPriorityExpired
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFFFFB347),
                    width: 0.9,
                  ),
                ),
                child: Text(
                  layer.isPriorityExpired ? '✕' : '${layer.priorityCountdown}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    color: layer.isPriorityExpired
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFFFFE08A),
                  ),
                ),
              ),
            ),
          // Time-bomb crate — red overlay + countdown badge. Active
          // bomb (countdown > 0): red wash + numeric badge. Detonated
          // (countdown == 0): deeper red + 💥 marker.
          if (layer.isTimeBomb)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      GameSizes.stackBorderRadius - 2,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: layer.isTimeBombDetonated
                          ? const [
                              Color(0x88E53935),
                              Color(0x55B71C1C),
                            ]
                          : const [
                              Color(0x66FF3030),
                              Color(0x44C0392B),
                            ],
                    ),
                  ),
                ),
              ),
            ),
          if (layer.isTimeBomb)
            Positioned(
              top: 2,
              left: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: layer.isTimeBombDetonated
                        ? const Color(0xFFFFD700)
                        : const Color(0xFFFF4757),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      layer.isTimeBombDetonated
                          ? '💥'
                          : '${layer.timeBombCountdown}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        color: layer.isTimeBombDetonated
                            ? const Color(0xFFFFD700)
                            : const Color(0xFFFFE08A),
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

/// Paints a cracked-glass crackle pattern over fragile crates so the
/// player has a clear visual cue that this crate carries the
/// wrong-drop cash penalty. Lines radiate from a random-ish "impact
/// point" in the upper-left so each crate looks slightly different.
class _FragileCrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Anchor the "impact" near top-left of the crate so the cracks
    // look like the box took a knock during loading. Drawing the
    // shadow line first then the white highlight gives the bevel
    // illusion that sells the crack as 3D.
    final impact = Offset(size.width * 0.30, size.height * 0.30);

    // 5 radial fissures fanning out from the impact.
    final List<Offset> ends = [
      Offset(size.width * 0.05, size.height * 0.65),
      Offset(size.width * 0.55, size.height * 0.95),
      Offset(size.width * 0.95, size.height * 0.55),
      Offset(size.width * 0.80, size.height * 0.05),
      Offset(size.width * 0.10, size.height * 0.10),
    ];
    for (final end in ends) {
      canvas.drawLine(impact + const Offset(0.6, 0.6), end, shadow);
      canvas.drawLine(impact, end, paint);
    }

    // Two short cross-fissures connecting the radials for the
    // characteristic "broken windshield" branch geometry.
    canvas.drawLine(
      Offset(size.width * 0.42, size.height * 0.60),
      Offset(size.width * 0.62, size.height * 0.40),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.20, size.height * 0.45),
      Offset(size.width * 0.40, size.height * 0.78),
      paint,
    );
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

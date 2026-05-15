import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// Reusable warehouse-themed decorations. These give every surface in
/// the game a consistent industrial vocabulary: hazard-stripe borders,
/// shipping-label stamps, corrugated cardboard texture, embossed metal
/// nameplates. Pulled into one file so changes ripple everywhere.

// ---------------------------------------------------------------------------
// Hazard stripe
// ---------------------------------------------------------------------------

/// A horizontal yellow + black diagonal hazard-tape strip. Drop it
/// above and below cards to scream "warehouse" without saying it.
class HazardStripe extends StatelessWidget {
  final double height;
  final Color color1;
  final Color color2;
  final double stripeWidth;

  const HazardStripe({
    super.key,
    this.height = 8,
    this.color1 = const Color(0xFFFFC107),
    this.color2 = const Color(0xFF1A1F26),
    this.stripeWidth = 14,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: HazardStripePainter(
          color1: color1,
          color2: color2,
          stripeWidth: stripeWidth,
        ),
      ),
    );
  }
}

class HazardStripePainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final double stripeWidth;

  const HazardStripePainter({
    required this.color1,
    required this.color2,
    required this.stripeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()..color = color1;
    final p2 = Paint()..color = color2;
    // Slant the stripes -45deg.
    final dy = size.height;
    final stride = stripeWidth * 2;
    for (var x = -size.height; x < size.width + size.height; x += stride) {
      final path1 = Path()
        ..moveTo(x, 0)
        ..lineTo(x + stripeWidth, 0)
        ..lineTo(x + stripeWidth + dy, dy)
        ..lineTo(x + dy, dy)
        ..close();
      canvas.drawPath(path1, p1);
      final path2 = Path()
        ..moveTo(x + stripeWidth, 0)
        ..lineTo(x + stride, 0)
        ..lineTo(x + stride + dy, dy)
        ..lineTo(x + stripeWidth + dy, dy)
        ..close();
      canvas.drawPath(path2, p2);
    }
  }

  @override
  bool shouldRepaint(covariant HazardStripePainter oldDelegate) {
    return oldDelegate.color1 != color1 ||
        oldDelegate.color2 != color2 ||
        oldDelegate.stripeWidth != stripeWidth;
  }
}

// ---------------------------------------------------------------------------
// Corrugated cardboard texture (for crates)
// ---------------------------------------------------------------------------

/// Paints vertical corrugated "fluting" lines + a subtle paper-grain
/// noise to make a crate read as cardboard at small sizes. Cheap —
/// 30 short lines + 50 dots, repaints only on size/seed change.
class CorrugatedCardboardPainter extends CustomPainter {
  final Color tint;
  final int seed;

  const CorrugatedCardboardPainter({
    this.tint = const Color(0xFFB8895A),
    this.seed = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fluting = Paint()
      ..color = tint.withValues(alpha: 0.18)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const fluteSpacing = 5.0;
    for (var x = 0.0; x < size.width; x += fluteSpacing) {
      canvas.drawLine(
        Offset(x, 3),
        Offset(x, size.height - 3),
        fluting,
      );
    }

    // Paper-grain dots — sparse but uneven via xorshift.
    final dotPaint = Paint()
      ..color = const Color(0xFF3D2A17).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final rng = math.Random(seed);
    final dotCount = (size.width * size.height / 24).clamp(8, 80).toInt();
    for (var i = 0; i < dotCount; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 0.8 + 0.3,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CorrugatedCardboardPainter oldDelegate) {
    return oldDelegate.tint != tint || oldDelegate.seed != seed;
  }
}

// ---------------------------------------------------------------------------
// Shipping stamp overlay (FRAGILE / HEAVY / KEEP DRY / THIS SIDE UP)
// ---------------------------------------------------------------------------

/// Picks one of a handful of warehouse stamps based on color index, so
/// each crate color gets a consistent persona ("red crates are always
/// FRAGILE"). Faint ink-on-cardboard look — rotated, low alpha, never
/// blocks the crate color.
class ShippingStampPainter extends CustomPainter {
  final int colorIndex;
  final Color inkColor;

  const ShippingStampPainter({
    required this.colorIndex,
    this.inkColor = const Color(0xFF1A1F26),
  });

  static const _stamps = <_StampSpec>[
    _StampSpec('FRAGILE', -0.10),
    _StampSpec('HEAVY', 0.08),
    _StampSpec('THIS SIDE UP', -0.06),
    _StampSpec('KEEP DRY', 0.05),
    _StampSpec('AIR FREIGHT', -0.08),
    _StampSpec('PRIORITY', 0.04),
    _StampSpec('HANDLE CARE', -0.07),
    _StampSpec('EXPRESS', 0.09),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final stamp = _stamps[colorIndex % _stamps.length];
    final fontSize = (size.height * 0.32).clamp(7.0, 12.0);
    final tp = TextPainter(
      text: TextSpan(
        text: stamp.text,
        style: TextStyle(
          color: inkColor.withValues(alpha: 0.42),
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          fontFamily: 'Courier',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width - 6);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(stamp.rotationRad);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ShippingStampPainter oldDelegate) {
    return oldDelegate.colorIndex != colorIndex ||
        oldDelegate.inkColor != inkColor;
  }
}

class _StampSpec {
  final String text;
  final double rotationRad;
  const _StampSpec(this.text, this.rotationRad);
}

// ---------------------------------------------------------------------------
// Embossed metal nameplate (for headers + section dividers)
// ---------------------------------------------------------------------------

/// Brushed-steel-looking pill with bevelled edges + rivets at corners.
/// Use for screen titles and section dividers — gives a manufactured-
/// product feel vs the generic glass card.
class MetalNameplate extends StatelessWidget {
  final String text;
  final IconData? icon;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final double letterSpacing;

  const MetalNameplate({
    super.key,
    required this.text,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    this.fontSize = 16,
    this.letterSpacing = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF3A4250),
            Color(0xFF252B36),
            Color(0xFF1A1F26),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF505868),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.08),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 2, color: GameColors.accent),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  color: GameColors.text,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: letterSpacing,
                  shadows: const [
                    Shadow(
                      color: Color(0xAA000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Rivets at the 4 corners.
          const Positioned(left: 4, top: 3, child: _Rivet()),
          const Positioned(right: 4, top: 3, child: _Rivet()),
          const Positioned(left: 4, bottom: 3, child: _Rivet()),
          const Positioned(right: 4, bottom: 3, child: _Rivet()),
        ],
      ),
    );
  }
}

class _Rivet extends StatelessWidget {
  const _Rivet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF7A8290), Color(0xFF2A303A)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 1,
            offset: const Offset(0, 0.5),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stencil-painted forklift mascot
// ---------------------------------------------------------------------------

/// A small forklift drawn from primitives (no asset dependency). Used
/// in the splash + can be reused as a cute idle mascot on home.
class StencilForklift extends StatelessWidget {
  final double width;
  final double height;
  final Color bodyColor;
  final Color accentColor;

  const StencilForklift({
    super.key,
    this.width = 120,
    this.height = 80,
    this.bodyColor = const Color(0xFFFFC107),
    this.accentColor = const Color(0xFF1A1F26),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _ForkliftPainter(
          bodyColor: bodyColor,
          accentColor: accentColor,
        ),
      ),
    );
  }
}

class _ForkliftPainter extends CustomPainter {
  final Color bodyColor;
  final Color accentColor;

  _ForkliftPainter({required this.bodyColor, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Paint()..color = bodyColor;
    final dark = Paint()..color = accentColor;
    final lighter = Paint()..color = bodyColor.withValues(alpha: 0.6);
    final glass = Paint()..color = const Color(0xFF7FBEEB).withValues(alpha: 0.7);

    // Mast (vertical lift column on the left).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.05, h * 0.10, w * 0.06, h * 0.65),
        const Radius.circular(2),
      ),
      dark,
    );

    // Forks (two horizontal prongs sticking forward-left).
    canvas.drawRect(
      Rect.fromLTWH(w * 0.0, h * 0.60, w * 0.20, h * 0.05),
      dark,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.0, h * 0.72, w * 0.20, h * 0.05),
      dark,
    );

    // Driver cab body.
    final bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.20, h * 0.25, w * 0.60, h * 0.45),
      topLeft: const Radius.circular(6),
      topRight: const Radius.circular(12),
      bottomLeft: const Radius.circular(2),
      bottomRight: const Radius.circular(2),
    );
    canvas.drawRRect(bodyRect, body);

    // Cab/roof bevel highlight.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.22, h * 0.27, w * 0.55, h * 0.04),
      lighter,
    );

    // Cab window.
    final winRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.32, h * 0.30, w * 0.36, h * 0.20),
      topLeft: const Radius.circular(4),
      topRight: const Radius.circular(8),
    );
    canvas.drawRRect(winRect, glass);

    // Cab pillars (window frame).
    canvas.drawRect(
      Rect.fromLTWH(w * 0.49, h * 0.30, w * 0.02, h * 0.20),
      dark,
    );

    // Seat detail (dark rectangle behind window bottom).
    canvas.drawRect(
      Rect.fromLTWH(w * 0.38, h * 0.50, w * 0.25, h * 0.10),
      dark.shaded(0.2),
    );

    // Rear counterweight block.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.78, h * 0.45, w * 0.18, h * 0.30),
        topRight: const Radius.circular(8),
        bottomRight: const Radius.circular(4),
      ),
      body,
    );

    // Front wheel (small).
    canvas.drawCircle(Offset(w * 0.32, h * 0.82), h * 0.13, dark);
    canvas.drawCircle(Offset(w * 0.32, h * 0.82), h * 0.06,
        Paint()..color = const Color(0xFF505868));
    // Rear wheel (large).
    canvas.drawCircle(Offset(w * 0.78, h * 0.82), h * 0.16, dark);
    canvas.drawCircle(Offset(w * 0.78, h * 0.82), h * 0.07,
        Paint()..color = const Color(0xFF505868));

    // Safety beacon dot on roof (signature flash of red).
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.22),
      h * 0.05,
      Paint()..color = const Color(0xFFE53935),
    );
  }

  @override
  bool shouldRepaint(covariant _ForkliftPainter oldDelegate) {
    return oldDelegate.bodyColor != bodyColor ||
        oldDelegate.accentColor != accentColor;
  }
}

extension on Paint {
  /// Convenience: tint a fill paint slightly darker.
  Paint shaded(double amount) {
    final c = color;
    final r = (c.r * 255.0).round() & 0xff;
    final g = (c.g * 255.0).round() & 0xff;
    final b = (c.b * 255.0).round() & 0xff;
    return Paint()
      ..color = Color.fromARGB(
        (c.a * 255.0).round() & 0xff,
        (r * (1 - amount)).round().clamp(0, 255),
        (g * (1 - amount)).round().clamp(0, 255),
        (b * (1 - amount)).round().clamp(0, 255),
      );
  }
}

/// Dark "riveted plate" frame — the canonical interactive-surface
/// primitive from the Lovart visual target (2026-05-15). Wraps any
/// child in a brushed-steel dark gradient body with 4 corner bolts
/// + an optional accent border. Used on the HUD chips (Cash, WH Lv,
/// XP), the Daily Contract pill, the menu pills, and the top-bar
/// utility icons.
///
/// Reuses the existing `_ChainRivet`-style radial-gradient rivet
/// pattern (`chain_text_popup.dart`) inlined here as `_PlateRivet`
/// so the decorations file has no cross-widget dependency.
class RivetedPlate extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  /// Optional accent color for the outer border. Pass `null` for a
  /// muted neutral border (default), or `GameColors.accent` to make
  /// the plate read as a "live" interactive target.
  final Color? accentBorder;
  /// Plate height — when set, the rivets re-position to corners of
  /// the plate. When null, the plate sizes to the child.
  final double? minHeight;

  const RivetedPlate({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.borderRadius = 6,
    this.accentBorder,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      constraints: minHeight != null
          ? BoxConstraints(minHeight: minHeight!)
          : null,
      decoration: BoxDecoration(
        // 3-stop dark brushed-steel gradient matching the cash chip
        // body shown in Lovart's mockup: lighter top edge, mid-grey
        // body, near-black bottom.
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF3A4250),
            Color(0xFF1F252E),
            Color(0xFF14181E),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: accentBorder?.withValues(alpha: 0.6) ??
              const Color(0xFF000000).withValues(alpha: 0.6),
          width: accentBorder != null ? 1.2 : 0.8,
        ),
        boxShadow: [
          // Slight outer shadow for separation from the brushed-steel
          // background the plate sits on.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Inner highlight — a thin lighter rectangle 1px inside the
          // top + sides to imply embossed metal. Subtle but it's what
          // makes the plate feel 3D instead of flat.
          Positioned(
            top: 0.5,
            left: 0.5,
            right: 0.5,
            height: 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(borderRadius)),
              ),
            ),
          ),
          // Child content sits on top of the plate.
          child,
          // 4 corner rivets — small radial-gradient circles with a
          // highlight pip. Placed just inside the plate edge so they
          // read as bolts driven into the plate's metal.
          const Positioned(top: 3, left: 3, child: _PlateRivet()),
          const Positioned(top: 3, right: 3, child: _PlateRivet()),
          const Positioned(bottom: 3, left: 3, child: _PlateRivet()),
          const Positioned(bottom: 3, right: 3, child: _PlateRivet()),
        ],
      ),
    );
  }
}

/// Tiny ~5dp metal bolt — radial gradient with a highlight pip,
/// dark border. Used by `RivetedPlate` for its 4 corner accents.
class _PlateRivet extends StatelessWidget {
  const _PlateRivet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF8A93A0), Color(0xFF2A2F38), Color(0xFF101418)],
          center: Alignment(-0.4, -0.5),
          radius: 1.3,
          stops: [0.0, 0.55, 1.0],
        ),
        border: Border.all(
          color: const Color(0xFF000000).withValues(alpha: 0.7),
          width: 0.4,
        ),
      ),
    );
  }
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/reputation_service.dart';
import '../utils/constants.dart';
import 'warehouse_decorations.dart';

/// Full-screen tier-promotion ceremony. Fires on top of the SHIPMENT
/// RECEIPT when a District clear pushed the player across a Reputation
/// tier boundary. Rare moment (the threshold grows by +5 RP per tier so
/// the first promotion takes ~5 district clears, tier 9 takes ~45),
/// loud celebration.
///
/// Sequence (~3.6s total but skippable):
///   0.00s  Backdrop blur + dim sheet fade in (300ms)
///   0.20s  Top HazardStripe slides in from above (200ms)
///   0.40s  "PROMOTION" Courier header fades in
///   0.80s  Tier medallion pops with elastic overshoot (600ms)
///   1.40s  Tier name big text fades in with slight upward float
///   1.70s  "+0.10× INCOME MULTIPLIER" benefit reveal
///   2.10s  Confetti particles burst from medallion outward
///   2.40s  ACKNOWLEDGE button slides up from bottom
class PromotionCeremonyOverlay extends StatefulWidget {
  /// The tier the player JUST promoted to. Displayed as "BRONZE",
  /// "SILVER", ..., "LEGENDARY II", etc.
  final String newTierName;

  /// The total income-multiplier bonus the player now has from
  /// Reputation alone (uncapped, infinite-scaling). Used for the
  /// benefit reveal line.
  final double reputationMultiplierBonus;

  /// Called when the player taps ACKNOWLEDGE (or the backdrop). The
  /// caller should dismiss the overlay + flip whatever state flag
  /// gated its display so it doesn't re-fire on rebuild.
  final VoidCallback onAcknowledge;

  const PromotionCeremonyOverlay({
    super.key,
    required this.newTierName,
    required this.reputationMultiplierBonus,
    required this.onAcknowledge,
  });

  @override
  State<PromotionCeremonyOverlay> createState() =>
      _PromotionCeremonyOverlayState();
}

class _PromotionCeremonyOverlayState extends State<PromotionCeremonyOverlay>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..forward();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    // Confetti burst starts at the 2.1s mark of the main timeline.
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (mounted) _confettiController.forward();
    });
    // SFX: layer the levelup fanfare + a coin chime ~250ms later for
    // the "register" feel.
    Future.delayed(const Duration(milliseconds: 800), () {
      AudioService().playLevelUp();
    });
    Future.delayed(const Duration(milliseconds: 1050), () {
      AudioService().playCoin();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  double _phase(double startMs, double durationMs) {
    final t = _controller.value * 2800; // ms
    if (t < startMs) return 0.0;
    if (t > startMs + durationMs) return 1.0;
    return ((t - startMs) / durationMs).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _confettiController]),
      builder: (context, _) {
        // Per-element progress fractions, staggered per timeline above.
        final dimT = Curves.easeOut.transform(_phase(0, 300));
        final hazardT = Curves.easeOutCubic.transform(_phase(200, 200));
        final headerT = Curves.easeOut.transform(_phase(400, 300));
        final medallionT = _phase(800, 600);
        final medallionScale =
            Curves.elasticOut.transform(medallionT.clamp(0.0, 1.0));
        final tierNameT = Curves.easeOutCubic.transform(_phase(1400, 400));
        final benefitT = Curves.easeOutCubic.transform(_phase(1700, 300));
        final ackT = Curves.easeOutCubic.transform(_phase(2400, 400));

        return Positioned.fill(
          child: GestureDetector(
            onTap: ackT > 0.5 ? widget.onAcknowledge : null,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                // Backdrop: blur + dark dim.
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 12 * dimT,
                      sigmaY: 12 * dimT,
                    ),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.75 * dimT),
                    ),
                  ),
                ),
                // Confetti particle burst from medallion center.
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _PromotionConfettiPainter(
                        progress: _confettiController.value,
                      ),
                    ),
                  ),
                ),
                // Center column: hazard + header + medallion + tier name +
                // benefit + ack button.
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Top hazard band — slides in from above.
                        Transform.translate(
                          offset: Offset(0, -20 * (1 - hazardT)),
                          child: Opacity(
                            opacity: hazardT,
                            child: const HazardStripe(
                                height: 8, stripeWidth: 16),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // "PROMOTION" Courier header.
                        Opacity(
                          opacity: headerT,
                          child: const Text(
                            'PROMOTION',
                            style: TextStyle(
                              color: GameColors.accent,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 8.0,
                              fontFamily: 'Courier',
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Opacity(
                          opacity: headerT * 0.6,
                          child: Text(
                            'DISPATCH CERTIFIED',
                            style: TextStyle(
                              color: GameColors.textMuted
                                  .withValues(alpha: 0.85),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3.4,
                              fontFamily: 'Courier',
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Brushed-steel medallion — pops with elastic
                        // overshoot. Reads as a riveted dock-floor
                        // award plaque.
                        Transform.scale(
                          scale: medallionScale,
                          child: _TierMedallion(
                            tierName: widget.newTierName,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Big tier name fades in below the medallion.
                        Transform.translate(
                          offset: Offset(0, 10 * (1 - tierNameT)),
                          child: Opacity(
                            opacity: tierNameT,
                            child: Text(
                              widget.newTierName.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4.0,
                                fontFamily: 'Courier',
                                height: 1.0,
                                shadows: [
                                  Shadow(
                                    color: GameColors.accent,
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Benefit reveal: how much income mult the
                        // player now has from Reputation alone.
                        Transform.translate(
                          offset: Offset(0, 8 * (1 - benefitT)),
                          child: Opacity(
                            opacity: benefitT,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: GameColors.accent
                                      .withValues(alpha: 0.6),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  const Icon(
                                    Icons.trending_up,
                                    size: 14,
                                    color: GameColors.accent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '+${widget.reputationMultiplierBonus.toStringAsFixed(2)}×',
                                    style: const TextStyle(
                                      color: GameColors.accent,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Courier',
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'INCOME MULT',
                                    style: TextStyle(
                                      color: GameColors.textMuted
                                          .withValues(alpha: 0.95),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.6,
                                      fontFamily: 'Courier',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        // Acknowledge button — slides in from bottom.
                        Transform.translate(
                          offset: Offset(0, 24 * (1 - ackT)),
                          child: Opacity(
                            opacity: ackT,
                            child: GestureDetector(
                              onTap: widget.onAcknowledge,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFFFD24A),
                                      GameColors.accent,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.black
                                        .withValues(alpha: 0.4),
                                    width: 1.4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: GameColors.accent
                                          .withValues(alpha: 0.45),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'ACKNOWLEDGE',
                                  style: TextStyle(
                                    color: Color(0xFF1A1F26),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.4,
                                    fontFamily: 'Courier',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom hazard band — slides in from below to bookend
                // the medallion frame.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - hazardT)),
                    child: Opacity(
                      opacity: hazardT,
                      child: const HazardStripe(
                          height: 8, stripeWidth: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Brushed-steel medallion containing the new tier name. Painted from
/// primitives (no asset dependency) so it scales infinitely with the
/// tier ladder. Reads as a riveted dock-floor award plaque.
class _TierMedallion extends StatelessWidget {
  final String tierName;
  const _TierMedallion({required this.tierName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFF6A7280),
            Color(0xFF3A4250),
            Color(0xFF1A1F26),
          ],
          center: Alignment(-0.3, -0.5),
          radius: 1.2,
        ),
        border: Border.all(
          color: GameColors.accent,
          width: 3.0,
        ),
        boxShadow: [
          BoxShadow(
            color: GameColors.accent.withValues(alpha: 0.6),
            blurRadius: 24,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Inner accent ring — a thinner second border for the
          // "stamped metal" depth feel.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: GameColors.accent.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          // Center stamp: tier short-name (first letter or short label).
          Center(
            child: Icon(
              Icons.workspace_premium,
              color: GameColors.accent,
              size: 64,
              shadows: [
                Shadow(
                  color: GameColors.accent.withValues(alpha: 0.8),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Confetti burst painter — 80 particles fanning outward from screen
/// center in a star-shaped pattern, with gravity and rotation. Colors
/// are accent yellow + steel + a hint of dispatch red. Reuses the
/// pattern from `chain_text_popup.dart` but tuned for a one-shot
/// celebration rather than an in-flight chain reaction.
class _PromotionConfettiPainter extends CustomPainter {
  final double progress;

  _PromotionConfettiPainter({required this.progress});

  static const int _count = 80;
  static const List<Color> _colors = [
    GameColors.accent,
    Color(0xFFFFA000), // amber
    Color(0xFFB0BEC5), // brushed steel
    Color(0xFFE53935), // dispatch red
    Colors.white,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final random = math.Random(42); // deterministic seed

    for (int i = 0; i < _count; i++) {
      final angle = (i / _count) * 2 * math.pi +
          random.nextDouble() * 0.4;
      final speed = 200 + random.nextDouble() * 300;
      final color = _colors[i % _colors.length];
      final particleSize = 4.0 + random.nextDouble() * 5.0;

      // Travel: scaled by progress. Gravity pulls down quadratically.
      final dx = math.cos(angle) * speed * progress;
      final dy = math.sin(angle) * speed * progress +
          400 * progress * progress;

      // Fade out in the last 30% of progress.
      final opacity = progress < 0.7 ? 1.0 : (1.0 - (progress - 0.7) / 0.3);

      final paint = Paint()..color = color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(cx + dx, cy + dy);
      canvas.rotate((i * 0.5 + progress * 6) % (2 * math.pi));
      // Mix rectangles + circles for visual variety.
      if (i % 3 == 0) {
        canvas.drawCircle(Offset.zero, particleSize * 0.5, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: particleSize,
            height: particleSize * 0.55,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PromotionConfettiPainter old) =>
      old.progress != progress;
}

/// Convenience factory that pulls the new tier name + multiplier bonus
/// directly from `ReputationService`. Use this when the caller has
/// already confirmed a promotion just fired.
PromotionCeremonyOverlay makePromotionCeremonyFromReputation({
  required VoidCallback onAcknowledge,
}) {
  final rep = ReputationService();
  return PromotionCeremonyOverlay(
    newTierName: rep.displayName,
    reputationMultiplierBonus: rep.tierMultiplierBonus,
    onAcknowledge: onAcknowledge,
  );
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/hydraulic_pressure_service.dart';
import '../utils/constants.dart';
import 'warehouse_decorations.dart';

/// Vertical brushed-steel hydraulic-pressure gauge. Anchored to the
/// left edge of the gameplay board. Fills as the player chains/combos
/// at tempo. When full, a VENT button rises from the base — tapping
/// it triggers a 4-move "combo doesn't reset, 2× cash" burst.
///
/// All visual layers compose top-down:
///   1. Brushed-steel frame with 4 corner rivets
///   2. Glass tube cut into the frame
///   3. Fluid level (yellow → red as pressure climbs)
///   4. Zone tick marks at 33% (yellow) and 66% (orange)
///   5. Analog needle overlay rotating 0° → 180° with pressure
///   6. "PRESSURE" Courier label running vertically
///   7. VENT button (rises when canVent)
///   8. Vent-active overlay (HazardStripe + frame pulse)
class HydraulicPressureGauge extends StatefulWidget {
  /// Optional width override. The gauge is otherwise ~24dp wide.
  final double width;

  const HydraulicPressureGauge({super.key, this.width = 28});

  @override
  State<HydraulicPressureGauge> createState() => _HydraulicPressureGaugeState();
}

class _HydraulicPressureGaugeState extends State<HydraulicPressureGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idleTicker;
  final HydraulicPressureService _svc = HydraulicPressureService();

  @override
  void initState() {
    super.initState();
    // Drives idle decay + the 2s steam puff cadence. ~1Hz is plenty.
    _idleTicker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _idleTicker.addListener(_onTick);
  }

  void _onTick() {
    if (!mounted) return;
    _svc.tickIdle(DateTime.now());
  }

  @override
  void dispose() {
    _idleTicker.removeListener(_onTick);
    _idleTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _svc,
      builder: (context, _) {
        final pressure = _svc.pressure;
        final isVenting = _svc.isVenting;
        final canVent = _svc.canVent;
        return SizedBox(
          width: widget.width,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // -------------------- Frame --------------------
                  Positioned.fill(
                    child: _BrushedSteelFrame(isVenting: isVenting),
                  ),
                  // ----------------- Glass tube + fluid ----------
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 18,
                      ),
                      child: _GlassTube(pressure: pressure, isVenting: isVenting),
                    ),
                  ),
                  // ----------------- Vertical label --------------
                  Positioned(
                    top: 22,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        'PRESSURE',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: GameColors.textMuted.withValues(alpha: 0.7),
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                  // ----------------- Vent active overlay ---------
                  if (isVenting)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Opacity(
                            opacity: 0.18,
                            child: HazardStripe(
                              height: constraints.maxHeight,
                              stripeWidth: 6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // ----------------- Vent move counter -----------
                  if (isVenting)
                    Positioned(
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: GameColors.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          '${_svc.ventMovesRemaining}',
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1F26),
                          ),
                        ),
                      ),
                    ),
                  // ----------------- VENT button -----------------
                  if (canVent)
                    Positioned(
                      bottom: 4,
                      child: _VentButton(
                        onTap: () {
                          final fired = _svc.tryActivateVent();
                          if (fired && mounted) {
                            // Pulse — handled by the frame border swap.
                          }
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Brushed steel frame + rivets
// ---------------------------------------------------------------------------

class _BrushedSteelFrame extends StatelessWidget {
  final bool isVenting;
  const _BrushedSteelFrame({required this.isVenting});

  @override
  Widget build(BuildContext context) {
    final border = isVenting
        ? Border.all(color: GameColors.accent, width: 1.2)
        : Border.all(color: const Color(0xFF14181E), width: 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3A4250),
            Color(0xFF252B36),
            Color(0xFF1A1F26),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(4),
        border: border,
        boxShadow: isVenting
            ? [
                BoxShadow(
                  color: GameColors.accent.withValues(alpha: 0.35),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: const _RivetCorners(),
    );
  }
}

class _RivetCorners extends StatelessWidget {
  const _RivetCorners();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned(top: 3, left: 3, child: _Rivet()),
        Positioned(top: 3, right: 3, child: _Rivet()),
        Positioned(bottom: 3, left: 3, child: _Rivet()),
        Positioned(bottom: 3, right: 3, child: _Rivet()),
      ],
    );
  }
}

class _Rivet extends StatelessWidget {
  const _Rivet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF6A7280), Color(0xFF14181E)],
          center: Alignment(-0.4, -0.5),
          radius: 1.2,
        ),
        border: Border.all(
          color: GameColors.accent.withValues(alpha: 0.45),
          width: 0.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass tube + fluid level
// ---------------------------------------------------------------------------

class _GlassTube extends StatelessWidget {
  final double pressure; // 0..1
  final bool isVenting;
  const _GlassTube({required this.pressure, required this.isVenting});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final fluidColor = isVenting
            ? GameColors.accent
            : Color.lerp(
                GameColors.accent,
                const Color(0xFFE53935),
                pressure.clamp(0.0, 1.0),
              )!;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0B0E13),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: const Color(0xFF14181E), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // -------- Fluid level --------
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: pressure, end: pressure),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, value, child) {
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: h * value.clamp(0.0, 1.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              fluidColor,
                              fluidColor.withValues(alpha: 0.65),
                            ],
                          ),
                          boxShadow: isVenting
                              ? [
                                  BoxShadow(
                                    color: GameColors.accent
                                        .withValues(alpha: 0.6),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
                // -------- Zone tick marks --------
                Positioned(
                  bottom: h * 0.33,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: const Color(0xFFFFD93D).withValues(alpha: 0.55),
                  ),
                ),
                Positioned(
                  bottom: h * 0.66,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: const Color(0xFFFF8A1F).withValues(alpha: 0.65),
                  ),
                ),
                // -------- Needle overlay --------
                Positioned(
                  bottom: 2,
                  child: _Needle(pressure: pressure),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Needle extends StatelessWidget {
  final double pressure;
  const _Needle({required this.pressure});

  @override
  Widget build(BuildContext context) {
    // 0% → 0 rad (pointing left); 100% → π rad (pointing right).
    final angle = pressure.clamp(0.0, 1.0) * math.pi;
    return Transform.rotate(
      angle: angle,
      child: CustomPaint(
        size: const Size(14, 4),
        painter: _NeedlePainter(),
      ),
    );
  }
}

class _NeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width - 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(0, size.height / 2),
      1.6,
      Paint()..color = const Color(0xFF1A1F26),
    );
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// VENT button
// ---------------------------------------------------------------------------

class _VentButton extends StatelessWidget {
  final VoidCallback onTap;
  const _VentButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        builder: (context, t, child) {
          // `easeOutBack` overshoots past 1.0 mid-curve, which is fine
          // for translate/scale but trips `Opacity`'s [0,1] assertion
          // and floods the log on every vent-button appearance. Clamp
          // only the opacity channel — the translate keeps the bounce.
          return Transform.translate(
            offset: Offset(0, (1 - t) * 8),
            child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
          );
        },
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: GameColors.accent,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFF14181E), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: GameColors.accent.withValues(alpha: 0.5),
                blurRadius: 6,
                spreadRadius: 0.5,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'VENT',
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 7,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1F26),
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

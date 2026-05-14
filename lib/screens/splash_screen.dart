import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/route_transitions.dart';
import '../widgets/warehouse_decorations.dart';
import 'home_screen.dart';

/// Animated launch splash. Used as `MaterialApp.home` so it's the very
/// first widget Flutter paints. Shows a forklift driving across a
/// warehouse dock floor while the wordmark stamps in, then transitions
/// to the home screen via the standard fade-slide route.
class WarehouseSplashScreen extends StatefulWidget {
  const WarehouseSplashScreen({super.key});

  @override
  State<WarehouseSplashScreen> createState() => _WarehouseSplashScreenState();
}

class _WarehouseSplashScreenState extends State<WarehouseSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2400), _goToHome);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      fadeSlideRoute(const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _goToHome,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => _buildContent(context, _ctrl.value),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, double t) {
    final mq = MediaQuery.of(context).size;

    // 0.00–0.30: forklift drives across screen
    // 0.30–0.55: forklift halts; "WAREHOUSE" stamps in
    // 0.55–0.80: "SORT" stamps in
    // 0.80–1.00: subtitle fades in
    final driveT = Curves.easeOutCubic.transform(t.clamp(0.0, 0.30) / 0.30);
    final forkliftX = -160.0 + driveT * (mq.width * 0.5 + 80);

    final warehouseStamp = _stampProgress(t, 0.30, 0.55);
    final sortStamp = _stampProgress(t, 0.55, 0.80);
    final subtitleFade = _stampProgress(t, 0.80, 1.0);

    return Column(
      children: [
        const HazardStripe(height: 14),
        Expanded(
          child: Stack(
            children: [
              // Centered wordmark.
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StampedText(
                      text: 'WAREHOUSE',
                      progress: warehouseStamp,
                      fontSize: 44,
                      rotationDeg: -1.5,
                    ),
                    const SizedBox(height: 4),
                    _StampedText(
                      text: 'SORT',
                      progress: sortStamp,
                      fontSize: 56,
                      rotationDeg: 1.2,
                      color: GameColors.accent,
                    ),
                    const SizedBox(height: 22),
                    Opacity(
                      opacity: subtitleFade,
                      child: const _SubtitleStrip(),
                    ),
                  ],
                ),
              ),
              // Forklift driving across the dock.
              Positioned(
                left: forkliftX,
                bottom: 80,
                child: const StencilForklift(width: 140, height: 92),
              ),
              // Dust trail behind the forklift while moving.
              Positioned(
                left: forkliftX - 30,
                bottom: 80,
                child: Opacity(
                  opacity: ((1.0 - driveT) * 0.5).clamp(0.0, 1.0),
                  child: _DustPuff(),
                ),
              ),
              // "LOADING DOCK READY" tagline pulses softly.
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: Opacity(
                  opacity:
                      (0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * math.pi * 4)))
                          .clamp(0.0, 1.0),
                  child: const Text(
                    'LOADING DOCK · READY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GameColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const HazardStripe(height: 14),
      ],
    );
  }

  /// Maps overall progress to a 0..1 phase value for a given window.
  /// We let easeOutBack drive the *visible* punch but always clamp the
  /// returned value to [0, 1] so it can be fed safely to Opacity.
  double _stampProgress(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    final phase = ((t - start) / (end - start)).clamp(0.0, 1.0);
    return Curves.easeOutBack.transform(phase).clamp(0.0, 1.0);
  }
}

/// Renders the wordmark like a rubber-stamp impression — drops in from
/// above with a slight overshoot + faint shadow + tiny rotation.
class _StampedText extends StatelessWidget {
  final String text;
  final double progress; // 0..1
  final double fontSize;
  final double rotationDeg;
  final Color color;

  const _StampedText({
    required this.text,
    required this.progress,
    required this.fontSize,
    required this.rotationDeg,
    this.color = GameColors.text,
  });

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();
    final dy = (1.0 - progress) * -24;
    final scale = 0.85 + 0.15 * progress;
    final rot = rotationDeg * math.pi / 180;
    return Transform.translate(
      offset: Offset(0, dy),
      child: Transform.rotate(
        angle: rot,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: progress,
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                shadows: const [
                  Shadow(
                    color: Color(0x88000000),
                    blurRadius: 4,
                    offset: Offset(2, 3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubtitleStrip extends StatelessWidget {
  const _SubtitleStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: GameColors.accent.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: const Text(
        'SORT THE CRATES · BUILD THE EMPIRE',
        style: TextStyle(
          color: GameColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.6,
          fontFamily: 'Courier',
        ),
      ),
    );
  }
}

class _DustPuff extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Container(
            width: 8 - i * 1.5,
            height: 8 - i * 1.5,
            decoration: BoxDecoration(
              color: const Color(0xFF8A7A60).withValues(alpha: 0.5 - i * 0.12),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

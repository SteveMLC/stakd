import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Home-screen streak badge — reskinned 2026-05-14 from the pre-rebrand
/// 🔥 "X days streak!" pill into an "ON-DUTY" timeclock stamp. Reads as
/// a warehouse attendance card stamped at the dock entry, anchored to
/// the brushed-steel / hazard-yellow / Courier vocabulary used across
/// the rest of the app.
class DailyStreakBadge extends StatefulWidget {
  final int streak;
  final bool highlight;

  const DailyStreakBadge({
    super.key,
    required this.streak,
    this.highlight = false,
  });

  @override
  State<DailyStreakBadge> createState() => _DailyStreakBadgeState();
}

class _DailyStreakBadgeState extends State<DailyStreakBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_controller);
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 0.35,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.highlight) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant DailyStreakBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight && !oldWidget.highlight) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel = widget.streak == 1 ? 'DAY' : 'DAYS';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = _glowAnimation.value;
        return Transform.scale(
          scale: widget.highlight ? _scaleAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              // Brushed-steel 3-stop gradient anchored to the warehouse
              // vocabulary (same gradient used in HUD, settings rows,
              // chain popup pill, leaderboard rows).
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF3A4250),
                  Color(0xFF252B36),
                  Color(0xFF1A1F26),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: GameColors.accent.withValues(alpha: 0.65 + glow),
                width: 1.2,
              ),
              boxShadow: glow > 0
                  ? [
                      BoxShadow(
                        color: GameColors.accent.withValues(alpha: glow),
                        blurRadius: 14,
                        spreadRadius: 1.5,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Time-clock glyph — the icon a dock supervisor would
                // tap to log a shift, anchors the "attendance card"
                // vocabulary.
                Icon(
                  Icons.schedule_outlined,
                  size: 14,
                  color: GameColors.accent.withValues(alpha: 0.95),
                ),
                const SizedBox(width: 8),
                // Two-line stamped value: header strip + big number.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ON-DUTY',
                      style: TextStyle(
                        color: GameColors.accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        fontFamily: 'Courier',
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${widget.streak}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Courier',
                            letterSpacing: 0.5,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          dayLabel,
                          style: TextStyle(
                            color: GameColors.textMuted
                                .withValues(alpha: 0.85),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Courier',
                            letterSpacing: 1.4,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

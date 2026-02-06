import 'package:flutter/material.dart';
import '../utils/constants.dart';

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
    final streakLabel = widget.streak == 1 ? 'day' : 'days';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = _glowAnimation.value;
        return Transform.scale(
          scale: widget.highlight ? _scaleAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  GameColors.accent.withValues(alpha: 0.9),
                  GameColors.palette[1].withValues(alpha: 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: glow > 0
                  ? [
                      BoxShadow(
                        color: GameColors.accent.withValues(alpha: glow),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              '\u{1F525} ${widget.streak} $streakLabel streak!',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: GameColors.text,
                letterSpacing: 0.3,
              ),
            ),
          ),
        );
      },
    );
  }
}

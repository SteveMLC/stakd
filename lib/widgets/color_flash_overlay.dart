import 'package:flutter/material.dart';

/// Full-screen color flash effect for combos and big clears
class ColorFlashOverlay extends StatefulWidget {
  final Color color;
  final Duration duration;
  final VoidCallback? onComplete;

  const ColorFlashOverlay({
    super.key,
    required this.color,
    this.duration = const Duration(milliseconds: 300),
    this.onComplete,
  });

  @override
  State<ColorFlashOverlay> createState() => _ColorFlashOverlayState();
}

class _ColorFlashOverlayState extends State<ColorFlashOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Quick flash: 0 → 0.3 → 0
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.3, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 70,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return IgnorePointer(
          child: Container(
            color: widget.color.withValues(alpha: _opacityAnimation.value),
          ),
        );
      },
    );
  }
}

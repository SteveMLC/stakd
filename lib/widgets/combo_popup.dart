import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Displays an animated combo multiplier popup
class ComboPopup extends StatefulWidget {
  final int comboMultiplier;
  final VoidCallback? onComplete;

  const ComboPopup({super.key, required this.comboMultiplier, this.onComplete});

  @override
  State<ComboPopup> createState() => _ComboPopupState();
}

class _ComboPopupState extends State<ComboPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Scale animation: 0.5 → 1.2 → 1.0 → fade
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.5,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 40),
    ]).animate(_controller);

    // Opacity: fade in quickly, stay, fade out
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
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

  Color _getComboColor() {
    switch (widget.comboMultiplier) {
      case 2:
        return const Color(0xFFFFD700); // Gold/Yellow
      case 3:
        return const Color(0xFFFF8C00); // Dark Orange
      case 4:
        return const Color(0xFFFF4500); // Red-Orange
      case 5:
        return const Color(0xFF9370DB); // Medium Purple
      default:
        return GameColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _getComboColor(), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: _getComboColor().withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'COMBO',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: GameColors.text,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.comboMultiplier}x',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: _getComboColor(),
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Overlay widget that manages combo popup display
class ComboPopupOverlay extends StatefulWidget {
  final int comboMultiplier;
  final VoidCallback? onComplete;

  const ComboPopupOverlay({
    super.key,
    required this.comboMultiplier,
    this.onComplete,
  });

  @override
  State<ComboPopupOverlay> createState() => _ComboPopupOverlayState();
}

class _ComboPopupOverlayState extends State<ComboPopupOverlay> {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: ComboPopup(
            comboMultiplier: widget.comboMultiplier,
            onComplete: widget.onComplete,
          ),
        ),
      ),
    );
  }
}

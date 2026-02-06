import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Reusable styled game button
class GameButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isSmall;
  final bool isDisabled;

  const GameButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.isPrimary = true,
    this.isSmall = false,
    this.isDisabled = false,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: GameDurations.buttonPress,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.isDisabled) return;
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.isSmall
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 32, vertical: 16);

    final fontSize = widget.isSmall ? 14.0 : 18.0;
    final iconSize = widget.isSmall ? 18.0 : 24.0;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.isDisabled ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: widget.isDisabled
                    ? GameColors.surface
                    : widget.isPrimary
                        ? GameColors.accent
                        : GameColors.surface,
                borderRadius: BorderRadius.circular(GameSizes.borderRadius),
                border: widget.isPrimary
                    ? null
                    : Border.all(color: GameColors.accent, width: 2),
                boxShadow: widget.isDisabled
                    ? null
                    : [
                        BoxShadow(
                          color: (widget.isPrimary
                                  ? GameColors.accent
                                  : GameColors.surface)
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: iconSize,
                      color: widget.isDisabled
                          ? GameColors.textMuted
                          : GameColors.text,
                    ),
                    SizedBox(width: widget.isSmall ? 6 : 8),
                  ],
                  Text(
                    widget.text,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: widget.isDisabled
                          ? GameColors.textMuted
                          : GameColors.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Icon-only game button
class GameIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? badge;
  final bool isDisabled;

  const GameIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.badge,
    this.isDisabled = false,
  });

  @override
  State<GameIconButton> createState() => _GameIconButtonState();
}

class _GameIconButtonState extends State<GameIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: GameDurations.buttonPress,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.isDisabled ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: GameColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isDisabled
                          ? GameColors.empty
                          : GameColors.accent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.isDisabled
                        ? GameColors.textMuted
                        : GameColors.text,
                  ),
                ),
                if (widget.badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: GameColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        widget.badge!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

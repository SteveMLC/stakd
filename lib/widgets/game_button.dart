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
  final Color? backgroundColor;
  final Color? borderColor;

  const GameButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.isPrimary = true,
    this.isSmall = false,
    this.isDisabled = false,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton>
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
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.isDisabled) return;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.isSmall
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 32, vertical: 16);

    final fontSize = widget.isSmall ? 14.0 : 18.0;
    final iconSize = widget.isSmall ? 18.0 : 24.0;

    final baseColor = widget.backgroundColor ??
        (widget.isPrimary ? GameColors.accent : GameColors.surface);
    final outlineColor = widget.borderColor ?? GameColors.accent;
    final gradientColors = widget.isPrimary
        ? [
            baseColor,
            baseColor.withValues(alpha: 0.8),
          ]
        : [
            GameColors.surface.withValues(alpha: 0.95),
            GameColors.background.withValues(alpha: 0.9),
          ];

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
                gradient: widget.isDisabled
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                color: widget.isDisabled ? GameColors.surface : null,
                borderRadius: BorderRadius.circular(GameSizes.borderRadius),
                border: Border.all(
                  color: widget.isPrimary
                      ? baseColor.withValues(alpha: 0.5)
                      : outlineColor.withValues(alpha: 0.4),
                  width: widget.isPrimary ? 2 : 1,
                ),
                boxShadow: widget.isDisabled
                    ? null
                    : [
                        if (widget.isPrimary)
                          BoxShadow(
                            color: baseColor.withValues(alpha: 0.45),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
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
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
                    gradient: widget.isDisabled
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              GameColors.surface.withValues(alpha: 0.95),
                              GameColors.background.withValues(alpha: 0.9),
                            ],
                          ),
                    color: widget.isDisabled ? GameColors.surface : null,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isDisabled
                          ? GameColors.empty
                          : GameColors.accent.withValues(alpha: 0.5),
                    ),
                    boxShadow: widget.isDisabled
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
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

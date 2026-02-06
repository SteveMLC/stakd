import 'package:flutter/material.dart';
import '../models/stack_model.dart';
import '../utils/constants.dart';
import 'layer_widget.dart';

/// Displays a single stack with its layers
class StackWidget extends StatelessWidget {
  final GameStack stack;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const StackWidget({
    super.key,
    required this.stack,
    this.isSelected = false,
    this.isHighlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: GameDurations.buttonPress,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, isSelected ? -10 : 0, 0),
        child: Container(
          width: GameSizes.stackWidth,
          height: GameSizes.stackHeight,
          decoration: BoxDecoration(
            color: GameColors.empty,
            borderRadius: BorderRadius.circular(GameSizes.stackBorderRadius),
            border: Border.all(
              color: isSelected
                  ? GameColors.accent
                  : isHighlighted
                  ? GameColors.accent.withValues(alpha: 0.5)
                  : GameColors.surface,
              width: isSelected ? 3 : 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: GameColors.accent.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Layers (bottom to top)
              ...stack.layers.asMap().entries.map((entry) {
                final index = entry.key;
                final layer = entry.value;
                final isTop = index == stack.layers.length - 1;

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == 0 ? 4 : 2,
                    left: 4,
                    right: 4,
                  ),
                  child: LayerWidget(layer: layer, isTop: isTop),
                );
              }),

              // Empty slots indicator
              if (stack.isEmpty)
                Expanded(
                  child: Center(
                    child: Icon(
                      Icons.add_circle_outline,
                      color: GameColors.textMuted.withValues(alpha: 0.3),
                      size: 32,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stack with completion animation
class AnimatedStackWidget extends StatefulWidget {
  final GameStack stack;
  final bool isSelected;
  final bool justCompleted;
  final VoidCallback? onTap;

  const AnimatedStackWidget({
    super.key,
    required this.stack,
    this.isSelected = false,
    this.justCompleted = false,
    this.onTap,
  });

  @override
  State<AnimatedStackWidget> createState() => _AnimatedStackWidgetState();
}

class _AnimatedStackWidgetState extends State<AnimatedStackWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: GameDurations.stackClear,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  void didUpdateWidget(AnimatedStackWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.justCompleted && !oldWidget.justCompleted) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: StackWidget(
            stack: widget.stack,
            isSelected: widget.isSelected,
            isHighlighted: widget.stack.isComplete,
            onTap: widget.onTap,
          ),
        );
      },
    );
  }
}

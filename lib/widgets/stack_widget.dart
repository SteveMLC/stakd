import 'package:flutter/material.dart';
import '../models/stack_model.dart';
import '../services/haptic_service.dart';
import '../utils/constants.dart';
import 'layer_widget.dart';

/// Displays a single stack with its layers
class StackWidget extends StatefulWidget {
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
  State<StackWidget> createState() => _StackWidgetState();
}

class _StackWidgetState extends State<StackWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if stack is one layer away from complete
    final isNearComplete = widget.stack.layers.isNotEmpty &&
        widget.stack.layers.length == GameConfig.maxStackDepth - 1;
    
    return GestureDetector(
      onTap: () {
        haptics.lightTap();
        widget.onTap?.call();
      },
      child: AnimatedContainer(
        duration: GameDurations.buttonPress,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, widget.isSelected ? -10 : 0, 0),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: GameSizes.stackWidth,
              height: GameSizes.stackHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    GameColors.empty.withValues(alpha: 0.85),
                    GameColors.empty,
                  ],
                ),
                borderRadius: BorderRadius.circular(GameSizes.stackBorderRadius),
                border: Border.all(
                  color: widget.isSelected
                      ? GameColors.accent
                      : widget.isHighlighted
                      ? GameColors.accent.withValues(alpha: 0.5)
                      : isNearComplete
                      ? GameColors.successGlow.withValues(alpha: _pulseAnimation.value)
                      : GameColors.surface,
                  width: widget.isSelected ? 3 : 2,
                ),
                boxShadow: [
                  if (widget.isSelected)
                    BoxShadow(
                      color: GameColors.accent.withValues(alpha: 0.5),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  if (isNearComplete)
                    BoxShadow(
                      color: GameColors.successGlow.withValues(alpha: _pulseAnimation.value * 0.5),
                      blurRadius: 20,
                      spreadRadius: 3,
                    ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Layers (bottom to top)
                  ...widget.stack.layers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final layer = entry.value;
                    final isTop = index == widget.stack.layers.length - 1;

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == 0 ? 4 : 2,
                        left: 4,
                        right: 4,
                      ),
                      child: LayerWidget(
                        layer: layer,
                        isTop: isTop,
                        glowEffect: isNearComplete,
                      ),
                    );
                  }),

                  // Empty slots indicator
                  if (widget.stack.isEmpty)
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: GameColors.textMuted.withValues(alpha: 0.15),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.add,
                            color: GameColors.textMuted.withValues(alpha: 0.2),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
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

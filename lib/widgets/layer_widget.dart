import 'package:flutter/material.dart';
import '../models/layer_model.dart';
import '../utils/constants.dart';

/// Displays a single colored layer
class LayerWidget extends StatelessWidget {
  final Layer layer;
  final bool isTop;
  final double width;
  final double height;

  const LayerWidget({
    super.key,
    required this.layer,
    this.isTop = false,
    this.width = GameSizes.stackWidth - 8,
    this.height = GameSizes.layerHeight,
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors = GameColors.getGradient(layer.colorIndex);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(GameSizes.stackBorderRadius),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle bevel highlight
          Positioned(
            top: 3,
            left: 6,
            right: 6,
            height: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Bottom shadow line for depth
          Positioned(
            bottom: 2,
            left: 4,
            right: 4,
            height: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Soft sheen overlay
          Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GameSizes.stackBorderRadius - 2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.25),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated layer that can move between stacks
class AnimatedLayerWidget extends StatelessWidget {
  final Layer layer;
  final bool isMoving;
  final Offset offset;
  final VoidCallback? onMoveComplete;

  const AnimatedLayerWidget({
    super.key,
    required this.layer,
    this.isMoving = false,
    this.offset = Offset.zero,
    this.onMoveComplete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: GameDurations.layerMove,
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(offset.dx, offset.dy, 0),
      onEnd: onMoveComplete,
      child: LayerWidget(layer: layer),
    );
  }
}

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
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: layer.color,
        borderRadius: BorderRadius.circular(GameSizes.stackBorderRadius),
        boxShadow: [
          BoxShadow(
            color: layer.color.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            layer.color.withValues(alpha: 0.9),
            layer.color,
            layer.color.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GameSizes.stackBorderRadius - 2),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.3),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.1),
            ],
          ),
        ),
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

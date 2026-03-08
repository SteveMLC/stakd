import 'package:flutter/material.dart';

import '../../models/stack_model.dart';
import '../../utils/constants.dart';
import '../layer_widget.dart';
import 'stack_painter.dart';

class StackRenderWidget extends StatelessWidget {
  final GameStack stack;
  final bool selected;
  final bool highlighted;

  const StackRenderWidget({
    super.key,
    required this.stack,
    this.selected = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? GameColors.accent
        : highlighted
        ? GameColors.accent.withValues(alpha: 0.5)
        : GameColors.surface;

    return CustomPaint(
      painter: StackPainter(borderColor: borderColor, selected: selected),
      child: SizedBox(
        width: GameSizes.stackWidth,
        height: GameSizes.stackHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layerCount = stack.layers.length;
            final baseHeight = GameSizes.layerHeight;
            final gap = 2.0;
            final bottomPadding = 4.0;
            final maxHeight = constraints.maxHeight;
            final totalNeeded = layerCount > 0
                ? (baseHeight * layerCount) +
                      (gap * (layerCount - 1)) +
                      bottomPadding
                : 0.0;
            final effectiveHeight = totalNeeded > maxHeight && layerCount > 0
                ? (maxHeight - bottomPadding - (gap * (layerCount - 1))) /
                      layerCount
                : baseHeight;

            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ...stack.layers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final layer = entry.value;
                  final isTop = index == stack.layers.length - 1;

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == 0 ? bottomPadding : gap,
                      left: 4,
                      right: 4,
                    ),
                    child: LayerWidget(
                      layer: layer,
                      isTop: isTop,
                      height: effectiveHeight,
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

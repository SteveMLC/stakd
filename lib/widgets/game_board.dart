import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../utils/constants.dart';

/// Game board widget - displays all stacks and handles interactions
class GameBoard extends StatelessWidget {
  final GameState gameState;

  const GameBoard({
    super.key,
    required this.gameState,
  });

  @override
  Widget build(BuildContext context) {
    final stacks = gameState.stacks;
    if (stacks.isEmpty) {
      return const Center(
        child: Text(
          'Loading...',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: GameColors.textMuted,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate optimal layout based on number of stacks
          final stackCount = stacks.length;
          final maxStacksPerRow = _getStacksPerRow(stackCount, constraints.maxWidth);
          final rows = (stackCount / maxStacksPerRow).ceil();
          
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(rows, (rowIndex) {
              final startIndex = rowIndex * maxStacksPerRow;
              final endIndex = (startIndex + maxStacksPerRow).clamp(0, stackCount);
              final rowStacks = stacks.sublist(startIndex, endIndex);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(rowStacks.length, (index) {
                    final actualIndex = startIndex + index;
                    final stack = rowStacks[index];
                    final isSelected = actualIndex == gameState.selectedStackIndex;
                    final isRecentlyCleared = gameState.recentlyCleared.contains(actualIndex);

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: GameSizes.stackSpacing / 2,
                      ),
                      child: _StackWidget(
                        stack: stack,
                        index: actualIndex,
                        isSelected: isSelected,
                        isRecentlyCleared: isRecentlyCleared,
                        onTap: () => gameState.onStackTap(actualIndex),
                      ),
                    );
                  }),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  int _getStacksPerRow(int total, double maxWidth) {
    final stackWidth = GameSizes.stackWidth + GameSizes.stackSpacing;
    final maxFit = (maxWidth / stackWidth).floor();
    
    // Try to balance rows
    if (total <= 4) return total;
    if (total <= 6) return 3;
    if (total <= 9) return 5;
    return maxFit.clamp(4, 6);
  }
}

class _StackWidget extends StatefulWidget {
  final dynamic stack; // GameStack
  final int index;
  final bool isSelected;
  final bool isRecentlyCleared;
  final VoidCallback onTap;

  const _StackWidget({
    required this.stack,
    required this.index,
    required this.isSelected,
    required this.isRecentlyCleared,
    required this.onTap,
  });

  @override
  State<_StackWidget> createState() => _StackWidgetState();
}

class _StackWidgetState extends State<_StackWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GameDurations.stackClear,
    );
    _bounceAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
    _glowAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _StackWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecentlyCleared && !oldWidget.isRecentlyCleared) {
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
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, widget.isSelected ? -8 : _bounceAnimation.value),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: GameDurations.buttonPress,
              width: GameSizes.stackWidth,
              height: GameSizes.stackHeight,
              decoration: BoxDecoration(
                color: GameColors.empty,
                borderRadius: BorderRadius.circular(GameSizes.stackBorderRadius),
                border: Border.all(
                  color: widget.isSelected
                      ? GameColors.accent
                      : widget.isRecentlyCleared
                          ? GameColors.palette[2]
                          : GameColors.empty,
                  width: widget.isSelected ? 3 : 2,
                ),
                boxShadow: [
                  if (widget.isSelected)
                    BoxShadow(
                      color: GameColors.accent.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  if (widget.isRecentlyCleared)
                    BoxShadow(
                      color: GameColors.palette[2]
                          .withOpacity(0.4 * _glowAnimation.value),
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  GameSizes.stackBorderRadius - 2,
                ),
                child: _buildLayers(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayers() {
    final layers = widget.stack.layers as List;
    if (layers.isEmpty) {
      return const SizedBox.expand();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: layers.map<Widget>((layer) {
        return Container(
          width: double.infinity,
          height: GameSizes.layerHeight,
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: GameColors.getColor(layer.colorIndex),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }).toList(),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_state.dart';
import '../utils/constants.dart';
import 'particles/particle_burst.dart';
import 'combo_popup.dart';

/// Game board widget - displays all stacks and handles interactions
class GameBoard extends StatefulWidget {
  final GameState gameState;
  final VoidCallback? onTap;
  final VoidCallback? onMove;
  final VoidCallback? onClear;
  final Map<int, GlobalKey>? stackKeys;

  const GameBoard({
    super.key,
    required this.gameState,
    this.onTap,
    this.onMove,
    this.onClear,
    this.stackKeys,
  });

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  late final Map<int, GlobalKey> _stackKeys;
  List<ParticleBurstData> _currentBursts = [];
  int? _showComboMultiplier;

  @override
  void initState() {
    super.initState();
    // Use provided keys or create new ones
    _stackKeys = widget.stackKeys ?? {};
  }

  @override
  Widget build(BuildContext context) {
    final stacks = widget.gameState.stacks;
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

    // Ensure we have keys for all stacks
    for (int i = 0; i < stacks.length; i++) {
      _stackKeys.putIfAbsent(i, () => GlobalKey());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate optimal layout based on number of stacks
          final stackCount = stacks.length;
          final maxStacksPerRow = _getStacksPerRow(stackCount, constraints.maxWidth);
          final rows = (stackCount / maxStacksPerRow).ceil();
          
          return Stack(
            children: [
              // Particle bursts overlay
              if (_currentBursts.isNotEmpty)
                Positioned.fill(
                  child: ParticleBurstOverlay(
                    bursts: _currentBursts,
                    onAllComplete: () {
                      setState(() {
                        _currentBursts = [];
                      });
                    },
                  ),
                ),
              Column(
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
                        final isSelected = actualIndex == widget.gameState.selectedStackIndex;
                        final isRecentlyCleared = widget.gameState.recentlyCleared.contains(actualIndex);

                        return Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: GameSizes.stackSpacing / 2,
                          ),
                          child: _StackWidget(
                            key: _stackKeys[actualIndex],
                            stack: stack,
                            index: actualIndex,
                            isSelected: isSelected,
                            isRecentlyCleared: isRecentlyCleared,
                            onTap: () {
                              final previousMoveCount = widget.gameState.moveCount;
                              final previousCleared = List<int>.from(
                                widget.gameState.recentlyCleared,
                              );

                              widget.gameState.onStackTap(actualIndex);
                              widget.onTap?.call();

                              if (widget.gameState.moveCount > previousMoveCount) {
                                widget.onMove?.call();
                              }

                              final currentCleared = widget.gameState.recentlyCleared;
                              if (currentCleared.isNotEmpty &&
                                  !listEquals(previousCleared, currentCleared)) {
                                widget.onClear?.call();
                                _triggerParticleBursts(currentCleared);
                                
                                // Show combo popup if combo > 1
                                final currentCombo = widget.gameState.currentCombo;
                                if (currentCombo > 1) {
                                  setState(() {
                                    _showComboMultiplier = currentCombo;
                                  });
                                }
                              }
                            },
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
              // Animation overlay
              if (widget.gameState.animatingLayer != null)
                _AnimatedLayerOverlay(
                  animatingLayer: widget.gameState.animatingLayer!,
                  fromKey: _stackKeys[widget.gameState.animatingLayer!.fromStackIndex]!,
                  toKey: _stackKeys[widget.gameState.animatingLayer!.toStackIndex]!,
                  onComplete: () {
                    widget.gameState.completeMove();
                    widget.onMove?.call();
                  },
                ),
              // Combo popup overlay
              if (_showComboMultiplier != null && _showComboMultiplier! > 1)
                ComboPopupOverlay(
                  comboMultiplier: _showComboMultiplier!,
                  onComplete: () {
                    setState(() {
                      _showComboMultiplier = null;
                    });
                  },
                ),
            ],
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

  void _triggerParticleBursts(List<int> clearedIndices) {
    if (clearedIndices.isEmpty) return;

    final bursts = <ParticleBurstData>[];
    
    for (final stackIndex in clearedIndices) {
      final stackKey = _stackKeys[stackIndex];
      if (stackKey?.currentContext == null) continue;

      // Get the render box to find the position
      final renderBox = stackKey!.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;

      // Get position relative to the screen
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      
      // Calculate center of the stack
      final center = Offset(
        position.dx + size.width / 2,
        position.dy + size.height / 2,
      );

      // Get the stack's color
      final stack = widget.gameState.stacks[stackIndex];
      final topLayer = stack.layers.isNotEmpty ? stack.layers.first : null;
      final color = topLayer != null 
          ? GameColors.getColor(topLayer.colorIndex)
          : GameColors.accent;

      bursts.add(ParticleBurstData(
        center: center,
        color: color,
        particleCount: 18,
        lifetime: const Duration(milliseconds: 500),
      ));
    }

    if (bursts.isNotEmpty) {
      setState(() {
        _currentBursts = bursts;
      });
    }
  }
}

class _StackWidget extends StatefulWidget {
  final dynamic stack; // GameStack
  final int index;
  final bool isSelected;
  final bool isRecentlyCleared;
  final VoidCallback onTap;

  const _StackWidget({
    super.key,
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
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap();
            },
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
                      color: GameColors.accent.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  if (widget.isRecentlyCleared)
                    BoxShadow(
                      color: GameColors.palette[2]
                          .withValues(alpha: 0.4 * _glowAnimation.value),
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

/// Animated overlay for moving layer
class _AnimatedLayerOverlay extends StatefulWidget {
  final dynamic animatingLayer; // AnimatingLayer
  final GlobalKey fromKey;
  final GlobalKey toKey;
  final VoidCallback onComplete;

  const _AnimatedLayerOverlay({
    required this.animatingLayer,
    required this.fromKey,
    required this.toKey,
    required this.onComplete,
  });

  @override
  State<_AnimatedLayerOverlay> createState() => _AnimatedLayerOverlayState();
}

class _AnimatedLayerOverlayState extends State<_AnimatedLayerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _curveAnimation;
  late Animation<double> _scaleAnimation;
  Offset _startPos = Offset.zero;
  Offset _endPos = Offset.zero;
  double _arcHeight = 60.0;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Main curve for position
    _curveAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Squash/stretch effect - compress slightly at end
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 0.95)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 20,
      ),
    ]).animate(_controller);

    // Wait for next frame to get positions, then animate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculatePositions();
      _controller.forward().then((_) {
        widget.onComplete();
      });
    });
  }

  void _calculatePositions() {
    final fromBox = widget.fromKey.currentContext?.findRenderObject() as RenderBox?;
    final toBox = widget.toKey.currentContext?.findRenderObject() as RenderBox?;

    if (fromBox == null || toBox == null) {
      widget.onComplete();
      return;
    }

    // Get global positions
    final fromGlobal = fromBox.localToGlobal(Offset.zero);
    final toGlobal = toBox.localToGlobal(Offset.zero);

    // Calculate position of top layer on source stack
    final fromLayerY = fromGlobal.dy + GameSizes.stackHeight - GameSizes.layerHeight - 2;
    
    // Calculate position where layer should land on destination stack (top of stack)
    final toLayerY = toGlobal.dy + GameSizes.stackHeight - GameSizes.layerHeight - 2;

    setState(() {
      _startPos = Offset(fromGlobal.dx, fromLayerY);
      _endPos = Offset(toGlobal.dx, toLayerY);
      
      // Arc height based on distance
      final distance = (_endPos - _startPos).distance;
      _arcHeight = (distance * 0.3).clamp(40.0, 80.0);
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
      animation: _controller,
      builder: (context, child) {
        // Calculate arc trajectory
        final t = _curveAnimation.value;
        final x = _startPos.dx + (_endPos.dx - _startPos.dx) * t;
        
        // Parabolic arc: goes up then down
        final arcProgress = 4 * t * (1 - t); // Peaks at t=0.5
        final y = _startPos.dy + (_endPos.dy - _startPos.dy) * t - _arcHeight * arcProgress;

        return Positioned(
          left: x,
          top: y,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: GameSizes.stackWidth,
              height: GameSizes.layerHeight,
              decoration: BoxDecoration(
                color: GameColors.getColor(widget.animatingLayer.layer.colorIndex),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
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

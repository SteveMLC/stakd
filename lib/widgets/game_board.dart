import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/stack_model.dart';
import '../services/haptic_service.dart';
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

class _GameBoardState extends State<GameBoard>
    with SingleTickerProviderStateMixin {
  late final Map<int, GlobalKey> _stackKeys;
  List<ParticleBurstData> _currentBursts = [];
  int? _showComboMultiplier;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    // Use provided keys or create new ones
    _stackKeys = widget.stackKeys ?? {};

    // Initialize shake animation
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -8.0, end: 6.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 6.0, end: -6.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stacks = widget.gameState.stacks;
    if (stacks.isEmpty) {
      return const Center(
        child: Text(
          'Loading...',
          style: TextStyle(color: GameColors.textMuted),
        ),
      );
    }

    // Ensure we have keys for all stacks
    for (int i = 0; i < stacks.length; i++) {
      _stackKeys.putIfAbsent(i, () => GlobalKey());
    }

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate optimal layout based on number of stacks
                final stackCount = stacks.length;
                final maxStacksPerRow = _getStacksPerRow(
                  stackCount,
                  constraints.maxWidth,
                );
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
                        final endIndex = (startIndex + maxStacksPerRow).clamp(
                          0,
                          stackCount,
                        );
                        final rowStacks = stacks.sublist(startIndex, endIndex);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(rowStacks.length, (index) {
                              final actualIndex = startIndex + index;
                              final stack = rowStacks[index];
                              final isSelected =
                                  actualIndex ==
                                  widget.gameState.selectedStackIndex;
                              final isRecentlyCleared = widget
                                  .gameState
                                  .recentlyCleared
                                  .contains(actualIndex);

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
                                    final previousMoveCount =
                                        widget.gameState.moveCount;
                                    final previousCleared = List<int>.from(
                                      widget.gameState.recentlyCleared,
                                    );

                                    widget.gameState.onStackTap(actualIndex);
                                    widget.onTap?.call();

                                    if (widget.gameState.moveCount >
                                        previousMoveCount) {
                                      widget.onMove?.call();
                                    }

                                    final currentCleared =
                                        widget.gameState.recentlyCleared;
                                    if (currentCleared.isNotEmpty &&
                                        !listEquals(
                                          previousCleared,
                                          currentCleared,
                                        )) {
                                      widget.onClear?.call();
                                      _triggerParticleBursts(currentCleared);

                                      // Haptic success pattern for stack complete
                                      haptics.successPattern();

                                      // Show combo popup if combo > 1
                                      final currentCombo =
                                          widget.gameState.currentCombo;
                                      if (currentCombo > 1) {
                                        setState(() {
                                          _showComboMultiplier = currentCombo;
                                        });

                                        // Haptic combo burst
                                        haptics.comboBurst(currentCombo);

                                        // Trigger screen shake for 4x+ combos
                                        if (currentCombo >= 4) {
                                          _shakeController.forward(from: 0);
                                        }
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
                        fromKey:
                            _stackKeys[widget
                                .gameState
                                .animatingLayer!
                                .fromStackIndex]!,
                        toKey:
                            _stackKeys[widget
                                .gameState
                                .animatingLayer!
                                .toStackIndex]!,
                        onComplete: () {
                          widget.gameState.completeMove();
                          widget.onMove?.call();
                        },
                      ),
                    // Combo popup overlay
                    if (_showComboMultiplier != null &&
                        _showComboMultiplier! > 1)
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
          ),
        );
      },
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
      final renderBox =
          stackKey!.currentContext!.findRenderObject() as RenderBox?;
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

      bursts.add(
        ParticleBurstData(
          center: center,
          color: color,
          particleCount: 18,
          lifetime: const Duration(milliseconds: 500),
        ),
      );
    }

    if (bursts.isNotEmpty) {
      setState(() {
        _currentBursts = bursts;
      });
    }
  }
}

class _StackWidget extends StatefulWidget {
  final GameStack stack;
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
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late Animation<double> _glowAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GameDurations.stackClear,
    );
    _bounceAnimation = Tween<double>(
      begin: 0,
      end: -8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _glowAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    // Pulse animation for nearing completion glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant _StackWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecentlyCleared && !oldWidget.isRecentlyCleared) {
      _controller.forward().then((_) => _controller.reverse());
    }

    // Start/stop pulsing based on nearing completion
    final nearingCompletion = _isNearingCompletion();
    if (nearingCompletion && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!nearingCompletion && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  /// Check if stack is nearing completion (3+ matching layers)
  bool _isNearingCompletion() {
    final layers = widget.stack.layers;
    if (layers.length < 3) return false;
    // Check if all layers have the same color
    final firstColor = layers.first.colorIndex;
    return layers.every((l) => l.colorIndex == firstColor);
  }

  /// Get the completion progress (0.0 to 1.0)
  double _getCompletionProgress() {
    final layers = widget.stack.layers;
    if (layers.isEmpty) return 0.0;
    final firstColor = layers.first.colorIndex;
    if (!layers.every((l) => l.colorIndex == firstColor)) return 0.0;
    // 3 layers = 0.6, 4 layers = 0.8, 5 layers = 1.0
    return (layers.length / 5.0).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layerCount = widget.stack.layers.length;
    final isComplete = widget.stack.isComplete;
    final nearingCompletion = _isNearingCompletion();
    final completionProgress = _getCompletionProgress();
    final semanticsLabel = StringBuffer('Stack ${widget.index + 1}, ')
      ..write('$layerCount layer');
    if (layerCount != 1) {
      semanticsLabel.write('s');
    }
    if (isComplete) {
      semanticsLabel.write(', complete');
    }
    if (widget.isSelected) {
      semanticsLabel.write(', selected');
    }

    // Get the stack's dominant color for glow effect
    final glowColor = widget.stack.layers.isNotEmpty
        ? GameColors.getColor(widget.stack.layers.first.colorIndex)
        : GameColors.accent;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: semanticsLabel.toString(),
      hint: widget.isSelected ? 'Selected' : 'Double tap to select or move',
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _pulseController]),
        builder: (context, child) {
          final pulseValue = nearingCompletion ? _pulseAnimation.value : 0.0;

          return Transform.translate(
            offset: Offset(0, widget.isSelected ? -8 : _bounceAnimation.value),
            child: GestureDetector(
              onTap: () {
                haptics.lightTap();
                widget.onTap();
              },
              child: AnimatedContainer(
                duration: GameDurations.buttonPress,
                width: GameSizes.stackWidth,
                height: GameSizes.stackHeight,
                decoration: BoxDecoration(
                  color: GameColors.empty,
                  borderRadius: BorderRadius.circular(
                    GameSizes.stackBorderRadius,
                  ),
                  border: Border.all(
                    color: widget.isSelected
                        ? GameColors.accent
                        : widget.isRecentlyCleared
                            ? GameColors.palette[2]
                            : nearingCompletion
                                ? glowColor.withValues(alpha: 0.6 + pulseValue * 0.4)
                                : GameColors.empty,
                    width: widget.isSelected ? 3 : nearingCompletion ? 2.5 : 2,
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
                        color: GameColors.palette[2].withValues(
                          alpha: 0.4 * _glowAnimation.value,
                        ),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    // Glow effect for nearing completion (3+ matching layers)
                    if (nearingCompletion && !widget.isSelected && !widget.isRecentlyCleared)
                      BoxShadow(
                        color: glowColor.withValues(
                          alpha: (0.2 + pulseValue * 0.3) * completionProgress,
                        ),
                        blurRadius: 8 + completionProgress * 8,
                        spreadRadius: completionProgress * 3,
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
      ),
    );
  }

  Widget _buildLayers() {
    final layers = widget.stack.layers;
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
  final AnimatingLayer animatingLayer;
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
  late Animation<double> _scaleXAnimation;
  late Animation<double> _scaleYAnimation;
  Offset _startPos = Offset.zero;
  Offset _endPos = Offset.zero;
  double _arcHeight = 60.0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    // Main curve for position - ease out for natural arc
    _curveAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuad,
    );

    // Horizontal scale: squash wide on pickup (1.1), stretch narrow on drop (0.85)
    _scaleXAnimation = TweenSequence<double>([
      // Pickup: squash wide (1.0 → 1.1)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      // Travel: back to normal (1.1 → 1.0)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 50,
      ),
      // Drop: stretch narrow (1.0 → 0.85)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.85)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      // Bounce back: elasticOut (0.85 → 1.0)
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 20,
      ),
    ]).animate(_controller);

    // Vertical scale: squash short on pickup (0.85), stretch tall on drop (1.1)
    _scaleYAnimation = TweenSequence<double>([
      // Pickup: squash short (1.0 → 0.85)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.85)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      // Travel: back to normal (0.85 → 1.0)
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 1.0)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 50,
      ),
      // Drop: stretch tall (1.0 → 1.15)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      // Bounce back: elasticOut (1.15 → 1.0)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 20,
      ),
    ]).animate(_controller);

    // Wait for next frame to get positions, then animate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculatePositions();
      _controller.forward().then((_) {
        // Medium impact haptic when layer lands
        haptics.mediumImpact();
        widget.onComplete();
      });
    });
  }

  void _calculatePositions() {
    final fromBox =
        widget.fromKey.currentContext?.findRenderObject() as RenderBox?;
    final toBox = widget.toKey.currentContext?.findRenderObject() as RenderBox?;

    if (fromBox == null || toBox == null) {
      widget.onComplete();
      return;
    }

    // Get global positions
    final fromGlobal = fromBox.localToGlobal(Offset.zero);
    final toGlobal = toBox.localToGlobal(Offset.zero);

    // Calculate position of top layer on source stack
    final fromLayerY =
        fromGlobal.dy + GameSizes.stackHeight - GameSizes.layerHeight - 2;

    // Calculate position where layer should land on destination stack (top of stack)
    final toLayerY =
        toGlobal.dy + GameSizes.stackHeight - GameSizes.layerHeight - 2;

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

  /// Calculate quadratic bezier point for arc trajectory
  Offset _quadraticBezier(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _curveAnimation.value;

        // Quadratic bezier arc trajectory
        // Control point is above the midpoint for a nice arc
        final midX = (_startPos.dx + _endPos.dx) / 2;
        final minY = _startPos.dy < _endPos.dy ? _startPos.dy : _endPos.dy;
        final controlPoint = Offset(midX, minY - _arcHeight);

        final pos = _quadraticBezier(_startPos, controlPoint, _endPos, t);

        // Get the layer color for glow effect
        final layerColor = GameColors.getColor(
          widget.animatingLayer.layer.colorIndex,
        );

        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(
              _scaleXAnimation.value,
              _scaleYAnimation.value,
              1.0,
            ),
            child: Container(
              width: GameSizes.stackWidth,
              height: GameSizes.layerHeight,
              decoration: BoxDecoration(
                color: layerColor,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  // Drop shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                  // Color glow while moving
                  BoxShadow(
                    color: layerColor.withValues(alpha: 0.4 * (1 - t)),
                    blurRadius: 12,
                    spreadRadius: 2,
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

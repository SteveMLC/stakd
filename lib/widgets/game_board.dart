import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/stack_model.dart';
import '../services/haptic_service.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../utils/theme_colors.dart';
import 'particles/particle_burst.dart';
import 'particles/confetti_overlay.dart';
import 'combo_popup.dart';
import 'color_flash_overlay.dart';
import 'chain_text_popup.dart';

/// Game board widget - displays all stacks and handles interactions
class GameBoard extends StatefulWidget {
  final GameState gameState;
  final VoidCallback? onTap;
  final VoidCallback? onMove;
  final VoidCallback? onClear;
  final void Function(int chainLevel)? onChain;
  final Map<int, GlobalKey>? stackKeys;
  final void Function(int stackIndex)? onStackTapOverride;
  final List<int>? highlightedStacks;

  const GameBoard({
    super.key,
    required this.gameState,
    this.onTap,
    this.onMove,
    this.onClear,
    this.onChain,
    this.stackKeys,
    this.onStackTapOverride,
    this.highlightedStacks,
  });

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard>
    with SingleTickerProviderStateMixin {
  late final Map<int, GlobalKey> _stackKeys;
  List<ParticleBurstData> _currentBursts = [];
  int? _showComboMultiplier;
  int? _showChainLevel;
  Color? _flashColor;
  bool _showConfetti = false;
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
                                  isMultiGrabMode:
                                      widget.gameState.isMultiGrabMode,
                                  multiGrabCount:
                                      widget.gameState.multiGrabCount,
                                  onTap: () {
                                    // Check if there's an override handler (for power-up selection)
                                    if (widget.onStackTapOverride != null) {
                                      widget.onStackTapOverride!(actualIndex);
                                      widget.onTap?.call();
                                      return;
                                    }

                                    final previousMoveCount =
                                        widget.gameState.moveCount;
                                    final previousCleared = List<int>.from(
                                      widget.gameState.recentlyCleared,
                                    );
                                    final previousSelectedStack =
                                        widget.gameState.selectedStackIndex;

                                    widget.gameState.onStackTap(actualIndex);
                                    widget.onTap?.call();

                                    // Check if move was made
                                    final moveMade =
                                        widget.gameState.moveCount >
                                        previousMoveCount;

                                    if (moveMade) {
                                      widget.onMove?.call();
                                    } else {
                                      // Check if this was an invalid move attempt
                                      // (tried to move to a stack that can't accept the layer)
                                      final wasSourceSelected =
                                          previousSelectedStack >= 0 &&
                                          previousSelectedStack != actualIndex;
                                      if (wasSourceSelected) {
                                        final sourceStack = widget
                                            .gameState
                                            .stacks[previousSelectedStack];
                                        final targetStack = widget
                                            .gameState
                                            .stacks[actualIndex];

                                        // Invalid move: has source layer but target can't accept it
                                        if (!sourceStack.isEmpty &&
                                            !targetStack.canAccept(
                                              sourceStack.topLayer!,
                                            )) {
                                          // Play error sound
                                          AudioService().playError();
                                          // Haptic feedback for invalid move
                                          haptics.error();
                                          // Trigger shake animation
                                          _shakeController.forward(from: 0);
                                        }
                                      }
                                    }

                                    final currentCleared =
                                        widget.gameState.recentlyCleared;
                                    if (currentCleared.isNotEmpty &&
                                        !listEquals(
                                          previousCleared,
                                          currentCleared,
                                        )) {
                                      widget.onClear?.call();

                                      // Get chain level (number of stacks cleared in one move)
                                      final chainLevel =
                                          widget.gameState.currentChainLevel;

                                      // Trigger appropriate effects based on chain level
                                      _triggerChainEffects(
                                        currentCleared,
                                        chainLevel,
                                      );
                                    }
                                  },
                                  onMultiGrab: () {
                                    widget.gameState.activateMultiGrab(
                                      actualIndex,
                                    );
                                    widget.onTap?.call();
                                  },
                                  isPowerUpHighlighted:
                                      widget.highlightedStacks?.contains(
                                        actualIndex,
                                      ) ??
                                      false,
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
                          // Show combo popup for consecutive correct moves (3+)
                          final combo = widget.gameState.currentCombo;
                          if (combo >= 3) {
                            setState(() {
                              _showComboMultiplier = combo;
                            });
                          }
                        },
                      ),
                    // Chain text popup overlay
                    if (_showChainLevel != null && _showChainLevel! >= 2)
                      ChainTextPopupOverlay(
                        chainLevel: _showChainLevel!,
                        onComplete: () {
                          setState(() {
                            _showChainLevel = null;
                          });
                        },
                      ),
                    // Combo popup overlay (shows after chain popup if both)
                    if (_showComboMultiplier != null &&
                        _showComboMultiplier! >= 3)
                      Positioned(
                        bottom: 120,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ComboPopup(
                            comboMultiplier: _showComboMultiplier!,
                            onComplete: () {
                              setState(() {
                                _showComboMultiplier = null;
                              });
                            },
                          ),
                        ),
                      ),
                    // Color flash overlay for chains
                    if (_flashColor != null)
                      Positioned.fill(
                        child: ColorFlashOverlay(
                          color: _flashColor!,
                          duration: const Duration(milliseconds: 400),
                          onComplete: () {
                            setState(() {
                              _flashColor = null;
                            });
                          },
                        ),
                      ),
                    // Confetti for mega chains (4+)
                    if (_showConfetti)
                      Positioned.fill(
                        child: ConfettiOverlay(
                          colors: GameColors.palette,
                          confettiCount: 60,
                          duration: const Duration(seconds: 2),
                        ),
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

  void _triggerParticleBursts(List<int> clearedIndices, [int chainLevel = 1]) {
    if (clearedIndices.isEmpty) return;

    // Skip particles if theme has them disabled
    if (!ThemeColors.hasParticles) return;

    final bursts = <ParticleBurstData>[];

    // Scale particle count and lifetime based on chain level
    final particleCount = 24 + (chainLevel - 1) * 12; // 24, 36, 48, 60...
    final lifetime = Duration(milliseconds: 600 + (chainLevel - 1) * 100);

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

      // Get the stack's color (use theme-aware colors)
      final stack = widget.gameState.stacks[stackIndex];
      final topLayer = stack.layers.isNotEmpty ? stack.layers.first : null;
      final color = topLayer != null
          ? ThemeColors.getColor(topLayer.colorIndex)
          : GameColors.accent;

      bursts.add(
        ParticleBurstData(
          center: center,
          color: color,
          particleCount: particleCount,
          lifetime: lifetime,
        ),
      );
    }

    if (bursts.isNotEmpty) {
      setState(() {
        _currentBursts = bursts;
      });
    }
  }

  Color _getChainFlashColor(int chainLevel) {
    switch (chainLevel) {
      case 2:
        return const Color(0xFFFFD700); // Gold
      case 3:
        return const Color(0xFFFF8C00); // Orange
      case 4:
        return const Color(0xFFFF4500); // Red-Orange
      default:
        if (chainLevel >= 5) {
          return const Color(0xFF9400D3); // Purple for insane chains
        }
        return GameColors.accent;
    }
  }

  /// Trigger chain reaction effects based on chain level
  void _triggerChainEffects(List<int> clearedIndices, int chainLevel) {
    // Always trigger particle bursts
    _triggerParticleBursts(clearedIndices, chainLevel);

    // Basic haptic for single clear
    if (chainLevel <= 1) {
      haptics.successPattern();
      return;
    }

    // Notify parent about chain for achievements
    widget.onChain?.call(chainLevel);

    // Chain level 2+: Show chain popup and enhanced effects
    setState(() {
      _showChainLevel = chainLevel;
      _flashColor = _getChainFlashColor(chainLevel);
    });

    // Play chain sound
    AudioService().playChain(chainLevel);

    // Chain-specific haptic
    haptics.chainReaction(chainLevel);

    // Screen shake - intensity based on chain level
    if (chainLevel >= 2) {
      _shakeController.forward(from: 0);
    }

    // Confetti for mega chains (4+)
    if (chainLevel >= 4) {
      setState(() {
        _showConfetti = true;
      });
      // Auto-hide confetti after animation
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showConfetti = false;
          });
        }
      });
    }

    // Combo is now handled per-move in onComplete
  }
}

class _StackWidget extends StatefulWidget {
  final GameStack stack;
  final int index;
  final bool isSelected;
  final bool isRecentlyCleared;
  final bool isMultiGrabMode;
  final int multiGrabCount;
  final VoidCallback onTap;
  final VoidCallback onMultiGrab;
  final bool isPowerUpHighlighted;

  const _StackWidget({
    super.key,
    required this.stack,
    required this.index,
    required this.isSelected,
    required this.isRecentlyCleared,
    required this.isMultiGrabMode,
    required this.multiGrabCount,
    required this.onTap,
    required this.onMultiGrab,
    this.isPowerUpHighlighted = false,
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
  late AnimationController _multiGrabPulseController;
  late Animation<double> _multiGrabPulseAnimation;
  late AnimationController _multiGrabIndicatorController;
  late Animation<double> _multiGrabIndicatorAnimation;
  late AnimationController _completionGlowController;
  late Animation<double> _completionGlowAnimation;
  bool _isLongPressing = false;

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

    // Multi-grab pulse animation
    _multiGrabPulseController = AnimationController(
      vsync: this,
      duration: GameDurations.multiGrabPulse,
    );
    _multiGrabPulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _multiGrabPulseController,
        curve: Curves.easeInOut,
      ),
    );

    _multiGrabIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _multiGrabIndicatorAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _multiGrabIndicatorController,
        curve: Curves.easeInOut,
      ),
    );

    // Completion glow pulse (1.0 → 1.5 → 1.0 over 500ms)
    _completionGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _completionGlowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.5,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.5,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_completionGlowController);

    _syncMultiGrabIndicator();
  }

  @override
  void didUpdateWidget(covariant _StackWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecentlyCleared && !oldWidget.isRecentlyCleared) {
      _controller.forward().then((_) => _controller.reverse());
      // Trigger completion glow pulse
      _completionGlowController.forward(from: 0);
      // Haptic: medium impact on column completion
      haptics.mediumImpact();
    }

    // Start/stop pulsing based on nearing completion
    final nearingCompletion = _isNearingCompletion();
    if (nearingCompletion && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!nearingCompletion && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    // Multi-grab pulse animation
    if (widget.isMultiGrabMode && widget.isSelected) {
      if (!_multiGrabPulseController.isAnimating) {
        _multiGrabPulseController.repeat(reverse: true);
      }
    } else {
      if (_multiGrabPulseController.isAnimating) {
        _multiGrabPulseController.stop();
        _multiGrabPulseController.reset();
      }
    }
    _syncMultiGrabIndicator();
    if (widget.stack.isEmpty && _isLongPressing) {
      _isLongPressing = false;
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
    _multiGrabPulseController.dispose();
    _multiGrabIndicatorController.dispose();
    _completionGlowController.dispose();
    super.dispose();
  }

  bool get _hasMultiGrabOpportunity => widget.stack.topGroupSize >= 2;

  bool get _shouldShowMultiGrabIndicator {
    final isMultiGrabActive = widget.isMultiGrabMode && widget.isSelected;
    return _hasMultiGrabOpportunity && !isMultiGrabActive;
  }

  void _syncMultiGrabIndicator() {
    if (_shouldShowMultiGrabIndicator) {
      if (!_multiGrabIndicatorController.isAnimating) {
        _multiGrabIndicatorController.repeat(reverse: true);
      }
    } else {
      if (_multiGrabIndicatorController.isAnimating) {
        _multiGrabIndicatorController.stop();
        _multiGrabIndicatorController.reset();
      }
    }
  }

  void _setLongPressing(bool value) {
    if (_isLongPressing == value) return;
    setState(() {
      _isLongPressing = value;
    });
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (widget.stack.isEmpty) return;
    _setLongPressing(true);
    haptics.mediumImpact();
  }

  void _onLongPress() {
    if (widget.stack.isEmpty) return;
    final topGroup = widget.stack.getTopGroup();
    if (topGroup.length > 1) {
      // Multi-grab activated!
      haptics.successPattern();
      widget.onMultiGrab();
      StorageService().setMultiGrabUsed();
      StorageService().incrementMultiGrabUsage();
    } else {
      // Only one layer, treat as normal tap
      widget.onTap();
    }
    _setLongPressing(false);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    // Long press completed
    _setLongPressing(false);
  }

  void _onLongPressCancel() {
    // Long press cancelled
    _setLongPressing(false);
  }

  @override
  Widget build(BuildContext context) {
    final layerCount = widget.stack.layers.length;
    final isComplete = widget.stack.isComplete;
    final nearingCompletion = _isNearingCompletion();
    final completionProgress = _getCompletionProgress();
    final isMultiGrabActive = widget.isMultiGrabMode && widget.isSelected;
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
    if (isMultiGrabActive) {
      semanticsLabel.write(', multi-grab ${widget.multiGrabCount} layers');
    }

    // Get the stack's dominant color for glow effect
    final glowColor = widget.stack.layers.isNotEmpty
        ? GameColors.getColor(widget.stack.layers.first.colorIndex)
        : GameColors.accent;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: semanticsLabel.toString(),
      hint: widget.isSelected
          ? (isMultiGrabActive ? 'Multi-grab active' : 'Selected')
          : 'Tap to select, hold for multi-grab',
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _controller,
          _pulseController,
          _multiGrabPulseController,
          _completionGlowController,
        ]),
        builder: (context, child) {
          final pulseValue = nearingCompletion ? _pulseAnimation.value : 0.0;
          final multiGrabPulse = isMultiGrabActive
              ? _multiGrabPulseAnimation.value
              : 0.0;

          // Enhanced lift effect for multi-grab
          final liftOffset = isMultiGrabActive
              ? -12.0 - (multiGrabPulse * 4)
              : (widget.isSelected ? -8.0 : _bounceAnimation.value);

          final scale = isMultiGrabActive
              ? 1.04 + (multiGrabPulse * 0.01)
              : (widget.isSelected ? 1.02 : 1.0);

          return Transform.translate(
            offset: Offset(0, liftOffset),
            child: AnimatedScale(
              scale: scale,
              duration: GameDurations.buttonPress,
              curve: Curves.easeOutCubic,
              child: GestureDetector(
                onTap: () {
                  haptics.lightTap();
                  widget.onTap();
                },
                onLongPressStart: _onLongPressStart,
                onLongPress: _onLongPress,
                onLongPressEnd: _onLongPressEnd,
                onLongPressCancel: _onLongPressCancel,
                child: SizedBox(
                  width: GameSizes.stackWidth,
                  height: GameSizes.getStackHeight(widget.stack.maxDepth),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: GameDurations.buttonPress,
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              GameColors.empty.withValues(alpha: 0.85),
                              GameColors.empty,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            GameSizes.stackBorderRadius,
                          ),
                          border: Border.all(
                            color: widget.isPowerUpHighlighted
                                ? GameColors.zen.withValues(alpha: 0.9)
                                : isMultiGrabActive
                                ? glowColor.withValues(
                                    alpha: 0.8 + multiGrabPulse * 0.2,
                                  )
                                : widget.isSelected
                                ? GameColors.accent
                                : widget.isRecentlyCleared
                                ? GameColors.palette[2]
                                : nearingCompletion
                                ? glowColor.withValues(
                                    alpha: 0.6 + pulseValue * 0.4,
                                  )
                                : GameColors.empty,
                            width: widget.isPowerUpHighlighted
                                ? 3
                                : (isMultiGrabActive
                                      ? 4
                                      : (widget.isSelected
                                            ? 3
                                            : nearingCompletion
                                            ? 2.5
                                            : 2)),
                          ),
                          boxShadow: [
                            // Power-up highlight glow (magnet eligible)
                            if (widget.isPowerUpHighlighted)
                              BoxShadow(
                                color: GameColors.zen.withValues(alpha: 0.5),
                                blurRadius: 16,
                                spreadRadius: 4,
                              ),
                            // Multi-grab glow effect (strongest)
                            if (isMultiGrabActive)
                              BoxShadow(
                                color: glowColor.withValues(
                                  alpha: 0.5 + multiGrabPulse * 0.3,
                                ),
                                blurRadius: 16 + multiGrabPulse * 8,
                                spreadRadius: 4 + multiGrabPulse * 2,
                              ),
                            if (widget.isSelected && !isMultiGrabActive)
                              BoxShadow(
                                color: GameColors.accent.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            if (widget.isRecentlyCleared)
                              BoxShadow(
                                color: GameColors.palette[2].withValues(
                                  alpha:
                                      0.4 *
                                      _glowAnimation.value *
                                      (_completionGlowController.isAnimating
                                          ? _completionGlowAnimation.value
                                          : 1.0),
                                ),
                                blurRadius:
                                    16 *
                                    (_completionGlowController.isAnimating
                                        ? _completionGlowAnimation.value
                                        : 1.0),
                                spreadRadius:
                                    4 *
                                    (_completionGlowController.isAnimating
                                        ? _completionGlowAnimation.value
                                        : 1.0),
                              ),
                            // Glow effect for nearing completion (3+ matching layers)
                            if (nearingCompletion &&
                                !widget.isSelected &&
                                !widget.isRecentlyCleared &&
                                !isMultiGrabActive)
                              BoxShadow(
                                color: glowColor.withValues(
                                  alpha:
                                      (0.2 + pulseValue * 0.3) *
                                      completionProgress,
                                ),
                                blurRadius: 8 + completionProgress * 8,
                                spreadRadius: completionProgress * 3,
                              ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
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
                      if (_isLongPressing)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _LongPressRing(
                              color: glowColor,
                              borderRadius: GameSizes.stackBorderRadius + 6,
                            ),
                          ),
                        ),
                      if (_shouldShowMultiGrabIndicator)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: _MultiGrabIndicator(
                            count: widget.stack.topGroupSize,
                            animation: _multiGrabIndicatorAnimation,
                          ),
                        ),
                    ],
                  ),
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

    final isMultiGrabActive = widget.isMultiGrabMode && widget.isSelected;
    final topGroupSize = widget.stack.topGroupSize;
    final multiGrabPulse = isMultiGrabActive
        ? _multiGrabPulseAnimation.value
        : 0.0;

    // Check if texture skins are enabled
    final textureSkinsEnabled = StorageService().getTextureSkinsEnabled();

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: layers.asMap().entries.map<Widget>((entry) {
        final index = entry.key;
        final layer = entry.value;
        final gradientColors = GameColors.getGradient(layer.colorIndex);

        // Check if this layer is part of the grab zone (top N layers)
        final isInGrabZone =
            isMultiGrabActive && index >= layers.length - topGroupSize;

        // Visual indicator for layers being grabbed
        final grabZoneDecoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
          // Texture skin overlay when enabled
          image: textureSkinsEnabled
              ? const DecorationImage(
                  image: AssetImage(
                    'assets/images/textures/cherry_blossom.png',
                  ),
                  fit: BoxFit.cover,
                  opacity: 0.3,
                )
              : null,
          borderRadius: BorderRadius.circular(4),
          border: isInGrabZone
              ? Border.all(
                  color: Colors.white.withValues(
                    alpha: 0.6 + multiGrabPulse * 0.4,
                  ),
                  width: 2,
                )
              : null,
          boxShadow: isInGrabZone
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(
                      alpha: 0.3 + multiGrabPulse * 0.2,
                    ),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        );

        return Transform.translate(
          offset: isInGrabZone ? Offset(0, -2.0 * multiGrabPulse) : Offset.zero,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            height: GameSizes.layerHeight,
            margin: const EdgeInsets.only(bottom: 2),
            decoration: grabZoneDecoration,
            child: Stack(
              children: [
                Positioned(
                  top: 2,
                  left: 4,
                  right: 4,
                  height: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 1,
                  left: 3,
                  right: 3,
                  height: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LongPressRing extends StatefulWidget {
  final Color color;
  final double borderRadius;

  const _LongPressRing({required this.color, required this.borderRadius});

  @override
  State<_LongPressRing> createState() => _LongPressRingState();
}

class _LongPressRingState extends State<_LongPressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.95,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        final opacity = 0.5 - (_scale.value - 0.95) * 1.2;
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: widget.color.withValues(alpha: opacity.clamp(0.15, 0.5)),
                width: 3,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MultiGrabIndicator extends StatelessWidget {
  final int count;
  final Animation<double> animation;

  const _MultiGrabIndicator({required this.count, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final pulse = animation.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3 + pulse * 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3 + pulse * 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.layers,
                size: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 2),
              Text(
                'x$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        );
      },
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
  bool _positionsReady = false;

  @override
  void initState() {
    super.initState();

    // Slightly longer animation for multi-grab
    final duration = widget.animatingLayer.isMultiGrab
        ? const Duration(milliseconds: 320)
        : const Duration(milliseconds: 280);

    _controller = AnimationController(vsync: this, duration: duration);

    // Main curve for position - ease out for natural arc
    _curveAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuad,
    );

    // Horizontal scale: squash wide on pickup (1.08), stretch narrow on drop (0.92)
    _scaleXAnimation = TweenSequence<double>([
      // Pickup: squash wide (1.0 → 1.08)
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      // Travel: back to normal (1.08 → 1.0)
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.linear)),
        weight: 50,
      ),
      // Drop: stretch narrow (1.0 → 0.92)
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.92,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      // Bounce back: elasticOut (0.92 → 1.0)
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.92,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 20,
      ),
    ]).animate(_controller);

    // Vertical scale: squash short on pickup (0.92), stretch tall on drop (1.08)
    _scaleYAnimation = TweenSequence<double>([
      // Pickup: squash short (1.0 → 0.92)
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.92,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      // Travel: back to normal (0.92 → 1.0)
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.92,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.linear)),
        weight: 50,
      ),
      // Drop: stretch tall (1.0 → 1.08)
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      // Bounce back: elasticOut (1.08 → 1.0)
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 20,
      ),
    ]).animate(_controller);

    // Wait for next frame to get positions, then animate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculatePositions();
      _controller.forward().then((_) {
        // Haptic feedback - stronger for multi-grab
        if (widget.animatingLayer.isMultiGrab) {
          haptics.successPattern();
        } else {
          haptics.mediumImpact();
        }
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

    // For multi-grab, account for multiple layers height
    final layerCount = widget.animatingLayer.layerCount;
    final totalHeight =
        GameSizes.layerHeight * layerCount + (2 * (layerCount - 1));

    // Use actual rendered stack height (dynamic based on maxDepth)
    final fromStackHeight = fromBox.size.height;
    final toStackHeight = toBox.size.height;

    // Calculate position of top layer on source stack
    final fromLayerY = fromGlobal.dy + fromStackHeight - totalHeight - 2;

    // Calculate position where layers should land on destination stack
    final toLayerY = toGlobal.dy + toStackHeight - totalHeight - 2;

    setState(() {
      _startPos = Offset(fromGlobal.dx, fromLayerY);
      _endPos = Offset(toGlobal.dx, toLayerY);

      // Arc height based on distance - higher for multi-grab
      final distance = (_endPos - _startPos).distance;
      final baseArc = (distance * 0.3).clamp(40.0, 80.0);
      _arcHeight = widget.animatingLayer.isMultiGrab ? baseArc * 1.3 : baseArc;
      _positionsReady = true;
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
    final isMultiGrab = widget.animatingLayer.isMultiGrab;
    final allLayers = widget.animatingLayer.allLayers;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (!_positionsReady) return const SizedBox.shrink();
        final t = _curveAnimation.value;

        // Quadratic bezier arc trajectory
        // Control point is above the midpoint for a nice arc
        final midX = (_startPos.dx + _endPos.dx) / 2;
        final minY = _startPos.dy < _endPos.dy ? _startPos.dy : _endPos.dy;
        final controlPoint = Offset(midX, minY - _arcHeight);

        final pos = _quadraticBezier(_startPos, controlPoint, _endPos, t);

        // Get the layer color for glow effect (use top layer color)
        final layerColor = GameColors.getColor(
          widget.animatingLayer.layer.colorIndex,
        );

        // Build the layer(s) widget
        Widget layerWidget;
        if (isMultiGrab) {
          // Multi-layer animation - stack them together
          final layerCount = allLayers.length;
          final totalHeight =
              GameSizes.layerHeight * layerCount + (2 * (layerCount - 1));

          layerWidget = SizedBox(
            width: GameSizes.stackWidth,
            height: totalHeight,
            child: ClipRect(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: allLayers.toList().asMap().entries.map((entry) {
                  final layer = entry.value;
                  final isLast = entry.key == allLayers.length - 1;
                  final gradientColors = GameColors.getGradient(
                    layer.colorIndex,
                  );
                  return Container(
                    width: GameSizes.stackWidth,
                    height: GameSizes.layerHeight,
                    margin: EdgeInsets.only(bottom: isLast ? 0 : 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3 * (1 - t)),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 2,
                          left: 4,
                          right: 4,
                          height: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 1,
                          left: 3,
                          right: 3,
                          height: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        } else {
          // Single layer animation
          layerWidget = Container(
            width: GameSizes.stackWidth,
            height: GameSizes.layerHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: GameColors.getGradient(
                  widget.animatingLayer.layer.colorIndex,
                ),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 2,
                  left: 4,
                  right: 4,
                  height: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 1,
                  left: 3,
                  right: 3,
                  height: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  // Drop shadow - bigger for multi-grab
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isMultiGrab ? 0.4 : 0.3,
                    ),
                    blurRadius: isMultiGrab ? 12 : 8,
                    offset: Offset(0, isMultiGrab ? 6 : 4),
                  ),
                  // Color glow while moving - stronger for multi-grab
                  BoxShadow(
                    color: layerColor.withValues(
                      alpha: (isMultiGrab ? 0.6 : 0.4) * (1 - t),
                    ),
                    blurRadius: isMultiGrab ? 16 : 12,
                    spreadRadius: isMultiGrab ? 4 : 2,
                  ),
                ],
              ),
              child: layerWidget,
            ),
          ),
        );
      },
    );
  }
}

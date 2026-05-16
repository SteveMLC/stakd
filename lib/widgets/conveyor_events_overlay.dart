import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/stack_model.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../services/warehouse_economy_service.dart';
import '../utils/constants.dart';
import '../utils/theme_colors.dart';

/// Renders the conveyor-mechanic VFX overlay — floating cash popup +
/// SFX/haptic — keyed off `GameState.bayShippedSlotThisFrame`. Subscribes
/// to the passed `GameState` and animates whenever a bay ships.
///
/// Phase D.2: this is the MINIMUM viable VFX. Future polish (Phase D.3+):
///   - capture and animate the OLD bay's contents sliding right with
///     simultaneous fade
///   - arrival slide-in for the new delivery from off-screen-right
///   - per-crate drop-in stagger with elasticOut bounce
///
/// For Phase D.2 we ship the cash popup + audio + haptic. The bay swap
/// itself is instantaneous (data already swapped by Phase D.1's
/// `shipBayAndPullNext` call); the popup + sound is enough to signal
/// the moment so the player gets feedback.
class ConveyorEventsOverlay extends StatefulWidget {
  final GameState gameState;

  /// Resolves a stack slot index to an `Offset` in this overlay's
  /// local coordinates. Game board passes a function that walks the
  /// `_stackKeys` map to compute the global position of each slot.
  /// Returns null when the slot isn't yet laid out.
  final Offset? Function(int slotIndex) slotCenterResolver;

  /// Fallback payout shown when we can't compute the bay-specific
  /// value (e.g. lastShippedStack is null at the moment of fire).
  /// In normal operation the payout is derived from the shipped
  /// bay's contents via `ShipmentRewardCalculator.forBay`.
  final int fallbackPayout;

  const ConveyorEventsOverlay({
    super.key,
    required this.gameState,
    required this.slotCenterResolver,
    this.fallbackPayout = 100,
  });

  @override
  State<ConveyorEventsOverlay> createState() => _ConveyorEventsOverlayState();
}

class _ConveyorEventsOverlayState extends State<ConveyorEventsOverlay>
    with TickerProviderStateMixin {
  /// Active popups currently animating. List so chain-clears (multiple
  /// bays shipped in the same frame) all show their own popup.
  final List<_CashPopup> _activePopups = <_CashPopup>[];
  int _nextPopupId = 0;

  @override
  void initState() {
    super.initState();
    widget.gameState.addListener(_onGameStateChanged);
  }

  @override
  void didUpdateWidget(covariant ConveyorEventsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameState != widget.gameState) {
      oldWidget.gameState.removeListener(_onGameStateChanged);
      widget.gameState.addListener(_onGameStateChanged);
    }
  }

  @override
  void dispose() {
    widget.gameState.removeListener(_onGameStateChanged);
    for (final p in _activePopups) {
      p.controller.dispose();
    }
    _activePopups.clear();
    super.dispose();
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    final slot = widget.gameState.bayShippedSlotThisFrame;
    if (slot == null) return;

    // Capture pre-swap state BEFORE consuming the event.
    final shippedStack = widget.gameState.lastShippedStack;

    // Compute the actual cash value of the shipped bay via the v0.3
    // economy: $10/standard crate + $25/frozen crate, scaled by the
    // current combo multiplier. Falls back to `fallbackPayout` only if
    // the pre-swap stack isn't available (rare edge case).
    final int payout = shippedStack != null
        ? _computePayout(shippedStack, widget.gameState)
        : widget.fallbackPayout;

    // Consume the event flag so we don't double-fire on the next
    // notifyListeners. Done synchronously before kicking off the
    // animation.
    widget.gameState.consumeBayShippedEvent();

    final center = widget.slotCenterResolver(slot);
    if (center == null) {
      // Slot not laid out yet — skip visuals, still play audio +
      // haptic so the moment isn't completely silent.
      AudioService().playWin();
      haptics.successPattern();
      return;
    }

    AudioService().playWin();
    haptics.successPattern();

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    final popup = _CashPopup(
      id: _nextPopupId++,
      origin: center,
      controller: controller,
      shippedStack: shippedStack,
      payout: payout,
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) {
          controller.dispose();
          return;
        }
        setState(() {
          _activePopups.removeWhere((p) => p.id == popup.id);
        });
        controller.dispose();
      }
    });

    setState(() {
      _activePopups.add(popup);
    });
    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_activePopups.isEmpty) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Stack(
        children: _activePopups.expand((p) sync* {
          // Ghost slide-off (Phase D.3) — only when we captured the
          // pre-swap stack. Renders BELOW the arrival overlay so it
          // exits stage right while the new delivery slides in.
          if (p.shippedStack != null) {
            yield _ShippedGhostWidget(popup: p);
          }
          // Arrival slide-in cover (Phase D.4) — masks the slot for
          // ~350ms with a dark panel sliding in from the right, then
          // fades away to reveal the new delivery contents which
          // already populate the slot underneath.
          yield _ArrivalSlideWidget(popup: p);
          // Cash popup on top of everything else.
          yield _CashPopupWidget(popup: p);
        }).toList(),
      ),
    );
  }
}

class _CashPopup {
  final int id;
  final Offset origin;
  final AnimationController controller;
  /// Captured BEFORE the slot was replaced — drives the Phase D.3
  /// ghost slide-off animation. Null when no pre-swap state was
  /// available (e.g. legacy non-conveyor mode).
  final GameStack? shippedStack;
  /// Pre-computed cash value for this bay shipment. Captured at
  /// fire-time so the popup text is stable across the 700ms animation
  /// even if game state churns underneath.
  final int payout;
  _CashPopup({
    required this.id,
    required this.origin,
    required this.controller,
    required this.payout,
    this.shippedStack,
  });
}

/// Arrival slide-in cover for the new delivery. Renders a dark panel
/// at the SAME slot position the bay just shipped from. The panel
/// slides in from off-screen-right over the first 350ms of the run
/// then fades away by 600ms, revealing the new delivery layers that
/// already populate the slot underneath (Phase D.1's data flow swaps
/// them in synchronously when `shipBayAndPullNext` fires).
///
/// Gives the visual narrative: shipped bay slides off-right (ghost)
/// → fresh dock panel slides in from off-screen-right → panel fades
/// to reveal the new mixed cargo crates the player has to sort.
class _ArrivalSlideWidget extends StatelessWidget {
  final _CashPopup popup;
  const _ArrivalSlideWidget({required this.popup});

  @override
  Widget build(BuildContext context) {
    final stack = popup.shippedStack;
    if (stack == null) return const SizedBox.shrink();
    final stackHeight = GameSizes.getStackHeight(stack.maxDepth);
    return AnimatedBuilder(
      animation: popup.controller,
      builder: (context, _) {
        // Arrival fires AFTER the ghost has cleared (ghost is done by
        // t=0.55). Start the slide-in at t=0.40 so there's a brief
        // overlap with the ghost exit — feels like the conveyor belt
        // immediately delivering the next package.
        final t = popup.controller.value;
        if (t < 0.40) return const SizedBox.shrink();
        // Remap t=0.40..0.85 → 0..1 for the slide phase.
        final slideT = ((t - 0.40) / 0.45).clamp(0.0, 1.0);
        // easeOutCubic: 1 - (1-t)^3
        final eased = 1 - ((1 - slideT) * (1 - slideT) * (1 - slideT));
        // Slide from +400px (off-screen-right) to 0 (slot position).
        final dx = popup.origin.dx -
            GameSizes.stackWidth / 2 +
            400 * (1 - eased);
        final dy = popup.origin.dy - stackHeight / 2;
        // After slide completes, fade out 0.85 → 1.0 of run.
        final fadeT = ((t - 0.85) / 0.15).clamp(0.0, 1.0);
        final alpha = (1.0 - fadeT * 0.85).clamp(0.0, 1.0);
        return Positioned(
          left: dx,
          top: dy,
          child: Opacity(
            opacity: alpha,
            child: Container(
              width: GameSizes.stackWidth,
              height: stackHeight,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xCC0E1422),
                    Color(0xCC050810),
                  ],
                ),
                borderRadius: BorderRadius.circular(
                  GameSizes.stackBorderRadius,
                ),
                border: Border.all(
                  color: const Color(0xFF2E5A8C).withValues(alpha: 0.7),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2EE0C0).withValues(alpha: 0.2),
                    blurRadius: 10,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.local_shipping,
                size: 22,
                color: Color(0xFF6BD3FF),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Compute the cash value of a shipped bay using the same economy
/// rules `_onLevelComplete` uses at level end:
///   - $10 per standard crate, $25 per frozen crate
///   - scaled by current combo multiplier (rewards chained ships)
///
/// Wrinkle penalties (priority miss / time-bomb detonate / fragile
/// break) are NOT subtracted here — those still apply at payout time
/// in `_onLevelComplete`. The per-bay popup shows pre-penalty value
/// so the player sees the full reward for the bay they just shipped.
int _computePayout(GameStack bay, GameState gameState) {
  final standardCount = bay.layers.where((l) => !l.isFrozen).length;
  final frozenCount = bay.layers.where((l) => l.isFrozen).length;
  final combo = ShipmentRewardCalculator.comboMultiplier(
    gameState.currentCombo,
  );
  final reward = ShipmentRewardCalculator.forBay(
    standardCount: standardCount,
    frozenCount: frozenCount,
    comboMultiplier: combo,
  );
  return reward.cash;
}

/// Ghost render of the just-shipped bay sliding off-screen to the
/// right. Layered BELOW the cash popup. Renders the original crate
/// colors so the player sees the "completed cargo" leaving the dock.
class _ShippedGhostWidget extends StatelessWidget {
  final _CashPopup popup;
  const _ShippedGhostWidget({required this.popup});

  @override
  Widget build(BuildContext context) {
    final stack = popup.shippedStack;
    if (stack == null) return const SizedBox.shrink();
    final stackHeight = GameSizes.getStackHeight(stack.maxDepth);
    return AnimatedBuilder(
      animation: popup.controller,
      builder: (context, _) {
        // First 0.5 of the run = ghost slides right + fades; back
        // half it's gone. Slide distance ~600px right.
        final t = (popup.controller.value / 0.55).clamp(0.0, 1.0);
        // easeInCubic
        final eased = t * t * t;
        final dx = popup.origin.dx - GameSizes.stackWidth / 2 + 600 * eased;
        final dy = popup.origin.dy - stackHeight / 2;
        final alpha = (1.0 - t).clamp(0.0, 1.0);
        return Positioned(
          left: dx,
          top: dy,
          child: Opacity(
            opacity: alpha,
            child: SizedBox(
              width: GameSizes.stackWidth,
              height: stackHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: stack.layers.reversed.map((layer) {
                  final gradient = ThemeColors.getGradient(layer.colorIndex);
                  return Container(
                    width: GameSizes.stackWidth,
                    height: GameSizes.layerHeight,
                    margin: EdgeInsets.only(
                      bottom: GameSizes.layerMargin,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: gradient,
                      ),
                      borderRadius: BorderRadius.circular(
                        GameSizes.stackBorderRadius - 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gradient.first.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CashPopupWidget extends StatelessWidget {
  final _CashPopup popup;
  const _CashPopupWidget({required this.popup});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: popup.controller,
      builder: (context, _) {
        // 0 → 1 progress across the 700ms animation.
        final t = popup.controller.value;
        // Float up-left toward HUD: -80px Y, -40px X over the run.
        final dx = popup.origin.dx - 40 * t;
        final dy = popup.origin.dy - 80 * t;
        // Scale punches up to 1.4 by t=0.35 then settles back to 1.1.
        final scale = t < 0.35
            ? 1.0 + (1.4 - 1.0) * (t / 0.35)
            : 1.4 - (1.4 - 1.1) * ((t - 0.35) / 0.65);
        // Alpha fades out across the back half.
        final alpha = t < 0.55 ? 1.0 : (1.0 - (t - 0.55) / 0.45);
        return Positioned(
          left: dx - 32,
          top: dy - 16,
          child: Opacity(
            opacity: alpha.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFD93D).withValues(alpha: 0.85),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD93D).withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.attach_money,
                      size: 14,
                      color: Color(0xFFFFD93D),
                    ),
                    Text(
                      '+${popup.payout}',
                      style: const TextStyle(
                        color: Color(0xFFFFE08A),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

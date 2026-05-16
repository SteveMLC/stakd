import 'dart:collection';
import 'dart:math';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';
import 'stack_model.dart';
import 'layer_model.dart';
import '../utils/constants.dart';
import '../services/hydraulic_pressure_service.dart';

/// Move record for undo functionality (supports single or multi-layer)
class Move {
  final int fromStackIndex;
  final int toStackIndex;
  final Layer layer;
  final List<Layer>? multiLayers; // For multi-grab moves

  Move({
    required this.fromStackIndex,
    required this.toStackIndex,
    required this.layer,
    this.multiLayers,
  });

  bool get isMultiGrab => multiLayers != null && multiLayers!.length > 1;
  List<Layer> get allLayers => multiLayers ?? [layer];
}

/// Animation state for moving layer
class AnimatingLayer {
  final Layer layer;
  final int fromStackIndex;
  final int toStackIndex;
  final List<Layer>? multiLayers; // For multi-grab animation

  AnimatingLayer({
    required this.layer,
    required this.fromStackIndex,
    required this.toStackIndex,
    this.multiLayers,
  });

  bool get isMultiGrab => multiLayers != null && multiLayers!.length > 1;
  List<Layer> get allLayers => multiLayers ?? [layer];
  int get layerCount => multiLayers?.length ?? 1;
}

/// Main game state - manages all stacks and game logic
class GameState extends ChangeNotifier {
  static const int maxHistorySize = 10;
  List<GameStack> _stacks = [];
  int _selectedStackIndex = -1;
  int _currentLevel = 1;
  int _moveCount = 0;
  int _undosRemaining = GameConfig.maxUndos;
  bool _isComplete = false;
  List<Move> _moveHistory = [];
  List<int> _recentlyCleared = [];
  AnimatingLayer? _animatingLayer;
  int? _par; // Minimum moves to solve (null if unknown)

  // Combo tracking (consecutive correct moves — placing on matching color)
  int _comboCount = 0;
  int _maxCombo = 0;

  // Chain reaction tracking
  int _currentChainLevel = 0;
  int _maxChainLevel = 0;
  int _totalChains = 0; // Total chains triggered (2+)

  // Multi-grab state
  bool _isMultiGrabMode = false;
  List<Layer>? _multiGrabLayers;

  // Unstacking state
  int? _unstackSlotIndex; // Stack where unstacked layers are temporarily held
  List<Layer> _unstakedLayers = [];

  // Getters
  List<GameStack> get stacks => _stacks;
  int get selectedStackIndex => _selectedStackIndex;
  int get currentLevel => _currentLevel;
  int get moveCount => _moveCount;
  int get undosRemaining => _undosRemaining;
  bool get isComplete => _isComplete;
  bool get canUndo => _moveHistory.isNotEmpty && _undosRemaining > 0;
  List<int> get recentlyCleared => _recentlyCleared;
  AnimatingLayer? get animatingLayer => _animatingLayer;
  int get currentCombo => _comboCount;
  int get maxCombo => _maxCombo;
  int get currentChainLevel => _currentChainLevel;
  int get maxChainLevel => _maxChainLevel;
  int get totalChains => _totalChains;
  int? get par => _par;
  bool get isUnderPar => _par != null && _moveCount <= _par!;
  bool get isAtPar => _par != null && _moveCount == _par!;

  /// True when every non-empty, non-completed bay has a movable top that has
  /// no legal destination. The game is over (dock-jam) but the level isn't
  /// solved — caller should surface the jam-recovery modal.
  ///
  /// Returns false in the winning state (every non-empty bay is single-color
  /// complete) even when `_isComplete` hasn't been flipped yet — this avoids
  /// a spurious jam fire when a level is initGame'd into a pre-solved layout.
  bool get isJammed {
    if (_isComplete) return false;
    if (_animatingLayer != null) return false;
    var hasIncompleteWork = false;
    for (var i = 0; i < _stacks.length; i++) {
      final src = _stacks[i];
      if (src.isEmpty) continue;
      if (src.isComplete) continue;
      hasIncompleteWork = true;
      final top = src.topLayer;
      if (top == null) continue;
      if (top.isFrozen) continue; // frozen tops can't be moved this turn
      if (top.isLocked) continue; // locked layers also can't be moved
      for (var j = 0; j < _stacks.length; j++) {
        if (i == j) continue;
        if (_stacks[j].canAccept(top)) return false;
      }
    }
    return hasIncompleteWork;
  }

  /// Calculate stars earned for this level completion
  /// ★ (1 star) = Complete the level
  /// ★★ (2 stars) = Complete at or under par moves
  /// ★★★ (3 stars) = Complete at <= 70% of par moves AND no undo used
  int calculateStars() {
    if (!_isComplete) return 0;
    if (_par == null) return 1; // No par = 1 star for completion

    final bool usedNoUndo = (GameConfig.maxUndos - _undosRemaining) == 0;
    final int threeStarTarget = (_par! * 0.7).ceil();

    if (_moveCount <= threeStarTarget && usedNoUndo) return 3;
    if (_moveCount <= _par!) return 2;
    return 1;
  }

  bool get isMultiGrabMode => _isMultiGrabMode;
  List<Layer>? get multiGrabLayers => _multiGrabLayers;
  int get multiGrabCount => _multiGrabLayers?.length ?? 0;
  int get completedStackCount => _stacks.where((s) => s.isComplete).length;
  int get totalStacks => _stacks.length;
  bool get hasUnstakedLayers => _unstakedLayers.isNotEmpty;
  List<Layer> get unstakedLayers => _unstakedLayers;
  int? get unstackSlotIndex => _unstackSlotIndex;

  /// Initialize game with stacks
  void initGame(
    List<GameStack> stacks,
    int level, {
    int? par,
    bool gravityFlipActive = false,
    int gravityFlipPeriodMoves = 5,
    // Conveyor mechanic (Phase C). Pass a non-empty queue + total
    // count to opt in to delivery-queue mode. Default empty/zero means
    // the legacy "sort everything on screen at once" flow runs.
    Iterable<GameStack>? pendingDeliveries,
    int totalDeliveries = 0,
  }) {
    _stacks = stacks;
    _currentLevel = level;
    _selectedStackIndex = -1;
    _moveCount = 0;
    _undosRemaining = GameConfig.maxUndos;
    _isComplete = false;
    _moveHistory = [];
    _recentlyCleared = [];
    _comboCount = 0;
    _maxCombo = 0;
    _currentChainLevel = 0;
    _maxChainLevel = 0;
    _totalChains = 0;
    _par = par;
    _isMultiGrabMode = false;
    _multiGrabLayers = null;
    _unstackSlotIndex = null;
    _unstakedLayers = [];
    _addTubeUsed = false;
    _fragilePenaltyAccrued = 0;
    _fragileBrokeThisFrame = false;
    _priorityPenaltyAccrued = 0;
    _priorityExpiredThisFrame = false;
    _timeBombPenaltyAccrued = 0;
    _timeBombDetonatedThisFrame = false;
    _gravityFlipActive = gravityFlipActive;
    _gravityFlipPeriodMoves = gravityFlipPeriodMoves;
    _gravityFlipped = false;
    _movesSinceFlip = 0;
    _gravityFlippedThisFrame = false;
    // Conveyor-mode init. Opt-in when caller passes deliveries.
    _pendingDeliveries.clear();
    _baysShipped = 0;
    _bayShippedSlotThisFrame = null;
    _lastShippedStack = null;
    if (pendingDeliveries != null && pendingDeliveries.isNotEmpty) {
      _pendingDeliveries.addAll(pendingDeliveries);
      _conveyorMode = true;
      // totalDeliveries = visible bays already on screen + pending
      // queue if caller didn't override.
      _totalDeliveries = totalDeliveries > 0
          ? totalDeliveries
          : (_stacks.where((b) => b.layers.isNotEmpty).length +
              _pendingDeliveries.length);
    } else {
      _conveyorMode = false;
      _totalDeliveries = 0;
    }
    _resetPowerUpTracking();
    notifyListeners();
  }

  // Add Tube power-up tracking
  bool _addTubeUsed = false;
  bool get addTubeUsed => _addTubeUsed;

  /// Add an empty tube to the puzzle (Add Tube power-up)
  /// Returns true if successful
  bool addEmptyTube() {
    if (_addTubeUsed) return false;
    final maxDepth = _stacks.isNotEmpty ? _stacks.first.maxDepth : 4;
    _stacks.add(GameStack(layers: [], maxDepth: maxDepth));
    _addTubeUsed = true;
    notifyListeners();
    return true;
  }

  /// Attempt to thaw a frozen top block. Returns true if thawed.
  bool tryThawBlock(int stackIndex) {
    if (stackIndex < 0 || stackIndex >= _stacks.length) return false;
    final stack = _stacks[stackIndex];
    if (stack.isEmpty) return false;
    final top = stack.topLayer!;
    if (!top.isFrozen) return false;

    final thawed = stack.thawTopLayer();
    if (thawed != null) {
      _stacks[stackIndex] = thawed;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Handle tap on a stack
  void onStackTap(int stackIndex) {
    if (_isComplete || _animatingLayer != null) return;

    // Check for frozen block tap-to-thaw
    if (_selectedStackIndex == -1) {
      final stack = _stacks[stackIndex];
      if (!stack.isEmpty && stack.topLayer!.isFrozen) {
        tryThawBlock(stackIndex);
        return;
      }
    }

    if (_selectedStackIndex == -1) {
      // No stack selected - try to select this one
      if (!_stacks[stackIndex].isEmpty && _stacks[stackIndex].canPickUpTop) {
        _selectedStackIndex = stackIndex;
        _isMultiGrabMode = false;
        _multiGrabLayers = null;
        notifyListeners();
      }
    } else if (_selectedStackIndex == stackIndex) {
      // Tapped same stack - deselect
      _selectedStackIndex = -1;
      _isMultiGrabMode = false;
      _multiGrabLayers = null;
      notifyListeners();
    } else {
      // Try to move layer(s) from selected to tapped stack
      if (_isMultiGrabMode && _multiGrabLayers != null) {
        _tryMultiMove(_selectedStackIndex, stackIndex);
      } else {
        _tryMove(_selectedStackIndex, stackIndex);
      }
    }
  }

  /// Activate multi-grab mode on a stack (called after long press)
  void activateMultiGrab(int stackIndex) {
    if (_isComplete || _animatingLayer != null) return;
    if (_stacks[stackIndex].isEmpty) return;

    final topGroup = _stacks[stackIndex].getTopGroup();
    if (topGroup.length > 1) {
      _selectedStackIndex = stackIndex;
      _isMultiGrabMode = true;
      _multiGrabLayers = topGroup;
      notifyListeners();
    } else {
      // Only one layer of this color, fall back to normal select
      _selectedStackIndex = stackIndex;
      _isMultiGrabMode = false;
      _multiGrabLayers = null;
      notifyListeners();
    }
  }

  /// Cancel multi-grab mode without deselecting
  void cancelMultiGrab() {
    if (_isMultiGrabMode) {
      _isMultiGrabMode = false;
      _multiGrabLayers = null;
      notifyListeners();
    }
  }

  /// Pending cash penalties owed for fragile-crate wrong-drop attempts
  /// during the current puzzle. The game_screen reads this and forwards
  /// to WarehouseEconomyService at level-complete time so the player
  /// sees the deduction in the cash payout breakdown.
  int _fragilePenaltyAccrued = 0;
  int get fragilePenaltyAccrued => _fragilePenaltyAccrued;

  /// One-shot event flag for the UI to react to a just-occurred fragile
  /// break (haptic, sound, particle burst). Cleared by the consumer.
  bool _fragileBrokeThisFrame = false;
  bool get fragileBrokeThisFrame => _fragileBrokeThisFrame;
  void consumeFragileBreakEvent() {
    _fragileBrokeThisFrame = false;
  }

  /// Pending cash penalty from priority crates that hit their countdown.
  /// Same payout-time deduction pattern as fragile.
  int _priorityPenaltyAccrued = 0;
  int get priorityPenaltyAccrued => _priorityPenaltyAccrued;

  /// One-shot event flag for the UI when a priority just expired this
  /// frame. The game_screen surfaces a haptic + sfx + snackbar.
  bool _priorityExpiredThisFrame = false;
  bool get priorityExpiredThisFrame => _priorityExpiredThisFrame;
  void consumePriorityExpiredEvent() {
    _priorityExpiredThisFrame = false;
  }

  /// Pending cash penalty from time-bomb crates that detonated. Same
  /// payout-time pattern as priority but $80 per detonation (vs $40).
  int _timeBombPenaltyAccrued = 0;
  int get timeBombPenaltyAccrued => _timeBombPenaltyAccrued;

  /// One-shot event flag for the UI when a time-bomb just detonated.
  bool _timeBombDetonatedThisFrame = false;
  bool get timeBombDetonatedThisFrame => _timeBombDetonatedThisFrame;
  void consumeTimeBombDetonatedEvent() {
    _timeBombDetonatedThisFrame = false;
  }

  /// Gravity-flip wrinkle state. When `_gravityFlipActive` is true (set
  /// from LevelParams by `_loadLevel`), the board inverts its render
  /// direction every `_gravityFlipPeriodMoves` completed moves. The
  /// flip is purely visual — stack math + solvability are untouched;
  /// `game_board.dart` reads `gravityFlipped` and conditionally wraps
  /// the board in a Transform.scale(scaleY: -1).
  bool _gravityFlipActive = false;
  bool _gravityFlipped = false;
  int _movesSinceFlip = 0;
  int _gravityFlipPeriodMoves = 5;
  bool _gravityFlippedThisFrame = false;
  bool get gravityFlipActive => _gravityFlipActive;
  bool get gravityFlipped => _gravityFlipped;
  bool get gravityFlippedThisFrame => _gravityFlippedThisFrame;
  void consumeGravityFlipEvent() {
    _gravityFlippedThisFrame = false;
  }

  // ── Conveyor mechanic (Phase C — data model only) ─────────────────────
  // Per `docs/conveyor-mechanic-spec.md`. A level is now a queue of
  // mini-deliveries instead of a static board. `_stacks` holds the
  // currently visible bays (4-5 of them); `_pendingDeliveries` is the
  // FIFO queue of bays that will slide in as visible bays get cleared.
  // `_baysShipped` tracks player progress through the queue;
  // `_totalDeliveries` is the level's target.
  //
  // **Backward-compat in Phase C:** when `_conveyorMode` is false
  // (which is the default + the only mode the game uses today), all
  // conveyor state is dormant and the existing `_checkWinCondition`
  // logic runs unchanged. Phase F flips the switch to use the conveyor
  // win check; Phase C just stages the data + the ship-and-pull method.
  bool _conveyorMode = false;
  final Queue<GameStack> _pendingDeliveries = Queue<GameStack>();
  int _baysShipped = 0;
  int _totalDeliveries = 0;

  bool get conveyorMode => _conveyorMode;
  int get pendingDeliveryCount => _pendingDeliveries.length;
  int get baysShipped => _baysShipped;
  int get totalDeliveries => _totalDeliveries;
  int get baysRemaining => _totalDeliveries - _baysShipped;

  /// One-shot event flag: a bay just shipped this frame (for VFX hooks
  /// in Phase D). Cleared by `consumeBayShippedEvent`.
  int? _bayShippedSlotThisFrame;
  int? get bayShippedSlotThisFrame => _bayShippedSlotThisFrame;
  /// Pre-swap bay state — captured the instant before
  /// `shipBayAndPullNext` replaces the slot. Phase D.3 VFX uses this
  /// to render a "ghost" of the shipped bay sliding right while the
  /// new delivery fades in at the original position. Cleared along
  /// with `_bayShippedSlotThisFrame` via `consumeBayShippedEvent`.
  GameStack? _lastShippedStack;
  GameStack? get lastShippedStack => _lastShippedStack;
  void consumeBayShippedEvent() {
    _bayShippedSlotThisFrame = null;
    _lastShippedStack = null;
  }

  /// Ship the bay at [slotIndex] (must be fully-sorted single-color
  /// full-depth) and slide the next pending delivery into its slot.
  /// Returns true if a bay was actually shipped; false otherwise (slot
  /// wasn't shipping-ready or no pending deliveries left).
  ///
  /// Phase C: data-flow only. Phase D wires the VFX. Phase F wires the
  /// win check. Phase C callers should pre-check `conveyorMode` to
  /// avoid running this path when the old level harness is active.
  bool shipBayAndPullNext(int slotIndex) {
    if (!_conveyorMode) return false;
    if (slotIndex < 0 || slotIndex >= _stacks.length) return false;
    final bay = _stacks[slotIndex];
    if (!bay.isComplete) return false;

    _baysShipped++;
    _bayShippedSlotThisFrame = slotIndex;
    // Capture pre-swap bay state for VFX ghost slide-off. Snapshot
    // BEFORE we replace `_stacks[slotIndex]` so the overlay can render
    // the shipped bay's colors mid-flight.
    _lastShippedStack = bay;

    if (_pendingDeliveries.isEmpty) {
      // No more deliveries — leave the slot empty so the player has
      // workspace until the level wins.
      _stacks[slotIndex] = GameStack(
        layers: const <Layer>[],
        maxDepth: bay.maxDepth,
      );
    } else {
      // Slide the next pending delivery into this slot.
      _stacks[slotIndex] = _pendingDeliveries.removeFirst();
    }

    notifyListeners();
    return true;
  }

  /// True when the conveyor-mode level is fully shipped: every delivery
  /// has been completed and no in-progress bay is on screen. Phase F
  /// wires this into the win check.
  bool get conveyorLevelComplete {
    if (!_conveyorMode) return false;
    if (_baysShipped < _totalDeliveries) return false;
    // Player must have shipped or emptied every visible bay.
    return _stacks.every((b) => b.isEmpty || b.isComplete);
  }

  /// Attempt to move a layer between stacks
  void _tryMove(int fromIndex, int toIndex) {
    final fromStack = _stacks[fromIndex];
    final toStack = _stacks[toIndex];

    if (fromStack.isEmpty) {
      _selectedStackIndex = -1;
      _isMultiGrabMode = false;
      _multiGrabLayers = null;
      notifyListeners();
      return;
    }

    final layer = fromStack.topLayer!;

    if (toStack.canAccept(layer)) {
      // Valid move - start animation
      _animatingLayer = AnimatingLayer(
        layer: layer,
        fromStackIndex: fromIndex,
        toStackIndex: toIndex,
      );

      // Remove from source stack immediately (will be hidden during animation)
      _stacks[fromIndex] = fromStack.withTopLayerRemoved();
      _selectedStackIndex = -1;
      _isMultiGrabMode = false;
      _multiGrabLayers = null;

      notifyListeners();
    } else {
      // Invalid move. If the source layer is FRAGILE, the player just
      // gambled with a crack-prone crate and lost — accrue a cash
      // penalty and surface a one-shot event for the UI. The crate
      // stays on the source stack (it doesn't shatter / vanish) so
      // the player can still recover the puzzle, but they take the
      // hit on payout.
      if (layer.isFragile) {
        const fragilePenalty = 25;
        _fragilePenaltyAccrued += fragilePenalty;
        _fragileBrokeThisFrame = true;
      }
      // Invalid move - if destination has layers, select it instead
      if (!toStack.isEmpty) {
        _selectedStackIndex = toIndex;
        _isMultiGrabMode = false;
        _multiGrabLayers = null;
        notifyListeners();
      } else if (layer.isFragile) {
        // Empty target + fragile would normally be a valid drop; if
        // we got here with empty toStack the move was rejected by
        // some other rule. Still notify so the UI gets the penalty
        // event surface.
        notifyListeners();
      }
    }
  }

  /// Attempt to move multiple layers between stacks (multi-grab)
  void _tryMultiMove(int fromIndex, int toIndex) {
    final fromStack = _stacks[fromIndex];
    final toStack = _stacks[toIndex];

    if (fromStack.isEmpty || _multiGrabLayers == null) {
      _selectedStackIndex = -1;
      _isMultiGrabMode = false;
      _multiGrabLayers = null;
      notifyListeners();
      return;
    }

    final layersToMove = _multiGrabLayers!;

    if (toStack.canAcceptMultiple(layersToMove)) {
      // Valid multi-move - start animation
      _animatingLayer = AnimatingLayer(
        layer: layersToMove.last, // Top layer for positioning
        fromStackIndex: fromIndex,
        toStackIndex: toIndex,
        multiLayers: layersToMove,
      );

      // Remove all grabbed layers from source stack
      _stacks[fromIndex] = fromStack.withTopGroupRemoved(layersToMove.length);
      _selectedStackIndex = -1;
      _isMultiGrabMode = false;
      _multiGrabLayers = null;

      notifyListeners();
    } else {
      // Invalid move - check if we can select the destination instead
      if (!toStack.isEmpty) {
        _selectedStackIndex = toIndex;
        _isMultiGrabMode = false;
        _multiGrabLayers = null;
        notifyListeners();
      }
    }
  }

  /// Complete the layer move after animation finishes
  void completeMove() {
    if (_animatingLayer == null) return;

    final anim = _animatingLayer!;

    // Clear recently cleared list when completing a new move
    _recentlyCleared = [];

    // Add layer(s) to destination stack
    if (anim.isMultiGrab) {
      _stacks[anim.toStackIndex] = _stacks[anim.toStackIndex].withLayersAdded(
        anim.multiLayers!,
      );
    } else {
      _stacks[anim.toStackIndex] = _stacks[anim.toStackIndex].withLayerAdded(
        anim.layer,
      );
    }

    _moveHistory.add(
      Move(
        fromStackIndex: anim.fromStackIndex,
        toStackIndex: anim.toStackIndex,
        layer: anim.layer,
        multiLayers: anim.multiLayers,
      ),
    );
    if (_moveHistory.length > maxHistorySize) {
      _moveHistory.removeAt(0);
    }

    _moveCount++; // Still counts as 1 move!

    // Track consecutive correct moves combo
    _updateMoveCombo(anim.toStackIndex);

    _animatingLayer = null;

    // Decrement locked block counters
    _decrementLockedBlocks();

    // Decrement priority countdowns + apply penalty for any priorities
    // that just hit 0. The crate stays on the board (rendered as
    // "MISSED" via the layer_widget priority overlay) so the puzzle is
    // still solvable, but the player takes a cash hit on this clear.
    _tickPriorityCountdowns();

    // Time-bomb countdowns tick the same way but with a harsher $80
    // detonation penalty. Detonated bombs render the 💥 marker in
    // layer_widget and stay on the board (so solvability isn't broken).
    _tickTimeBombCountdowns();

    // Gravity-flip wrinkle: every `_gravityFlipPeriodMoves` completed
    // moves, toggle the render-inversion flag. Pure visual — stack
    // math + solvability unaffected. UI consumes the event to surface
    // a snackbar + haptic so the player isn't surprised by the flip.
    if (_gravityFlipActive) {
      _movesSinceFlip++;
      if (_movesSinceFlip >= _gravityFlipPeriodMoves) {
        _movesSinceFlip = 0;
        _gravityFlipped = !_gravityFlipped;
        _gravityFlippedThisFrame = true;
      }
    }

    // Check for completed stacks
    _checkForCompletedStacks();

    // Hydraulic Pressure meter — fires AFTER combo + chain math so the
    // service sees the post-move state. Additive notification only:
    // does NOT touch any existing combo/chain/scoring logic.
    final now = DateTime.now();
    final bayJustCompleted = _recentlyCleared.isNotEmpty;
    HydraulicPressureService().onMove(
      now: now,
      comboStep: _comboCount,
      wasBayCompleted: bayJustCompleted,
    );
    if (_currentChainLevel >= 2) {
      HydraulicPressureService().onChain(_currentChainLevel);
    }

    // Conveyor mode: a completed bay ships off + pulls the next delivery.
    // Phase D wire-up — happens AFTER pressure tick so the bay's
    // completion is still credited to the pressure system, then the
    // bay rotates out to the conveyor queue. Single bay shipped per
    // move (chain-clear case still ships them all, but in sequence
    // since `_recentlyCleared` lists them all). VFX hooks read
    // `bayShippedSlotThisFrame` to animate.
    if (_conveyorMode && _recentlyCleared.isNotEmpty) {
      for (final slot in _recentlyCleared.toList()) {
        shipBayAndPullNext(slot);
      }
    }

    // Check win condition
    _checkWinCondition();

    notifyListeners();
  }

  /// Decrement lock counters on all locked blocks after each move
  void _decrementLockedBlocks() {
    for (int i = 0; i < _stacks.length; i++) {
      final stack = _stacks[i];
      bool changed = false;
      final newLayers = <Layer>[];

      for (final layer in stack.layers) {
        if (layer.isLocked) {
          newLayers.add(layer.decrementLock());
          changed = true;
        } else {
          newLayers.add(layer);
        }
      }

      if (changed) {
        _stacks[i] = GameStack(
          layers: newLayers,
          maxDepth: stack.maxDepth,
          id: stack.id,
        );
      }
    }
  }

  /// Tick all priority countdowns down by one move. Any that just hit
  /// zero this tick trigger a cash penalty + UI event. Once a priority
  /// has expired (countdown == 0) it stays expired — single-shot
  /// penalty, no further deductions on subsequent moves.
  void _tickPriorityCountdowns() {
    const priorityPenalty = 40;
    bool anyExpiredThisTick = false;

    for (int i = 0; i < _stacks.length; i++) {
      final stack = _stacks[i];
      bool changed = false;
      final newLayers = <Layer>[];

      for (final layer in stack.layers) {
        if (layer.priorityCountdown > 0) {
          final next = layer.decrementPriority();
          newLayers.add(next);
          changed = true;
          if (next.priorityCountdown == 0) {
            // Just expired this tick — apply the penalty once.
            _priorityPenaltyAccrued += priorityPenalty;
            anyExpiredThisTick = true;
          }
        } else {
          newLayers.add(layer);
        }
      }

      if (changed) {
        _stacks[i] = GameStack(
          layers: newLayers,
          maxDepth: stack.maxDepth,
          id: stack.id,
        );
      }
    }

    if (anyExpiredThisTick) {
      _priorityExpiredThisFrame = true;
    }
  }

  /// Tick all time-bomb countdowns. Same shape as priority but with a
  /// $80 detonation penalty (vs $40 for priority). A detonated bomb
  /// stays on the board with a 💥 marker — no further deductions on
  /// subsequent moves.
  void _tickTimeBombCountdowns() {
    const timeBombPenalty = 80;
    bool anyDetonatedThisTick = false;

    for (int i = 0; i < _stacks.length; i++) {
      final stack = _stacks[i];
      bool changed = false;
      final newLayers = <Layer>[];

      for (final layer in stack.layers) {
        if (layer.timeBombCountdown > 0) {
          final next = layer.decrementTimeBomb();
          newLayers.add(next);
          changed = true;
          if (next.timeBombCountdown == 0) {
            _timeBombPenaltyAccrued += timeBombPenalty;
            anyDetonatedThisTick = true;
          }
        } else {
          newLayers.add(layer);
        }
      }

      if (changed) {
        _stacks[i] = GameStack(
          layers: newLayers,
          maxDepth: stack.maxDepth,
          id: stack.id,
        );
      }
    }

    if (anyDetonatedThisTick) {
      _timeBombDetonatedThisFrame = true;
    }
  }

  /// Check and mark completed stacks
  void _checkForCompletedStacks() {
    _recentlyCleared = [];
    for (int i = 0; i < _stacks.length; i++) {
      if (_stacks[i].isComplete) {
        _recentlyCleared.add(i);
      }
    }

    // Calculate chain level based on stacks cleared this move
    // Chain level = number of stacks cleared simultaneously
    // A "chain" is when multiple stacks complete from a single move
    _currentChainLevel = _recentlyCleared.length;

    // Track max chain and total chains
    if (_currentChainLevel > _maxChainLevel) {
      _maxChainLevel = _currentChainLevel;
    }
    if (_currentChainLevel >= 2) {
      _totalChains++;
    }

    // (Combo is now tracked per-move in completeMove)
  }

  /// Update combo counter — called on every completed move
  /// Combo increments when block lands on a matching color.
  /// Resets on move to empty tube or wrong color.
  ///
  /// **Hydraulic vent exception:** when `HydraulicPressureService.isVenting`
  /// is true, the combo NEVER resets — the 4-move vent window grants
  /// the player free experimentation. This is the unique-axis value
  /// the burst provides (in addition to the 2× cash multiplier). Per
  /// design: vent = "combo immortality + 2× cash + speedier animation
  /// for 4 moves," so risky color-change moves are free during it.
  void _updateMoveCombo(int toStackIndex) {
    // Vent override: combo doesn't reset for the duration of the burst.
    // Combo INCREMENT path still runs when the player happens to land
    // on a matching color — vent doesn't penalize good play, only
    // protects bad play from breaking the run.
    final ventActive = HydraulicPressureService().isVenting;

    final destStack = _stacks[toStackIndex];
    final layers = destStack.layers;
    if (layers.length < 2) {
      // Moved to empty tube (only 1 layer now) — reset combo unless
      // venting.
      if (!ventActive) _comboCount = 0;
      return;
    }
    // Check if top layer matches the one below it
    final topColor = layers.last.colorIndex;
    final belowColor = layers[layers.length - 2].colorIndex;
    if (topColor == belowColor) {
      _comboCount++;
      if (_comboCount > _maxCombo) {
        _maxCombo = _comboCount;
      }
    } else if (!ventActive) {
      _comboCount = 0;
    }
    // else: color mismatch BUT venting → freeze the combo at its
    // current value (do nothing). When the vent ends, the next
    // mismatch will reset normally.
  }

  /// Calculate chain bonus multiplier
  /// 2x chain = 2x points
  /// 3x chain = 4x points
  /// 4x+ chain = 8x points
  int getChainBonusMultiplier() {
    if (_currentChainLevel >= 4) return 8;
    if (_currentChainLevel == 3) return 4;
    if (_currentChainLevel == 2) return 2;
    return 1;
  }

  /// Check if all non-empty stacks are complete
  void _checkWinCondition() {
    // Phase F — when conveyor mode is on, the level is won when the
    // delivery queue is drained AND every visible bay is empty or
    // single-color-complete. The conveyorLevelComplete getter
    // encapsulates that check (see field definition above).
    if (_conveyorMode) {
      _isComplete = conveyorLevelComplete;
      return;
    }
    final nonEmptyStacks = _stacks.where((s) => !s.isEmpty).toList();
    if (nonEmptyStacks.isEmpty) {
      _isComplete = true;
      return;
    }
    _isComplete = nonEmptyStacks.every((s) => s.isComplete);
  }

  /// Undo the last move
  void undo() {
    if (!canUndo) return;

    final lastMove = _moveHistory.removeLast();

    // Reverse the move (supports multi-layer)
    if (lastMove.isMultiGrab) {
      _stacks[lastMove.toStackIndex] = _stacks[lastMove.toStackIndex]
          .withTopGroupRemoved(lastMove.multiLayers!.length);
      _stacks[lastMove.fromStackIndex] = _stacks[lastMove.fromStackIndex]
          .withLayersAdded(lastMove.multiLayers!);
    } else {
      _stacks[lastMove.toStackIndex] = _stacks[lastMove.toStackIndex]
          .withTopLayerRemoved();
      _stacks[lastMove.fromStackIndex] = _stacks[lastMove.fromStackIndex]
          .withLayerAdded(lastMove.layer);
    }

    _undosRemaining--;
    _moveCount--;
    _selectedStackIndex = -1;
    _isComplete = false;
    _recentlyCleared = [];
    _animatingLayer = null; // Clear any ongoing animation
    _comboCount = 0; // Reset combo on undo
    _currentChainLevel = 0; // Reset chain on undo
    _isMultiGrabMode = false;
    _multiGrabLayers = null;
    _unstackSlotIndex = null;
    _unstakedLayers = [];

    notifyListeners();
  }

  /// Force undo without checking remaining (paid undo)
  void forceUndo() {
    if (_moveHistory.isEmpty) return;

    final lastMove = _moveHistory.removeLast();

    if (lastMove.isMultiGrab) {
      _stacks[lastMove.toStackIndex] = _stacks[lastMove.toStackIndex]
          .withTopGroupRemoved(lastMove.multiLayers!.length);
      _stacks[lastMove.fromStackIndex] = _stacks[lastMove.fromStackIndex]
          .withLayersAdded(lastMove.multiLayers!);
    } else {
      _stacks[lastMove.toStackIndex] = _stacks[lastMove.toStackIndex]
          .withTopLayerRemoved();
      _stacks[lastMove.fromStackIndex] = _stacks[lastMove.fromStackIndex]
          .withLayerAdded(lastMove.layer);
    }

    _moveCount--;
    _selectedStackIndex = -1;
    _isComplete = false;
    _recentlyCleared = [];
    _animatingLayer = null;
    _comboCount = 0;
    _currentChainLevel = 0;
    _isMultiGrabMode = false;
    _multiGrabLayers = null;
    _unstackSlotIndex = null;
    _unstakedLayers = [];

    notifyListeners();
  }

  /// Add undo from rewarded ad
  void addUndo() {
    _undosRemaining += 3;
    notifyListeners();
  }

  /// Deselect current selection
  void deselect() {
    if (_selectedStackIndex != -1) {
      _selectedStackIndex = -1;
      _isMultiGrabMode = false;
      _multiGrabLayers = null;
      notifyListeners();
    }
  }

  /// Check if a move from one stack to another is valid
  bool isValidMove(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return false;
    final fromStack = _stacks[fromIndex];
    final toStack = _stacks[toIndex];
    if (fromStack.isEmpty) return false;
    return toStack.canAccept(fromStack.topLayer!);
  }

  /// Check if a multi-grab move is valid (for hints/validation)
  bool isValidMultiMove(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return false;
    final fromStack = _stacks[fromIndex];
    final toStack = _stacks[toIndex];
    if (fromStack.isEmpty) return false;
    final topGroup = fromStack.getTopGroup();
    return toStack.canAcceptMultiple(topGroup);
  }

  /// Get hint for next move (simple implementation)
  (int, int)? getHint() {
    for (int from = 0; from < _stacks.length; from++) {
      if (_stacks[from].isEmpty) continue;
      for (int to = 0; to < _stacks.length; to++) {
        if (from == to) continue;
        if (isValidMove(from, to)) {
          // Prefer moves that make progress
          final toStack = _stacks[to];
          if (toStack.isEmpty || toStack.topGroupSize > 1) {
            return (from, to);
          }
        }
      }
    }
    // Fallback to any valid move
    for (int from = 0; from < _stacks.length; from++) {
      if (_stacks[from].isEmpty) continue;
      for (int to = 0; to < _stacks.length; to++) {
        if (isValidMove(from, to)) {
          return (from, to);
        }
      }
    }
    return null;
  }

  /// Reset the current level
  void resetLevel(List<GameStack> stacks) {
    initGame(stacks, _currentLevel);
  }

  /// Unstack layers from a stack (remove from top to access buried colors)
  /// Returns true if successful
  bool unstackFrom(int stackIndex, int count) {
    if (_animatingLayer != null) return false;
    if (stackIndex < 0 || stackIndex >= _stacks.length) return false;
    if (hasUnstakedLayers) {
      return false; // Can only have one unstack operation at a time
    }

    final stack = _stacks[stackIndex];
    if (stack.isEmpty || count > stack.layers.length) return false;

    // Extract top N layers
    final layersToUnstack = stack.layers.sublist(
      stack.layers.length - count,
      stack.layers.length,
    );

    // Can't unstack locked layers
    if (layersToUnstack.any((l) => l.isLocked)) return false;

    _unstakedLayers = layersToUnstack;
    _unstackSlotIndex = stackIndex;
    _stacks[stackIndex] = stack.withTopGroupRemoved(count);

    notifyListeners();
    return true;
  }

  /// Restack the unstacked layers back to any valid stack
  /// Returns true if successful
  bool restackTo(int stackIndex) {
    if (!hasUnstakedLayers) return false;
    if (_animatingLayer != null) return false;
    if (stackIndex < 0 || stackIndex >= _stacks.length) return false;

    final targetStack = _stacks[stackIndex];

    // Check if we can add all unstacked layers
    if (!targetStack.canAcceptMultiple(_unstakedLayers)) return false;

    _stacks[stackIndex] = targetStack.withLayersAdded(_unstakedLayers);
    _unstakedLayers = [];
    _unstackSlotIndex = null;
    _moveCount++; // Unstacking counts as a move

    // Decrement locked blocks
    _decrementLockedBlocks();

    // Check for completed stacks
    _checkForCompletedStacks();

    // Check win condition
    _checkWinCondition();

    notifyListeners();
    return true;
  }

  /// Cancel unstacking and return layers to original stack
  void cancelUnstack() {
    if (!hasUnstakedLayers || _unstackSlotIndex == null) return;

    _stacks[_unstackSlotIndex!] = _stacks[_unstackSlotIndex!].withLayersAdded(
      _unstakedLayers,
    );
    _unstakedLayers = [];
    _unstackSlotIndex = null;

    notifyListeners();
  }

  // ============== POWER-UP METHODS ==============

  /// Power-up tracking
  int _colorBombsUsed = 0;
  int _shufflesUsed = 0;
  int _magnetsUsed = 0;
  int _hintsUsed = 0;

  int get colorBombsUsed => _colorBombsUsed;
  int get shufflesUsed => _shufflesUsed;
  int get magnetsUsed => _magnetsUsed;
  int get hintsUsed => _hintsUsed;

  /// Activate Color Bomb - Remove all blocks of a specific color
  /// Returns the list of stack indices and positions where blocks were removed
  List<(int stackIndex, int layerIndex)> activateColorBomb(int colorIndex) {
    final removed = <(int, int)>[];

    for (int stackIdx = 0; stackIdx < _stacks.length; stackIdx++) {
      final stack = _stacks[stackIdx];
      final newLayers = <Layer>[];

      for (int layerIdx = 0; layerIdx < stack.layers.length; layerIdx++) {
        final layer = stack.layers[layerIdx];
        if (layer.colorIndex == colorIndex && !layer.isLocked) {
          // This layer will be removed
          removed.add((stackIdx, layerIdx));
        } else {
          newLayers.add(layer);
        }
      }

      if (newLayers.length != stack.layers.length) {
        _stacks[stackIdx] = GameStack(
          layers: newLayers,
          maxDepth: stack.maxDepth,
          id: stack.id,
        );
      }
    }

    if (removed.isNotEmpty) {
      _colorBombsUsed++;
      _checkForCompletedStacks();
      _checkWinCondition();
      notifyListeners();
    }

    return removed;
  }

  /// Find all unique colors currently on the board (for Color Bomb selection)
  Set<int> getActiveColors() {
    final colors = <int>{};
    for (final stack in _stacks) {
      for (final layer in stack.layers) {
        if (!layer.isLocked) {
          colors.add(layer.colorIndex);
        }
      }
    }
    return colors;
  }

  /// Activate Shuffle - Regenerate the puzzle with current blocks
  /// Returns true if shuffle was successful
  bool activateShuffle() {
    // Collect all current layers (excluding locked ones from shuffling)
    final allLayers = <Layer>[];
    final lockedLayersMap =
        <int, List<(int, Layer)>>{}; // stackIdx -> [(layerIdx, layer)]

    for (int i = 0; i < _stacks.length; i++) {
      final stack = _stacks[i];
      lockedLayersMap[i] = [];

      for (int j = 0; j < stack.layers.length; j++) {
        final layer = stack.layers[j];
        if (layer.isLocked) {
          lockedLayersMap[i]!.add((j, layer));
        } else {
          allLayers.add(layer);
        }
      }
    }

    if (allLayers.isEmpty) return false;

    // Shuffle the layers
    final random = Random();
    allLayers.shuffle(random);

    // Redistribute layers across stacks
    final maxDepth = _stacks.first.maxDepth;
    final stackCount = _stacks.length;
    final newStacks = <GameStack>[];

    int layerIndex = 0;
    for (int i = 0; i < stackCount; i++) {
      final stackLayers = <Layer>[];
      final locked = lockedLayersMap[i] ?? [];

      // Calculate how many layers this stack should have (random distribution)
      int targetLayers = 0;
      if (layerIndex < allLayers.length) {
        // Distribute evenly with some randomness
        final remaining = allLayers.length - layerIndex;
        final remainingStacks = stackCount - i;
        targetLayers = (remaining / remainingStacks).ceil();
        targetLayers = min(targetLayers, maxDepth - locked.length);
        // Add some randomness to avoid perfectly even distribution
        if (random.nextBool() && targetLayers > 1) {
          targetLayers = random.nextInt(targetLayers) + 1;
        }
      }

      // Add shuffled layers
      for (int j = 0; j < targetLayers && layerIndex < allLayers.length; j++) {
        stackLayers.add(allLayers[layerIndex++]);
      }

      // Re-insert locked layers at their original positions (approximately)
      for (final (_, lockedLayer) in locked) {
        stackLayers.add(lockedLayer);
      }

      newStacks.add(
        GameStack(layers: stackLayers, maxDepth: maxDepth, id: _stacks[i].id),
      );
    }

    // Distribute any remaining layers
    while (layerIndex < allLayers.length) {
      for (int i = 0; i < stackCount && layerIndex < allLayers.length; i++) {
        if (newStacks[i].layers.length < maxDepth) {
          newStacks[i] = newStacks[i].withLayerAdded(allLayers[layerIndex++]);
        }
      }
    }

    _stacks = newStacks;
    _shufflesUsed++;
    _selectedStackIndex = -1;
    _isMultiGrabMode = false;
    _multiGrabLayers = null;
    _recentlyCleared = [];

    notifyListeners();
    return true;
  }

  /// Find stacks that are eligible for Magnet (all same color except 1 mismatched block)
  /// Returns list of (stackIndex, mismatchedLayerIndex, dominantColor)
  List<(int stackIndex, int mismatchedLayerIndex, int dominantColor)>
  findMagnetEligibleStacks() {
    final eligible = <(int, int, int)>[];

    for (int stackIdx = 0; stackIdx < _stacks.length; stackIdx++) {
      final stack = _stacks[stackIdx];
      if (stack.isEmpty || stack.isComplete || stack.layers.length < 2) {
        continue;
      }

      // Count colors in this stack
      final colorCounts = <int, int>{};
      for (final layer in stack.layers) {
        colorCounts[layer.colorIndex] =
            (colorCounts[layer.colorIndex] ?? 0) + 1;
      }

      // Find if there's exactly one mismatched block
      if (colorCounts.length == 2) {
        // Check if one color has count 1 and the other has count (layers.length - 1)
        int? mismatchedColor;
        int? dominantColor;

        for (final entry in colorCounts.entries) {
          if (entry.value == 1) {
            mismatchedColor = entry.key;
          } else if (entry.value == stack.layers.length - 1) {
            dominantColor = entry.key;
          }
        }

        if (mismatchedColor != null && dominantColor != null) {
          // Find the index of the mismatched layer
          for (int layerIdx = 0; layerIdx < stack.layers.length; layerIdx++) {
            if (stack.layers[layerIdx].colorIndex == mismatchedColor &&
                !stack.layers[layerIdx].isLocked) {
              eligible.add((stackIdx, layerIdx, dominantColor));
              break;
            }
          }
        }
      }
    }

    return eligible;
  }

  /// Activate Magnet on a specific stack
  /// Returns the removed layer info: (stackIndex, removedLayer, layerPosition) or null if failed
  (int stackIndex, Layer removedLayer, Offset layerPosition)? activateMagnet(
    int stackIndex,
  ) {
    final eligibleStacks = findMagnetEligibleStacks();
    final match = eligibleStacks.where((e) => e.$1 == stackIndex).firstOrNull;

    if (match == null) return null;

    final (_, mismatchedLayerIndex, _) = match;
    final stack = _stacks[stackIndex];
    final removedLayer = stack.layers[mismatchedLayerIndex];

    // Remove the mismatched layer
    final newLayers = [...stack.layers];
    newLayers.removeAt(mismatchedLayerIndex);

    _stacks[stackIndex] = GameStack(
      layers: newLayers,
      maxDepth: stack.maxDepth,
      id: stack.id,
    );

    _magnetsUsed++;
    _checkForCompletedStacks();
    _checkWinCondition();
    notifyListeners();

    // Calculate approximate position for animation (will be refined in widget)
    final layerY =
        mismatchedLayerIndex * (GameSizes.layerHeight + GameSizes.layerMargin);
    return (stackIndex, removedLayer, Offset(0, layerY));
  }

  /// Get enhanced hint with animation data
  /// Returns (fromStackIndex, toStackIndex, fromPosition, toPosition) or null
  (int, int, int?, int?)? getEnhancedHint() {
    final hint = getHint();
    if (hint == null) return null;

    _hintsUsed++;
    return (hint.$1, hint.$2, null, null);
  }

  /// Reset power-up usage tracking (for new level)
  void _resetPowerUpTracking() {
    _colorBombsUsed = 0;
    _shufflesUsed = 0;
    _magnetsUsed = 0;
    _hintsUsed = 0;
  }
}

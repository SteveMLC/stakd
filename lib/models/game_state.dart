import 'dart:math';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';
import 'stack_model.dart';
import 'layer_model.dart';
import '../utils/constants.dart';

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
  bool _isZenMode = false;

  // Combo tracking
  int _comboCount = 0;
  DateTime? _lastClearTime;
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
  
  /// Calculate stars earned for this level completion
  /// ★ (1 star) = Complete the level
  /// ★★ (2 stars) = Complete at or under par moves
  /// ★★★ (3 stars) = Complete at par-2 moves OR no undo used
  int calculateStars() {
    if (!_isComplete) return 0;
    if (_par == null) return 1; // No par = 1 star for completion
    
    final bool usedNoUndo = (GameConfig.maxUndos - _undosRemaining) == 0;
    final bool underPar2 = _moveCount <= (_par! - 2);
    
    if (underPar2 || usedNoUndo) return 3;
    if (_moveCount <= _par!) return 2;
    return 1;
  }
  bool get isMultiGrabMode => _isMultiGrabMode;
  List<Layer>? get multiGrabLayers => _multiGrabLayers;
  int get multiGrabCount => _multiGrabLayers?.length ?? 0;
  bool get isZenMode => _isZenMode;
  int get completedStackCount => _stacks.where((s) => s.isComplete).length;
  int get totalStacks => _stacks.length;
  bool get hasUnstakedLayers => _unstakedLayers.isNotEmpty;
  List<Layer> get unstakedLayers => _unstakedLayers;
  int? get unstackSlotIndex => _unstackSlotIndex;

  /// Initialize game with stacks
  void initGame(List<GameStack> stacks, int level, {int? par}) {
    _stacks = stacks;
    _currentLevel = level;
    _selectedStackIndex = -1;
    _moveCount = 0;
    _undosRemaining = GameConfig.maxUndos;
    _isComplete = false;
    _moveHistory = [];
    _recentlyCleared = [];
    _comboCount = 0;
    _lastClearTime = null;
    _maxCombo = 0;
    _currentChainLevel = 0;
    _maxChainLevel = 0;
    _totalChains = 0;
    _par = par;
    _isMultiGrabMode = false;
    _multiGrabLayers = null;
    _isZenMode = false;
    _unstackSlotIndex = null;
    _unstakedLayers = [];
    _resetPowerUpTracking();
    notifyListeners();
  }

  void initZenGame(List<GameStack> stacks) {
    _stacks = stacks;
    _currentLevel = 0;
    _selectedStackIndex = -1;
    _moveCount = 0;
    _undosRemaining = GameConfig.maxUndos;
    _isComplete = false;
    _moveHistory = [];
    _recentlyCleared = [];
    _comboCount = 0;
    _lastClearTime = null;
    _maxCombo = 0;
    _currentChainLevel = 0;
    _maxChainLevel = 0;
    _totalChains = 0;
    _par = null;
    _isMultiGrabMode = false;
    _multiGrabLayers = null;
    _isZenMode = true;
    _unstackSlotIndex = null;
    _unstakedLayers = [];
    notifyListeners();
  }

  /// Handle tap on a stack
  void onStackTap(int stackIndex) {
    if (_isComplete || _animatingLayer != null) return;

    if (_selectedStackIndex == -1) {
      // No stack selected - try to select this one
      if (!_stacks[stackIndex].isEmpty) {
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
      // Invalid move - if destination has layers, select it instead
      if (!toStack.isEmpty) {
        _selectedStackIndex = toIndex;
        _isMultiGrabMode = false;
        _multiGrabLayers = null;
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
    _animatingLayer = null;

    // Decrement locked block counters
    _decrementLockedBlocks();

    // Check for completed stacks
    _checkForCompletedStacks();

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

    // Update combo if stacks were cleared
    if (_recentlyCleared.isNotEmpty) {
      _updateCombo();
    }
  }

  /// Update combo counter based on clear timing
  void _updateCombo() {
    final now = DateTime.now();

    // Check if this clear is within combo window (3 seconds)
    if (_lastClearTime != null &&
        now.difference(_lastClearTime!).inMilliseconds <= 3000) {
      _comboCount = (_comboCount + 1).clamp(0, 5); // Cap at 5x
      if (_comboCount > _maxCombo) {
        _maxCombo = _comboCount;
      }
    } else {
      // Start new combo
      _comboCount = 1;
    }

    _lastClearTime = now;
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
    _lastClearTime = null;
    _currentChainLevel = 0; // Reset chain on undo
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
    if (hasUnstakedLayers) return false; // Can only have one unstack operation at a time
    
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
    
    _stacks[_unstackSlotIndex!] = _stacks[_unstackSlotIndex!].withLayersAdded(_unstakedLayers);
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
    final lockedLayersMap = <int, List<(int, Layer)>>{}; // stackIdx -> [(layerIdx, layer)]
    
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
      
      newStacks.add(GameStack(
        layers: stackLayers,
        maxDepth: maxDepth,
        id: _stacks[i].id,
      ));
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
  List<(int stackIndex, int mismatchedLayerIndex, int dominantColor)> findMagnetEligibleStacks() {
    final eligible = <(int, int, int)>[];
    
    for (int stackIdx = 0; stackIdx < _stacks.length; stackIdx++) {
      final stack = _stacks[stackIdx];
      if (stack.isEmpty || stack.isComplete || stack.layers.length < 2) continue;
      
      // Count colors in this stack
      final colorCounts = <int, int>{};
      for (final layer in stack.layers) {
        colorCounts[layer.colorIndex] = (colorCounts[layer.colorIndex] ?? 0) + 1;
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
  (int stackIndex, Layer removedLayer, Offset layerPosition)? activateMagnet(int stackIndex) {
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
    final layerY = mismatchedLayerIndex * (GameSizes.layerHeight + GameSizes.layerMargin);
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

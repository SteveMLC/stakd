import 'package:flutter/foundation.dart';
import 'stack_model.dart';
import 'layer_model.dart';
import '../utils/constants.dart';

/// Move record for undo functionality
class Move {
  final int fromStackIndex;
  final int toStackIndex;
  final Layer layer;

  Move({
    required this.fromStackIndex,
    required this.toStackIndex,
    required this.layer,
  });
}

/// Animation state for moving layer
class AnimatingLayer {
  final Layer layer;
  final int fromStackIndex;
  final int toStackIndex;

  AnimatingLayer({
    required this.layer,
    required this.fromStackIndex,
    required this.toStackIndex,
  });
}

/// Main game state - manages all stacks and game logic
class GameState extends ChangeNotifier {
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

  // Combo tracking
  int _comboCount = 0;
  DateTime? _lastClearTime;
  int _maxCombo = 0;

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
  int? get par => _par;
  bool get isUnderPar => _par != null && _moveCount <= _par!;
  bool get isAtPar => _par != null && _moveCount == _par!;

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
    _par = par;
    notifyListeners();
  }

  /// Handle tap on a stack
  void onStackTap(int stackIndex) {
    if (_isComplete || _animatingLayer != null) return;

    if (_selectedStackIndex == -1) {
      // No stack selected - try to select this one
      if (!_stacks[stackIndex].isEmpty) {
        _selectedStackIndex = stackIndex;
        notifyListeners();
      }
    } else if (_selectedStackIndex == stackIndex) {
      // Tapped same stack - deselect
      _selectedStackIndex = -1;
      notifyListeners();
    } else {
      // Try to move layer from selected to tapped stack
      _tryMove(_selectedStackIndex, stackIndex);
    }
  }

  /// Attempt to move a layer between stacks
  void _tryMove(int fromIndex, int toIndex) {
    final fromStack = _stacks[fromIndex];
    final toStack = _stacks[toIndex];

    if (fromStack.isEmpty) {
      _selectedStackIndex = -1;
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

      notifyListeners();
    } else {
      // Invalid move - if destination has layers, select it instead
      if (!toStack.isEmpty) {
        _selectedStackIndex = toIndex;
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

    // Add layer to destination stack
    _stacks[anim.toStackIndex] = _stacks[anim.toStackIndex].withLayerAdded(
      anim.layer,
    );

    _moveHistory.add(
      Move(
        fromStackIndex: anim.fromStackIndex,
        toStackIndex: anim.toStackIndex,
        layer: anim.layer,
      ),
    );

    _moveCount++;
    _animatingLayer = null;

    // Check for completed stacks
    _checkForCompletedStacks();

    // Check win condition
    _checkWinCondition();

    notifyListeners();
  }

  /// Check and mark completed stacks
  void _checkForCompletedStacks() {
    _recentlyCleared = [];
    for (int i = 0; i < _stacks.length; i++) {
      if (_stacks[i].isComplete) {
        _recentlyCleared.add(i);
      }
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

    // Reverse the move
    _stacks[lastMove.toStackIndex] = _stacks[lastMove.toStackIndex]
        .withTopLayerRemoved();
    _stacks[lastMove.fromStackIndex] = _stacks[lastMove.fromStackIndex]
        .withLayerAdded(lastMove.layer);

    _undosRemaining--;
    _moveCount--;
    _selectedStackIndex = -1;
    _isComplete = false;
    _recentlyCleared = [];
    _animatingLayer = null; // Clear any ongoing animation
    _comboCount = 0; // Reset combo on undo
    _lastClearTime = null;

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
}

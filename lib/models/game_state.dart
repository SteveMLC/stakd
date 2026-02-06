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

  // Getters
  List<GameStack> get stacks => _stacks;
  int get selectedStackIndex => _selectedStackIndex;
  int get currentLevel => _currentLevel;
  int get moveCount => _moveCount;
  int get undosRemaining => _undosRemaining;
  bool get isComplete => _isComplete;
  bool get canUndo => _moveHistory.isNotEmpty && _undosRemaining > 0;
  List<int> get recentlyCleared => _recentlyCleared;

  /// Initialize game with stacks
  void initGame(List<GameStack> stacks, int level) {
    _stacks = stacks;
    _currentLevel = level;
    _selectedStackIndex = -1;
    _moveCount = 0;
    _undosRemaining = GameConfig.maxUndos;
    _isComplete = false;
    _moveHistory = [];
    _recentlyCleared = [];
    notifyListeners();
  }

  /// Handle tap on a stack
  void onStackTap(int stackIndex) {
    if (_isComplete) return;

    // Clear recently cleared list on any tap
    if (_recentlyCleared.isNotEmpty) {
      _recentlyCleared = [];
    }

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
      // Valid move - execute it
      _stacks[fromIndex] = fromStack.withTopLayerRemoved();
      _stacks[toIndex] = toStack.withLayerAdded(layer);
      
      _moveHistory.add(Move(
        fromStackIndex: fromIndex,
        toStackIndex: toIndex,
        layer: layer,
      ));
      
      _moveCount++;
      _selectedStackIndex = -1;

      // Check for completed stacks
      _checkForCompletedStacks();

      // Check win condition
      _checkWinCondition();

      notifyListeners();
    } else {
      // Invalid move - if destination has layers, select it instead
      if (!toStack.isEmpty) {
        _selectedStackIndex = toIndex;
        notifyListeners();
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
    _stacks[lastMove.toStackIndex] = _stacks[lastMove.toStackIndex].withTopLayerRemoved();
    _stacks[lastMove.fromStackIndex] = _stacks[lastMove.fromStackIndex].withLayerAdded(lastMove.layer);
    
    _undosRemaining--;
    _moveCount--;
    _selectedStackIndex = -1;
    _isComplete = false;
    _recentlyCleared = [];

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

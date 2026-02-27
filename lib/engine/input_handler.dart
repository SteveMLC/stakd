import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/layer_model.dart';
import '../services/haptic_service.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';

/// Callback signatures for input handler events
typedef OnMoveCallback = void Function();
typedef OnClearCallback = void Function(List<int> clearedIndices, int chainLevel);

/// Handles all gesture input for the game board: tap, drag, multi-grab.
/// Decoupled from rendering so it can be reused across game modes.
class BoardInputHandler {
  final GameState gameState;
  final Map<int, GlobalKey> stackKeys;
  final VoidCallback? onTap;
  final OnMoveCallback? onMove;
  final OnClearCallback? onClear;
  final void Function(int stackIndex)? onStackTapOverride;
  final VoidCallback? onInvalidMove;

  // Drag state
  bool isDragging = false;
  int dragSourceTube = -1;
  Offset dragPosition = Offset.zero;
  List<Layer>? dragLayers;
  int? dragHoverTube;

  BoardInputHandler({
    required this.gameState,
    required this.stackKeys,
    this.onTap,
    this.onMove,
    this.onClear,
    this.onStackTapOverride,
    this.onInvalidMove,
  });

  /// Handle tap on a stack index. Returns true if state changed.
  bool handleStackTap(int actualIndex) {
    if (isDragging) return false;
    if (onStackTapOverride != null) {
      onStackTapOverride!(actualIndex);
      onTap?.call();
      return true;
    }

    final previousMoveCount = gameState.moveCount;
    final previousCleared = List<int>.from(gameState.recentlyCleared);
    final previousSelectedStack = gameState.selectedStackIndex;

    gameState.onStackTap(actualIndex);
    onTap?.call();

    final moveMade = gameState.moveCount > previousMoveCount;

    if (moveMade) {
      onMove?.call();
    } else {
      // Check for invalid move attempt
      final wasSourceSelected = previousSelectedStack >= 0 && previousSelectedStack != actualIndex;
      if (wasSourceSelected) {
        final sourceStack = gameState.stacks[previousSelectedStack];
        final targetStack = gameState.stacks[actualIndex];
        if (!sourceStack.isEmpty && !targetStack.canAccept(sourceStack.topLayer!)) {
          AudioService().playError();
          haptics.error();
          onInvalidMove?.call();
        }
      }
    }

    final currentCleared = gameState.recentlyCleared;
    if (currentCleared.isNotEmpty && _listsDiffer(previousCleared, currentCleared)) {
      onClear?.call(currentCleared, gameState.currentChainLevel);
    }

    return true;
  }

  /// Handle multi-grab activation on a stack
  void handleMultiGrab(int actualIndex) {
    gameState.activateMultiGrab(actualIndex);
    onTap?.call();
  }

  /// Start a drag from the given tube index
  bool startDrag(int tubeIndex, Offset globalPosition) {
    if (gameState.isComplete || gameState.animatingLayer != null) return false;
    final stack = gameState.stacks[tubeIndex];
    if (stack.isEmpty || !stack.canPickUpTop) return false;

    final topGroup = stack.getTopGroup();
    final isMulti = topGroup.length > 1;

    isDragging = true;
    dragSourceTube = tubeIndex;
    dragPosition = globalPosition;
    dragLayers = topGroup;
    dragHoverTube = null;

    haptics.mediumImpact();
    if (isMulti) {
      StorageService().setMultiGrabUsed();
      StorageService().incrementMultiGrabUsage();
    }
    return true;
  }

  /// Update drag position and determine hover target
  int? updateDrag(Offset globalPosition) {
    if (!isDragging) return null;

    int? hoverTube;
    final stacks = gameState.stacks;
    for (int i = 0; i < stacks.length; i++) {
      if (i == dragSourceTube) continue;
      final key = stackKeys[i];
      if (key?.currentContext == null) continue;
      final box = key!.currentContext!.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final pos = box.localToGlobal(Offset.zero);
      final size = box.size;
      final rect = Rect.fromLTWH(pos.dx - 8, pos.dy - 8, size.width + 16, size.height + 16);
      if (rect.contains(globalPosition)) {
        hoverTube = i;
        break;
      }
    }

    dragPosition = globalPosition;
    dragHoverTube = hoverTube;
    return hoverTube;
  }

  /// End drag and attempt move. Returns true if a valid move was made.
  bool endDrag() {
    if (!isDragging) return false;

    final targetTube = dragHoverTube;
    final sourceTube = dragSourceTube;
    final layers = dragLayers;

    // Clear drag state
    isDragging = false;
    dragSourceTube = -1;
    dragLayers = null;
    dragHoverTube = null;

    if (targetTube == null || layers == null) {
      haptics.lightTap();
      return false;
    }

    // Use existing game state move logic
    final gs = gameState;
    if (layers.length > 1) {
      gs.activateMultiGrab(sourceTube);
    } else {
      gs.onStackTap(sourceTube);
    }

    final previousMoveCount = gs.moveCount;
    final previousCleared = List<int>.from(gs.recentlyCleared);

    gs.onStackTap(targetTube);

    final moveMade = gs.moveCount > previousMoveCount;
    if (moveMade) {
      onTap?.call();
      onMove?.call();
    } else {
      AudioService().playError();
      haptics.error();
      onInvalidMove?.call();
      if (gs.selectedStackIndex >= 0) {
        gs.onStackTap(gs.selectedStackIndex);
      }
    }

    final currentCleared = gs.recentlyCleared;
    if (currentCleared.isNotEmpty && _listsDiffer(previousCleared, currentCleared)) {
      onClear?.call(currentCleared, gs.currentChainLevel);
    }

    return moveMade;
  }

  /// Check if a tube is a valid drop target during drag
  bool isValidDropTarget(int tubeIndex) {
    if (dragLayers == null || dragSourceTube < 0) return false;
    if (tubeIndex == dragSourceTube) return false;
    final targetStack = gameState.stacks[tubeIndex];
    if (dragLayers!.length > 1) {
      return targetStack.canAcceptMultiple(dragLayers!);
    } else {
      return targetStack.canAccept(dragLayers!.first);
    }
  }

  bool _listsDiffer(List<int> a, List<int> b) {
    if (a.length != b.length) return true;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }
}

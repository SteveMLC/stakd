import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../utils/theme_colors.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import '../widgets/particles/particle_burst.dart';

/// Manages chain/combo effects and particle bursts for the game board.
/// Pure logic — no widgets. The board widget reads state from this controller.
class BoardEffectsController {
  List<ParticleBurstData> currentBursts = [];
  int? showComboMultiplier;
  int? showChainLevel;
  Color? flashColor;
  bool showConfetti = false;

  /// Trigger a small landing burst on a stack after block lands.
  List<ParticleBurstData>? triggerLandingBurst(
    int stackIndex,
    int colorIndex,
    Map<int, GlobalKey> stackKeys,
  ) {
    if (!ThemeColors.hasParticles) return null;
    final stackKey = stackKeys[stackIndex];
    if (stackKey?.currentContext == null) return null;
    final renderBox = stackKey!.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final center = Offset(position.dx + size.width / 2, position.dy + size.height - 10);
    final color = ThemeColors.getColor(colorIndex);
    currentBursts = [
      ParticleBurstData(
        center: center,
        color: color,
        particleCount: 5,
        lifetime: const Duration(milliseconds: 200),
      ),
    ];
    return currentBursts;
  }

  /// Trigger particle bursts for cleared stacks.
  List<ParticleBurstData> triggerClearBursts(
    List<int> clearedIndices,
    int chainLevel,
    GameState gameState,
    Map<int, GlobalKey> stackKeys,
  ) {
    if (clearedIndices.isEmpty || !ThemeColors.hasParticles) return [];

    final bursts = <ParticleBurstData>[];
    final particleCount = 24 + (chainLevel - 1) * 12;
    final lifetime = Duration(milliseconds: 600 + (chainLevel - 1) * 100);

    for (final stackIndex in clearedIndices) {
      final stackKey = stackKeys[stackIndex];
      if (stackKey?.currentContext == null) continue;
      final renderBox = stackKey!.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final center = Offset(position.dx + size.width / 2, position.dy + size.height / 2);
      final stack = gameState.stacks[stackIndex];
      final topLayer = stack.layers.isNotEmpty ? stack.layers.last : null;
      final color = topLayer != null
          ? ThemeColors.getColor(topLayer.colorIndex)
          : ThemeColors.accentColor;
      bursts.add(ParticleBurstData(
        center: center,
        color: color,
        particleCount: particleCount,
        lifetime: lifetime,
      ));
    }

    currentBursts = bursts;
    return bursts;
  }

  /// Get the flash color for a chain level.
  Color getChainFlashColor(int chainLevel) {
    switch (chainLevel) {
      case 2:
        return const Color(0xFFFFD700);
      case 3:
        return const Color(0xFFFF8C00);
      case 4:
        return const Color(0xFFFF4500);
      default:
        if (chainLevel >= 5) {
          return const Color(0xFF9400D3);
        }
        return ThemeColors.accentColor;
    }
  }

  /// Process chain effects for cleared stacks. 
  /// Returns true if shake animation should play.
  bool triggerChainEffects(
    List<int> clearedIndices,
    int chainLevel,
    GameState gameState,
    Map<int, GlobalKey> stackKeys, {
    void Function(int chainLevel)? onChain,
  }) {
    // Always trigger particle bursts
    triggerClearBursts(clearedIndices, chainLevel, gameState, stackKeys);

    if (chainLevel <= 1) {
      haptics.successPattern();
      return false;
    }

    onChain?.call(chainLevel);

    showChainLevel = chainLevel;
    flashColor = getChainFlashColor(chainLevel);

    AudioService().playChain(chainLevel);
    haptics.chainReaction(chainLevel);

    bool shouldShake = chainLevel >= 2;

    if (chainLevel >= 4) {
      showConfetti = true;
    }

    return shouldShake;
  }

  /// Clear all visible overlays.
  void clearAllOverlays() {
    showComboMultiplier = null;
    showChainLevel = null;
    flashColor = null;
    showConfetti = false;
  }
}

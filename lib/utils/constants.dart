import 'package:flutter/material.dart';

/// Game color palette - vibrant, high contrast
class GameColors {
  // Default palette - richer, more saturated
  static const List<Color> _defaultPalette = [
    Color(0xFFFF4757), // Coral Red
    Color(0xFF3742FA), // Electric Blue
    Color(0xFF2ED573), // Emerald Green
    Color(0xFFFFD93D), // Golden Yellow
    Color(0xFFA55EEA), // Royal Purple
    Color(0xFF17A2B8), // Teal Cyan
    Color(0xFFFF6B81), // Soft Pink
    Color(0xFF1E90FF), // Dodger Blue
  ];

  // Ultra palette - high contrast, colorblind-friendly, distinct hues
  static const List<Color> _ultraPalette = [
    Color(0xFFE74C3C), // Red
    Color(0xFF3498DB), // Blue
    Color(0xFF2ECC71), // Green
    Color(0xFFF1C40F), // Yellow
    Color(0xFF9B59B6), // Purple
    Color(0xFFE67E22), // Orange
    Color(0xFF1ABC9C), // Teal
    Color(0xFFE91E63), // Pink
  ];

  // Gradients for layers (top to bottom)
  static const List<List<Color>> _defaultGradients = [
    [Color(0xFFFF4757), Color(0xFFE74C3C)], // Red gradient
    [Color(0xFF3742FA), Color(0xFF2C3E50)], // Blue gradient
    [Color(0xFF2ED573), Color(0xFF27AE60)], // Green gradient
    [Color(0xFFFFD93D), Color(0xFFF39C12)], // Yellow gradient
    [Color(0xFFA55EEA), Color(0xFF9B59B6)], // Purple gradient
    [Color(0xFF17A2B8), Color(0xFF1ABC9C)], // Cyan gradient
    [Color(0xFFFF6B81), Color(0xFFE91E63)], // Pink gradient
    [Color(0xFF1E90FF), Color(0xFF2980B9)], // Blue 2 gradient
  ];

  static const List<List<Color>> _ultraGradients = [
    [Color(0xFFE74C3C), Color(0xFFC0392B)], // Red
    [Color(0xFF3498DB), Color(0xFF2980B9)], // Blue
    [Color(0xFF2ECC71), Color(0xFF27AE60)], // Green
    [Color(0xFFF1C40F), Color(0xFFD4AC0D)], // Yellow
    [Color(0xFF9B59B6), Color(0xFF8E44AD)], // Purple
    [Color(0xFFE67E22), Color(0xFFD35400)], // Orange
    [Color(0xFF1ABC9C), Color(0xFF16A085)], // Teal
    [Color(0xFFE91E63), Color(0xFFC2185B)], // Pink
  ];

  static bool _useUltraPalette = false;

  static bool get isUltraMode => _useUltraPalette;

  static void setUltraPalette(bool enabled) {
    _useUltraPalette = enabled;
  }

  static List<Color> get palette =>
      _useUltraPalette ? _ultraPalette : _defaultPalette;

  static List<List<Color>> get layerGradients =>
      _useUltraPalette ? _ultraGradients : _defaultGradients;

  // Background enhancement
  static const Color backgroundDark = Color(0xFF0D1117);
  static const Color backgroundMid = Color(0xFF161B22);
  static const Color backgroundLight = Color(0xFF21262D);

  static const Color background = Color(0xFF0F1622);
  static const Color surface = Color(0xFF141C2A);
  static const Color accent = Color(0xFFFF6B81);
  static const Color zen = Color(0xFF2FB9B3);
  static const Color text = Color(0xFFEEEEEE);
  static const Color textMuted = Color(0xFF8B95A1);
  static const Color empty = Color(0xFF1C2433);

  // Accent glow colors
  static const Color successGlow = Color(0xFF2ED573);
  static const Color warningGlow = Color(0xFFFFD93D);
  static const Color errorGlow = Color(0xFFFF4757);

  static Color getColor(int index) {
    return palette[index % palette.length];
  }

  static List<Color> getGradient(int index) {
    return layerGradients[index % layerGradients.length];
  }
}

/// Layout constants
class GameSizes {
  static const double stackWidth = 60.0;
  static const double stackHeight = 200.0; // Default for depth 4-5
  static const double layerHeight = 40.0;
  static const double layerMargin = 2.0;
  static const double stackSpacing = 12.0;
  static const double borderRadius = 12.0;
  static const double stackBorderRadius = 8.0;

  /// Calculate dynamic stack height based on max depth
  /// Formula: (depth × (layerHeight + margin)) + topPadding
  static double getStackHeight(int maxDepth) {
    const topPadding = 8.0;
    return (maxDepth * (layerHeight + layerMargin)) + topPadding;
  }
}

/// Animation durations
class GameDurations {
  static const Duration layerMove = Duration(milliseconds: 150);
  static const Duration stackClear = Duration(milliseconds: 400);
  static const Duration levelComplete = Duration(milliseconds: 800);
  static const Duration buttonPress = Duration(milliseconds: 100);
  static const Duration multiGrabHold = Duration(milliseconds: 300);
  static const Duration multiGrabPulse = Duration(milliseconds: 600);
}

/// Game configuration
class GameConfig {
  static const int maxColors = 7;
  static const int maxStackDepth = 6;
  static const int adsEveryNLevels = 3;
  static const int maxUndos = 3;
}

/// Level difficulty parameters
class LevelParams {
  final int colors;
  final int stacks;
  final int emptySlots;
  final int depth;
  final int shuffleMoves;
  final int minDifficultyScore;
  final double lockedBlockProbability; // 0.0 to 1.0: chance of locked blocks
  final int maxLockedMoves; // Maximum moves a block can be locked for
  final double frozenBlockProbability; // 0.0 to 1.0: chance of frozen blocks

  const LevelParams({
    required this.colors,
    required this.stacks,
    required this.emptySlots,
    required this.depth,
    required this.shuffleMoves,
    this.minDifficultyScore = 0,
    this.lockedBlockProbability = 0.0,
    this.maxLockedMoves = 3,
    this.frozenBlockProbability = 0.0,
  });

  /// Get parameters for a given level number with progressive difficulty
  static LevelParams forLevel(int level) {
    if (level <= 10) {
      // Learning: 4 colors, 2 empty slots, no special blocks
      return LevelParams(
        colors: 4,
        depth: 4,
        stacks: 6,
        emptySlots: 2,
        shuffleMoves: 25 + (level * 3),
        minDifficultyScore: level,
        lockedBlockProbability: 0.0,
        frozenBlockProbability: 0.0,
      );
    }
    if (level <= 20) {
      // Intermediate: 5 colors, introduce locked blocks
      final lockedProb = ((level - 10) / 10 * 0.12).clamp(0.0, 0.12);
      return LevelParams(
        colors: 5,
        depth: 4,
        stacks: 7,
        emptySlots: 2,
        shuffleMoves: 30 + ((level - 10) * 2),
        minDifficultyScore: 4 + (level - 10),
        lockedBlockProbability: lockedProb,
        frozenBlockProbability: 0.0,
      );
    }
    if (level <= 30) {
      // Advanced: 5-6 colors, locked + first frozen blocks
      final colors = level <= 25 ? 5 : 6;
      final lockedProb = 0.12 + ((level - 20) / 10 * 0.08).clamp(0.0, 0.2);
      final frozenProb = ((level - 20) / 10 * 0.08).clamp(0.0, 0.08);
      return LevelParams(
        colors: colors,
        depth: 5,
        stacks: colors + 2,
        emptySlots: 2,
        shuffleMoves: 45 + ((level - 20) * 2),
        minDifficultyScore: 8 + (level - 20),
        lockedBlockProbability: lockedProb,
        frozenBlockProbability: frozenProb,
        maxLockedMoves: 3,
      );
    }
    if (level <= 40) {
      // Expert: 6 colors, locked + frozen
      final lockedProb = 0.15 + ((level - 30) / 10 * 0.05).clamp(0.0, 0.2);
      final frozenProb = 0.08 + ((level - 30) / 10 * 0.07).clamp(0.0, 0.15);
      return LevelParams(
        colors: 6,
        depth: 5,
        stacks: 8,
        emptySlots: 2,
        shuffleMoves: 55 + ((level - 30) * 2),
        minDifficultyScore: 12 + (level - 30),
        lockedBlockProbability: lockedProb,
        frozenBlockProbability: frozenProb,
        maxLockedMoves: 3,
      );
    }
    if (level <= 50) {
      // Master: 7 colors, full mechanics
      final lockedProb = 0.18;
      final frozenProb = 0.12;
      return LevelParams(
        colors: 7,
        depth: 5,
        stacks: 9,
        emptySlots: 2,
        shuffleMoves: 70 + ((level - 40) * 2),
        minDifficultyScore: 18 + (level - 40),
        lockedBlockProbability: lockedProb,
        frozenBlockProbability: frozenProb,
        maxLockedMoves: 3,
      );
    }
    if (level <= 100) {
      // Expert+: 7-8 colors, maximum difficulty
      final extraColors = level >= 75 ? 1 : 0;
      final lockedProb = 0.2;
      final frozenProb = 0.15;
      return LevelParams(
        colors: 7 + extraColors,
        depth: 5,
        stacks: 8 + extraColors,
        emptySlots: 1,
        shuffleMoves: 80 + (level - 50),
        minDifficultyScore: 20 + ((level - 50) ~/ 5),
        lockedBlockProbability: lockedProb,
        frozenBlockProbability: frozenProb,
        maxLockedMoves: 3,
      );
    }
    // Master 100+: max difficulty
    final extraColors = ((level - 100) ~/ 25).clamp(0, 1);
    return LevelParams(
      colors: (7 + extraColors).clamp(0, 8),
      depth: 6,
      stacks: 8 + extraColors,
      emptySlots: 1,
      shuffleMoves: 80 + ((level - 100) ~/ 2),
      minDifficultyScore: 25,
      lockedBlockProbability: 0.2,
      frozenBlockProbability: 0.15,
      maxLockedMoves: 3,
    );
  }
}

class ZenParams {
  static const LevelParams easy = LevelParams(
    colors: 4,
    depth: 4,
    stacks: 6,
    emptySlots: 2,
    shuffleMoves: 35,
  );

  static const LevelParams medium = LevelParams(
    colors: 5,
    depth: 5,
    stacks: 7,
    emptySlots: 2,
    shuffleMoves: 55,
    lockedBlockProbability: 0.06,
  );

  static const LevelParams hard = LevelParams(
    colors: 6,
    depth: 5,
    stacks: 8,
    emptySlots: 2,
    shuffleMoves: 80,
    lockedBlockProbability: 0.08,
    frozenBlockProbability: 0.04,
  );

  static const LevelParams ultra = LevelParams(
    colors: 6,
    depth: 5,
    stacks: 8,
    emptySlots: 2,
    shuffleMoves: 100,
    lockedBlockProbability: 0.1,
    frozenBlockProbability: 0.06,
  );
}

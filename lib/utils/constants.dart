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
  static const Duration layerMove = Duration(milliseconds: 200);
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
  final double
  multiColorProbability; // 0.0 to 1.0: chance of multi-color blocks
  final double lockedBlockProbability; // 0.0 to 1.0: chance of locked blocks
  final int maxLockedMoves; // Maximum moves a block can be locked for

  const LevelParams({
    required this.colors,
    required this.stacks,
    required this.emptySlots,
    required this.depth,
    required this.shuffleMoves,
    this.minDifficultyScore = 0,
    this.multiColorProbability = 0.0,
    this.lockedBlockProbability = 0.0,
    this.maxLockedMoves = 3,
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
        multiColorProbability: 0.0,
        lockedBlockProbability: 0.0,
      );
    }
    if (level <= 25) {
      // Intermediate: 5 colors, introduce multi-color blocks gradually
      final multiColorProb = ((level - 10) / 15).clamp(0.0, 0.15);
      return LevelParams(
        colors: 5,
        depth: 4,
        stacks: 7,
        emptySlots: 2,
        shuffleMoves: 30 + ((level - 10) * 2),
        minDifficultyScore: 4 + (level - 10),
        multiColorProbability: multiColorProb,
        lockedBlockProbability: 0.0,
      );
    }
    if (level <= 50) {
      // Advanced: 5-6 colors, more multi-color blocks, introduce locked blocks
      final colors = level <= 35 ? 5 : 6;
      final multiColorProb = 0.15 + ((level - 25) / 25 * 0.15).clamp(0.0, 0.3);
      final lockedProb = level >= 35
          ? ((level - 35) / 15).clamp(0.0, 0.1)
          : 0.0;
      return LevelParams(
        colors: colors,
        depth: 5,
        stacks: colors + 2,
        emptySlots: 2,
        shuffleMoves: 45 + ((level - 25) * 2),
        minDifficultyScore: 8 + (level - 25),
        multiColorProbability: multiColorProb,
        lockedBlockProbability: lockedProb,
        maxLockedMoves: 3,
      );
    }
    if (level <= 100) {
      // Expert: 6 colors, 1 empty slot, frequent multi-color and locked blocks
      final multiColorProb = 0.3 + ((level - 50) / 50 * 0.15).clamp(0.0, 0.45);
      final lockedProb = 0.1 + ((level - 50) / 50 * 0.1).clamp(0.0, 0.2);
      return LevelParams(
        colors: 6,
        depth: 5,
        stacks: 7,
        emptySlots: 1,
        shuffleMoves: 60 + (level - 50),
        minDifficultyScore: 15 + ((level - 50) ~/ 5),
        multiColorProbability: multiColorProb,
        lockedBlockProbability: lockedProb,
        maxLockedMoves: 4,
      );
    }
    // Master: 6-7 colors, 1 empty, deep, maximum difficulty
    final extraColors = ((level - 100) ~/ 25).clamp(0, 1);
    final multiColorProb = 0.45 + (extraColors * 0.1);
    final lockedProb = 0.2 + (extraColors * 0.05);
    return LevelParams(
      colors: 6 + extraColors,
      depth: 6,
      stacks: 7 + extraColors,
      emptySlots: 1,
      shuffleMoves: 80 + ((level - 100) ~/ 2),
      minDifficultyScore: 25,
      multiColorProbability: multiColorProb.clamp(0.0, 0.6),
      lockedBlockProbability: lockedProb.clamp(0.0, 0.3),
      maxLockedMoves: 5,
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
    minDifficultyScore: 6,
  );

  static const LevelParams medium = LevelParams(
    colors: 5,
    depth: 5,
    stacks: 7,
    emptySlots: 2,
    shuffleMoves: 55,
    minDifficultyScore: 10,
  );

  static const LevelParams hard = LevelParams(
    colors: 6,
    depth: 5,
    stacks: 8,
    emptySlots: 2,
    shuffleMoves: 80,
    minDifficultyScore: 15,
  );

  static const LevelParams ultra = LevelParams(
    colors: 7,
    depth: 6,
    stacks: 9,
    emptySlots: 2,
    shuffleMoves: 120,
    minDifficultyScore: 22,
  );
}

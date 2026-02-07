import 'package:flutter/material.dart';

/// Game color palette - vibrant, high contrast
class GameColors {
  // Primary palette - richer, more saturated
  static const List<Color> palette = [
    Color(0xFFFF4757), // Coral Red
    Color(0xFF3742FA), // Electric Blue
    Color(0xFF2ED573), // Emerald Green
    Color(0xFFFFD93D), // Golden Yellow
    Color(0xFFA55EEA), // Royal Purple
    Color(0xFF17A2B8), // Teal Cyan
    Color(0xFFFF6B81), // Soft Pink
    Color(0xFF1E90FF), // Dodger Blue
  ];

  // Gradients for layers (top to bottom)
  static const List<List<Color>> layerGradients = [
    [Color(0xFFFF4757), Color(0xFFE74C3C)], // Red gradient
    [Color(0xFF3742FA), Color(0xFF2C3E50)], // Blue gradient
    [Color(0xFF2ED573), Color(0xFF27AE60)], // Green gradient
    [Color(0xFFFFD93D), Color(0xFFF39C12)], // Yellow gradient
    [Color(0xFFA55EEA), Color(0xFF9B59B6)], // Purple gradient
    [Color(0xFF17A2B8), Color(0xFF1ABC9C)], // Cyan gradient
    [Color(0xFFFF6B81), Color(0xFFE91E63)], // Pink gradient
    [Color(0xFF1E90FF), Color(0xFF2980B9)], // Blue 2 gradient
  ];

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
  static const double stackHeight = 200.0;
  static const double layerHeight = 40.0;
  static const double stackSpacing = 12.0;
  static const double borderRadius = 12.0;
  static const double stackBorderRadius = 8.0;
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

  const LevelParams({
    required this.colors,
    required this.stacks,
    required this.emptySlots,
    required this.depth,
    required this.shuffleMoves,
    this.minDifficultyScore = 0,
  });

  /// Get parameters for a given level number
  static LevelParams forLevel(int level) {
    if (level <= 10) {
      // Learning: 4 colors, 2 empty slots
      return LevelParams(
        colors: 4,
        depth: 4,
        stacks: 6,
        emptySlots: 2,
        shuffleMoves: 15 + (level * 3),
        minDifficultyScore: level,
      );
    }
    if (level <= 25) {
      // Intermediate: 5 colors
      return LevelParams(
        colors: 5,
        depth: 4,
        stacks: 7,
        emptySlots: 2,
        shuffleMoves: 30 + ((level - 10) * 2),
        minDifficultyScore: 4 + (level - 10),
      );
    }
    if (level <= 50) {
      // Advanced: 5-6 colors, deeper
      final colors = level <= 35 ? 5 : 6;
      return LevelParams(
        colors: colors,
        depth: 5,
        stacks: colors + 2,
        emptySlots: 2,
        shuffleMoves: 45 + ((level - 25) * 2),
        minDifficultyScore: 8 + (level - 25),
      );
    }
    if (level <= 100) {
      // Expert: 6 colors, 1 empty slot
      return LevelParams(
        colors: 6,
        depth: 5,
        stacks: 7,
        emptySlots: 1,
        shuffleMoves: 60 + (level - 50),
        minDifficultyScore: 15 + ((level - 50) ~/ 5),
      );
    }
    // Master: 6-7 colors, 1 empty, deep
    final extraColors = ((level - 100) ~/ 25).clamp(0, 1);
    return LevelParams(
      colors: 6 + extraColors,
      depth: 6,
      stacks: 7 + extraColors,
      emptySlots: 1,
      shuffleMoves: 80 + ((level - 100) ~/ 2),
      minDifficultyScore: 25,
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

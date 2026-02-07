import 'package:flutter/material.dart';

/// Game color palette - vibrant, high contrast
class GameColors {
  static const List<Color> palette = [
    Color(0xFFE53935), // Red
    Color(0xFF1E88E5), // Blue
    Color(0xFF43A047), // Green
    Color(0xFFFFB300), // Amber
    Color(0xFF8E24AA), // Purple
    Color(0xFF00ACC1), // Cyan
  ];

  static const Color background = Color(0xFF1A1A2E);
  static const Color surface = Color(0xFF16213E);
  static const Color accent = Color(0xFFE94560);
  static const Color text = Color(0xFFEEEEEE);
  static const Color textMuted = Color(0xFF888888);
  static const Color empty = Color(0xFF2D2D44);

  static Color getColor(int index) {
    return palette[index % palette.length];
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
}

/// Game configuration
class GameConfig {
  static const int maxColors = 6;
  static const int maxStackDepth = 5;
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

  const LevelParams({
    required this.colors,
    required this.stacks,
    required this.emptySlots,
    required this.depth,
    required this.shuffleMoves,
  });

  /// Get parameters for a given level number
  static LevelParams forLevel(int level) {
    if (level <= 10) {
      // Tutorial: 3 colors, 2 empty slots, easy
      return LevelParams(
        colors: 3,
        stacks: 3 + 2, // 3 color stacks + 2 empty
        emptySlots: 2,
        depth: 3,
        shuffleMoves: 15 + level,
      );
    } else if (level <= 30) {
      // Early game: 4 colors, still 2 empty slots
      return LevelParams(
        colors: 4,
        stacks: 4 + 2,
        emptySlots: 2,
        depth: 4,
        shuffleMoves: 20 + level,
      );
    } else if (level <= 50) {
      // Mid game: 5 colors, 2 empty slots
      return LevelParams(
        colors: 5,
        stacks: 5 + 2,
        emptySlots: 2,
        depth: 4,
        shuffleMoves: 30 + level,
      );
    } else if (level <= 75) {
      // Difficulty ramp: 5 colors, reduce to 1 empty slot
      return LevelParams(
        colors: 5,
        stacks: 5 + 1,
        emptySlots: 1,
        depth: 4,
        shuffleMoves: 40 + level,
      );
    } else if (level <= 100) {
      // Hard: 6 colors, 1 empty slot
      return LevelParams(
        colors: 6,
        stacks: 6 + 1,
        emptySlots: 1,
        depth: 5,
        shuffleMoves: 50 + level,
      );
    } else {
      // Expert: 6 colors, 1 empty slot, max depth
      return LevelParams(
        colors: 6,
        stacks: 6 + 1,
        emptySlots: 1,
        depth: 5,
        shuffleMoves: 60 + level,
      );
    }
  }

  /// Minimum difficulty score required for this level
  int get minDifficultyScore {
    if (emptySlots >= 2) {
      return 3; // Low bar for easy levels
    } else if (colors <= 5) {
      return 5; // Medium bar
    } else {
      return 7; // Higher bar for hard levels
    }
  }
}

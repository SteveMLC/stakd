import 'package:flutter/material.dart';
import '../models/theme_data.dart';
import '../services/theme_service.dart';

/// Theme-aware color accessor
/// Use this in non-const contexts where you need theme colors
class ThemeColors {
  ThemeColors._();

  /// Get the current theme
  static GameTheme get theme {
    final service = ThemeService();
    return service.isInitialized ? service.currentTheme : defaultTheme;
  }

  // Primary palette - from theme
  static List<Color> get palette => theme.blockPalette;

  // Gradients for layers
  static List<List<Color>> get layerGradients => theme.blockGradients;

  // Background colors
  static Color get backgroundColor => theme.backgroundColor;
  static Color get backgroundGradientEnd => theme.backgroundGradientEnd;
  static Color get surfaceColor => theme.surfaceColor;
  static Color get emptySlotColor => theme.emptySlotColor;
  static Color get textColor => theme.textColor;
  static Color get textMutedColor => theme.textMutedColor;
  static Color get accentColor => theme.accentColor;
  static Color get particleColor => theme.particleColor;

  // Theme properties
  static bool get hasBlockGlow => theme.hasBlockGlow;
  static bool get hasParticles => theme.hasParticles;
  static double get blockBorderRadius => theme.blockBorderRadius;

  /// Get a color from the palette by index
  static Color getColor(int index) {
    final p = palette;
    return p[index % p.length];
  }

  /// Get a gradient from the palette by index
  static List<Color> getGradient(int index) {
    final g = layerGradients;
    return g[index % g.length];
  }
}

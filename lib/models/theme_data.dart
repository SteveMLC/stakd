import 'package:flutter/material.dart';

/// Represents a visual theme for the game
class GameTheme {
  final String id;
  final String name;
  final String icon; // Emoji
  final Color backgroundColor;
  final Color backgroundGradientEnd;
  final Color surfaceColor;
  final Color emptySlotColor;
  final Color textColor;
  final Color textMutedColor;
  final Color accentColor;
  final List<Color> blockPalette;
  final List<List<Color>> blockGradients;
  final Color particleColor;
  final bool hasBlockGlow;
  final bool hasParticles;
  final double blockBorderRadius;
  final int price; // In coins, 0 = free/default

  const GameTheme({
    required this.id,
    required this.name,
    required this.icon,
    required this.backgroundColor,
    required this.backgroundGradientEnd,
    required this.surfaceColor,
    required this.emptySlotColor,
    required this.textColor,
    required this.textMutedColor,
    required this.accentColor,
    required this.blockPalette,
    required this.blockGradients,
    required this.particleColor,
    this.hasBlockGlow = false,
    this.hasParticles = true,
    this.blockBorderRadius = 8.0,
    this.price = 0,
  });
}

// ============================================================================
// THEME DEFINITIONS
// ============================================================================

/// Default theme - Dark with vibrant colors
const defaultTheme = GameTheme(
  id: 'default',
  name: 'Default',
  icon: '🎮',
  backgroundColor: Color(0xFF0F1622),
  backgroundGradientEnd: Color(0xFF1A1A2E),
  surfaceColor: Color(0xFF141C2A),
  emptySlotColor: Color(0xFF1C2433),
  textColor: Color(0xFFEEEEEE),
  textMutedColor: Color(0xFF8B95A1),
  accentColor: Color(0xFFFF6B81),
  blockPalette: [
    Color(0xFFFF4757), // Coral Red
    Color(0xFF3742FA), // Electric Blue
    Color(0xFF2ED573), // Emerald Green
    Color(0xFFFFD93D), // Golden Yellow
    Color(0xFFA55EEA), // Royal Purple
    Color(0xFF17A2B8), // Teal Cyan
    Color(0xFFFF6B81), // Soft Pink
    Color(0xFF1E90FF), // Dodger Blue
  ],
  blockGradients: [
    [Color(0xFFFF4757), Color(0xFFE74C3C)],
    [Color(0xFF3742FA), Color(0xFF2C3E50)],
    [Color(0xFF2ED573), Color(0xFF27AE60)],
    [Color(0xFFFFD93D), Color(0xFFF39C12)],
    [Color(0xFFA55EEA), Color(0xFF9B59B6)],
    [Color(0xFF17A2B8), Color(0xFF1ABC9C)],
    [Color(0xFFFF6B81), Color(0xFFE91E63)],
    [Color(0xFF1E90FF), Color(0xFF2980B9)],
  ],
  particleColor: Color(0xFFFFFFFF),
  hasBlockGlow: false,
  hasParticles: true,
  price: 0,
);

/// Neon Night - Glowing neon colors on black
const neonTheme = GameTheme(
  id: 'neon',
  name: 'Neon Night',
  icon: '🌃',
  backgroundColor: Color(0xFF000000),
  backgroundGradientEnd: Color(0xFF0A0A0A),
  surfaceColor: Color(0xFF0D0D0D),
  emptySlotColor: Color(0xFF1A1A1A),
  textColor: Color(0xFFFFFFFF),
  textMutedColor: Color(0xFF666666),
  accentColor: Color(0xFF00FFFF),
  blockPalette: [
    Color(0xFF00FFFF), // Electric Cyan
    Color(0xFFFF00FF), // Hot Magenta
    Color(0xFF00FF00), // Acid Green
    Color(0xFFFF0080), // Neon Pink
    Color(0xFF8000FF), // Electric Purple
    Color(0xFFFFFF00), // Electric Yellow
    Color(0xFFFF4000), // Neon Orange
    Color(0xFF0080FF), // Electric Blue
  ],
  blockGradients: [
    [Color(0xFF00FFFF), Color(0xFF0099CC)],
    [Color(0xFFFF00FF), Color(0xFFCC0099)],
    [Color(0xFF00FF00), Color(0xFF00CC00)],
    [Color(0xFFFF0080), Color(0xFFCC0066)],
    [Color(0xFF8000FF), Color(0xFF6600CC)],
    [Color(0xFFFFFF00), Color(0xFFCCCC00)],
    [Color(0xFFFF4000), Color(0xFFCC3300)],
    [Color(0xFF0080FF), Color(0xFF0066CC)],
  ],
  particleColor: Color(0xFF00FFFF),
  hasBlockGlow: true,
  hasParticles: true,
  price: 500,
);

/// Ocean Calm - Deep blue ocean colors
const oceanTheme = GameTheme(
  id: 'ocean',
  name: 'Ocean Calm',
  icon: '🌊',
  backgroundColor: Color(0xFF0A1628),
  backgroundGradientEnd: Color(0xFF1A2E4A),
  surfaceColor: Color(0xFF0D1E33),
  emptySlotColor: Color(0xFF14273E),
  textColor: Color(0xFFE0F4FF),
  textMutedColor: Color(0xFF6B9AC4),
  accentColor: Color(0xFF4DD0E1),
  blockPalette: [
    Color(0xFF00BCD4), // Cyan
    Color(0xFF26C6DA), // Light Cyan
    Color(0xFF00ACC1), // Dark Cyan
    Color(0xFF0097A7), // Teal
    Color(0xFF00838F), // Deep Teal
    Color(0xFF4DD0E1), // Aqua
    Color(0xFF80DEEA), // Light Aqua
    Color(0xFF84FFFF), // Bright Aqua
  ],
  blockGradients: [
    [Color(0xFF00BCD4), Color(0xFF0097A7)],
    [Color(0xFF26C6DA), Color(0xFF00ACC1)],
    [Color(0xFF00ACC1), Color(0xFF00838F)],
    [Color(0xFF0097A7), Color(0xFF006064)],
    [Color(0xFF00838F), Color(0xFF004D40)],
    [Color(0xFF4DD0E1), Color(0xFF26C6DA)],
    [Color(0xFF80DEEA), Color(0xFF4DD0E1)],
    [Color(0xFF84FFFF), Color(0xFF80DEEA)],
  ],
  particleColor: Color(0xFF80DEEA),
  hasBlockGlow: false,
  hasParticles: true,
  blockBorderRadius: 10.0,
  price: 750,
);

/// Forest Spirit - Earthy greens and browns
const forestTheme = GameTheme(
  id: 'forest',
  name: 'Forest Spirit',
  icon: '🌲',
  backgroundColor: Color(0xFF1A2416),
  backgroundGradientEnd: Color(0xFF2D3A26),
  surfaceColor: Color(0xFF232E1F),
  emptySlotColor: Color(0xFF2A3524),
  textColor: Color(0xFFE8F0E4),
  textMutedColor: Color(0xFF8BAF80),
  accentColor: Color(0xFF8BC34A),
  blockPalette: [
    Color(0xFF4CAF50), // Forest Green
    Color(0xFF66BB6A), // Light Green
    Color(0xFF388E3C), // Dark Green
    Color(0xFF8D6E63), // Brown
    Color(0xFFFFB74D), // Amber
    Color(0xFFA5D6A7), // Sage
    Color(0xFF795548), // Dark Brown
    Color(0xFFAED581), // Lime Green
  ],
  blockGradients: [
    [Color(0xFF4CAF50), Color(0xFF388E3C)],
    [Color(0xFF66BB6A), Color(0xFF4CAF50)],
    [Color(0xFF388E3C), Color(0xFF2E7D32)],
    [Color(0xFF8D6E63), Color(0xFF6D4C41)],
    [Color(0xFFFFB74D), Color(0xFFFFA000)],
    [Color(0xFFA5D6A7), Color(0xFF81C784)],
    [Color(0xFF795548), Color(0xFF5D4037)],
    [Color(0xFFAED581), Color(0xFF8BC34A)],
  ],
  particleColor: Color(0xFFA5D6A7),
  hasBlockGlow: false,
  hasParticles: true,
  blockBorderRadius: 12.0,
  price: 750,
);

/// Candy Land - Pastel candy colors
const candyTheme = GameTheme(
  id: 'candy',
  name: 'Candy Land',
  icon: '🍬',
  backgroundColor: Color(0xFFFFF0F5),
  backgroundGradientEnd: Color(0xFFFFE4EC),
  surfaceColor: Color(0xFFFFE8EE),
  emptySlotColor: Color(0xFFFFD6E0),
  textColor: Color(0xFF5A4050),
  textMutedColor: Color(0xFF9A8090),
  accentColor: Color(0xFFFF80AB),
  blockPalette: [
    Color(0xFFFFB6C1), // Light Pink
    Color(0xFFB8E0D2), // Mint
    Color(0xFFE6E6FA), // Lavender
    Color(0xFFFFDAB9), // Peach
    Color(0xFFFFE4B5), // Moccasin
    Color(0xFFF0E68C), // Khaki
    Color(0xFFD4EDDA), // Light Green
    Color(0xFFCCD5FF), // Periwinkle
  ],
  blockGradients: [
    [Color(0xFFFFB6C1), Color(0xFFFF91A4)],
    [Color(0xFFB8E0D2), Color(0xFF98D6C4)],
    [Color(0xFFE6E6FA), Color(0xFFD8BFD8)],
    [Color(0xFFFFDAB9), Color(0xFFFFC89A)],
    [Color(0xFFFFE4B5), Color(0xFFFFD699)],
    [Color(0xFFF0E68C), Color(0xFFDDCE6E)],
    [Color(0xFFD4EDDA), Color(0xFFB8DFC4)],
    [Color(0xFFCCD5FF), Color(0xFFB3C0FF)],
  ],
  particleColor: Color(0xFFFFB6C1),
  hasBlockGlow: false,
  hasParticles: true,
  blockBorderRadius: 14.0,
  price: 1000,
);

/// Minimalist - Clean black and white
const minimalistTheme = GameTheme(
  id: 'minimalist',
  name: 'Minimalist',
  icon: '⬜',
  backgroundColor: Color(0xFFFAFAFA),
  backgroundGradientEnd: Color(0xFFF0F0F0),
  surfaceColor: Color(0xFFFFFFFF),
  emptySlotColor: Color(0xFFE8E8E8),
  textColor: Color(0xFF1A1A1A),
  textMutedColor: Color(0xFF888888),
  accentColor: Color(0xFF333333),
  blockPalette: [
    Color(0xFF1A1A1A), // Black
    Color(0xFF333333), // Dark Gray
    Color(0xFF4D4D4D), // Medium Dark Gray
    Color(0xFF666666), // Gray
    Color(0xFF808080), // Medium Gray
    Color(0xFF999999), // Light Gray
    Color(0xFFB3B3B3), // Lighter Gray
    Color(0xFFCCCCCC), // Very Light Gray
  ],
  blockGradients: [
    [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
    [Color(0xFF333333), Color(0xFF262626)],
    [Color(0xFF4D4D4D), Color(0xFF404040)],
    [Color(0xFF666666), Color(0xFF595959)],
    [Color(0xFF808080), Color(0xFF737373)],
    [Color(0xFF999999), Color(0xFF8C8C8C)],
    [Color(0xFFB3B3B3), Color(0xFFA6A6A6)],
    [Color(0xFFCCCCCC), Color(0xFFBFBFBF)],
  ],
  particleColor: Color(0xFF666666),
  hasBlockGlow: false,
  hasParticles: false,
  blockBorderRadius: 4.0,
  price: 500,
);

/// All available themes
const allGameThemes = [
  defaultTheme,
  neonTheme,
  oceanTheme,
  forestTheme,
  candyTheme,
  minimalistTheme,
];

/// Get theme by ID
GameTheme? getThemeById(String id) {
  try {
    return allGameThemes.firstWhere((theme) => theme.id == id);
  } catch (_) {
    return null;
  }
}

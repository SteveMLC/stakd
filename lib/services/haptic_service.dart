import 'package:flutter/services.dart';

/// Haptic feedback service for Stakd
/// Provides consistent haptic patterns throughout the game
class HapticService {
  // Private constructor - singleton pattern
  HapticService._();
  static final HapticService instance = HapticService._();

  /// Light tap - used for layer/stack selection
  Future<void> lightTap() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium impact - used for layer drop/placement
  Future<void> mediumImpact() async {
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact - used for significant events
  Future<void> heavyImpact() async {
    await HapticFeedback.heavyImpact();
  }

  /// Success pattern - 3 quick pulses for stack complete
  Future<void> successPattern() async {
    for (int i = 0; i < 3; i++) {
      await HapticFeedback.lightImpact();
      if (i < 2) {
        await Future.delayed(const Duration(milliseconds: 80));
      }
    }
  }

  /// Level win pattern - heavy impact followed by success sequence
  Future<void> levelWinPattern() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    await successPattern();
  }

  /// Combo burst - medium impact with varying intensity based on combo level
  Future<void> comboBurst(int comboLevel) async {
    if (comboLevel >= 4) {
      // High combo gets heavy impact
      await HapticFeedback.heavyImpact();
    } else if (comboLevel >= 2) {
      // Medium combo gets medium impact
      await HapticFeedback.mediumImpact();
    }
  }

  /// Error/invalid move feedback
  Future<void> error() async {
    await HapticFeedback.vibrate();
  }

  /// Selection feedback (alias for lightTap)
  Future<void> selection() async {
    await lightTap();
  }
}

/// Global instance for easy access
final haptics = HapticService.instance;

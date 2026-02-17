import 'package:flutter/services.dart';
import 'storage_service.dart';

/// Haptic feedback service for Stakd
/// Provides consistent haptic patterns throughout the game
class HapticService {
  // Private constructor - singleton pattern
  HapticService._();
  static final HapticService instance = HapticService._();

  bool _isEnabled() => StorageService().getHapticsEnabled();

  /// Light tap - used for layer/stack selection
  Future<void> lightTap() async {
    if (!_isEnabled()) return;
    await HapticFeedback.lightImpact();
  }

  /// Medium impact - used for layer drop/placement
  Future<void> mediumImpact() async {
    if (!_isEnabled()) return;
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact - used for significant events
  Future<void> heavyImpact() async {
    if (!_isEnabled()) return;
    await HapticFeedback.heavyImpact();
  }

  /// Success pattern - 3 quick pulses for stack complete
  Future<void> successPattern() async {
    if (!_isEnabled()) return;
    for (int i = 0; i < 3; i++) {
      await HapticFeedback.lightImpact();
      if (i < 2) {
        await Future.delayed(const Duration(milliseconds: 80));
      }
    }
  }

  /// Level win pattern - heavy impact followed by success sequence
  Future<void> levelWinPattern() async {
    if (!_isEnabled()) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    await successPattern();
  }

  /// Combo burst - medium impact with varying intensity based on combo level
  Future<void> comboBurst(int comboLevel) async {
    if (!_isEnabled()) return;
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
    if (!_isEnabled()) return;
    await HapticFeedback.vibrate();
  }

  /// Selection feedback (alias for lightTap)
  Future<void> selection() async {
    await lightTap();
  }

  /// Chain reaction haptic - escalating intensity based on chain level
  Future<void> chainReaction(int chainLevel) async {
    if (!_isEnabled()) return;
    
    if (chainLevel >= 4) {
      // Mega chain - heavy burst pattern
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await successPattern();
    } else if (chainLevel == 3) {
      // Triple chain - strong double tap
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.lightImpact();
    } else if (chainLevel == 2) {
      // Double chain - medium double tap
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
    } else {
      // Single - just the normal success
      await successPattern();
    }
  }
}

/// Global instance for easy access
final haptics = HapticService.instance;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages review prompts and tracking user engagement
class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  SharedPreferences? _prefs;

  // Keys
  static const String _keySessionCount = 'review_session_count';
  static const String _keyTotalMoves = 'review_total_moves';
  static const String _keyLastPromptDate = 'review_last_prompt_date';
  static const String _keyHasReviewed = 'review_has_reviewed';
  static const String _keyLevel10Completed = 'review_level10_completed';

  // Configuration
  static const int _sessionThreshold = 5;
  static const int _movesThreshold = 100;
  static const int _cooldownDays = 7;

  /// Initialize the review service (called from StorageService init)
  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
  }

  /// Increment session count (call when app opens)
  Future<void> incrementSessionCount() async {
    try {
      final current = getSessionCount();
      await _prefs?.setInt(_keySessionCount, current + 1);
    } catch (e) {
      debugPrint('ReviewService incrementSessionCount failed: $e');
    }
  }

  /// Get current session count
  int getSessionCount() {
    try {
      return _prefs?.getInt(_keySessionCount) ?? 0;
    } catch (e) {
      debugPrint('ReviewService getSessionCount failed: $e');
      return 0;
    }
  }

  /// Mark level 10 as completed (call when level 10 is completed for first time)
  Future<void> markLevel10Completed() async {
    try {
      await _prefs?.setBool(_keyLevel10Completed, true);
    } catch (e) {
      debugPrint('ReviewService markLevel10Completed failed: $e');
    }
  }

  /// Check if level 10 has been completed
  bool isLevel10Completed() {
    try {
      return _prefs?.getBool(_keyLevel10Completed) ?? false;
    } catch (e) {
      debugPrint('ReviewService isLevel10Completed failed: $e');
      return false;
    }
  }

  /// Check if user has already reviewed
  bool hasReviewed() {
    try {
      return _prefs?.getBool(_keyHasReviewed) ?? false;
    } catch (e) {
      debugPrint('ReviewService hasReviewed failed: $e');
      return false;
    }
  }

  /// Mark that user has reviewed
  Future<void> markReviewed() async {
    try {
      await _prefs?.setBool(_keyHasReviewed, true);
      await markReviewPromptShown(); // Also update last shown date
    } catch (e) {
      debugPrint('ReviewService markReviewed failed: $e');
    }
  }

  /// Mark that review prompt was shown (declined or accepted)
  Future<void> markReviewPromptShown() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _prefs?.setInt(_keyLastPromptDate, now);
    } catch (e) {
      debugPrint('ReviewService markReviewPromptShown failed: $e');
    }
  }

  /// Get last prompt date
  DateTime? getLastPromptDate() {
    try {
      final millis = _prefs?.getInt(_keyLastPromptDate);
      if (millis == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    } catch (e) {
      debugPrint('ReviewService getLastPromptDate failed: $e');
      return null;
    }
  }

  /// Check if we're within cooldown period
  bool isInCooldown() {
    final lastPrompt = getLastPromptDate();
    if (lastPrompt == null) return false;

    final daysSinceLastPrompt = DateTime.now().difference(lastPrompt).inDays;
    return daysSinceLastPrompt < _cooldownDays;
  }

  /// Determine if review prompt should be shown
  /// Returns true if ANY trigger condition is met AND not in cooldown
  bool shouldShowReviewPrompt(int currentLevel, int totalMoves) {
    // Never show if already reviewed
    if (hasReviewed()) return false;

    // Don't show if in cooldown period
    if (isInCooldown()) return false;

    // Trigger 1: Level 10 completed for the first time
    if (currentLevel == 10 && !isLevel10Completed()) {
      return true;
    }

    // Trigger 2: 5th game session
    if (getSessionCount() >= _sessionThreshold) {
      return true;
    }

    // Trigger 3: 100 total moves made
    if (totalMoves >= _movesThreshold) {
      return true;
    }

    return false;
  }

  /// Reset all review tracking (for testing)
  Future<void> resetReviewData() async {
    try {
      await _prefs?.remove(_keySessionCount);
      await _prefs?.remove(_keyTotalMoves);
      await _prefs?.remove(_keyLastPromptDate);
      await _prefs?.remove(_keyHasReviewed);
      await _prefs?.remove(_keyLevel10Completed);
    } catch (e) {
      debugPrint('ReviewService resetReviewData failed: $e');
    }
  }

  /// Get review stats for debugging
  Map<String, Object?> getStats() {
    return {
      'sessionCount': getSessionCount(),
      'lastPromptDate': getLastPromptDate()?.toIso8601String(),
      'hasReviewed': hasReviewed(),
      'level10Completed': isLevel10Completed(),
      'isInCooldown': isInCooldown(),
    };
  }
}

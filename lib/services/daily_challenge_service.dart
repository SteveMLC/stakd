import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_challenge.dart';

class DailyChallengeService {
  static const String _historyKey = 'daily_challenge_history';
  static const String _streakKey = 'daily_challenge_streak';
  static const String _lastCompletedKey = 'daily_challenge_last_completed';

  /// Get today's challenge
  Future<DailyChallenge> getTodaysChallenge() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DailyChallenge.today();
    
    // Check if we have completion data for today
    final historyJson = prefs.getString(_historyKey);
    if (historyJson != null) {
      final history = Map<String, dynamic>.from(jsonDecode(historyJson));
      final todayKey = _dateKey(today.date);
      
      if (history.containsKey(todayKey)) {
        final data = history[todayKey];
        return today.copyWith(
          completed: data['completed'] ?? false,
          bestTime: data['bestTime'] != null
              ? Duration(seconds: data['bestTime'])
              : null,
        );
      }
    }
    
    return today;
  }

  /// Mark today's challenge as completed
  Future<void> markCompleted(Duration time) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = _dateKey(today);
    
    // Load existing history
    final historyJson = prefs.getString(_historyKey);
    final history = historyJson != null
        ? Map<String, dynamic>.from(jsonDecode(historyJson))
        : <String, dynamic>{};
    
    // Check if already completed with a better time
    final existing = history[todayKey];
    final existingTime = existing?['bestTime'];
    
    if (existingTime == null || time.inSeconds < existingTime) {
      history[todayKey] = {
        'completed': true,
        'bestTime': time.inSeconds,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(_historyKey, jsonEncode(history));
      
      // Update streak
      await _updateStreak(today);
    }
  }

  /// Get current streak count
  Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }

  /// Get completion history for past 30 days
  Future<Map<DateTime, Duration?>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    
    if (historyJson == null) return {};
    
    final history = Map<String, dynamic>.from(jsonDecode(historyJson));
    final result = <DateTime, Duration?>{};
    
    final now = DateTime.now();
    for (var i = 0; i < 30; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final key = _dateKey(date);
      
      if (history.containsKey(key)) {
        final data = history[key];
        result[date] = data['bestTime'] != null
            ? Duration(seconds: data['bestTime'])
            : null;
      }
    }
    
    return result;
  }

  /// Check if today's challenge is completed
  Future<bool> isTodayCompleted() async {
    final challenge = await getTodaysChallenge();
    return challenge.completed;
  }

  /// Update streak based on completion
  Future<void> _updateStreak(DateTime completedDate) async {
    final prefs = await SharedPreferences.getInstance();
    final lastCompletedStr = prefs.getString(_lastCompletedKey);
    
    final normalized = DateTime(
      completedDate.year,
      completedDate.month,
      completedDate.day,
    );
    
    int currentStreak = prefs.getInt(_streakKey) ?? 0;
    
    if (lastCompletedStr == null) {
      // First completion ever
      currentStreak = 1;
    } else {
      final lastCompleted = DateTime.parse(lastCompletedStr);
      final daysDiff = normalized.difference(lastCompleted).inDays;
      
      if (daysDiff == 1) {
        // Consecutive day
        currentStreak++;
      } else if (daysDiff == 0) {
        // Same day (already handled, but keep streak)
        // Don't change streak
      } else {
        // Streak broken
        currentStreak = 1;
      }
    }
    
    await prefs.setInt(_streakKey, currentStreak);
    await prefs.setString(_lastCompletedKey, normalized.toIso8601String());
  }

  /// Generate date key for storage
  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Reset all data (for testing)
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    await prefs.remove(_streakKey);
    await prefs.remove(_lastCompletedKey);
  }
}

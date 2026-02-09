import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_challenge.dart';
import 'storage_service.dart';

class DailyChallengeResult {
  final Duration time;
  final int moves;

  const DailyChallengeResult({required this.time, required this.moves});
}

class DailyChallengeService {
  static const String _historyKey = 'daily_challenge_history';

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
        final data = Map<String, dynamic>.from(history[todayKey]);
        return today.copyWith(
          completed: data['completed'] ?? false,
          bestTime: data['bestTime'] != null
              ? Duration(seconds: data['bestTime'])
              : null,
          bestMoves: data['bestMoves'],
        );
      }
    }

    return today;
  }

  /// Mark today's challenge as completed
  Future<void> markCompleted(Duration time, int moves) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toUtc();
    final todayKey = _dateKey(today);
    
    // Load existing history
    final historyJson = prefs.getString(_historyKey);
    final history = historyJson != null
        ? Map<String, dynamic>.from(jsonDecode(historyJson))
        : <String, dynamic>{};
    
    // Check if already completed with a better time
    final existing = history[todayKey];
    final existingTime = existing?['bestTime'];
    final existingMoves = existing?['bestMoves'];

    final shouldUpdate = existingTime == null ||
        time.inSeconds < existingTime ||
        (time.inSeconds == existingTime &&
            (existingMoves == null || moves < existingMoves));

    if (shouldUpdate) {
      history[todayKey] = {
        'completed': true,
        'bestTime': time.inSeconds,
        'bestMoves': moves,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_historyKey, jsonEncode(history));

      // Update streak tracking
      final storage = StorageService();
      await storage.markDailyChallengeCompleted(_dateKey(today.toUtc()));
    }
  }

  /// Get current streak count
  Future<int> getStreak() async {
    final storage = StorageService();
    return storage.getDailyChallengeStreak();
  }

  /// Get completion history for past 30 days
  Future<Map<DateTime, DailyChallengeResult>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    
    if (historyJson == null) return {};
    
    final history = Map<String, dynamic>.from(jsonDecode(historyJson));
    final result = <DateTime, DailyChallengeResult>{};
    
    final now = DateTime.now().toUtc();
    for (var i = 0; i < 30; i++) {
      final date = DateTime.utc(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      final key = _dateKey(date);
      
      if (history.containsKey(key)) {
        final data = Map<String, dynamic>.from(history[key]);
        final bestTimeSeconds = data['bestTime'];
        final bestMoves = data['bestMoves'];
        if (bestTimeSeconds != null && bestMoves != null) {
          result[date] = DailyChallengeResult(
            time: Duration(seconds: bestTimeSeconds),
            moves: bestMoves,
          );
        }
      }
    }
    
    return result;
  }

  /// Check if today's challenge is completed
  Future<bool> isTodayCompleted() async {
    final challenge = await getTodaysChallenge();
    return challenge.completed;
  }

  /// Generate date key for storage
  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> shareResult({
    required DailyChallenge challenge,
    required Duration time,
    required int moves,
    required int streak,
  }) async {
    final text = buildShareText(
      challenge: challenge,
      time: time,
      moves: moves,
      streak: streak,
    );
    await Clipboard.setData(ClipboardData(text: text));
  }

  String buildShareText({
    required DailyChallenge challenge,
    required Duration time,
    required int moves,
    required int streak,
  }) {
    final dayNum = challenge.getDayNumber();
    final timeStr = _formatDuration(time);
    final grid = _buildShareGrid(time, moves);
    return '''Stakd Daily #$dayNum\n$grid\n⏱️ $timeStr  •  $moves moves\n🔥 $streak day streak\ngo7studio.com/stakd''';
  }

  String _buildShareGrid(Duration time, int moves) {
    final timeScore = _scoreFromTime(time);
    final moveScore = _scoreFromMoves(moves);
    final timeRow = _scoreToSquares(timeScore);
    final moveRow = _scoreToSquares(moveScore);
    return '$timeRow\n$moveRow';
  }

  int _scoreFromTime(Duration time) {
    final seconds = time.inSeconds;
    if (seconds <= 60) return 5;
    if (seconds <= 120) return 4;
    if (seconds <= 180) return 3;
    if (seconds <= 240) return 2;
    return 1;
  }

  int _scoreFromMoves(int moves) {
    if (moves <= 40) return 5;
    if (moves <= 60) return 4;
    if (moves <= 80) return 3;
    if (moves <= 100) return 2;
    return 1;
  }

  String _scoreToSquares(int score) {
    final clamped = score.clamp(1, 5);
    final filled = '🟩' * clamped;
    final empty = '⬜' * (5 - clamped);
    return '$filled$empty';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Reset all data (for testing)
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for tracking puzzle statistics and progression
class StatsService {
  static final StatsService _instance = StatsService._();
  factory StatsService() => _instance;
  StatsService._();

  SharedPreferences? _prefs;

  // Keys
  static const String _keyTotalPuzzlesSolved = 'stats_total_puzzles_solved';
  static const String _keyTotalMoves = 'stats_total_moves';
  static const String _keyBestMoves = 'stats_best_moves';
  static const String _keyBestTimeMs = 'stats_best_time_ms';
  static const String _keyCurrentStreak = 'stats_current_streak';
  static const String _keyBestStreak = 'stats_best_streak';
  static const String _keyTotalCombos = 'stats_total_combos';
  static const String _keyBestCombo = 'stats_best_combo';
  static const String _keyBestMovesPrefix = 'stats_best_moves_';
  static const String _keyBestTimePrefix = 'stats_best_time_ms_';

  // Stats data
  int totalPuzzlesSolved = 0;
  int totalMoves = 0;
  int bestMoves = 999999;
  Duration bestTime = const Duration(hours: 99);
  int currentStreak = 0;
  int bestStreak = 0;
  int totalCombos = 0;
  int bestCombo = 0;
  Map<String, int> bestMovesPerDifficulty = {};
  Map<String, Duration> bestTimePerDifficulty = {};

  /// Initialize the stats service
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _load();
    } catch (e) {
      debugPrint('StatsService init failed: $e');
    }
  }

  /// Load stats from SharedPreferences
  Future<void> _load() async {
    try {
      totalPuzzlesSolved = _prefs?.getInt(_keyTotalPuzzlesSolved) ?? 0;
      totalMoves = _prefs?.getInt(_keyTotalMoves) ?? 0;
      bestMoves = _prefs?.getInt(_keyBestMoves) ?? 999999;
      
      final bestTimeMs = _prefs?.getInt(_keyBestTimeMs) ?? 0;
      bestTime = bestTimeMs > 0 
          ? Duration(milliseconds: bestTimeMs) 
          : const Duration(hours: 99);
      
      currentStreak = _prefs?.getInt(_keyCurrentStreak) ?? 0;
      bestStreak = _prefs?.getInt(_keyBestStreak) ?? 0;
      totalCombos = _prefs?.getInt(_keyTotalCombos) ?? 0;
      bestCombo = _prefs?.getInt(_keyBestCombo) ?? 0;

      // Load per-difficulty bests
      bestMovesPerDifficulty = {};
      bestTimePerDifficulty = {};
      
      for (final difficulty in ['Easy', 'Medium', 'Hard', 'Ultra']) {
        final moves = _prefs?.getInt('$_keyBestMovesPrefix$difficulty');
        if (moves != null) {
          bestMovesPerDifficulty[difficulty] = moves;
        }
        
        final timeMs = _prefs?.getInt('$_keyBestTimePrefix$difficulty');
        if (timeMs != null) {
          bestTimePerDifficulty[difficulty] = Duration(milliseconds: timeMs);
        }
      }
    } catch (e) {
      debugPrint('StatsService _load failed: $e');
    }
  }

  /// Save stats to SharedPreferences
  Future<void> _save() async {
    try {
      await _prefs?.setInt(_keyTotalPuzzlesSolved, totalPuzzlesSolved);
      await _prefs?.setInt(_keyTotalMoves, totalMoves);
      await _prefs?.setInt(_keyBestMoves, bestMoves);
      await _prefs?.setInt(_keyBestTimeMs, bestTime.inMilliseconds);
      await _prefs?.setInt(_keyCurrentStreak, currentStreak);
      await _prefs?.setInt(_keyBestStreak, bestStreak);
      await _prefs?.setInt(_keyTotalCombos, totalCombos);
      await _prefs?.setInt(_keyBestCombo, bestCombo);

      // Save per-difficulty bests
      for (final entry in bestMovesPerDifficulty.entries) {
        await _prefs?.setInt('$_keyBestMovesPrefix${entry.key}', entry.value);
      }
      for (final entry in bestTimePerDifficulty.entries) {
        await _prefs?.setInt('$_keyBestTimePrefix${entry.key}', entry.value.inMilliseconds);
      }
    } catch (e) {
      debugPrint('StatsService _save failed: $e');
    }
  }

  /// Record completion of a puzzle
  Future<void> recordPuzzleComplete({
    required String difficulty, 
    required int moves, 
    required Duration time, 
    required int combos,
  }) async {
    try {
      // Update global stats
      totalPuzzlesSolved++;
      totalMoves += moves;
      currentStreak++;
      if (currentStreak > bestStreak) bestStreak = currentStreak;
      totalCombos += combos;
      if (combos > bestCombo) bestCombo = combos;

      // Update global bests
      if (moves < bestMoves) bestMoves = moves;
      if (time < bestTime) bestTime = time;

      // Track per-difficulty bests
      final prevBestMoves = bestMovesPerDifficulty[difficulty] ?? 999999;
      if (moves < prevBestMoves) {
        bestMovesPerDifficulty[difficulty] = moves;
      }

      final prevBestTime = bestTimePerDifficulty[difficulty] ?? const Duration(hours: 99);
      if (time < prevBestTime) {
        bestTimePerDifficulty[difficulty] = time;
      }

      await _save();
    } catch (e) {
      debugPrint('StatsService recordPuzzleComplete failed: $e');
    }
  }

  /// Check if this is a new personal best for moves in given difficulty
  bool isNewMoveBest(String difficulty, int moves) {
    final current = bestMovesPerDifficulty[difficulty] ?? 999999;
    return moves < current;
  }

  /// Check if this is a new personal best for time in given difficulty
  bool isNewTimeBest(String difficulty, Duration time) {
    final current = bestTimePerDifficulty[difficulty] ?? const Duration(hours: 99);
    return time < current;
  }

  /// Reset current streak (e.g., when player exits without completing)
  Future<void> resetStreak() async {
    try {
      currentStreak = 0;
      await _save();
    } catch (e) {
      debugPrint('StatsService resetStreak failed: $e');
    }
  }

  /// Get best moves for difficulty (display purposes)
  int getBestMoves(String difficulty) {
    return bestMovesPerDifficulty[difficulty] ?? 999999;
  }

  /// Get best time for difficulty (display purposes)
  Duration getBestTime(String difficulty) {
    return bestTimePerDifficulty[difficulty] ?? const Duration(hours: 99);
  }

  /// Get formatted time string
  String formatTime(Duration duration) {
    if (duration.inHours >= 99) return '--:--';
    
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Reset all stats (for debugging/testing)
  Future<void> resetAllStats() async {
    try {
      totalPuzzlesSolved = 0;
      totalMoves = 0;
      bestMoves = 999999;
      bestTime = const Duration(hours: 99);
      currentStreak = 0;
      bestStreak = 0;
      totalCombos = 0;
      bestCombo = 0;
      bestMovesPerDifficulty.clear();
      bestTimePerDifficulty.clear();
      
      await _save();
    } catch (e) {
      debugPrint('StatsService resetAllStats failed: $e');
    }
  }
}
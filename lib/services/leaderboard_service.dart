import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/leaderboard_entry.dart';

/// Service for managing global leaderboards (local stub — no Firebase)
class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  static const String _playerIdKey = 'leaderboard_player_id';
  static const String _playerNameKey = 'leaderboard_player_name';

  String? _playerId;
  String? _playerName;
  bool _initialized = false;

  /// Initialize the leaderboard service
  Future<void> init() async {
    if (_initialized) return;
    await _loadPlayerIdentity();
    _initialized = true;
  }

  /// Check if Firebase is available
  bool get isAvailable => false;

  /// Get current player ID
  String get playerId => _playerId ?? '';

  /// Get current player name
  String get playerName => _playerName ?? 'Anonymous';

  /// Load or generate player identity
  Future<void> _loadPlayerIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    _playerId = prefs.getString(_playerIdKey);
    _playerName = prefs.getString(_playerNameKey);

    if (_playerId == null) {
      _playerId = const Uuid().v4();
      await prefs.setString(_playerIdKey, _playerId!);
    }

    if (_playerName == null) {
      final random = Random();
      _playerName = 'Player_${random.nextInt(9999).toString().padLeft(4, '0')}';
      await prefs.setString(_playerNameKey, _playerName!);
    }
  }

  /// Set player display name
  Future<void> setPlayerName(String name) async {
    final sanitized = name.trim();
    if (sanitized.isEmpty || sanitized.length > 20) return;

    _playerName = sanitized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playerNameKey, sanitized);
  }

  /// Check if player has set a custom name
  Future<bool> hasCustomName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_playerNameKey);
    return name != null && !name.startsWith('Player_');
  }

  // ==================== Submit Scores (no-ops) ====================

  Future<void> submitDailyTime(int seconds) async {}
  Future<void> submitWeeklyStars(int stars) async {}
  Future<void> submitAllTimeStars(int stars) async {}
  Future<void> submitBestCombo(int combo) async {}

  // ==================== Fetch Leaderboards (empty) ====================

  Future<List<LeaderboardEntry>> getDailyLeaderboard() async => [];
  Future<List<LeaderboardEntry>> getWeeklyStarsLeaderboard() async => [];
  Future<List<LeaderboardEntry>> getAllTimeStarsLeaderboard() async => [];
  Future<List<LeaderboardEntry>> getBestComboLeaderboard() async => [];

  Future<List<LeaderboardEntry>> getLeaderboard(LeaderboardType type) async {
    switch (type) {
      case LeaderboardType.dailyChallenge:
        return getDailyLeaderboard();
      case LeaderboardType.weeklyStars:
        return getWeeklyStarsLeaderboard();
      case LeaderboardType.allTimeStars:
        return getAllTimeStarsLeaderboard();
      case LeaderboardType.bestCombo:
        return getBestComboLeaderboard();
    }
  }

  Future<int?> getPlayerRank(LeaderboardType type) async => null;

  // ==================== Helpers ====================

  String formatScore(int score, LeaderboardType type) {
    switch (type) {
      case LeaderboardType.dailyChallenge:
        final minutes = score ~/ 60;
        final seconds = score % 60;
        return '$minutes:${seconds.toString().padLeft(2, '0')}';
      case LeaderboardType.weeklyStars:
      case LeaderboardType.allTimeStars:
        return '$score ⭐';
      case LeaderboardType.bestCombo:
        return '${score}x';
    }
  }
}

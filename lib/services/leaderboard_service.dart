import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/leaderboard_entry.dart';

/// Service for managing global leaderboards via Firebase
class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  static const int _maxEntries = 100;
  static const String _playerIdKey = 'leaderboard_player_id';
  static const String _playerNameKey = 'leaderboard_player_name';
  static const String _pendingSubmissionsKey = 'pending_leaderboard_submissions';
  static const String _cachedLeaderboardsKey = 'cached_leaderboards';

  FirebaseFirestore? _firestore;
  String? _playerId;
  String? _playerName;
  bool _initialized = false;

  /// Initialize the leaderboard service
  Future<void> init() async {
    if (_initialized) return;

    try {
      _firestore = FirebaseFirestore.instance;
      await _loadPlayerIdentity();
      await _processPendingSubmissions();
      _initialized = true;
    } catch (e) {
      debugPrint('LeaderboardService init failed: $e');
    }
  }

  /// Check if Firebase is available
  bool get isAvailable => _firestore != null && _initialized;

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

  // ==================== Submit Scores ====================

  /// Submit daily challenge completion time (in seconds)
  Future<void> submitDailyTime(int seconds) async {
    if (seconds <= 0) return;

    final dateKey = _getTodayKey();
    final path = 'leaderboards/daily/$dateKey/entries';

    await _submitScore(
      path: path,
      scoreField: 'score',
      score: seconds,
      lowerIsBetter: true,
    );
  }

  /// Submit weekly stars count
  Future<void> submitWeeklyStars(int stars) async {
    if (stars <= 0) return;

    final weekKey = _getWeekKey();
    final path = 'leaderboards/weekly_stars/$weekKey/entries';

    await _submitScore(
      path: path,
      scoreField: 'stars',
      score: stars,
      lowerIsBetter: false,
    );
  }

  /// Submit all-time stars count
  Future<void> submitAllTimeStars(int stars) async {
    if (stars <= 0) return;

    const path = 'leaderboards/alltime_stars/entries';

    await _submitScore(
      path: path,
      scoreField: 'stars',
      score: stars,
      lowerIsBetter: false,
    );
  }

  /// Submit best combo achieved
  Future<void> submitBestCombo(int combo) async {
    if (combo <= 1) return;

    const path = 'leaderboards/best_combo/entries';

    await _submitScore(
      path: path,
      scoreField: 'combo',
      score: combo,
      lowerIsBetter: false,
    );
  }

  /// Generic score submission with offline queueing
  Future<void> _submitScore({
    required String path,
    required String scoreField,
    required int score,
    required bool lowerIsBetter,
  }) async {
    if (_playerId == null) return;

    final data = {
      'name': _playerName ?? 'Anonymous',
      scoreField: score,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty &&
        !connectivity.contains(ConnectivityResult.none);

    if (!isOnline || _firestore == null) {
      // Queue for later
      await _queueSubmission(path, data, scoreField, lowerIsBetter);
      return;
    }

    try {
      final docRef = _firestore!.collection(path).doc(_playerId);
      final existing = await docRef.get();

      bool shouldUpdate = true;
      if (existing.exists) {
        final existingScore = existing.data()?[scoreField] as int? ?? 0;
        if (lowerIsBetter) {
          shouldUpdate = score < existingScore;
        } else {
          shouldUpdate = score > existingScore;
        }
      }

      if (shouldUpdate) {
        await docRef.set(data, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Failed to submit score: $e');
      await _queueSubmission(path, data, scoreField, lowerIsBetter);
    }
  }

  /// Queue a submission for when back online
  Future<void> _queueSubmission(
    String path,
    Map<String, dynamic> data,
    String scoreField,
    bool lowerIsBetter,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingJson = prefs.getString(_pendingSubmissionsKey);
    final pending = pendingJson != null
        ? List<Map<String, dynamic>>.from(jsonDecode(pendingJson))
        : <Map<String, dynamic>>[];

    pending.add({
      'path': path,
      'data': data,
      'scoreField': scoreField,
      'lowerIsBetter': lowerIsBetter,
    });

    await prefs.setString(_pendingSubmissionsKey, jsonEncode(pending));
  }

  /// Process any queued submissions
  Future<void> _processPendingSubmissions() async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty &&
        !connectivity.contains(ConnectivityResult.none);

    if (!isOnline || _firestore == null) return;

    final prefs = await SharedPreferences.getInstance();
    final pendingJson = prefs.getString(_pendingSubmissionsKey);
    if (pendingJson == null) return;

    final pending = List<Map<String, dynamic>>.from(jsonDecode(pendingJson));
    await prefs.remove(_pendingSubmissionsKey);

    for (final submission in pending) {
      try {
        await _submitScore(
          path: submission['path'] as String,
          scoreField: submission['scoreField'] as String,
          score: (submission['data'] as Map<String, dynamic>)[submission['scoreField']] as int,
          lowerIsBetter: submission['lowerIsBetter'] as bool,
        );
      } catch (e) {
        debugPrint('Failed to process pending submission: $e');
      }
    }
  }

  // ==================== Fetch Leaderboards ====================

  /// Get daily challenge leaderboard
  Future<List<LeaderboardEntry>> getDailyLeaderboard() async {
    final dateKey = _getTodayKey();
    final path = 'leaderboards/daily/$dateKey/entries';
    return _fetchLeaderboard(path, 'score', true);
  }

  /// Get weekly stars leaderboard
  Future<List<LeaderboardEntry>> getWeeklyStarsLeaderboard() async {
    final weekKey = _getWeekKey();
    final path = 'leaderboards/weekly_stars/$weekKey/entries';
    return _fetchLeaderboard(path, 'stars', false);
  }

  /// Get all-time stars leaderboard
  Future<List<LeaderboardEntry>> getAllTimeStarsLeaderboard() async {
    const path = 'leaderboards/alltime_stars/entries';
    return _fetchLeaderboard(path, 'stars', false);
  }

  /// Get best combo leaderboard
  Future<List<LeaderboardEntry>> getBestComboLeaderboard() async {
    const path = 'leaderboards/best_combo/entries';
    return _fetchLeaderboard(path, 'combo', false);
  }

  /// Fetch leaderboard by type
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

  /// Generic leaderboard fetch with caching
  Future<List<LeaderboardEntry>> _fetchLeaderboard(
    String path,
    String scoreField,
    bool lowerIsBetter,
  ) async {
    // Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.isNotEmpty &&
        !connectivity.contains(ConnectivityResult.none);

    if (!isOnline || _firestore == null) {
      return _getCachedLeaderboard(path);
    }

    try {
      final query = _firestore!
          .collection(path)
          .orderBy(scoreField, descending: !lowerIsBetter)
          .limit(_maxEntries);

      final snapshot = await query.get();
      final entries = <LeaderboardEntry>[];

      for (int i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        entries.add(LeaderboardEntry.fromFirestore(
          doc.data(),
          doc.id,
          i + 1,
          isCurrentPlayer: doc.id == _playerId,
        ));
      }

      // Cache the results
      await _cacheLeaderboard(path, entries);

      return entries;
    } catch (e) {
      debugPrint('Failed to fetch leaderboard: $e');
      return _getCachedLeaderboard(path);
    }
  }

  /// Get player's rank on a specific leaderboard
  Future<int?> getPlayerRank(LeaderboardType type) async {
    final entries = await getLeaderboard(type);
    for (final entry in entries) {
      if (entry.isCurrentPlayer) {
        return entry.rank;
      }
    }
    return null;
  }

  // ==================== Caching ====================

  /// Cache leaderboard data locally
  Future<void> _cacheLeaderboard(String path, List<LeaderboardEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cachedLeaderboardsKey);
    final cached = cachedJson != null
        ? Map<String, dynamic>.from(jsonDecode(cachedJson))
        : <String, dynamic>{};

    cached[path] = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'entries': entries
          .map((e) => {
                'playerId': e.playerId,
                'playerName': e.playerName,
                'score': e.score,
                'rank': e.rank,
                'timestamp': e.timestamp.millisecondsSinceEpoch,
                'isCurrentPlayer': e.isCurrentPlayer,
              })
          .toList(),
    };

    await prefs.setString(_cachedLeaderboardsKey, jsonEncode(cached));
  }

  /// Get cached leaderboard data
  Future<List<LeaderboardEntry>> _getCachedLeaderboard(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cachedLeaderboardsKey);
    if (cachedJson == null) return [];

    final cached = Map<String, dynamic>.from(jsonDecode(cachedJson));
    final pathCache = cached[path] as Map<String, dynamic>?;
    if (pathCache == null) return [];

    final entriesJson = pathCache['entries'] as List<dynamic>?;
    if (entriesJson == null) return [];

    return entriesJson.map((e) {
      final map = Map<String, dynamic>.from(e);
      return LeaderboardEntry(
        playerId: map['playerId'] as String,
        playerName: map['playerName'] as String,
        score: map['score'] as int,
        rank: map['rank'] as int,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        isCurrentPlayer: map['isCurrentPlayer'] as bool? ?? false,
      );
    }).toList();
  }

  // ==================== Helpers ====================

  /// Get today's date key (YYYY-MM-DD in UTC)
  String _getTodayKey() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get current week key (YYYY-WNN in UTC)
  String _getWeekKey() {
    final now = DateTime.now().toUtc();
    final firstDayOfYear = DateTime.utc(now.year, 1, 1);
    final daysSinceFirstDay = now.difference(firstDayOfYear).inDays;
    final weekNumber = ((daysSinceFirstDay + firstDayOfYear.weekday - 1) / 7).ceil();
    return '${now.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  /// Format score for display based on leaderboard type
  String formatScore(int score, LeaderboardType type) {
    switch (type) {
      case LeaderboardType.dailyChallenge:
        // Score is in seconds, format as MM:SS
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

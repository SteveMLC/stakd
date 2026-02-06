import 'package:shared_preferences/shared_preferences.dart';

/// Handles local storage for game progress and settings
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  // Keys
  static const String _keyHighestLevel = 'highest_level';
  static const String _keyCompletedLevels = 'completed_levels';
  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keyMusicEnabled = 'music_enabled';
  static const String _keyTotalMoves = 'total_moves';
  static const String _keyAdsRemoved = 'ads_removed';
  static const String _keyLastDailyChallengeDate = 'last_daily_challenge_date';
  static const String _keyDailyChallengeStreak = 'daily_challenge_streak';
  static const String _keyTutorialCompleted = 'tutorial_completed';

  /// Initialize the storage service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get the highest unlocked level
  int getHighestLevel() {
    return _prefs?.getInt(_keyHighestLevel) ?? 1;
  }

  /// Set the highest unlocked level
  Future<void> setHighestLevel(int level) async {
    await _prefs?.setInt(_keyHighestLevel, level);
  }

  /// Get list of completed level numbers
  List<int> getCompletedLevels() {
    final data = _prefs?.getStringList(_keyCompletedLevels) ?? [];
    return data.map((s) => int.parse(s)).toList();
  }

  /// Mark a level as completed
  Future<void> markLevelCompleted(int level) async {
    final completed = getCompletedLevels();
    if (!completed.contains(level)) {
      completed.add(level);
      await _prefs?.setStringList(
        _keyCompletedLevels,
        completed.map((l) => l.toString()).toList(),
      );
    }
    
    // Update highest level if needed
    if (level >= getHighestLevel()) {
      await setHighestLevel(level + 1);
    }
  }

  /// Check if a level is completed
  bool isLevelCompleted(int level) {
    return getCompletedLevels().contains(level);
  }

  /// Check if a level is unlocked
  bool isLevelUnlocked(int level) {
    return level <= getHighestLevel();
  }

  /// Get sound enabled setting
  bool getSoundEnabled() {
    return _prefs?.getBool(_keySoundEnabled) ?? true;
  }

  /// Set sound enabled setting
  Future<void> setSoundEnabled(bool enabled) async {
    await _prefs?.setBool(_keySoundEnabled, enabled);
  }

  /// Get music enabled setting
  bool getMusicEnabled() {
    return _prefs?.getBool(_keyMusicEnabled) ?? true;
  }

  /// Set music enabled setting
  Future<void> setMusicEnabled(bool enabled) async {
    await _prefs?.setBool(_keyMusicEnabled, enabled);
  }

  /// Get total moves across all games
  int getTotalMoves() {
    return _prefs?.getInt(_keyTotalMoves) ?? 0;
  }

  /// Add to total moves count
  Future<void> addMoves(int moves) async {
    final total = getTotalMoves() + moves;
    await _prefs?.setInt(_keyTotalMoves, total);
  }

  /// Check if ads have been removed (IAP)
  bool getAdsRemoved() {
    return _prefs?.getBool(_keyAdsRemoved) ?? false;
  }

  /// Set ads removed (after IAP purchase)
  Future<void> setAdsRemoved(bool removed) async {
    await _prefs?.setBool(_keyAdsRemoved, removed);
  }

  /// Get the last completed daily challenge date (YYYYMMDD, UTC)
  String? getLastDailyChallengeDate() {
    return _prefs?.getString(_keyLastDailyChallengeDate);
  }

  /// Get the current daily challenge streak
  int getDailyChallengeStreak() {
    return _prefs?.getInt(_keyDailyChallengeStreak) ?? 0;
  }

  /// Check if the daily challenge is completed for a given date (YYYYMMDD)
  bool isDailyChallengeCompleted(String dateKey) {
    return getLastDailyChallengeDate() == dateKey;
  }

  /// Mark daily challenge completed and update streak, returns updated streak
  Future<int> markDailyChallengeCompleted(String dateKey) async {
    final lastDateKey = getLastDailyChallengeDate();
    var streak = getDailyChallengeStreak();

    if (lastDateKey == dateKey) {
      return streak;
    }

    final lastDate = _parseDateKey(lastDateKey);
    final currentDate = _parseDateKey(dateKey);

    if (lastDate != null && currentDate != null) {
      final diffDays = currentDate.difference(lastDate).inDays;
      if (diffDays == 1) {
        streak += 1;
      } else {
        streak = 1;
      }
    } else {
      streak = 1;
    }

    await _prefs?.setString(_keyLastDailyChallengeDate, dateKey);
    await _prefs?.setInt(_keyDailyChallengeStreak, streak);
    return streak;
  }

  DateTime? _parseDateKey(String? dateKey) {
    if (dateKey == null || dateKey.length != 8) return null;
    final year = int.tryParse(dateKey.substring(0, 4));
    final month = int.tryParse(dateKey.substring(4, 6));
    final day = int.tryParse(dateKey.substring(6, 8));
    if (year == null || month == null || day == null) return null;
    return DateTime.utc(year, month, day);
  }

  /// Check if tutorial has been completed
  bool getTutorialCompleted() {
    return _prefs?.getBool(_keyTutorialCompleted) ?? false;
  }

  /// Set tutorial as completed
  Future<void> setTutorialCompleted(bool completed) async {
    await _prefs?.setBool(_keyTutorialCompleted, completed);
  }

  /// Clear all data (for testing)
  Future<void> clearAll() async {
    await _prefs?.clear();
  }

  /// Get progress stats
  Map<String, dynamic> getStats() {
    return {
      'highestLevel': getHighestLevel(),
      'completedCount': getCompletedLevels().length,
      'totalMoves': getTotalMoves(),
      'dailyStreak': getDailyChallengeStreak(),
    };
  }
}

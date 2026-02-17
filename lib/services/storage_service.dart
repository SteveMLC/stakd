import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'power_up_service.dart';

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
  static const String _keyHapticsEnabled = 'haptics_enabled';
  static const String _keyTotalMoves = 'total_moves';
  static const String _keyAdsRemoved = 'ads_removed';
  static const String _keyHintCount = 'hint_count';
  static const int _defaultHintCount = 3;
  static const String _keyLastDailyChallengeDate = 'last_daily_challenge_date';
  static const String _keyDailyChallengeStreak = 'daily_challenge_streak';
  static const String _keyTutorialCompleted = 'tutorial_completed';
  static const String _keyMultiGrabHintSeen = 'multi_grab_hint_seen';
  static const String _keyMultiGrabUsed = 'multi_grab_used';
  static const String _keyMultiGrabUsageCount = 'multi_grab_usage_count';
  static const String _keyMultiGrabHintsEnabled = 'multi_grab_hints_enabled';
  static const String _keyTextureSkinsEnabled = 'texture_skins_enabled';
  static const String _keyLevelStarsPrefix = 'level_stars_';
  static const String _keyPowerUpPrefix = 'power_up_';
  static const String _keyPowerUpsInitialized = 'power_ups_initialized';

  /// Initialize the storage service
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('StorageService init failed: $e');
      _prefs = null;
    }
  }

  /// Get the highest unlocked level
  int getHighestLevel() {
    try {
      return _prefs?.getInt(_keyHighestLevel) ?? 1;
    } catch (e) {
      debugPrint('StorageService getHighestLevel failed: $e');
      return 1;
    }
  }

  /// Set the highest unlocked level
  Future<void> setHighestLevel(int level) async {
    try {
      await _prefs?.setInt(_keyHighestLevel, level);
    } catch (e) {
      debugPrint('StorageService setHighestLevel failed: $e');
    }
  }

  /// Get list of completed level numbers
  List<int> getCompletedLevels() {
    try {
      final data = _prefs?.getStringList(_keyCompletedLevels) ?? [];
      return data
          .map((s) => int.tryParse(s))
          .whereType<int>()
          .toList();
    } catch (e) {
      debugPrint('StorageService getCompletedLevels failed: $e');
      return [];
    }
  }

  /// Mark a level as completed
  Future<void> markLevelCompleted(int level) async {
    try {
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
    } catch (e) {
      debugPrint('StorageService markLevelCompleted failed: $e');
    }
  }

  /// Check if a level is completed
  bool isLevelCompleted(int level) {
    try {
      return getCompletedLevels().contains(level);
    } catch (e) {
      debugPrint('StorageService isLevelCompleted failed: $e');
      return false;
    }
  }

  /// Check if a level is unlocked
  bool isLevelUnlocked(int level) {
    try {
      return level <= getHighestLevel();
    } catch (e) {
      debugPrint('StorageService isLevelUnlocked failed: $e');
      return false;
    }
  }

  /// Get sound enabled setting
  bool getSoundEnabled() {
    try {
      return _prefs?.getBool(_keySoundEnabled) ?? true;
    } catch (e) {
      debugPrint('StorageService getSoundEnabled failed: $e');
      return true;
    }
  }

  /// Set sound enabled setting
  Future<void> setSoundEnabled(bool enabled) async {
    try {
      await _prefs?.setBool(_keySoundEnabled, enabled);
    } catch (e) {
      debugPrint('StorageService setSoundEnabled failed: $e');
    }
  }

  /// Get music enabled setting
  bool getMusicEnabled() {
    try {
      return _prefs?.getBool(_keyMusicEnabled) ?? true;
    } catch (e) {
      debugPrint('StorageService getMusicEnabled failed: $e');
      return true;
    }
  }

  /// Set music enabled setting
  Future<void> setMusicEnabled(bool enabled) async {
    try {
      await _prefs?.setBool(_keyMusicEnabled, enabled);
    } catch (e) {
      debugPrint('StorageService setMusicEnabled failed: $e');
    }
  }

  /// Get haptics enabled setting
  bool getHapticsEnabled() {
    try {
      return _prefs?.getBool(_keyHapticsEnabled) ?? true;
    } catch (e) {
      debugPrint('StorageService getHapticsEnabled failed: $e');
      return true;
    }
  }

  /// Set haptics enabled setting
  Future<void> setHapticsEnabled(bool enabled) async {
    try {
      await _prefs?.setBool(_keyHapticsEnabled, enabled);
    } catch (e) {
      debugPrint('StorageService setHapticsEnabled failed: $e');
    }
  }

  /// Get total moves across all games
  int getTotalMoves() {
    try {
      return _prefs?.getInt(_keyTotalMoves) ?? 0;
    } catch (e) {
      debugPrint('StorageService getTotalMoves failed: $e');
      return 0;
    }
  }

  /// Add to total moves count
  Future<void> addMoves(int moves) async {
    try {
      final total = getTotalMoves() + moves;
      await _prefs?.setInt(_keyTotalMoves, total);
    } catch (e) {
      debugPrint('StorageService addMoves failed: $e');
    }
  }

  /// Check if ads have been removed (IAP)
  bool getAdsRemoved() {
    try {
      return _prefs?.getBool(_keyAdsRemoved) ?? false;
    } catch (e) {
      debugPrint('StorageService getAdsRemoved failed: $e');
      return false;
    }
  }

  /// Set ads removed (after IAP purchase)
  Future<void> setAdsRemoved(bool removed) async {
    try {
      await _prefs?.setBool(_keyAdsRemoved, removed);
    } catch (e) {
      debugPrint('StorageService setAdsRemoved failed: $e');
    }
  }

  /// Get remaining hints
  int getHintCount() {
    try {
      return _prefs?.getInt(_keyHintCount) ?? _defaultHintCount;
    } catch (e) {
      debugPrint('StorageService getHintCount failed: $e');
      return _defaultHintCount;
    }
  }

  /// Set remaining hints
  Future<void> setHintCount(int count) async {
    try {
      await _prefs?.setInt(_keyHintCount, count);
    } catch (e) {
      debugPrint('StorageService setHintCount failed: $e');
    }
  }

  /// Get the last completed daily challenge date (YYYYMMDD, UTC)
  String? getLastDailyChallengeDate() {
    try {
      return _prefs?.getString(_keyLastDailyChallengeDate);
    } catch (e) {
      debugPrint('StorageService getLastDailyChallengeDate failed: $e');
      return null;
    }
  }

  /// Get the current daily challenge streak
  int getDailyChallengeStreak() {
    try {
      return _prefs?.getInt(_keyDailyChallengeStreak) ?? 0;
    } catch (e) {
      debugPrint('StorageService getDailyChallengeStreak failed: $e');
      return 0;
    }
  }

  /// Check if the daily challenge is completed for a given date (YYYYMMDD)
  bool isDailyChallengeCompleted(String dateKey) {
    try {
      return getLastDailyChallengeDate() == dateKey;
    } catch (e) {
      debugPrint('StorageService isDailyChallengeCompleted failed: $e');
      return false;
    }
  }

  /// Mark daily challenge completed and update streak, returns updated streak
  Future<int> markDailyChallengeCompleted(String dateKey) async {
    try {
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
    } catch (e) {
      debugPrint('StorageService markDailyChallengeCompleted failed: $e');
      return getDailyChallengeStreak();
    }
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
    try {
      return _prefs?.getBool(_keyTutorialCompleted) ?? false;
    } catch (e) {
      debugPrint('StorageService getTutorialCompleted failed: $e');
      return false;
    }
  }

  /// Set tutorial as completed
  Future<void> setTutorialCompleted(bool completed) async {
    try {
      await _prefs?.setBool(_keyTutorialCompleted, completed);
    } catch (e) {
      debugPrint('StorageService setTutorialCompleted failed: $e');
    }
  }

  /// Check if multi-grab hint has been seen
  bool hasSeenMultiGrabHint() {
    try {
      return _prefs?.getBool(_keyMultiGrabHintSeen) ?? false;
    } catch (e) {
      debugPrint('StorageService hasSeenMultiGrabHint failed: $e');
      return false;
    }
  }

  /// Mark multi-grab hint as seen
  Future<void> setMultiGrabHintSeen() async {
    try {
      await _prefs?.setBool(_keyMultiGrabHintSeen, true);
    } catch (e) {
      debugPrint('StorageService setMultiGrabHintSeen failed: $e');
    }
  }

  /// Check if multi-grab has been used
  bool hasUsedMultiGrab() {
    try {
      return _prefs?.getBool(_keyMultiGrabUsed) ?? false;
    } catch (e) {
      debugPrint('StorageService hasUsedMultiGrab failed: $e');
      return false;
    }
  }

  /// Mark multi-grab as used
  Future<void> setMultiGrabUsed() async {
    try {
      await _prefs?.setBool(_keyMultiGrabUsed, true);
    } catch (e) {
      debugPrint('StorageService setMultiGrabUsed failed: $e');
    }
  }

  /// Get total multi-grab usage count
  int getMultiGrabUsageCount() {
    try {
      return _prefs?.getInt(_keyMultiGrabUsageCount) ?? 0;
    } catch (e) {
      debugPrint('StorageService getMultiGrabUsageCount failed: $e');
      return 0;
    }
  }

  /// Increment multi-grab usage count
  Future<void> incrementMultiGrabUsage() async {
    try {
      final count = getMultiGrabUsageCount() + 1;
      await _prefs?.setInt(_keyMultiGrabUsageCount, count);
    } catch (e) {
      debugPrint('StorageService incrementMultiGrabUsage failed: $e');
    }
  }

  /// Get multi-grab hint visibility setting
  bool getMultiGrabHintsEnabled() {
    try {
      return _prefs?.getBool(_keyMultiGrabHintsEnabled) ?? true;
    } catch (e) {
      debugPrint('StorageService getMultiGrabHintsEnabled failed: $e');
      return true;
    }
  }

  /// Set multi-grab hint visibility setting
  Future<void> setMultiGrabHintsEnabled(bool enabled) async {
    try {
      await _prefs?.setBool(_keyMultiGrabHintsEnabled, enabled);
    } catch (e) {
      debugPrint('StorageService setMultiGrabHintsEnabled failed: $e');
    }
  }

  /// Get texture skins enabled setting
  bool getTextureSkinsEnabled() {
    try {
      return _prefs?.getBool(_keyTextureSkinsEnabled) ?? false;
    } catch (e) {
      debugPrint('StorageService getTextureSkinsEnabled failed: $e');
      return false;
    }
  }

  /// Set texture skins enabled setting
  Future<void> setTextureSkinsEnabled(bool enabled) async {
    try {
      await _prefs?.setBool(_keyTextureSkinsEnabled, enabled);
    } catch (e) {
      debugPrint('StorageService setTextureSkinsEnabled failed: $e');
    }
  }

  /// Get stars for a specific level (0-3)
  int getLevelStars(int level) {
    try {
      return _prefs?.getInt('$_keyLevelStarsPrefix$level') ?? 0;
    } catch (e) {
      debugPrint('StorageService getLevelStars failed: $e');
      return 0;
    }
  }

  /// Set stars for a level (only saves if new stars > existing)
  /// Returns true if stars were updated (new record)
  Future<bool> setLevelStars(int level, int stars) async {
    try {
      final currentStars = getLevelStars(level);
      if (stars > currentStars) {
        await _prefs?.setInt('$_keyLevelStarsPrefix$level', stars);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('StorageService setLevelStars failed: $e');
      return false;
    }
  }

  /// Get total stars earned across all levels
  int getTotalStars() {
    try {
      int total = 0;
      final completedLevels = getCompletedLevels();
      for (final level in completedLevels) {
        total += getLevelStars(level);
      }
      return total;
    } catch (e) {
      debugPrint('StorageService getTotalStars failed: $e');
      return 0;
    }
  }

  /// Get count of levels with 3 stars
  int getThreeStarCount() {
    try {
      int count = 0;
      final completedLevels = getCompletedLevels();
      for (final level in completedLevels) {
        if (getLevelStars(level) == 3) count++;
      }
      return count;
    } catch (e) {
      debugPrint('StorageService getThreeStarCount failed: $e');
      return 0;
    }
  }

  /// Get power-up count for a type
  int getPowerUpCount(PowerUpType type) {
    try {
      return _prefs?.getInt('$_keyPowerUpPrefix${type.name}') ?? 0;
    } catch (e) {
      debugPrint('StorageService getPowerUpCount failed: $e');
      return 0;
    }
  }

  /// Set power-up count for a type
  Future<void> setPowerUpCount(PowerUpType type, int count) async {
    try {
      await _prefs?.setInt('$_keyPowerUpPrefix${type.name}', count);
    } catch (e) {
      debugPrint('StorageService setPowerUpCount failed: $e');
    }
  }

  /// Check if power-ups have been initialized
  bool getPowerUpsInitialized() {
    try {
      return _prefs?.getBool(_keyPowerUpsInitialized) ?? false;
    } catch (e) {
      debugPrint('StorageService getPowerUpsInitialized failed: $e');
      return false;
    }
  }

  /// Set power-ups initialized flag
  Future<void> setPowerUpsInitialized(bool initialized) async {
    try {
      await _prefs?.setBool(_keyPowerUpsInitialized, initialized);
    } catch (e) {
      debugPrint('StorageService setPowerUpsInitialized failed: $e');
    }
  }

  // ============ Chain Tracking ============

  /// Get max chain ever achieved
  int getMaxChainEver() {
    try {
      return _prefs?.getInt('max_chain_ever') ?? 0;
    } catch (e) {
      debugPrint('StorageService getMaxChainEver failed: $e');
      return 0;
    }
  }

  /// Update max chain if new chain is higher
  Future<bool> updateMaxChain(int chainLevel) async {
    try {
      final currentMax = getMaxChainEver();
      if (chainLevel > currentMax) {
        await _prefs?.setInt('max_chain_ever', chainLevel);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('StorageService updateMaxChain failed: $e');
      return false;
    }
  }

  /// Get total chains triggered (2+)
  int getTotalChains() {
    try {
      return _prefs?.getInt('total_chains') ?? 0;
    } catch (e) {
      debugPrint('StorageService getTotalChains failed: $e');
      return 0;
    }
  }

  /// Increment total chains count
  Future<void> incrementTotalChains() async {
    try {
      final count = getTotalChains() + 1;
      await _prefs?.setInt('total_chains', count);
    } catch (e) {
      debugPrint('StorageService incrementTotalChains failed: $e');
    }
  }

  /// Clear all data (for testing)
  Future<void> clearAll() async {
    try {
      await _prefs?.clear();
    } catch (e) {
      debugPrint('StorageService clearAll failed: $e');
    }
  }

  /// Get progress stats
  Map<String, Object?> getStats() {
    return {
      'highestLevel': getHighestLevel(),
      'completedCount': getCompletedLevels().length,
      'totalMoves': getTotalMoves(),
      'dailyStreak': getDailyChallengeStreak(),
      'multiGrabUses': getMultiGrabUsageCount(),
      'totalStars': getTotalStars(),
      'threeStarCount': getThreeStarCount(),
      'maxChainEver': getMaxChainEver(),
      'totalChains': getTotalChains(),
    };
  }
}

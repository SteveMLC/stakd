import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_reward.dart';
import 'currency_service.dart';
import 'storage_service.dart';

/// Service for managing daily rewards calendar
class DailyRewardsService {
  static final DailyRewardsService _instance = DailyRewardsService._internal();
  factory DailyRewardsService() => _instance;
  DailyRewardsService._internal();

  static const String _lastClaimDateKey = 'daily_last_claim';
  static const String _streakDayKey = 'daily_streak_day';

  SharedPreferences? _prefs;
  final CurrencyService _currencyService = CurrencyService();
  final StorageService _storageService = StorageService();

  /// Initialize the service
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _currencyService.init();
    } catch (e) {
      debugPrint('DailyRewardsService init failed: $e');
      _prefs = null;
    }
  }

  /// Get the date of the last claim (or null if never claimed)
  Future<DateTime?> getLastClaimDate() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final dateStr = _prefs?.getString(_lastClaimDateKey);
      if (dateStr == null) return null;
      return DateTime.tryParse(dateStr);
    } catch (e) {
      debugPrint('DailyRewardsService getLastClaimDate failed: $e');
      return null;
    }
  }

  /// Get the current streak day (1-7)
  Future<int> getCurrentDay() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final day = _prefs?.getInt(_streakDayKey) ?? 1;
      return day.clamp(1, 7);
    } catch (e) {
      debugPrint('DailyRewardsService getCurrentDay failed: $e');
      return 1;
    }
  }

  /// Check if player can claim today's reward
  /// Returns true if:
  /// - Never claimed before (first time)
  /// - Last claim was on a different calendar day
  Future<bool> canClaimToday() async {
    try {
      final lastClaim = await getLastClaimDate();
      
      // First time - can claim
      if (lastClaim == null) return true;
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastClaimDay = DateTime(lastClaim.year, lastClaim.month, lastClaim.day);
      
      // Can claim if last claim was before today
      return lastClaimDay.isBefore(today);
    } catch (e) {
      debugPrint('DailyRewardsService canClaimToday failed: $e');
      return false;
    }
  }

  /// Check if the streak should reset (missed more than 1 day)
  /// Being player-friendly: we allow continuing the streak if they missed a day
  /// Set [strictMode] to true to reset on any missed day
  Future<bool> shouldResetStreak({bool strictMode = false}) async {
    try {
      final lastClaim = await getLastClaimDate();
      
      // First time - no reset needed
      if (lastClaim == null) return false;
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastClaimDay = DateTime(lastClaim.year, lastClaim.month, lastClaim.day);
      
      final daysDifference = today.difference(lastClaimDay).inDays;
      
      // In strict mode, reset if missed any day
      // In player-friendly mode, allow 1 missed day grace period
      if (strictMode) {
        return daysDifference > 1;
      } else {
        return daysDifference > 2; // Allow up to 2 days gap (1 missed day)
      }
    } catch (e) {
      debugPrint('DailyRewardsService shouldResetStreak failed: $e');
      return false;
    }
  }

  /// Claim today's reward
  /// Returns the claimed reward, or null if cannot claim
  Future<DailyReward?> claimReward() async {
    try {
      // Check if can claim
      final canClaim = await canClaimToday();
      if (!canClaim) {
        debugPrint('DailyRewardsService: Cannot claim today - already claimed');
        return null;
      }

      _prefs ??= await SharedPreferences.getInstance();

      // Check if streak should reset
      final shouldReset = await shouldResetStreak();
      int currentDay = await getCurrentDay();
      
      if (shouldReset) {
        debugPrint('DailyRewardsService: Streak reset - missed days');
        currentDay = 1;
      }

      // Get today's reward
      final reward = getRewardForDay(currentDay);
      
      // Award the reward
      await _awardReward(reward);
      
      // Update last claim date to now
      final now = DateTime.now();
      await _prefs?.setString(_lastClaimDateKey, now.toIso8601String());
      
      // Advance to next day (or reset to 1 after day 7)
      final nextDay = currentDay >= 7 ? 1 : currentDay + 1;
      await _prefs?.setInt(_streakDayKey, nextDay);
      
      debugPrint('DailyRewardsService: Claimed day $currentDay reward. Next day: $nextDay');
      
      return reward;
    } catch (e) {
      debugPrint('DailyRewardsService claimReward failed: $e');
      return null;
    }
  }

  /// Award the reward to the player
  Future<void> _awardReward(DailyReward reward) async {
    switch (reward.type) {
      case RewardType.coins:
        await _currencyService.addCoins(reward.amount);
        break;
      case RewardType.powerUp:
        // TODO: Implement power-up system when ready
        // For now, convert to coins bonus
        await _currencyService.addCoins(reward.amount * 25);
        break;
      case RewardType.hints:
        // Add hints using storage service
        final currentHints = _storageService.getHintCount();
        await _storageService.setHintCount(currentHints + reward.amount);
        break;
      case RewardType.theme:
        // TODO: Implement theme unlock system when ready
        // For now, award bonus coins
        await _currencyService.addCoins(100);
        break;
    }
  }

  /// Get reward status for all 7 days
  /// Returns map of day -> status (claimed, current, locked)
  Future<Map<int, RewardStatus>> getRewardStatuses() async {
    final currentDay = await getCurrentDay();
    final canClaim = await canClaimToday();
    final lastClaim = await getLastClaimDate();
    
    final Map<int, RewardStatus> statuses = {};
    
    for (int day = 1; day <= 7; day++) {
      if (lastClaim == null) {
        // Never claimed - day 1 is current, rest are locked
        if (day == 1) {
          statuses[day] = RewardStatus.current;
        } else {
          statuses[day] = RewardStatus.locked;
        }
      } else if (day < currentDay) {
        // Days before current day are claimed
        statuses[day] = RewardStatus.claimed;
      } else if (day == currentDay && !canClaim) {
        // Already claimed today - currentDay points to NEXT day, which is locked
        statuses[day] = RewardStatus.locked;
      } else if (day == currentDay && canClaim) {
        // Current day and can claim
        statuses[day] = RewardStatus.current;
      } else {
        // Future days
        statuses[day] = RewardStatus.locked;
      }
    }
    
    // Handle the edge case where currentDay is 1 but we have claimed before
    // This means we completed day 7 and reset
    if (currentDay == 1 && lastClaim != null && !canClaim) {
      // Just completed the cycle, waiting for next day
      statuses[1] = RewardStatus.locked;
    }
    
    return statuses;
  }

  /// Reset all daily rewards data (for testing)
  Future<void> resetAll() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.remove(_lastClaimDateKey);
      await _prefs?.remove(_streakDayKey);
    } catch (e) {
      debugPrint('DailyRewardsService resetAll failed: $e');
    }
  }
}

/// Status of a reward day
enum RewardStatus {
  claimed,   // Already collected (checkmark)
  current,   // Available to claim now (glowing)
  locked,    // Future day (locked/dimmed)
}

import 'package:flutter/material.dart';

/// Types of rewards available in daily rewards
enum RewardType {
  coins,
  powerUp,
  hints,
  theme,
}

/// Extension to get display info for reward types
extension RewardTypeExtension on RewardType {
  String get displayName {
    switch (this) {
      case RewardType.coins:
        return 'Coins';
      case RewardType.powerUp:
        return 'Power-Up';
      case RewardType.hints:
        return 'Hints';
      case RewardType.theme:
        return 'Theme';
    }
  }

  IconData get icon {
    switch (this) {
      case RewardType.coins:
        return Icons.monetization_on;
      case RewardType.powerUp:
        return Icons.flash_on;
      case RewardType.hints:
        return Icons.lightbulb;
      case RewardType.theme:
        return Icons.palette;
    }
  }

  Color get color {
    switch (this) {
      case RewardType.coins:
        return const Color(0xFFFFD700); // Gold
      case RewardType.powerUp:
        return const Color(0xFFFF6B81); // Pink
      case RewardType.hints:
        return const Color(0xFF2ED573); // Green
      case RewardType.theme:
        return const Color(0xFFA55EEA); // Purple
    }
  }
}

/// Represents a single day's reward in the daily calendar
class DailyReward {
  final int day; // 1-7
  final RewardType type;
  final int amount;
  final String? specialItem; // Theme ID, etc.

  const DailyReward({
    required this.day,
    required this.type,
    required this.amount,
    this.specialItem,
  });

  /// Get a description of the reward
  String get description {
    switch (type) {
      case RewardType.coins:
        return '$amount Coins';
      case RewardType.powerUp:
        return '$amount Power-Up${amount > 1 ? 's' : ''}';
      case RewardType.hints:
        return '$amount Hint${amount > 1 ? 's' : ''}';
      case RewardType.theme:
        return 'Special Theme';
    }
  }

  /// Check if this is a premium/special reward (day 7)
  bool get isPremium => day == 7;
}

/// The 7-day daily rewards calendar
const List<DailyReward> dailyRewards = [
  DailyReward(day: 1, type: RewardType.coins, amount: 25),
  DailyReward(day: 2, type: RewardType.powerUp, amount: 1),
  DailyReward(day: 3, type: RewardType.coins, amount: 50),
  DailyReward(day: 4, type: RewardType.powerUp, amount: 2),
  DailyReward(day: 5, type: RewardType.coins, amount: 100),
  DailyReward(day: 6, type: RewardType.hints, amount: 3),
  DailyReward(day: 7, type: RewardType.coins, amount: 250),
];

/// Get a reward for a specific day (1-7)
DailyReward getRewardForDay(int day) {
  final index = (day - 1).clamp(0, dailyRewards.length - 1);
  return dailyRewards[index];
}

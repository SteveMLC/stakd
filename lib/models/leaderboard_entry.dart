/// Represents a single entry on a leaderboard
class LeaderboardEntry {
  final String playerId;
  final String playerName;
  final int score;
  final int rank;
  final DateTime timestamp;
  final bool isCurrentPlayer;

  const LeaderboardEntry({
    required this.playerId,
    required this.playerName,
    required this.score,
    required this.rank,
    required this.timestamp,
    this.isCurrentPlayer = false,
  });

  LeaderboardEntry copyWith({
    String? playerId,
    String? playerName,
    int? score,
    int? rank,
    DateTime? timestamp,
    bool? isCurrentPlayer,
  }) {
    return LeaderboardEntry(
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      score: score ?? this.score,
      rank: rank ?? this.rank,
      timestamp: timestamp ?? this.timestamp,
      isCurrentPlayer: isCurrentPlayer ?? this.isCurrentPlayer,
    );
  }

  factory LeaderboardEntry.fromFirestore(
    Map<String, dynamic> data,
    String docId,
    int rank, {
    bool isCurrentPlayer = false,
  }) {
    return LeaderboardEntry(
      playerId: docId,
      playerName: data['name'] as String? ?? 'Unknown',
      score: data['score'] as int? ?? data['stars'] as int? ?? data['combo'] as int? ?? 0,
      rank: rank,
      timestamp: data['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
      isCurrentPlayer: isCurrentPlayer,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': playerName,
      'score': score,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() {
    return 'LeaderboardEntry(playerId: $playerId, playerName: $playerName, score: $score, rank: $rank)';
  }
}

/// Types of leaderboards available
enum LeaderboardType {
  dailyChallenge,
  weeklyStars,
  allTimeStars,
  bestCombo,
}

extension LeaderboardTypeExtension on LeaderboardType {
  String get displayName {
    switch (this) {
      case LeaderboardType.dailyChallenge:
        return 'Daily Challenge';
      case LeaderboardType.weeklyStars:
        return 'Weekly Stars';
      case LeaderboardType.allTimeStars:
        return 'All-Time Stars';
      case LeaderboardType.bestCombo:
        return 'Best Combo';
    }
  }

  String get shortName {
    switch (this) {
      case LeaderboardType.dailyChallenge:
        return 'Daily';
      case LeaderboardType.weeklyStars:
        return 'Weekly';
      case LeaderboardType.allTimeStars:
        return 'All-Time';
      case LeaderboardType.bestCombo:
        return 'Combo';
    }
  }

  String get icon {
    switch (this) {
      case LeaderboardType.dailyChallenge:
        return '⏱️';
      case LeaderboardType.weeklyStars:
        return '📅';
      case LeaderboardType.allTimeStars:
        return '⭐';
      case LeaderboardType.bestCombo:
        return '🔥';
    }
  }

  /// Lower is better for time-based, higher is better for score-based
  bool get lowerIsBetter => this == LeaderboardType.dailyChallenge;
}

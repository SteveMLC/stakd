import 'dart:math';

class DailyChallenge {
  final DateTime date;
  final int seed;
  final int difficulty;
  final bool completed;
  final Duration? bestTime;

  DailyChallenge({
    required this.date,
    required this.seed,
    this.difficulty = 3,
    this.completed = false,
    this.bestTime,
  });

  /// Generate a deterministic seed from a date
  /// Same date = same seed for all players
  static int generateSeedFromDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.millisecondsSinceEpoch ~/ 1000;
  }

  /// Create today's challenge
  factory DailyChallenge.today() {
    final today = DateTime.now();
    final normalized = DateTime(today.year, today.month, today.day);
    return DailyChallenge(
      date: normalized,
      seed: generateSeedFromDate(normalized),
      difficulty: 3,
    );
  }

  /// Get day number since app epoch (Jan 1, 2025)
  int getDayNumber() {
    final epoch = DateTime(2025, 1, 1);
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.difference(epoch).inDays + 1;
  }

  /// Generate puzzle grid from seed
  List<List<int>> generatePuzzle() {
    final random = Random(seed);
    final gridSize = 4; // 4x4 grid
    final grid = List.generate(
      gridSize,
      (i) => List.generate(gridSize, (j) => random.nextInt(6) + 1),
    );
    return grid;
  }

  DailyChallenge copyWith({
    DateTime? date,
    int? seed,
    int? difficulty,
    bool? completed,
    Duration? bestTime,
  }) {
    return DailyChallenge(
      date: date ?? this.date,
      seed: seed ?? this.seed,
      difficulty: difficulty ?? this.difficulty,
      completed: completed ?? this.completed,
      bestTime: bestTime ?? this.bestTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'seed': seed,
      'difficulty': difficulty,
      'completed': completed,
      'bestTime': bestTime?.inSeconds,
    };
  }

  factory DailyChallenge.fromJson(Map<String, dynamic> json) {
    return DailyChallenge(
      date: DateTime.parse(json['date']),
      seed: json['seed'],
      difficulty: json['difficulty'] ?? 3,
      completed: json['completed'] ?? false,
      bestTime: json['bestTime'] != null
          ? Duration(seconds: json['bestTime'])
          : null,
    );
  }
}

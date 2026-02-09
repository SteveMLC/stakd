import '../services/level_generator.dart';
import 'stack_model.dart';

class DailyChallenge {
  final DateTime date;
  final int seed;
  final int difficulty;
  final bool completed;
  final Duration? bestTime;
  final int? bestMoves;

  DailyChallenge({
    required this.date,
    required this.seed,
    this.difficulty = 3,
    this.completed = false,
    this.bestTime,
    this.bestMoves,
  });

  /// Generate a deterministic seed from a date
  /// Same date = same seed for all players
  static int generateSeedFromDate(DateTime date) {
    final normalized = DateTime.utc(date.year, date.month, date.day);
    return normalized.millisecondsSinceEpoch ~/ 1000;
  }

  /// Create today's challenge
  factory DailyChallenge.today() {
    final today = DateTime.now().toUtc();
    final normalized = DateTime.utc(today.year, today.month, today.day);
    return DailyChallenge(
      date: normalized,
      seed: generateSeedFromDate(normalized),
      difficulty: 3,
    );
  }

  /// Get day number since app epoch (Jan 1, 2025)
  int getDayNumber() {
    final epoch = DateTime.utc(2025, 1, 1);
    final normalized = DateTime.utc(date.year, date.month, date.day);
    return normalized.difference(epoch).inDays + 1;
  }

  /// Generate deterministic stacks for the daily puzzle
  List<GameStack> generateStacks() {
    final generator = LevelGenerator(seed: seed);
    return generator.generateDailyChallenge(date: date);
  }

  DailyChallenge copyWith({
    DateTime? date,
    int? seed,
    int? difficulty,
    bool? completed,
    Duration? bestTime,
    int? bestMoves,
  }) {
    return DailyChallenge(
      date: date ?? this.date,
      seed: seed ?? this.seed,
      difficulty: difficulty ?? this.difficulty,
      completed: completed ?? this.completed,
      bestTime: bestTime ?? this.bestTime,
      bestMoves: bestMoves ?? this.bestMoves,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'seed': seed,
      'difficulty': difficulty,
      'completed': completed,
      'bestTime': bestTime?.inSeconds,
      'bestMoves': bestMoves,
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
      bestMoves: json['bestMoves'],
    );
  }
}

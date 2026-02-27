/// Service for calculating puzzle scores and rewards
class ScoreService {
  static ScoreService? _instance;
  factory ScoreService() => _instance ??= ScoreService._();
  ScoreService._();

  static const int _baseScore = 50;

  /// Calculate score for a completed puzzle
  PuzzleScore calculateScore({
    required String difficulty, // 'Easy', 'Medium', 'Hard', 'Ultra'
    required int stars,
    required int moves,
    required int parMoves,
    required Duration time,
    required int undosUsed,
    required int maxUndos,
    required int comboCount,
    required int lockedCleared,
    required int frozenCleared,
    bool isDailyChallenge = false,
  }) {
    // 1. Difficulty multiplier
    final difficultyMultiplier = _getDifficultyMultiplier(difficulty);

    // 2. Star multiplier
    final starMultiplier = _getStarMultiplier(stars);

    // 3. Move efficiency
    final moveEfficiency = _getMoveEfficiency(moves, parMoves);

    // 4. Time efficiency
    final timeEfficiency = _getTimeEfficiency(time);

    // 5. Bonus multipliers
    final bonusMultiplier = _getBonusMultiplier(
      undosUsed: undosUsed,
      maxUndos: maxUndos,
      comboCount: comboCount,
    );

    // 6. Calculate base score with multipliers
    final efficiency = starMultiplier * moveEfficiency * timeEfficiency;
    final baseScoreValue = (_baseScore * difficultyMultiplier * efficiency * bonusMultiplier).round();

    // 7. Flat bonuses
    final flatBonus = _getFlatBonus(
      lockedCleared: lockedCleared,
      frozenCleared: frozenCleared,
      isDailyChallenge: isDailyChallenge,
    );

    // 8. Total score
    final totalScore = baseScoreValue + flatBonus;

    // 9. XP and coins (reduced for slower progression)
    final xpEarned = (totalScore / 5).round();
    final coinsEarned = (totalScore / 15).round().clamp(1, double.infinity).toInt();

    return PuzzleScore(
      totalScore: totalScore,
      xpEarned: xpEarned,
      coinsEarned: coinsEarned,
      baseScore: baseScoreValue,
      difficultyMultiplier: difficultyMultiplier,
      starMultiplier: starMultiplier,
      moveEfficiency: moveEfficiency,
      timeEfficiency: timeEfficiency,
      bonusMultiplier: bonusMultiplier,
      flatBonus: flatBonus,
      breakdown: {
        'base': _baseScore,
        'difficulty': difficulty,
        'difficultyMultiplier': difficultyMultiplier,
        'stars': stars,
        'starMultiplier': starMultiplier,
        'moves': moves,
        'parMoves': parMoves,
        'moveEfficiency': moveEfficiency,
        'time': time.inSeconds,
        'timeEfficiency': timeEfficiency,
        'efficiency': efficiency,
        'undosUsed': undosUsed,
        'maxUndos': maxUndos,
        'comboCount': comboCount,
        'bonusMultiplier': bonusMultiplier,
        'baseScoreValue': baseScoreValue,
        'lockedCleared': lockedCleared,
        'frozenCleared': frozenCleared,
        'isDailyChallenge': isDailyChallenge,
        'flatBonus': flatBonus,
      },
    );
  }

  double _getDifficultyMultiplier(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 1.0;
      case 'medium':
        return 1.5;
      case 'hard':
        return 2.5;
      case 'ultra':
        return 4.0;
      default:
        return 1.0;
    }
  }

  double _getStarMultiplier(int stars) {
    switch (stars) {
      case 3:
        return 2.5; // +150% bonus
      case 2:
        return 1.5; // +50% bonus
      case 1:
        return 1.0; // +0% bonus
      default:
        return 1.0;
    }
  }

  double _getMoveEfficiency(int moves, int parMoves) {
    if (moves <= 0 || parMoves <= 0) return 1.0;
    return (parMoves / moves).clamp(0.5, 2.0);
  }

  double _getTimeEfficiency(Duration time) {
    final seconds = time.inSeconds;
    if (seconds < 30) return 1.5;
    if (seconds < 60) return 1.2;
    if (seconds < 120) return 1.0;
    return 0.9;
  }

  double _getBonusMultiplier({
    required int undosUsed,
    required int maxUndos,
    required int comboCount,
  }) {
    double multiplier = 1.0;

    // No undos bonus
    if (undosUsed == 0 && maxUndos > 0) {
      multiplier *= 1.5;
    }

    // Combo bonus (3+ chain)
    if (comboCount >= 3) {
      multiplier *= (1.0 + 0.1 * comboCount);
    }

    return multiplier;
  }

  int _getFlatBonus({
    required int lockedCleared,
    required int frozenCleared,
    required bool isDailyChallenge,
  }) {
    int bonus = 0;
    bonus += lockedCleared * 100;
    bonus += frozenCleared * 150;
    if (isDailyChallenge) bonus += 500;
    return bonus;
  }
}

class PuzzleScore {
  final int totalScore;
  final int xpEarned; // totalScore / 10
  final int coinsEarned; // xpEarned / 10, min 1
  final int baseScore;
  final double difficultyMultiplier;
  final double starMultiplier;
  final double moveEfficiency;
  final double timeEfficiency;
  final double bonusMultiplier;
  final int flatBonus;
  final Map<String, dynamic> breakdown; // for UI display

  PuzzleScore({
    required this.totalScore,
    required this.xpEarned,
    required this.coinsEarned,
    required this.baseScore,
    required this.difficultyMultiplier,
    required this.starMultiplier,
    required this.moveEfficiency,
    required this.timeEfficiency,
    required this.bonusMultiplier,
    required this.flatBonus,
    required this.breakdown,
  });

  @override
  String toString() {
    return 'PuzzleScore(total: $totalScore, xp: $xpEarned, coins: $coinsEarned)';
  }
}

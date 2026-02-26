import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing player progression (XP, ranks, level-ups)
class ProgressionService {
  static ProgressionService? _instance;
  factory ProgressionService() => _instance ??= ProgressionService._();
  ProgressionService._();

  SharedPreferences? _prefs;

  // State
  int _totalXP = 0;
  int _lifetimeScore = 0;
  int _totalPuzzlesScored = 0;

  // Keys
  static const String _keyTotalXP = 'progression_total_xp';
  static const String _keyLifetimeScore = 'progression_lifetime_score';
  static const String _keyTotalPuzzles = 'progression_total_puzzles';

  /// Initialize and load from SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _totalXP = _prefs!.getInt(_keyTotalXP) ?? 0;
    _lifetimeScore = _prefs!.getInt(_keyLifetimeScore) ?? 0;
    _totalPuzzlesScored = _prefs!.getInt(_keyTotalPuzzles) ?? 0;
  }

  // Getters
  int get totalXP => _totalXP;
  int get lifetimeScore => _lifetimeScore;
  int get totalPuzzlesScored => _totalPuzzlesScored;

  /// Current rank (1-25)
  int get currentRank {
    for (int i = ranks.length - 1; i >= 0; i--) {
      if (_totalXP >= ranks[i].xpRequired) {
        return ranks[i].rank;
      }
    }
    return 1;
  }

  RankDefinition get _currentRankDef => ranks[currentRank - 1];

  String get rankTitle => _currentRankDef.title;
  String get rankTier => _currentRankDef.tier;
  String get tierEmoji => _currentRankDef.emoji;

  /// XP required to reach the current rank
  int get xpForCurrentRank => _currentRankDef.xpRequired;

  /// XP required to reach the next rank
  int get xpForNextRank {
    if (currentRank >= 25) return _currentRankDef.xpRequired; // Max rank
    return ranks[currentRank].xpRequired;
  }

  /// Progress to next rank (0.0 to 1.0)
  double get progressToNextRank {
    if (currentRank >= 25) return 1.0; // Max rank

    final currentRankXP = xpForCurrentRank;
    final nextRankXP = xpForNextRank;
    final xpIntoCurrentRank = _totalXP - currentRankXP;
    final xpNeededForNextRank = nextRankXP - currentRankXP;

    if (xpNeededForNextRank <= 0) return 1.0;
    return (xpIntoCurrentRank / xpNeededForNextRank).clamp(0.0, 1.0);
  }

  /// Add XP and check for rank up
  Future<RankUpResult?> addXP(int xp) async {
    final oldRank = currentRank;
    _totalXP += xp;
    await _prefs!.setInt(_keyTotalXP, _totalXP);

    final newRank = currentRank;
    if (newRank > oldRank) {
      return RankUpResult(
        oldRank: oldRank,
        newRank: newRank,
        newRankDef: ranks[newRank - 1],
      );
    }
    return null;
  }

  /// Add score to lifetime total
  Future<void> addScore(int score) async {
    _lifetimeScore += score;
    _totalPuzzlesScored++;
    await _prefs!.setInt(_keyLifetimeScore, _lifetimeScore);
    await _prefs!.setInt(_keyTotalPuzzles, _totalPuzzlesScored);
  }

  /// The 25 ranks with their XP requirements
  static const List<RankDefinition> ranks = [
    RankDefinition(
      rank: 1,
      title: 'Curious Wanderer',
      tier: 'Seedling',
      emoji: '🌱',
      xpRequired: 0,
      iconDesc: 'A sprouting seed',
    ),
    RankDefinition(
      rank: 2,
      title: 'Stone Apprentice',
      tier: 'Seedling',
      emoji: '🌱',
      xpRequired: 500,
      iconDesc: 'A young plant',
    ),
    RankDefinition(
      rank: 3,
      title: 'Block Novice',
      tier: 'Seedling',
      emoji: '🌱',
      xpRequired: 1500,
      iconDesc: 'Growing seedling',
    ),
    RankDefinition(
      rank: 4,
      title: 'Color Seeker',
      tier: 'Seedling',
      emoji: '🌱',
      xpRequired: 3000,
      iconDesc: 'Strong seedling',
    ),
    RankDefinition(
      rank: 5,
      title: 'Garden Tender',
      tier: 'Seedling',
      emoji: '🌱',
      xpRequired: 5500,
      iconDesc: 'Mature seedling',
    ),
    RankDefinition(
      rank: 6,
      title: 'Mindful Stacker',
      tier: 'Sprout',
      emoji: '🌿',
      xpRequired: 9000,
      iconDesc: 'Young sprout',
    ),
    RankDefinition(
      rank: 7,
      title: 'Balance Keeper',
      tier: 'Sprout',
      emoji: '🌿',
      xpRequired: 13500,
      iconDesc: 'Growing sprout',
    ),
    RankDefinition(
      rank: 8,
      title: 'Flow Finder',
      tier: 'Sprout',
      emoji: '🌿',
      xpRequired: 19000,
      iconDesc: 'Strong sprout',
    ),
    RankDefinition(
      rank: 9,
      title: 'Harmony Weaver',
      tier: 'Sprout',
      emoji: '🌿',
      xpRequired: 26000,
      iconDesc: 'Flourishing sprout',
    ),
    RankDefinition(
      rank: 10,
      title: 'Garden Guardian',
      tier: 'Sprout',
      emoji: '🌿',
      xpRequired: 35000,
      iconDesc: 'Mature sprout',
    ),
    RankDefinition(
      rank: 11,
      title: 'Zen Adept',
      tier: 'Blossom',
      emoji: '🌸',
      xpRequired: 46000,
      iconDesc: 'Early blossom',
    ),
    RankDefinition(
      rank: 12,
      title: 'Pattern Master',
      tier: 'Blossom',
      emoji: '🌸',
      xpRequired: 59000,
      iconDesc: 'Budding flower',
    ),
    RankDefinition(
      rank: 13,
      title: 'Tranquil Mind',
      tier: 'Blossom',
      emoji: '🌸',
      xpRequired: 74000,
      iconDesc: 'Opening blossom',
    ),
    RankDefinition(
      rank: 14,
      title: 'Color Sage',
      tier: 'Blossom',
      emoji: '🌸',
      xpRequired: 91000,
      iconDesc: 'Full bloom',
    ),
    RankDefinition(
      rank: 15,
      title: 'Serenity Guide',
      tier: 'Blossom',
      emoji: '🌸',
      xpRequired: 110000,
      iconDesc: 'Radiant blossom',
    ),
    RankDefinition(
      rank: 16,
      title: 'Wisdom Keeper',
      tier: 'Ancient',
      emoji: '🌳',
      xpRequired: 132000,
      iconDesc: 'Young tree',
    ),
    RankDefinition(
      rank: 17,
      title: 'Master Stacker',
      tier: 'Ancient',
      emoji: '🌳',
      xpRequired: 157000,
      iconDesc: 'Growing tree',
    ),
    RankDefinition(
      rank: 18,
      title: 'Enlightened One',
      tier: 'Ancient',
      emoji: '🌳',
      xpRequired: 185000,
      iconDesc: 'Strong tree',
    ),
    RankDefinition(
      rank: 19,
      title: 'Garden Sage',
      tier: 'Ancient',
      emoji: '🌳',
      xpRequired: 217000,
      iconDesc: 'Mighty tree',
    ),
    RankDefinition(
      rank: 20,
      title: 'Zen Master',
      tier: 'Ancient',
      emoji: '🌳',
      xpRequired: 253000,
      iconDesc: 'Ancient tree',
    ),
    RankDefinition(
      rank: 21,
      title: 'Eternal Gardener',
      tier: 'Transcendent',
      emoji: '🏔️',
      xpRequired: 295000,
      iconDesc: 'Mountain peak',
    ),
    RankDefinition(
      rank: 22,
      title: 'Cosmic Arranger',
      tier: 'Transcendent',
      emoji: '🏔️',
      xpRequired: 343000,
      iconDesc: 'Snowy summit',
    ),
    RankDefinition(
      rank: 23,
      title: 'Harmony Eternal',
      tier: 'Transcendent',
      emoji: '🏔️',
      xpRequired: 398000,
      iconDesc: 'Celestial peak',
    ),
    RankDefinition(
      rank: 24,
      title: 'Nirvana Seeker',
      tier: 'Transcendent',
      emoji: '🏔️',
      xpRequired: 461000,
      iconDesc: 'Divine mountain',
    ),
    RankDefinition(
      rank: 25,
      title: 'Infinite Keeper',
      tier: 'Transcendent',
      emoji: '🏔️',
      xpRequired: 533000,
      iconDesc: 'Eternal summit',
    ),
  ];
}

class RankDefinition {
  final int rank; // 1-25
  final String title;
  final String tier; // 'Seedling', 'Sprout', 'Blossom', 'Ancient', 'Transcendent'
  final String emoji; // 🌱🌿🌸🌳🏔️
  final int xpRequired;
  final String iconDesc; // description for future icon

  const RankDefinition({
    required this.rank,
    required this.title,
    required this.tier,
    required this.emoji,
    required this.xpRequired,
    required this.iconDesc,
  });

  @override
  String toString() {
    return 'Rank $rank: $emoji $title ($tier) - $xpRequired XP';
  }
}

class RankUpResult {
  final int oldRank;
  final int newRank;
  final RankDefinition newRankDef;

  RankUpResult({
    required this.oldRank,
    required this.newRank,
    required this.newRankDef,
  });

  @override
  String toString() {
    return 'Ranked up from $oldRank to $newRank: ${newRankDef.emoji} ${newRankDef.title}';
  }
}

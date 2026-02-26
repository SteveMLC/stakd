import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Achievement categories
enum AchievementCategory {
  mastery,
  speed,
  streak,
  specialBlocks,
  garden,
  variety,
  hidden,
}

/// Achievement definition
class AchievementDef {
  final String id;
  final String name;
  final String description;
  final AchievementCategory category;
  final int xpReward;
  final int coinReward;
  final int? target;
  final bool isHidden;

  const AchievementDef({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.xpReward,
    required this.coinReward,
    this.target,
    this.isHidden = false,
  });
}

/// Achievement state (player progress)
class AchievementState {
  final String id;
  final bool unlocked;
  final DateTime? unlockedAt;
  final int progress;

  const AchievementState({
    required this.id,
    required this.unlocked,
    this.unlockedAt,
    this.progress = 0,
  });

  AchievementState copyWith({
    bool? unlocked,
    DateTime? unlockedAt,
    int? progress,
  }) {
    return AchievementState(
      id: id,
      unlocked: unlocked ?? this.unlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
    );
  }
}

/// Service for managing achievements
class AchievementService extends ChangeNotifier {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  SharedPreferences? _prefs;
  final Map<String, AchievementState> _states = {};
  final List<AchievementDef> _recentlyUnlocked = [];

  // ============================================================================
  // ACHIEVEMENT DEFINITIONS (48 total)
  // ============================================================================

  static const List<AchievementDef> _allAchievements = [
    // 🎯 MASTERY (12)
    AchievementDef(
      id: 'first_steps',
      name: 'First Steps',
      description: 'Solve any puzzle',
      category: AchievementCategory.mastery,
      xpReward: 100,
      coinReward: 50,
    ),
    AchievementDef(
      id: 'perfectionist',
      name: 'Perfectionist',
      description: '3-star any puzzle',
      category: AchievementCategory.mastery,
      xpReward: 200,
      coinReward: 75,
    ),
    AchievementDef(
      id: 'star_collector',
      name: 'Star Collector',
      description: '3-star 10 puzzles',
      category: AchievementCategory.mastery,
      xpReward: 500,
      coinReward: 150,
      target: 10,
    ),
    AchievementDef(
      id: 'star_hoarder',
      name: 'Star Hoarder',
      description: '3-star 50 puzzles',
      category: AchievementCategory.mastery,
      xpReward: 1500,
      coinReward: 500,
      target: 50,
    ),
    AchievementDef(
      id: 'constellation',
      name: 'Constellation',
      description: '3-star 100 puzzles',
      category: AchievementCategory.mastery,
      xpReward: 3000,
      coinReward: 1000,
      target: 100,
    ),
    AchievementDef(
      id: 'under_par',
      name: 'Under Par',
      description: 'Complete under par moves',
      category: AchievementCategory.mastery,
      xpReward: 300,
      coinReward: 100,
    ),
    AchievementDef(
      id: 'efficiency_expert',
      name: 'Efficiency Expert',
      description: '25 under-par wins',
      category: AchievementCategory.mastery,
      xpReward: 1000,
      coinReward: 300,
      target: 25,
    ),
    AchievementDef(
      id: 'optimal_path',
      name: 'Optimal Path',
      description: 'Complete at exact par',
      category: AchievementCategory.mastery,
      xpReward: 500,
      coinReward: 200,
    ),
    AchievementDef(
      id: 'no_mistakes',
      name: 'No Mistakes',
      description: 'Complete without undo',
      category: AchievementCategory.mastery,
      xpReward: 400,
      coinReward: 150,
    ),
    AchievementDef(
      id: 'flawless_mind',
      name: 'Flawless Mind',
      description: '20 no-undo puzzles',
      category: AchievementCategory.mastery,
      xpReward: 1200,
      coinReward: 400,
      target: 20,
    ),
    AchievementDef(
      id: 'marathon_runner',
      name: 'Marathon Runner',
      description: '500 total solves',
      category: AchievementCategory.mastery,
      xpReward: 5000,
      coinReward: 2000,
      target: 500,
    ),
    AchievementDef(
      id: 'thousand_stacks',
      name: 'Thousand Stacks',
      description: '1000 total solves',
      category: AchievementCategory.mastery,
      xpReward: 10000,
      coinReward: 5000,
      target: 1000,
    ),

    // ⚡ SPEED (8)
    AchievementDef(
      id: 'lightning',
      name: 'Lightning Reflexes',
      description: 'Solve under 30s',
      category: AchievementCategory.speed,
      xpReward: 300,
      coinReward: 100,
    ),
    AchievementDef(
      id: 'speed_demon',
      name: 'Speed Demon',
      description: '10 solves under 30s',
      category: AchievementCategory.speed,
      xpReward: 800,
      coinReward: 250,
      target: 10,
    ),
    AchievementDef(
      id: 'blink_twice',
      name: 'Blink Twice',
      description: 'Solve under 15s',
      category: AchievementCategory.speed,
      xpReward: 600,
      coinReward: 200,
    ),
    AchievementDef(
      id: 'bullet_time',
      name: 'Bullet Time',
      description: 'Easy under 10s',
      category: AchievementCategory.speed,
      xpReward: 400,
      coinReward: 150,
    ),
    AchievementDef(
      id: 'zen_flash',
      name: 'Zen Flash',
      description: 'Medium under 20s',
      category: AchievementCategory.speed,
      xpReward: 500,
      coinReward: 175,
    ),
    AchievementDef(
      id: 'rapid_master',
      name: 'Rapid Master',
      description: 'Hard under 40s',
      category: AchievementCategory.speed,
      xpReward: 700,
      coinReward: 225,
    ),
    AchievementDef(
      id: 'ultra_velocity',
      name: 'Ultra Velocity',
      description: 'Ultra under 60s',
      category: AchievementCategory.speed,
      xpReward: 1000,
      coinReward: 350,
    ),
    AchievementDef(
      id: 'speedrun_legend',
      name: 'Speedrun Legend',
      description: '20 puzzles avg under 60s',
      category: AchievementCategory.speed,
      xpReward: 2000,
      coinReward: 750,
      target: 20,
    ),

    // 🔥 STREAK (6)
    AchievementDef(
      id: 'hot_start',
      name: 'Hot Start',
      description: '5-puzzle streak',
      category: AchievementCategory.streak,
      xpReward: 400,
      coinReward: 125,
      target: 5,
    ),
    AchievementDef(
      id: 'on_fire',
      name: 'On Fire',
      description: '10-puzzle streak',
      category: AchievementCategory.streak,
      xpReward: 800,
      coinReward: 250,
      target: 10,
    ),
    AchievementDef(
      id: 'unstoppable',
      name: 'Unstoppable',
      description: '25-puzzle streak',
      category: AchievementCategory.streak,
      xpReward: 2000,
      coinReward: 600,
      target: 25,
    ),
    AchievementDef(
      id: 'legendary_flow',
      name: 'Legendary Flow',
      description: '50-puzzle streak',
      category: AchievementCategory.streak,
      xpReward: 5000,
      coinReward: 1500,
      target: 50,
    ),
    AchievementDef(
      id: 'daily_devotee',
      name: 'Daily Devotee',
      description: '7-day streak',
      category: AchievementCategory.streak,
      xpReward: 700,
      coinReward: 200,
      target: 7,
    ),
    AchievementDef(
      id: 'monthly_master',
      name: 'Monthly Master',
      description: '30-day streak',
      category: AchievementCategory.streak,
      xpReward: 3000,
      coinReward: 1000,
      target: 30,
    ),

    // 🧊 SPECIAL BLOCKS (6)
    AchievementDef(
      id: 'ice_breaker',
      name: 'Ice Breaker',
      description: 'Clear 1 frozen',
      category: AchievementCategory.specialBlocks,
      xpReward: 200,
      coinReward: 75,
    ),
    AchievementDef(
      id: 'frost_fighter',
      name: 'Frost Fighter',
      description: 'Clear 25 frozen',
      category: AchievementCategory.specialBlocks,
      xpReward: 600,
      coinReward: 200,
      target: 25,
    ),
    AchievementDef(
      id: 'glacial_master',
      name: 'Glacial Master',
      description: 'Clear 100 frozen',
      category: AchievementCategory.specialBlocks,
      xpReward: 1500,
      coinReward: 500,
      target: 100,
    ),
    AchievementDef(
      id: 'lock_picker',
      name: 'Lock Picker',
      description: 'Clear 1 locked',
      category: AchievementCategory.specialBlocks,
      xpReward: 200,
      coinReward: 75,
    ),
    AchievementDef(
      id: 'chain_breaker',
      name: 'Chain Breaker',
      description: 'Clear 25 locked',
      category: AchievementCategory.specialBlocks,
      xpReward: 600,
      coinReward: 200,
      target: 25,
    ),
    AchievementDef(
      id: 'liberation_expert',
      name: 'Liberation Expert',
      description: 'Clear 100 locked',
      category: AchievementCategory.specialBlocks,
      xpReward: 1500,
      coinReward: 500,
      target: 100,
    ),

    // 🌸 GARDEN (6)
    AchievementDef(
      id: 'garden_sprout',
      name: 'Garden Sprout',
      description: 'Reach stage 3',
      category: AchievementCategory.garden,
      xpReward: 500,
      coinReward: 150,
    ),
    AchievementDef(
      id: 'blooming_garden',
      name: 'Blooming Garden',
      description: 'Reach stage 5',
      category: AchievementCategory.garden,
      xpReward: 1000,
      coinReward: 300,
    ),
    AchievementDef(
      id: 'sacred_grove',
      name: 'Sacred Grove',
      description: 'Reach stage 7',
      category: AchievementCategory.garden,
      xpReward: 2000,
      coinReward: 600,
    ),
    AchievementDef(
      id: 'paradise_found',
      name: 'Paradise Found',
      description: 'Reach stage 10',
      category: AchievementCategory.garden,
      xpReward: 5000,
      coinReward: 1500,
    ),
    AchievementDef(
      id: 'collectors_pride',
      name: "Collector's Pride",
      description: '25 garden elements',
      category: AchievementCategory.garden,
      xpReward: 1500,
      coinReward: 500,
      target: 25,
    ),
    AchievementDef(
      id: 'garden_completionist',
      name: 'Garden Completionist',
      description: 'All garden elements',
      category: AchievementCategory.garden,
      xpReward: 10000,
      coinReward: 3000,
    ),

    // 🎨 VARIETY (5)
    AchievementDef(
      id: 'color_explorer',
      name: 'Color Explorer',
      description: 'Try all 4 difficulties',
      category: AchievementCategory.variety,
      xpReward: 400,
      coinReward: 150,
    ),
    AchievementDef(
      id: 'difficulty_warrior',
      name: 'Difficulty Warrior',
      description: '10 each difficulty',
      category: AchievementCategory.variety,
      xpReward: 1200,
      coinReward: 400,
      target: 40,
    ),
    AchievementDef(
      id: 'jack_of_all',
      name: 'Jack of All Stacks',
      description: '3-star one each difficulty',
      category: AchievementCategory.variety,
      xpReward: 1000,
      coinReward: 350,
    ),
    AchievementDef(
      id: 'challenge_accepted',
      name: 'Challenge Accepted',
      description: '10 daily challenges',
      category: AchievementCategory.variety,
      xpReward: 1500,
      coinReward: 500,
      target: 10,
    ),
    AchievementDef(
      id: 'challenge_master',
      name: 'Challenge Master',
      description: '50 daily challenges',
      category: AchievementCategory.variety,
      xpReward: 5000,
      coinReward: 1500,
      target: 50,
    ),

    // 🎁 HIDDEN (5)
    AchievementDef(
      id: 'midnight_stacker',
      name: 'Midnight Stacker 🌙',
      description: 'Play 12-3AM',
      category: AchievementCategory.hidden,
      xpReward: 300,
      coinReward: 100,
      isHidden: true,
    ),
    AchievementDef(
      id: 'century_score',
      name: 'Century Score',
      description: 'Score exactly 100',
      category: AchievementCategory.hidden,
      xpReward: 500,
      coinReward: 200,
      isHidden: true,
    ),
    AchievementDef(
      id: 'lucky_seven',
      name: 'Lucky Seven',
      description: 'Complete in exactly 7 moves',
      category: AchievementCategory.hidden,
      xpReward: 777,
      coinReward: 250,
      isHidden: true,
    ),
    AchievementDef(
      id: 'zen_moment',
      name: 'Zen Moment',
      description: 'Pause 60s mid-puzzle then complete',
      category: AchievementCategory.hidden,
      xpReward: 400,
      coinReward: 150,
      isHidden: true,
    ),
    AchievementDef(
      id: 'backwards_brain',
      name: 'Backwards Brain',
      description: 'Retry and improve 3×',
      category: AchievementCategory.hidden,
      xpReward: 600,
      coinReward: 200,
      isHidden: true,
    ),
  ];

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadStates();
    } catch (e) {
      debugPrint('AchievementService init failed: $e');
    }
  }

  void _loadStates() {
    for (final def in _allAchievements) {
      final unlocked = _prefs?.getBool('achievement_${def.id}_unlocked') ?? false;
      final progress = _prefs?.getInt('achievement_${def.id}_progress') ?? 0;
      final dateStr = _prefs?.getString('achievement_${def.id}_unlocked_at');
      final unlockedAt = dateStr != null ? DateTime.tryParse(dateStr) : null;

      _states[def.id] = AchievementState(
        id: def.id,
        unlocked: unlocked,
        unlockedAt: unlockedAt,
        progress: progress,
      );
    }
  }

  // ============================================================================
  // STATE ACCESSORS
  // ============================================================================

  List<AchievementDef> get allAchievements => List.unmodifiable(_allAchievements);

  List<AchievementState> get unlockedAchievements {
    return _states.values.where((s) => s.unlocked).toList();
  }

  List<AchievementState> get lockedAchievements {
    return _states.values.where((s) => !s.unlocked).toList();
  }

  int get unlockedCount => unlockedAchievements.length;

  int get totalCount => _allAchievements.length;

  List<AchievementState> get recentlyUnlocked {
    return _recentlyUnlocked
        .map((def) => _states[def.id]!)
        .where((s) => s.unlocked)
        .toList();
  }

  AchievementState getState(String id) {
    return _states[id] ?? const AchievementState(id: '', unlocked: false);
  }

  double getProgress(String id) {
    final state = _states[id];
    final def = _allAchievements.firstWhere((d) => d.id == id);
    
    if (state == null || state.unlocked) return 1.0;
    if (def.target == null) return 0.0;
    
    return (state.progress / def.target!).clamp(0.0, 1.0);
  }

  void markSeen(String id) {
    _recentlyUnlocked.removeWhere((def) => def.id == id);
    notifyListeners();
  }

  // ============================================================================
  // CHECK METHODS
  // ============================================================================

  List<AchievementDef> checkPuzzleComplete({
    required String difficulty,
    required int stars,
    required int moves,
    required int parMoves,
    required Duration time,
    required int undosUsed,
    required int streak,
    required int totalSolved,
    required int score,
  }) {
    final newlyUnlocked = <AchievementDef>[];
    final hour = DateTime.now().hour;

    // MASTERY
    if (totalSolved >= 1) {
      newlyUnlocked.addAll(_tryUnlock(['first_steps']));
    }
    if (stars >= 3) {
      newlyUnlocked.addAll(_tryUnlock(['perfectionist']));
      newlyUnlocked.addAll(_incrementAndCheck('star_collector'));
      newlyUnlocked.addAll(_incrementAndCheck('star_hoarder'));
      newlyUnlocked.addAll(_incrementAndCheck('constellation'));
    }
    if (moves < parMoves) {
      newlyUnlocked.addAll(_tryUnlock(['under_par']));
      newlyUnlocked.addAll(_incrementAndCheck('efficiency_expert'));
    }
    if (moves == parMoves) {
      newlyUnlocked.addAll(_tryUnlock(['optimal_path']));
    }
    if (undosUsed == 0) {
      newlyUnlocked.addAll(_tryUnlock(['no_mistakes']));
      newlyUnlocked.addAll(_incrementAndCheck('flawless_mind'));
    }
    newlyUnlocked.addAll(_setProgressAndCheck('marathon_runner', totalSolved));
    newlyUnlocked.addAll(_setProgressAndCheck('thousand_stacks', totalSolved));

    // SPEED
    final seconds = time.inSeconds;
    if (seconds < 30) {
      newlyUnlocked.addAll(_tryUnlock(['lightning']));
      newlyUnlocked.addAll(_incrementAndCheck('speed_demon'));
    }
    if (seconds < 15) {
      newlyUnlocked.addAll(_tryUnlock(['blink_twice']));
    }
    if (difficulty.toLowerCase() == 'easy' && seconds < 10) {
      newlyUnlocked.addAll(_tryUnlock(['bullet_time']));
    }
    if (difficulty.toLowerCase() == 'medium' && seconds < 20) {
      newlyUnlocked.addAll(_tryUnlock(['zen_flash']));
    }
    if (difficulty.toLowerCase() == 'hard' && seconds < 40) {
      newlyUnlocked.addAll(_tryUnlock(['rapid_master']));
    }
    if (difficulty.toLowerCase() == 'ultra' && seconds < 60) {
      newlyUnlocked.addAll(_tryUnlock(['ultra_velocity']));
    }
    if (seconds < 60) {
      newlyUnlocked.addAll(_incrementAndCheck('speedrun_legend'));
    }

    // STREAK
    newlyUnlocked.addAll(_setProgressAndCheck('hot_start', streak));
    newlyUnlocked.addAll(_setProgressAndCheck('on_fire', streak));
    newlyUnlocked.addAll(_setProgressAndCheck('unstoppable', streak));
    newlyUnlocked.addAll(_setProgressAndCheck('legendary_flow', streak));

    // HIDDEN
    if (hour >= 0 && hour < 3) {
      newlyUnlocked.addAll(_tryUnlock(['midnight_stacker']));
    }
    if (score == 100) {
      newlyUnlocked.addAll(_tryUnlock(['century_score']));
    }
    if (moves == 7) {
      newlyUnlocked.addAll(_tryUnlock(['lucky_seven']));
    }

    return newlyUnlocked;
  }

  List<AchievementDef> checkSpecialBlockCleared({
    required bool isFrozen,
    required bool isLocked,
  }) {
    final newlyUnlocked = <AchievementDef>[];

    if (isFrozen) {
      newlyUnlocked.addAll(_tryUnlock(['ice_breaker']));
      newlyUnlocked.addAll(_incrementAndCheck('frost_fighter'));
      newlyUnlocked.addAll(_incrementAndCheck('glacial_master'));
    }

    if (isLocked) {
      newlyUnlocked.addAll(_tryUnlock(['lock_picker']));
      newlyUnlocked.addAll(_incrementAndCheck('chain_breaker'));
      newlyUnlocked.addAll(_incrementAndCheck('liberation_expert'));
    }

    return newlyUnlocked;
  }

  List<AchievementDef> checkGardenProgress({
    required int stage,
    required int elements,
  }) {
    final newlyUnlocked = <AchievementDef>[];

    if (stage >= 3) newlyUnlocked.addAll(_tryUnlock(['garden_sprout']));
    if (stage >= 5) newlyUnlocked.addAll(_tryUnlock(['blooming_garden']));
    if (stage >= 7) newlyUnlocked.addAll(_tryUnlock(['sacred_grove']));
    if (stage >= 10) newlyUnlocked.addAll(_tryUnlock(['paradise_found']));

    newlyUnlocked.addAll(_setProgressAndCheck('collectors_pride', elements));

    return newlyUnlocked;
  }

  List<AchievementDef> checkDailyStreak({required int days}) {
    final newlyUnlocked = <AchievementDef>[];
    
    newlyUnlocked.addAll(_setProgressAndCheck('daily_devotee', days));
    newlyUnlocked.addAll(_setProgressAndCheck('monthly_master', days));

    return newlyUnlocked;
  }

  // ============================================================================
  // INTERNAL HELPERS
  // ============================================================================

  List<AchievementDef> _tryUnlock(List<String> ids) {
    final unlocked = <AchievementDef>[];
    
    for (final id in ids) {
      final state = _states[id];
      if (state == null || state.unlocked) continue;

      final def = _allAchievements.firstWhere((d) => d.id == id);
      _unlock(id);
      unlocked.add(def);
    }

    return unlocked;
  }

  List<AchievementDef> _incrementAndCheck(String id) {
    final state = _states[id];
    if (state == null || state.unlocked) return [];

    final def = _allAchievements.firstWhere((d) => d.id == id);
    if (def.target == null) return [];

    final newProgress = state.progress + 1;
    _updateProgress(id, newProgress);

    if (newProgress >= def.target!) {
      _unlock(id);
      return [def];
    }

    return [];
  }

  List<AchievementDef> _setProgressAndCheck(String id, int progress) {
    final state = _states[id];
    if (state == null || state.unlocked) return [];

    final def = _allAchievements.firstWhere((d) => d.id == id);
    if (def.target == null) return [];

    _updateProgress(id, progress);

    if (progress >= def.target!) {
      _unlock(id);
      return [def];
    }

    return [];
  }

  void _unlock(String id) {
    final now = DateTime.now();
    _states[id] = _states[id]!.copyWith(
      unlocked: true,
      unlockedAt: now,
    );

    _prefs?.setBool('achievement_${id}_unlocked', true);
    _prefs?.setString('achievement_${id}_unlocked_at', now.toIso8601String());

    final def = _allAchievements.firstWhere((d) => d.id == id);
    _recentlyUnlocked.add(def);

    notifyListeners();
  }

  void _updateProgress(String id, int progress) {
    _states[id] = _states[id]!.copyWith(progress: progress);
    _prefs?.setInt('achievement_${id}_progress', progress);
    notifyListeners();
  }
}

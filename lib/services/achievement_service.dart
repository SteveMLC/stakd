import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import 'income_multiplier_service.dart';

/// Extended achievement categories for the new system
enum AchievementCategoryExt {
  mastery,
  speed,
  streak,
  specialBlocks,
  warehouse,
  variety,
  hidden,
}

/// Achievement definition with XP and coin rewards
class AchievementDef {
  final String id;
  final String name;
  final String description;
  final AchievementCategoryExt category;
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
  final List<Achievement> _pendingToasts = [];

  /// Achievements waiting to be shown as toasts (legacy support)
  List<Achievement> get pendingToasts => List.unmodifiable(_pendingToasts);

  /// Clear a pending toast after it's been displayed (legacy support)
  void dismissToast(Achievement achievement) {
    _pendingToasts.remove(achievement);
    notifyListeners();
  }

  // ============================================================================
  // ACHIEVEMENT DEFINITIONS (48 total)
  // ============================================================================

  static const List<AchievementDef> _allAchievements = [
    // 🎯 MASTERY (12)
    AchievementDef(
      id: 'first_steps',
      name: 'First Steps',
      description: 'Solve any puzzle',
      category: AchievementCategoryExt.mastery,
      xpReward: 50,
      coinReward: 25,
    ),
    AchievementDef(
      id: 'perfectionist',
      name: 'Perfectionist',
      description: '3-star any puzzle',
      category: AchievementCategoryExt.mastery,
      xpReward: 100,
      coinReward: 40,
    ),
    AchievementDef(
      id: 'star_collector',
      name: 'Star Collector',
      description: '3-star 10 puzzles',
      category: AchievementCategoryExt.mastery,
      xpReward: 200,
      coinReward: 75,
      target: 10,
    ),
    AchievementDef(
      id: 'star_hoarder',
      name: 'Star Hoarder',
      description: '3-star 50 puzzles',
      category: AchievementCategoryExt.mastery,
      xpReward: 600,
      coinReward: 200,
      target: 50,
    ),
    AchievementDef(
      id: 'constellation',
      name: 'Constellation',
      description: '3-star 100 puzzles',
      category: AchievementCategoryExt.mastery,
      xpReward: 1200,
      coinReward: 400,
      target: 100,
    ),
    AchievementDef(
      id: 'under_par',
      name: 'Under Par',
      description: 'Complete under target moves',
      category: AchievementCategoryExt.mastery,
      xpReward: 150,
      coinReward: 50,
    ),
    AchievementDef(
      id: 'efficiency_expert',
      name: 'Efficiency Expert',
      description: '25 under-target wins',
      category: AchievementCategoryExt.mastery,
      xpReward: 400,
      coinReward: 125,
      target: 25,
    ),
    AchievementDef(
      id: 'optimal_path',
      name: 'Optimal Path',
      description: 'Complete at exact target',
      category: AchievementCategoryExt.mastery,
      xpReward: 200,
      coinReward: 80,
    ),
    AchievementDef(
      id: 'no_mistakes',
      name: 'No Mistakes',
      description: 'Complete without undo',
      category: AchievementCategoryExt.mastery,
      xpReward: 150,
      coinReward: 60,
    ),
    AchievementDef(
      id: 'flawless_mind',
      name: 'Flawless Mind',
      description: '20 no-undo puzzles',
      category: AchievementCategoryExt.mastery,
      xpReward: 500,
      coinReward: 175,
      target: 20,
    ),
    AchievementDef(
      id: 'marathon_runner',
      name: 'Marathon Runner',
      description: '500 total solves',
      category: AchievementCategoryExt.mastery,
      xpReward: 2000,
      coinReward: 800,
      target: 500,
    ),
    AchievementDef(
      id: 'thousand_stacks',
      name: 'Thousand Stacks',
      description: '1000 total solves',
      category: AchievementCategoryExt.mastery,
      xpReward: 4000,
      coinReward: 2000,
      target: 1000,
    ),

    // ⚡ SPEED (8)
    AchievementDef(
      id: 'lightning',
      name: 'Lightning Reflexes',
      description: 'Solve under 30s',
      category: AchievementCategoryExt.speed,
      xpReward: 125,
      coinReward: 50,
    ),
    AchievementDef(
      id: 'speed_demon',
      name: 'Speed Demon',
      description: '10 solves under 30s',
      category: AchievementCategoryExt.speed,
      xpReward: 300,
      coinReward: 100,
      target: 10,
    ),
    AchievementDef(
      id: 'blink_twice',
      name: 'Blink Twice',
      description: 'Solve under 15s',
      category: AchievementCategoryExt.speed,
      xpReward: 250,
      coinReward: 80,
    ),
    AchievementDef(
      id: 'bullet_time',
      name: 'Bullet Time',
      description: 'Easy under 10s',
      category: AchievementCategoryExt.speed,
      xpReward: 150,
      coinReward: 60,
    ),
    AchievementDef(
      id: 'quick_dispatch',
      name: 'Quick Dispatch',
      description: 'Medium contract under 20s',
      category: AchievementCategoryExt.speed,
      xpReward: 200,
      coinReward: 75,
    ),
    AchievementDef(
      id: 'rapid_master',
      name: 'Rapid Master',
      description: 'Hard under 40s',
      category: AchievementCategoryExt.speed,
      xpReward: 300,
      coinReward: 100,
    ),
    AchievementDef(
      id: 'ultra_velocity',
      name: 'Ultra Velocity',
      description: 'Ultra under 60s',
      category: AchievementCategoryExt.speed,
      xpReward: 400,
      coinReward: 150,
    ),
    AchievementDef(
      id: 'speedrun_legend',
      name: 'Speedrun Legend',
      description: '20 puzzles avg under 60s',
      category: AchievementCategoryExt.speed,
      xpReward: 800,
      coinReward: 300,
      target: 20,
    ),

    // 🔥 STREAK (6)
    AchievementDef(
      id: 'hot_start',
      name: 'Hot Start',
      description: '5-puzzle streak',
      category: AchievementCategoryExt.streak,
      xpReward: 150,
      coinReward: 50,
      target: 5,
    ),
    AchievementDef(
      id: 'on_fire',
      name: 'On Fire',
      description: '10-puzzle streak',
      category: AchievementCategoryExt.streak,
      xpReward: 300,
      coinReward: 100,
      target: 10,
    ),
    AchievementDef(
      id: 'unstoppable',
      name: 'Unstoppable',
      description: '25-puzzle streak',
      category: AchievementCategoryExt.streak,
      xpReward: 800,
      coinReward: 250,
      target: 25,
    ),
    AchievementDef(
      id: 'legendary_flow',
      name: 'Legendary Flow',
      description: '50-puzzle streak',
      category: AchievementCategoryExt.streak,
      xpReward: 2000,
      coinReward: 600,
      target: 50,
    ),
    AchievementDef(
      id: 'daily_devotee',
      name: 'Daily Devotee',
      description: '7-day streak',
      category: AchievementCategoryExt.streak,
      xpReward: 300,
      coinReward: 80,
      target: 7,
    ),
    AchievementDef(
      id: 'monthly_master',
      name: 'Monthly Master',
      description: '30-day streak',
      category: AchievementCategoryExt.streak,
      xpReward: 1200,
      coinReward: 400,
      target: 30,
    ),

    // 🧊 SPECIAL BLOCKS (6)
    AchievementDef(
      id: 'ice_breaker',
      name: 'Ice Breaker',
      description: 'Clear 1 frozen block',
      category: AchievementCategoryExt.specialBlocks,
      xpReward: 100,
      coinReward: 30,
    ),
    AchievementDef(
      id: 'frost_fighter',
      name: 'Frost Fighter',
      description: 'Clear 25 frozen blocks',
      category: AchievementCategoryExt.specialBlocks,
      xpReward: 250,
      coinReward: 80,
      target: 25,
    ),
    AchievementDef(
      id: 'glacial_master',
      name: 'Glacial Master',
      description: 'Clear 100 frozen blocks',
      category: AchievementCategoryExt.specialBlocks,
      xpReward: 600,
      coinReward: 200,
      target: 100,
    ),
    AchievementDef(
      id: 'lock_picker',
      name: 'Lock Picker',
      description: 'Clear 1 locked block',
      category: AchievementCategoryExt.specialBlocks,
      xpReward: 100,
      coinReward: 30,
    ),
    AchievementDef(
      id: 'chain_breaker',
      name: 'Chain Breaker',
      description: 'Clear 25 locked blocks',
      category: AchievementCategoryExt.specialBlocks,
      xpReward: 250,
      coinReward: 80,
      target: 25,
    ),
    AchievementDef(
      id: 'liberation_expert',
      name: 'Liberation Expert',
      description: 'Clear 100 locked',
      category: AchievementCategoryExt.specialBlocks,
      xpReward: 600,
      coinReward: 200,
      target: 100,
    ),

    // 🏭 WAREHOUSE PROGRESSION (6) — replaces zen-garden achievements
    AchievementDef(
      id: 'first_shipment',
      name: 'First Shipment',
      description: 'Ship your first sorted bay',
      category: AchievementCategoryExt.warehouse,
      xpReward: 200,
      coinReward: 60,
    ),
    AchievementDef(
      id: 'forklift_collector',
      name: 'Forklift Collector',
      description: 'Buy your first cosmetic forklift',
      category: AchievementCategoryExt.warehouse,
      xpReward: 400,
      coinReward: 125,
    ),
    AchievementDef(
      id: 'regional_unlocked',
      name: 'Going Regional',
      description: 'Unlock the Regional Hub tier',
      category: AchievementCategoryExt.warehouse,
      xpReward: 800,
      coinReward: 250,
    ),
    AchievementDef(
      id: 'local_tycoon',
      name: 'Local Tycoon',
      description: 'Clear all 3 Local contracts',
      category: AchievementCategoryExt.warehouse,
      xpReward: 2000,
      coinReward: 600,
    ),
    AchievementDef(
      id: 'cash_milestone_5k',
      name: 'Five-Figure Foreman',
      description: 'Earn \$5,000 in shipments',
      category: AchievementCategoryExt.warehouse,
      xpReward: 600,
      coinReward: 200,
      target: 5000,
    ),
    AchievementDef(
      id: 'warehouse_lv_15',
      name: 'Senior Operator',
      description: 'Reach Warehouse Level 15',
      category: AchievementCategoryExt.warehouse,
      xpReward: 4000,
      coinReward: 1200,
    ),

    // 🏭 WAREHOUSE PROGRESSION (extended, 6) — growth-loop bumps
    AchievementDef(
      id: 'zero_damage_dispatch',
      name: 'Zero-Damage Dispatch',
      description: 'Clear all 3 levels of any Local contract without using undo',
      category: AchievementCategoryExt.mastery,
      xpReward: 800,
      coinReward: 250,
    ),
    AchievementDef(
      id: 'waybill_streak',
      name: 'Clean Waybill',
      description: '3-star every level in any Local contract',
      category: AchievementCategoryExt.mastery,
      xpReward: 1000,
      coinReward: 300,
    ),
    AchievementDef(
      id: 'fleet_foreman',
      name: 'Fleet Foreman',
      description: 'Own 4 of the 6 machinery items simultaneously',
      category: AchievementCategoryExt.warehouse,
      xpReward: 1500,
      coinReward: 500,
    ),
    AchievementDef(
      id: 'overtime_payout',
      name: 'Overtime Payout',
      description: 'Earn a single shipment payout at 5× total income multiplier',
      category: AchievementCategoryExt.warehouse,
      xpReward: 2000,
      coinReward: 750,
    ),
    AchievementDef(
      id: 'union_steward',
      name: 'Union Steward',
      description: 'Own 2 forklift skins beyond Yellow Standard AND own Regional',
      category: AchievementCategoryExt.warehouse,
      xpReward: 1200,
      coinReward: 400,
    ),
    AchievementDef(
      id: 'night_shift_supervisor',
      name: 'Night Shift Supervisor 🌙',
      description: 'Clear 10 contracts between midnight and 6 AM',
      category: AchievementCategoryExt.hidden,
      xpReward: 600,
      coinReward: 200,
      target: 10,
      isHidden: true,
    ),

    // District + Reputation milestones (Phase C infinite-scaling
    // architecture, 2026-05-15). Players cross these meta-loop
    // boundaries and the system already celebrates with receipt
    // beats + promotion ceremony — this gives them achievement
    // credit too, so the achievements screen has entries for the
    // new infinite-scaling milestones.
    AchievementDef(
      id: 'first_district_cleared',
      name: 'Dispatch Foreman',
      description: 'Clear all 5 levels of District 1 — Local Dock',
      category: AchievementCategoryExt.warehouse,
      xpReward: 400,
      coinReward: 150,
    ),
    AchievementDef(
      id: 'regional_district_cleared',
      name: 'Regional Operator',
      description: 'Clear a Regional-tier district (D4 Sea Port or later)',
      category: AchievementCategoryExt.warehouse,
      xpReward: 1000,
      coinReward: 400,
    ),
    AchievementDef(
      id: 'procedural_explorer',
      name: 'Procedural Explorer',
      description: 'Clear District 7 — the first procedural district',
      category: AchievementCategoryExt.warehouse,
      xpReward: 2500,
      coinReward: 800,
    ),
    AchievementDef(
      id: 'bronze_promotion',
      name: 'Bronze Tier',
      description: 'Earn 5 Reputation Points and reach Bronze tier',
      category: AchievementCategoryExt.warehouse,
      xpReward: 600,
      coinReward: 200,
    ),
    AchievementDef(
      id: 'silver_promotion',
      name: 'Silver Tier',
      description: 'Reach Silver Reputation tier (15 RP)',
      category: AchievementCategoryExt.warehouse,
      xpReward: 1200,
      coinReward: 400,
    ),
    AchievementDef(
      id: 'gold_promotion',
      name: 'Gold Tier',
      description: 'Reach Gold Reputation tier (30 RP)',
      category: AchievementCategoryExt.warehouse,
      xpReward: 2000,
      coinReward: 700,
    ),
    AchievementDef(
      id: 'platinum_promotion',
      name: 'Platinum Tier',
      description: 'Reach Platinum Reputation tier (50 RP)',
      category: AchievementCategoryExt.warehouse,
      xpReward: 3500,
      coinReward: 1100,
    ),
    AchievementDef(
      id: 'diamond_promotion',
      name: 'Diamond Tier',
      description: 'Reach Diamond Reputation tier (75 RP)',
      category: AchievementCategoryExt.warehouse,
      xpReward: 5500,
      coinReward: 1600,
    ),
    AchievementDef(
      id: 'legendary_promotion',
      name: 'Legendary Tycoon',
      description: 'Reach Legendary Reputation tier (225 RP)',
      category: AchievementCategoryExt.warehouse,
      xpReward: 10000,
      coinReward: 3000,
    ),

    // 🎨 VARIETY (5)
    AchievementDef(
      id: 'color_explorer',
      name: 'Color Explorer',
      description: 'Try all 4 difficulties',
      category: AchievementCategoryExt.variety,
      xpReward: 150,
      coinReward: 60,
    ),
    AchievementDef(
      id: 'difficulty_warrior',
      name: 'Difficulty Warrior',
      description: '10 each difficulty',
      category: AchievementCategoryExt.variety,
      xpReward: 500,
      coinReward: 175,
      target: 40,
    ),
    AchievementDef(
      id: 'jack_of_all',
      name: 'Jack of All Stacks',
      description: '3-star one each difficulty',
      category: AchievementCategoryExt.variety,
      xpReward: 400,
      coinReward: 150,
    ),
    AchievementDef(
      id: 'challenge_accepted',
      name: 'Challenge Accepted',
      description: '10 daily challenges',
      category: AchievementCategoryExt.variety,
      xpReward: 600,
      coinReward: 200,
      target: 10,
    ),
    AchievementDef(
      id: 'challenge_master',
      name: 'Challenge Master',
      description: '50 daily challenges',
      category: AchievementCategoryExt.variety,
      xpReward: 2000,
      coinReward: 600,
      target: 50,
    ),

    // 🎁 HIDDEN (5)
    AchievementDef(
      id: 'midnight_stacker',
      name: 'Midnight Stacker 🌙',
      description: 'Play 12-3AM',
      category: AchievementCategoryExt.hidden,
      xpReward: 125,
      coinReward: 40,
      isHidden: true,
    ),
    AchievementDef(
      id: 'century_score',
      name: 'Century Score',
      description: 'Score exactly 100',
      category: AchievementCategoryExt.hidden,
      xpReward: 200,
      coinReward: 80,
      isHidden: true,
    ),
    AchievementDef(
      id: 'lucky_seven',
      name: 'Lucky Seven',
      description: 'Complete in exactly 7 moves',
      category: AchievementCategoryExt.hidden,
      xpReward: 300,
      coinReward: 100,
      isHidden: true,
    ),
    AchievementDef(
      id: 'zen_moment',
      name: 'Zen Moment',
      description: 'Pause 60s mid-puzzle then complete',
      category: AchievementCategoryExt.hidden,
      xpReward: 150,
      coinReward: 60,
      isHidden: true,
    ),
    AchievementDef(
      id: 'backwards_brain',
      name: 'Backwards Brain',
      description: 'Retry and improve 3×',
      category: AchievementCategoryExt.hidden,
      xpReward: 250,
      coinReward: 80,
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
  // LEGACY SUPPORT METHODS
  // ============================================================================

  /// Check if an achievement is unlocked (legacy support)
  bool isUnlocked(String achievementId) {
    final state = _states[achievementId];
    if (state != null) return state.unlocked;
    
    // Fallback to old prefs format
    try {
      return _prefs?.getBool('achievement_$achievementId') ?? false;
    } catch (e) {
      debugPrint('AchievementService isUnlocked failed: $e');
      return false;
    }
  }

  /// Unlock an achievement (legacy support, returns true if newly unlocked)
  Future<bool> unlock(Achievement achievement) async {
    if (isUnlocked(achievement.id)) return false;
    
    try {
      await _prefs?.setBool('achievement_${achievement.id}', true);
      await _prefs?.setString(
        'achievement_${achievement.id}_date',
        DateTime.now().toIso8601String(),
      );
      
      // Add to pending toasts
      _pendingToasts.add(achievement.unlock());
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AchievementService unlock failed: $e');
      return false;
    }
  }

  /// Check and unlock star-based achievements (legacy support)
  Future<void> checkStarAchievements() async {
    // This is kept for backward compatibility
    // The new system handles this via checkPuzzleComplete
  }

  /// Check and unlock chain reaction achievements (legacy support)
  Future<void> checkChainAchievements(int chainLevel, int maxChainEver) async {
    // This is kept for backward compatibility
    // Chain achievements will be implemented in the new system if needed
  }

  // ============================================================================
  // NEW CHECK METHODS
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
      newlyUnlocked.addAll(_tryUnlock(['quick_dispatch']));
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

  List<AchievementDef> checkDailyStreak({required int days}) {
    final newlyUnlocked = <AchievementDef>[];

    newlyUnlocked.addAll(_setProgressAndCheck('daily_devotee', days));
    newlyUnlocked.addAll(_setProgressAndCheck('monthly_master', days));

    return newlyUnlocked;
  }

  // ============================================================================
  // WAREHOUSE-PROGRESSION CHECKS (extended catalog)
  // ============================================================================

  /// Internal cache for per-contract "no undo across all 3 levels" tracking.
  /// `Map<contractIndex, Set<levelNumber>>` — populated by
  /// [checkContractLevelClear]; cleared on undo via [resetContractUndoTrack].
  final Map<int, Set<int>> _noUndoLevelsPerContract = {};

  /// Call when a contract level finishes. Tracks per-contract undo state
  /// for [zero_damage_dispatch] and 3-star state for [waybill_streak].
  ///
  /// - [contractIndex] — see [ContractService.contracts]
  /// - [levelInContract] — the absolute level number (1..30)
  /// - [contractFirstLevel] / [contractLastLevel] — bounds of the contract
  /// - [stars] — 0..3 stars earned on this clear
  /// - [undoUsed] — whether the player used undo at any point this level
  /// - [allLevelStarsInContract] — best-stars map for every level in the
  ///   contract after this clear; used to detect the 3-star sweep.
  /// - [contractTier] — pass `'local'` if this contract is a Local-tier
  ///   contract; the two new achievements only fire on Local contracts.
  List<AchievementDef> checkContractLevelClear({
    required int contractIndex,
    required int levelInContract,
    required int contractFirstLevel,
    required int contractLastLevel,
    required int stars,
    required bool undoUsed,
    required Map<int, int> allLevelStarsInContract,
    required String contractTier,
  }) {
    final newlyUnlocked = <AchievementDef>[];
    final isLocal = contractTier.toLowerCase() == 'local';

    // ---- zero_damage_dispatch: track no-undo levels per contract --------
    if (undoUsed) {
      _noUndoLevelsPerContract.remove(contractIndex);
    } else {
      final set = _noUndoLevelsPerContract.putIfAbsent(
        contractIndex,
        () => <int>{},
      );
      set.add(levelInContract);

      // Local contracts in this codebase are 3-level groups when the
      // spec is interpreted as "all 3 levels"; we also tolerate 5-level
      // contracts by treating the contract as "all levels in the
      // contract span". Either way: every level in [first..last] must be
      // present in the set with undoUsed==false.
      if (isLocal) {
        final fullSpan = <int>{
          for (var l = contractFirstLevel; l <= contractLastLevel; l++) l,
        };
        if (set.containsAll(fullSpan)) {
          newlyUnlocked.addAll(_tryUnlock(['zero_damage_dispatch']));
        }
      }
    }

    // ---- waybill_streak: 3-star every level in any Local contract -------
    if (isLocal) {
      var allThreeStar = true;
      for (var l = contractFirstLevel; l <= contractLastLevel; l++) {
        if ((allLevelStarsInContract[l] ?? 0) < 3) {
          allThreeStar = false;
          break;
        }
      }
      if (allThreeStar) {
        newlyUnlocked.addAll(_tryUnlock(['waybill_streak']));
      }
    }

    return newlyUnlocked;
  }

  /// Optional helper — clears the per-contract no-undo tracking for one
  /// contract. The UI can call this on explicit "undo" action so a single
  /// undo invalidates the streak even before the level finishes.
  void resetContractUndoTrack(int contractIndex) {
    _noUndoLevelsPerContract.remove(contractIndex);
  }

  /// Call when a contract is fully cleared (every level ≥1 star). Counts
  /// toward [night_shift_supervisor] only when the device-local hour is
  /// in `[0, 6)`. The unlock fires at 10 such night-shift clears. Pass
  /// `nowOverride` from tests; defaults to `DateTime.now()`.
  List<AchievementDef> checkContractCleared({DateTime? nowOverride}) {
    final newlyUnlocked = <AchievementDef>[];
    final hour = (nowOverride ?? DateTime.now()).hour;
    if (hour >= 0 && hour < 6) {
      newlyUnlocked.addAll(_incrementAndCheck('night_shift_supervisor'));
    }
    return newlyUnlocked;
  }

  /// Call after every [MachineryService.purchase]. Fires
  /// [fleet_foreman] when the player owns ≥4 of the 6 machinery items.
  List<AchievementDef> checkMachineryOwnership({required int ownedCount}) {
    final newlyUnlocked = <AchievementDef>[];
    if (ownedCount >= 4) {
      newlyUnlocked.addAll(_tryUnlock(['fleet_foreman']));
    }
    return newlyUnlocked;
  }

  /// Call after shipment-reward payout. Fires [overtime_payout] when the
  /// total income multiplier applied to the shipment is ≥5.0×.
  List<AchievementDef> checkPayoutMultiplier({required double multiplier}) {
    final newlyUnlocked = <AchievementDef>[];
    if (multiplier >= 5.0) {
      newlyUnlocked.addAll(_tryUnlock(['overtime_payout']));
    }
    return newlyUnlocked;
  }

  /// Call after [CosmeticService.purchase] OR [BusinessTierService.purchase].
  /// Fires [union_steward] when the player owns ≥2 forklift skins beyond
  /// Yellow Standard AND owns the Regional business tier.
  ///
  /// - [forkliftSkinsOwnedBeyondDefault] — count of owned forklift skins
  ///   excluding `ForkliftSkin.yellowStandard`
  /// - [ownsRegionalTier] — true if Regional Hub has been purchased
  List<AchievementDef> checkUnionSteward({
    required int forkliftSkinsOwnedBeyondDefault,
    required bool ownsRegionalTier,
  }) {
    final newlyUnlocked = <AchievementDef>[];
    if (forkliftSkinsOwnedBeyondDefault >= 2 && ownsRegionalTier) {
      newlyUnlocked.addAll(_tryUnlock(['union_steward']));
    }
    return newlyUnlocked;
  }

  /// Call after a District has been cleared (i.e. the FINAL level of
  /// the district was completed with stars on every level inside).
  /// Fires up to three district-milestone achievements depending on
  /// which district number just cleared:
  ///
  /// - `first_district_cleared` — when D1 clears
  /// - `regional_district_cleared` — when any D4-D6 clears (regional
  ///   tier hand-tuned)
  /// - `procedural_explorer` — when D7 (first procedural district)
  ///   clears
  ///
  /// [districtNumber] is the 1-indexed district that just cleared.
  List<AchievementDef> checkDistrictMilestones({
    required int districtNumber,
  }) {
    final newlyUnlocked = <AchievementDef>[];
    if (districtNumber == 1) {
      newlyUnlocked.addAll(_tryUnlock(['first_district_cleared']));
    }
    if (districtNumber >= 4 && districtNumber <= 6) {
      newlyUnlocked.addAll(_tryUnlock(['regional_district_cleared']));
    }
    if (districtNumber == 7) {
      newlyUnlocked.addAll(_tryUnlock(['procedural_explorer']));
    }
    return newlyUnlocked;
  }

  /// Call after `ReputationService.addReputation` returns true (a
  /// tier promotion fired). Fires the appropriate tier-milestone
  /// achievements based on the new tier level. Idempotent — re-firing
  /// at the same tier is a no-op.
  ///
  /// Tier coverage:
  /// - tier 1 (Bronze, 5 RP) → `bronze_promotion`
  /// - tier 2 (Silver, 15 RP) → `silver_promotion`
  /// - tier 3 (Gold, 30 RP) → `gold_promotion`
  /// - tier 4 (Platinum, 50 RP) → `platinum_promotion`
  /// - tier 5 (Diamond, 75 RP) → `diamond_promotion`
  /// - tier 9 (Legendary, 225 RP) → `legendary_promotion`
  ///
  /// Atomic at multi-tier jumps: if the player crosses several tiers
  /// in one award (e.g. starts at 0 RP and earns 30 RP all at once,
  /// crossing Bronze + Silver + Gold), all three achievements unlock
  /// in the same call. `_tryUnlock` filters out previously-unlocked
  /// entries so re-runs are safe.
  ///
  /// Intermediate Master (tier 6) + Apex (tier 7) + Mythic (tier 8)
  /// + post-Legendary tiers are tracked implicitly by the player's
  /// `currentTierLevel`. Diamond → Legendary is the longest gap
  /// (75 → 225 RP, ~150 district clears) and matches the difficulty
  /// jump the player feels in the meta-loop.
  List<AchievementDef> checkReputationTier({
    required int newTierLevel,
  }) {
    final newlyUnlocked = <AchievementDef>[];
    if (newTierLevel >= 1) {
      newlyUnlocked.addAll(_tryUnlock(['bronze_promotion']));
    }
    if (newTierLevel >= 2) {
      newlyUnlocked.addAll(_tryUnlock(['silver_promotion']));
    }
    if (newTierLevel >= 3) {
      newlyUnlocked.addAll(_tryUnlock(['gold_promotion']));
    }
    if (newTierLevel >= 4) {
      newlyUnlocked.addAll(_tryUnlock(['platinum_promotion']));
    }
    if (newTierLevel >= 5) {
      newlyUnlocked.addAll(_tryUnlock(['diamond_promotion']));
    }
    if (newTierLevel >= 9) {
      newlyUnlocked.addAll(_tryUnlock(['legendary_promotion']));
    }
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

    // Queue a toast for AchievementToastMixin to display. AchievementDef
    // (services-side) is bridged into the legacy Achievement (models-side)
    // shape so the existing toast widget renders it without changes.
    _pendingToasts.add(
      Achievement(
        id: def.id,
        title: def.name,
        description: def.description,
        ppReward: def.xpReward,
        rarity: AchievementRarity.common,
        category: AchievementCategory.gameplay,
        isUnlocked: true,
        unlockedAt: now,
      ),
    );

    // Growth-loop: certain achievement IDs grant a permanent +0.25×
    // income bump. Fire-and-forget — the multiplier service is itself
    // idempotent and persists across launches.
    unawaited(IncomeMultiplierService().recordAchievementBump(id));

    notifyListeners();
  }

  void _updateProgress(String id, int progress) {
    _states[id] = _states[id]!.copyWith(progress: progress);
    _prefs?.setInt('achievement_${id}_progress', progress);
    notifyListeners();
  }
}

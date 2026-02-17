import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import 'storage_service.dart';

/// Service for managing achievements
class AchievementService extends ChangeNotifier {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  SharedPreferences? _prefs;
  final List<Achievement> _pendingToasts = [];

  /// Achievements waiting to be shown as toasts
  List<Achievement> get pendingToasts => List.unmodifiable(_pendingToasts);

  /// Clear a pending toast after it's been displayed
  void dismissToast(Achievement achievement) {
    _pendingToasts.remove(achievement);
    notifyListeners();
  }

  /// Initialize the achievement service
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('AchievementService init failed: $e');
    }
  }

  /// Check if an achievement is unlocked
  bool isUnlocked(String achievementId) {
    try {
      return _prefs?.getBool('achievement_$achievementId') ?? false;
    } catch (e) {
      debugPrint('AchievementService isUnlocked failed: $e');
      return false;
    }
  }

  /// Unlock an achievement (returns true if newly unlocked)
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

  /// Check and unlock star-based achievements
  Future<void> checkStarAchievements() async {
    final storage = StorageService();
    final totalStars = storage.getTotalStars();
    final threeStarCount = storage.getThreeStarCount();

    // Rising Star — Earn your first 3-star rating
    if (threeStarCount >= 1) {
      await unlock(StarAchievements.risingStar);
    }

    // Star Collector — Earn 50 total stars
    if (totalStars >= 50) {
      await unlock(StarAchievements.starCollector);
    }

    // Perfectionist — Get 3 stars on 25 levels
    if (threeStarCount >= 25) {
      await unlock(StarAchievements.perfectionist);
    }

    // Star Master — Get 3 stars on 100 levels
    if (threeStarCount >= 100) {
      await unlock(StarAchievements.starMaster);
    }
  }

  /// Check and unlock chain reaction achievements
  Future<void> checkChainAchievements(int chainLevel, int maxChainEver) async {
    // Chain Reaction — Trigger your first chain (2+)
    if (chainLevel >= 2) {
      await unlock(ChainAchievements.chainReaction);
    }

    // Chain Master — Trigger a 3x chain
    if (chainLevel >= 3) {
      await unlock(ChainAchievements.chainMaster);
    }

    // Chain God — Trigger a 4x chain
    if (chainLevel >= 4) {
      await unlock(ChainAchievements.chainGod);
    }

    // Accidental Genius — Trigger a 5x chain
    if (chainLevel >= 5) {
      await unlock(ChainAchievements.accidentalGenius);
    }
  }
}

/// Star-based achievement definitions
class StarAchievements {
  static const Achievement risingStar = Achievement(
    id: 'rising_star',
    title: 'Rising Star',
    description: 'Earn your first 3-star rating',
    ppReward: 10,
    rarity: AchievementRarity.common,
    category: AchievementCategory.mastery,
  );

  static const Achievement starCollector = Achievement(
    id: 'star_collector',
    title: 'Star Collector',
    description: 'Earn 50 total stars',
    ppReward: 25,
    rarity: AchievementRarity.rare,
    category: AchievementCategory.collection,
  );

  static const Achievement perfectionist = Achievement(
    id: 'perfectionist',
    title: 'Perfectionist',
    description: 'Get 3 stars on 25 levels',
    ppReward: 50,
    rarity: AchievementRarity.epic,
    category: AchievementCategory.mastery,
  );

  static const Achievement starMaster = Achievement(
    id: 'star_master',
    title: 'Star Master',
    description: 'Get 3 stars on 100 levels',
    ppReward: 100,
    rarity: AchievementRarity.legendary,
    category: AchievementCategory.mastery,
  );

  static const List<Achievement> all = [
    risingStar,
    starCollector,
    perfectionist,
    starMaster,
  ];
}

/// Chain reaction achievement definitions
class ChainAchievements {
  static const Achievement chainReaction = Achievement(
    id: 'chain_reaction',
    title: 'Chain Reaction',
    description: 'Trigger your first chain (2+ stacks at once)',
    ppReward: 15,
    rarity: AchievementRarity.common,
    category: AchievementCategory.gameplay,
    customIcon: 'link',
  );

  static const Achievement chainMaster = Achievement(
    id: 'chain_master',
    title: 'Chain Master',
    description: 'Trigger a 3x chain',
    ppReward: 30,
    rarity: AchievementRarity.rare,
    category: AchievementCategory.mastery,
    customIcon: 'bolt',
  );

  static const Achievement chainGod = Achievement(
    id: 'chain_god',
    title: 'Chain God',
    description: 'Trigger a 4x chain',
    ppReward: 75,
    rarity: AchievementRarity.epic,
    category: AchievementCategory.mastery,
    customIcon: 'flash_on',
  );

  static const Achievement accidentalGenius = Achievement(
    id: 'accidental_genius',
    title: 'Accidental Genius',
    description: 'Trigger a 5x chain',
    ppReward: 150,
    rarity: AchievementRarity.legendary,
    category: AchievementCategory.special,
    customIcon: 'auto_awesome',
  );

  static const List<Achievement> all = [
    chainReaction,
    chainMaster,
    chainGod,
    accidentalGenius,
  ];
}

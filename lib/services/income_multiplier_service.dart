import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'business_tier_service.dart';
import 'contract_service.dart';
import 'machinery_service.dart';
import '../data/local_regional_levels.dart';

/// Aggregates *permanent* income multipliers earned across the game's
/// progression systems. Plugged into shipment rewards so every milestone
/// the player crosses raises the floor on all future earnings — the
/// "accretive growth" loop:
///
///   - +0.10× per contract cleared (lifetime)        — capped at +1.50×
///   - +0.50× per business tier purchased            — Local default 0
///   - +0.25× per "income bump" achievement unlocked — tracked here
///   - +0.05× per Warehouse Level past L5            — capped at +2.00×
///   - + machinery `incomeBonus` sum                 — capped at +2.50×
///
/// Final multiplier = 1.0 + sum of all bonuses. So a player who has cleared
/// 5 contracts, owns Regional, has 4 income-bump achievements, is at
/// WH Lv 25, and bought every machine sits at:
///   1.0 + (5 × 0.10) + (1 × 0.50) + (4 × 0.25) + (20 × 0.05) + 2.50
///   = 1.0 + 0.50 + 0.50 + 1.00 + 1.00 + 2.50 = 6.5× base earnings
///
/// Combined with the per-tier multiplier (×1.0 Local / ×1.5 Regional) and
/// the per-level star multiplier (×1/×1.5/×2), a 3★ clear in Regional with
/// every system maxed earns ≈20× the base cash a fresh-install Local clear
/// gets. That's the "income increases over time, contracts get better" feel.
class IncomeMultiplierService extends ChangeNotifier {
  static final IncomeMultiplierService _instance = IncomeMultiplierService._();
  factory IncomeMultiplierService() => _instance;
  IncomeMultiplierService._();

  static const String _kAchievementBumpsKey = 'wh_income_achievement_bumps_v1';

  static const double perContractClearBonus = 0.10;
  static const double maxContractBonus = 1.50; // = 15 contracts
  static const double perTierPurchaseBonus = 0.50;
  static const double perAchievementBumpBonus = 0.25;
  static const double perWarehouseLevelBonus = 0.05;
  static const int warehouseLevelBonusStartsAt = 5;
  static const double maxWarehouseLevelBonus = 2.00; // = WH Lv 45
  static const double maxMachineryBonus = 2.50; // = all 6 machines owned

  /// Achievement IDs that grant a permanent income bump.
  /// Curated set: tied to milestones the player feels proud about.
  static const Set<String> incomeBumpAchievementIds = {
    'local_tycoon', // Clear all 3 Local contracts
    'regional_unlocked', // Unlock Regional Hub tier
    'forklift_collector', // Buy first cosmetic forklift
    'cash_milestone_5k', // Earn $5,000 in shipments
    'warehouse_lv_15', // Reach Warehouse Level 15
    'first_shipment', // Ship first sorted bay
    'centurion', // Clear 100 puzzles (legacy carried over)
  };

  final Set<String> _unlockedBumps = {};
  bool _initialized = false;

  bool get isInitialized => _initialized;
  Set<String> get unlockedBumps => Set.unmodifiable(_unlockedBumps);

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kAchievementBumpsKey);
    if (raw != null) _unlockedBumps.addAll(raw);
    _initialized = true;
    notifyListeners();
  }

  /// Record that the player just unlocked an income-bump achievement.
  /// Idempotent — second call for the same ID is a no-op.
  Future<bool> recordAchievementBump(String achievementId) async {
    if (!incomeBumpAchievementIds.contains(achievementId)) return false;
    if (_unlockedBumps.contains(achievementId)) return false;
    _unlockedBumps.add(achievementId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kAchievementBumpsKey, _unlockedBumps.toList());
    notifyListeners();
    return true;
  }

  /// Compute the current multiplier given the player's state across
  /// ContractService + BusinessTierService + WarehouseEconomyService.
  /// Doesn't take WarehouseEconomyService directly to avoid a circular
  /// dependency — callers pass in the warehouseLevel.
  double computeMultiplier({required int warehouseLevel}) {
    final contractsCleared = ContractService.contracts
        .where((c) => ContractService().isContractCleared(c))
        .length;
    final contractBonus =
        (contractsCleared * perContractClearBonus).clamp(0.0, maxContractBonus);

    final tiersOwned = BusinessTierService().ownedTiers.length;
    // Local is owned by default → bonus only kicks in for purchased tiers.
    final tierBonus = (tiersOwned - 1).clamp(0, BusinessTier.values.length) *
        perTierPurchaseBonus;

    final achievementBonus =
        _unlockedBumps.length * perAchievementBumpBonus;

    final levelsPastStart =
        (warehouseLevel - warehouseLevelBonusStartsAt).clamp(0, 999);
    final levelBonus =
        (levelsPastStart * perWarehouseLevelBonus).clamp(0.0, maxWarehouseLevelBonus);

    final machineryBonus =
        MachineryService().totalIncomeBonus.clamp(0.0, maxMachineryBonus);

    return 1.0 +
        contractBonus +
        tierBonus +
        achievementBonus +
        levelBonus +
        machineryBonus;
  }

  /// Human-readable breakdown of the current multiplier — useful for
  /// the UI to show "Why am I at ×3.2?".
  List<({String label, double bonus})> breakdown({
    required int warehouseLevel,
  }) {
    final contractsCleared = ContractService.contracts
        .where((c) => ContractService().isContractCleared(c))
        .length;
    final tiersOwned = (BusinessTierService().ownedTiers.length - 1)
        .clamp(0, BusinessTier.values.length);
    final levelsPastStart =
        (warehouseLevel - warehouseLevelBonusStartsAt).clamp(0, 999);
    final machineryOwnedCount = MachineryService().owned.length;
    return [
      (label: 'Base', bonus: 1.0),
      (
        label: '$contractsCleared contracts cleared',
        bonus: (contractsCleared * perContractClearBonus)
            .clamp(0.0, maxContractBonus),
      ),
      (
        label: '$tiersOwned tier purchases',
        bonus: tiersOwned * perTierPurchaseBonus,
      ),
      (
        label: '${_unlockedBumps.length} achievement bumps',
        bonus: _unlockedBumps.length * perAchievementBumpBonus,
      ),
      (
        label: '$levelsPastStart WH levels past Lv5',
        bonus:
            (levelsPastStart * perWarehouseLevelBonus).clamp(0.0, maxWarehouseLevelBonus),
      ),
      (
        label: '$machineryOwnedCount machinery owned',
        bonus: MachineryService().totalIncomeBonus.clamp(0.0, maxMachineryBonus),
      ),
    ];
  }

  /// Reset for testing / future Prestige.
  Future<void> reset() async {
    _unlockedBumps.clear();
    _initialized = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAchievementBumpsKey);
    notifyListeners();
  }
}

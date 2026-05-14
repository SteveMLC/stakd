import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-shipment reward (one bay completion), immutable value class.
@immutable
class ShipmentReward {
  final int cash;
  final int xp;
  const ShipmentReward({required this.cash, required this.xp});

  ShipmentReward operator +(ShipmentReward other) =>
      ShipmentReward(cash: cash + other.cash, xp: xp + other.xp);

  @override
  String toString() => 'ShipmentReward(cash: $cash, xp: $xp)';
}

/// Computes shipment + contract rewards using the v0.3 design economy.
///
/// Pure static functions — no state, easy to unit-test.
class ShipmentRewardCalculator {
  ShipmentRewardCalculator._();

  static const int baseCashPerStandard = 10;
  static const int baseXpPerStandard = 5;
  static const int baseCashPerFrozen = 25;
  static const int baseXpPerFrozen = 12;

  /// Reward for clearing a single bay.
  static ShipmentReward forBay({
    required int standardCount,
    required int frozenCount,
    double comboMultiplier = 1.0,
    double businessTierMultiplier = 1.0,
    bool isDailyContract = false,
  }) {
    final cash =
        standardCount * baseCashPerStandard + frozenCount * baseCashPerFrozen;
    final xp =
        standardCount * baseXpPerStandard + frozenCount * baseXpPerFrozen;

    final multiplier = comboMultiplier *
        businessTierMultiplier *
        (isDailyContract ? 3.0 : 1.0);

    return ShipmentReward(
      cash: (cash * multiplier).floor(),
      xp: (xp * multiplier).floor(),
    );
  }

  /// Star bonus applied at level end. 1★ = ×1.0, 2★ = ×1.5, 3★ = ×2.0.
  static double starMultiplier(int stars) {
    switch (stars) {
      case 3:
        return 2.0;
      case 2:
        return 1.5;
      default:
        return 1.0;
    }
  }

  /// Combo multiplier: +10% per consecutive same-color, capped at +50%.
  static double comboMultiplier(int consecutiveSameColor) {
    final bumps = consecutiveSameColor.clamp(0, 5);
    return 1.0 + (bumps * 0.10);
  }

  /// Contract completion bonus: +50% of cumulative levels' base earnings.
  static int contractCompletionBonus(int cumulativeBaseCash) =>
      (cumulativeBaseCash * 0.5).floor();
}

/// Owns the warehouse economy: Cash, XP, and the derived Warehouse Level.
///
/// XP curve from v0.3 §4: `XP_needed(L→L+1) = floor(100 * L^1.4)`.
/// Level 1 = 0 XP; cumulative sum determines current level.
class WarehouseEconomyService extends ChangeNotifier {
  static final WarehouseEconomyService _instance =
      WarehouseEconomyService._internal();
  factory WarehouseEconomyService() => _instance;
  WarehouseEconomyService._internal();

  static const String _kCashKey = 'wh_economy_cash_v1';
  static const String _kXpKey = 'wh_economy_total_xp_v1';
  static const String _kWelcomeGrantKey = 'wh_economy_welcome_grant_v1';

  /// One-time grant for fresh installs so the HUD doesn't open with $0.
  static const int welcomeCashGrant = 200;

  int _cash = 0;
  int _totalXp = 0;
  bool _initialized = false;

  int get cash => _cash;
  int get totalXp => _totalXp;
  bool get isInitialized => _initialized;

  /// Current Warehouse Level computed from total XP.
  int get warehouseLevel => _computeLevel(_totalXp);

  /// XP earned within the current level (0 to xpNeededForCurrentLevel).
  int get xpInCurrentLevel => _totalXp - _cumulativeXpForLevel(warehouseLevel);

  /// XP required to advance from current level to the next.
  int get xpNeededForCurrentLevel => _xpForLevelTransition(warehouseLevel);

  /// XP remaining to next level.
  int get xpToNextLevel =>
      _cumulativeXpForLevel(warehouseLevel + 1) - _totalXp;

  /// Progress fraction 0..1 within the current level.
  double get levelProgressFraction {
    final start = _cumulativeXpForLevel(warehouseLevel);
    final end = _cumulativeXpForLevel(warehouseLevel + 1);
    if (end == start) return 0.0;
    return ((_totalXp - start) / (end - start)).clamp(0.0, 1.0);
  }

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _cash = prefs.getInt(_kCashKey) ?? 0;
    _totalXp = prefs.getInt(_kXpKey) ?? 0;

    // First-launch welcome grant — once per install.
    if (!(prefs.getBool(_kWelcomeGrantKey) ?? false)) {
      _cash += welcomeCashGrant;
      await prefs.setInt(_kCashKey, _cash);
      await prefs.setBool(_kWelcomeGrantKey, true);
    }

    _initialized = true;
    notifyListeners();
  }

  /// Add cash + XP from a shipment or contract. Returns the new Warehouse
  /// Level IF the player leveled up, otherwise null.
  Future<int?> awardReward(ShipmentReward reward) async {
    final levelBefore = warehouseLevel;
    _cash += reward.cash;
    _totalXp += reward.xp;
    await _persist();
    notifyListeners();
    final levelAfter = warehouseLevel;
    return levelAfter > levelBefore ? levelAfter : null;
  }

  /// Spend cash on a purchase (tier unlock, cosmetic, jam-skip, etc.).
  /// Returns true on success, false if insufficient cash.
  Future<bool> trySpend(int amount) async {
    if (amount < 0) throw ArgumentError.value(amount, 'amount', 'must be ≥ 0');
    if (amount > _cash) return false;
    _cash -= amount;
    await _persist();
    notifyListeners();
    return true;
  }

  /// Add cash directly (for tutorial grants, ad rewards, IAP, etc.).
  Future<void> grantCash(int amount) async {
    if (amount < 0) throw ArgumentError.value(amount, 'amount', 'must be ≥ 0');
    _cash += amount;
    await _persist();
    notifyListeners();
  }

  /// Reset to L1 / 0 cash / 0 XP. Reserved for testing + future Prestige.
  Future<void> reset() async {
    _cash = 0;
    _totalXp = 0;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCashKey, _cash);
    await prefs.setInt(_kXpKey, _totalXp);
  }

  // ---------------------------------------------------------------------------
  // Static level math (no state — exposed for tests and UI previews).
  // ---------------------------------------------------------------------------

  /// XP required to advance from `level` to `level + 1`.
  static int _xpForLevelTransition(int level) =>
      (100 * pow(level.toDouble(), 1.4)).floor();

  /// Cumulative XP required to be AT `level` (level 1 = 0).
  static int _cumulativeXpForLevel(int level) {
    if (level <= 1) return 0;
    var total = 0;
    for (var L = 1; L < level; L++) {
      total += _xpForLevelTransition(L);
    }
    return total;
  }

  /// Compute Warehouse Level given total XP. Capped at 999 for safety.
  static int _computeLevel(int totalXp) {
    if (totalXp <= 0) return 1;
    var level = 1;
    var cumulative = 0;
    while (level < 999) {
      final next = cumulative + _xpForLevelTransition(level);
      if (next > totalXp) break;
      cumulative = next;
      level++;
    }
    return level;
  }

  /// Public API for tests + UI: how much XP for level N → level N+1?
  static int xpForLevel(int level) => _xpForLevelTransition(level);

  /// Public API for tests: cumulative XP at level N.
  static int cumulativeXpForLevel(int level) => _cumulativeXpForLevel(level);
}

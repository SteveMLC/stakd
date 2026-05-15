import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_regional_levels.dart';
import 'warehouse_economy_service.dart';

/// Immutable metadata for a business tier.
@immutable
class BusinessTierInfo {
  final BusinessTier tier;
  final String displayName;
  final String shortName;
  final String tagline;
  final int cashCost;
  final int minWarehouseLevel;
  final double earningsMultiplier;

  const BusinessTierInfo({
    required this.tier,
    required this.displayName,
    required this.shortName,
    required this.tagline,
    required this.cashCost,
    required this.minWarehouseLevel,
    required this.earningsMultiplier,
  });
}

/// Result of attempting to purchase a tier.
enum PurchaseResult {
  success,
  alreadyOwned,
  warehouseLevelTooLow,
  insufficientCash,
}

/// Owns: which business tiers the player has unlocked, which one is currently
/// selected for play. Coordinates cash deduction with WarehouseEconomyService.
///
/// v1.0 ships Local + Regional. National/International/Global ship in v1.1+
/// (see warehouse-sort-decisions-2026-05-13.md §8.1).
class BusinessTierService extends ChangeNotifier {
  static final BusinessTierService _instance = BusinessTierService._internal();
  factory BusinessTierService() => _instance;
  BusinessTierService._internal();

  static const String _kOwnedKey = 'wh_tier_owned_v1';
  static const String _kSelectedKey = 'wh_tier_selected_v1';

  /// All tiers the v1.0 catalog knows about. Order matters for UI.
  static const List<BusinessTierInfo> catalog = [
    BusinessTierInfo(
      tier: BusinessTier.local,
      displayName: 'Local Warehouse',
      shortName: 'Local',
      tagline: 'Where every empire starts.',
      cashCost: 0,
      minWarehouseLevel: 1,
      earningsMultiplier: 1.0,
    ),
    BusinessTierInfo(
      tier: BusinessTier.regional,
      displayName: 'Regional Hub',
      shortName: 'Regional',
      tagline: 'Bigger trucks. Faster turns.',
      // Lowered $5,000 → $3,000 (2026-05-14 balance patch). The prior
      // cost gated casual players at L15 hard — audit Player A walk
      // showed them stalled at ~$2,166 cash against a $5K wall with
      // no path forward except replay grind. $3K lands ~1-2 clears
      // past their natural WH Lv 10 unlock so Regional reads as a
      // goal they're approaching, not a wall they hit.
      cashCost: 3000,
      minWarehouseLevel: 10,
      earningsMultiplier: 1.5,
    ),
  ];

  Set<BusinessTier> _owned = {BusinessTier.local};
  BusinessTier _selected = BusinessTier.local;
  bool _initialized = false;

  Set<BusinessTier> get ownedTiers => Set.unmodifiable(_owned);
  BusinessTier get selectedTier => _selected;
  BusinessTierInfo get selectedTierInfo => infoFor(_selected);
  bool get isInitialized => _initialized;

  /// True if the player owns this tier (Local is always owned).
  bool isOwned(BusinessTier tier) => _owned.contains(tier);

  BusinessTierInfo infoFor(BusinessTier tier) =>
      catalog.firstWhere((c) => c.tier == tier);

  double multiplierFor(BusinessTier tier) => infoFor(tier).earningsMultiplier;

  /// Current selected-tier multiplier (cheaper convenience accessor).
  double get currentMultiplier => multiplierFor(_selected);

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();

    final ownedNames = prefs.getStringList(_kOwnedKey);
    if (ownedNames != null && ownedNames.isNotEmpty) {
      _owned = ownedNames
          .map(_tierFromName)
          .whereType<BusinessTier>()
          .toSet();
    }
    // Local is always owned by default.
    _owned.add(BusinessTier.local);

    final selectedName = prefs.getString(_kSelectedKey);
    final maybeSelected = selectedName == null ? null : _tierFromName(selectedName);
    _selected = (maybeSelected != null && _owned.contains(maybeSelected))
        ? maybeSelected
        : BusinessTier.local;

    _initialized = true;
    notifyListeners();
  }

  /// Check whether a tier could be purchased right now. Returns a
  /// `PurchaseResult` describing the outcome — `success` means it's ready,
  /// but doesn't actually buy it. Pass `currentCash` from the economy service.
  PurchaseResult checkPurchase(BusinessTier tier, int currentCash, int warehouseLevel) {
    if (_owned.contains(tier)) return PurchaseResult.alreadyOwned;
    final info = infoFor(tier);
    if (warehouseLevel < info.minWarehouseLevel) {
      return PurchaseResult.warehouseLevelTooLow;
    }
    if (currentCash < info.cashCost) return PurchaseResult.insufficientCash;
    return PurchaseResult.success;
  }

  /// Attempt to purchase a tier. Deducts cash via the economy service and
  /// adds the tier to owned set. Selects it if successful.
  Future<PurchaseResult> purchase(BusinessTier tier) async {
    final economy = WarehouseEconomyService();
    final info = infoFor(tier);

    final precheck = checkPurchase(tier, economy.cash, economy.warehouseLevel);
    if (precheck != PurchaseResult.success) return precheck;

    final spent = await economy.trySpend(info.cashCost);
    if (!spent) return PurchaseResult.insufficientCash;

    _owned.add(tier);
    _selected = tier;
    await _persist();
    notifyListeners();
    return PurchaseResult.success;
  }

  /// Switch the active tier. Player must already own it.
  Future<bool> selectTier(BusinessTier tier) async {
    if (!_owned.contains(tier)) return false;
    if (_selected == tier) return true;
    _selected = tier;
    await _persist();
    notifyListeners();
    return true;
  }

  /// Find the next tier the player can unlock (if any). Returns null when all
  /// tiers in the catalog are owned.
  BusinessTierInfo? get nextLockedTier {
    for (final info in catalog) {
      if (!_owned.contains(info.tier)) return info;
    }
    return null;
  }

  /// Reset for testing / future Prestige (keeps Local owned).
  Future<void> reset() async {
    _owned = {BusinessTier.local};
    _selected = BusinessTier.local;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kOwnedKey,
      _owned.map((t) => t.name).toList(growable: false),
    );
    await prefs.setString(_kSelectedKey, _selected.name);
  }

  static BusinessTier? _tierFromName(String name) {
    for (final t in BusinessTier.values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

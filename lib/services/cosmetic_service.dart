import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'warehouse_economy_service.dart';

/// The four v1.0 forklift cosmetic skins. Yellow Standard is the free default;
/// the other three are cash-gated unlocks behind a Warehouse Level threshold.
enum ForkliftSkin { yellowStandard, redSport, blueHeavy, goldPremium }

/// Immutable metadata for a forklift skin.
@immutable
class ForkliftSkinInfo {
  final ForkliftSkin skin;
  final String displayName;
  final String description;
  final int cashCost;
  final int minWarehouseLevel;
  final String assetIconKey;

  const ForkliftSkinInfo({
    required this.skin,
    required this.displayName,
    required this.description,
    required this.cashCost,
    required this.minWarehouseLevel,
    required this.assetIconKey,
  });
}

/// Result of attempting to purchase a forklift skin.
enum CosmeticPurchaseResult {
  success,
  alreadyOwned,
  warehouseLevelTooLow,
  insufficientCash,
}

/// Owns: which forklift skins the player has unlocked, which one is currently
/// equipped. Coordinates cash deduction with WarehouseEconomyService.
///
/// v1.0 ships one cosmetic slot (Forklift) with 1 free + 3 cash skins,
/// $7,000 total cash sink. Additional slots (signage, uniforms, exterior,
/// music) ship in v1.1+ (see warehouse-sort-design-v0.3-2026-05-13.md §6).
class CosmeticService extends ChangeNotifier {
  static final CosmeticService _instance = CosmeticService._internal();
  factory CosmeticService() => _instance;
  CosmeticService._internal();

  static const String _kOwnedKey = 'wh_cosmetic_owned_forklifts_v1';
  static const String _kSelectedKey = 'wh_cosmetic_selected_forklift_v1';

  /// All forklift skins the v1.0 catalog knows about. Order matters for UI.
  static const List<ForkliftSkinInfo> catalog = [
    ForkliftSkinInfo(
      skin: ForkliftSkin.yellowStandard,
      displayName: 'Yellow Standard',
      description: 'The classic dock workhorse.',
      cashCost: 0,
      minWarehouseLevel: 1,
      assetIconKey: 'forklift_yellow',
    ),
    // Cosmetic restagger (2026-05-14 balance patch). All three skins
    // previously unlocked at WH Lv 15 — a single hype moment wasting
    // the goal-density potential of three distinct cosmetics. Now
    // staggered Red @ 8 / Blue @ 15 / Gold @ 25 so the player sees
    // a fresh forklift hit the shop roughly every 7 warehouse levels
    // through the early-to-mid game.
    ForkliftSkinInfo(
      skin: ForkliftSkin.redSport,
      displayName: 'Red Sport',
      description: 'Faster turns. Sharper looks.',
      cashCost: 500,
      minWarehouseLevel: 8,
      assetIconKey: 'forklift_red',
    ),
    ForkliftSkinInfo(
      skin: ForkliftSkin.blueHeavy,
      displayName: 'Blue Heavy',
      description: 'Built to carry the bigger orders.',
      cashCost: 1500,
      minWarehouseLevel: 15,
      assetIconKey: 'forklift_blue',
    ),
    ForkliftSkinInfo(
      skin: ForkliftSkin.goldPremium,
      displayName: 'Gold Premium',
      description: 'Pure flex. Maximum payout aura.',
      cashCost: 5000,
      minWarehouseLevel: 25,
      assetIconKey: 'forklift_gold',
    ),
  ];

  Set<ForkliftSkin> _ownedForklifts = {ForkliftSkin.yellowStandard};
  ForkliftSkin _selectedForklift = ForkliftSkin.yellowStandard;
  bool _initialized = false;

  Set<ForkliftSkin> get ownedForklifts => Set.unmodifiable(_ownedForklifts);
  ForkliftSkin get selectedForklift => _selectedForklift;
  ForkliftSkinInfo get selectedForkliftInfo => infoFor(_selectedForklift);
  bool get isInitialized => _initialized;

  /// True if the player owns this skin (Yellow Standard is always owned).
  bool isOwned(ForkliftSkin skin) => _ownedForklifts.contains(skin);

  ForkliftSkinInfo infoFor(ForkliftSkin skin) =>
      catalog.firstWhere((c) => c.skin == skin);

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();

    final ownedNames = prefs.getStringList(_kOwnedKey);
    if (ownedNames != null && ownedNames.isNotEmpty) {
      _ownedForklifts = ownedNames
          .map(_skinFromName)
          .whereType<ForkliftSkin>()
          .toSet();
    }
    // Yellow Standard is always owned by default.
    _ownedForklifts.add(ForkliftSkin.yellowStandard);

    final selectedName = prefs.getString(_kSelectedKey);
    final maybeSelected =
        selectedName == null ? null : _skinFromName(selectedName);
    _selectedForklift =
        (maybeSelected != null && _ownedForklifts.contains(maybeSelected))
            ? maybeSelected
            : ForkliftSkin.yellowStandard;

    _initialized = true;
    notifyListeners();
  }

  /// Check whether a skin could be purchased right now. `success` means it's
  /// ready, but doesn't actually buy it. Pass current cash + level.
  CosmeticPurchaseResult checkPurchase(
    ForkliftSkin skin,
    int currentCash,
    int warehouseLevel,
  ) {
    if (_ownedForklifts.contains(skin)) {
      return CosmeticPurchaseResult.alreadyOwned;
    }
    final info = infoFor(skin);
    if (warehouseLevel < info.minWarehouseLevel) {
      return CosmeticPurchaseResult.warehouseLevelTooLow;
    }
    if (currentCash < info.cashCost) {
      return CosmeticPurchaseResult.insufficientCash;
    }
    return CosmeticPurchaseResult.success;
  }

  /// Attempt to purchase a skin. Deducts cash via the economy service and
  /// adds the skin to owned set. Selects it if successful.
  Future<CosmeticPurchaseResult> purchase(ForkliftSkin skin) async {
    final economy = WarehouseEconomyService();
    final info = infoFor(skin);

    final precheck =
        checkPurchase(skin, economy.cash, economy.warehouseLevel);
    if (precheck != CosmeticPurchaseResult.success) return precheck;

    final spent = await economy.trySpend(info.cashCost);
    if (!spent) return CosmeticPurchaseResult.insufficientCash;

    _ownedForklifts.add(skin);
    _selectedForklift = skin;
    await _persist();
    notifyListeners();
    return CosmeticPurchaseResult.success;
  }

  /// Switch the equipped forklift skin. Player must already own it.
  Future<bool> selectForklift(ForkliftSkin skin) async {
    if (!_ownedForklifts.contains(skin)) return false;
    if (_selectedForklift == skin) return true;
    _selectedForklift = skin;
    await _persist();
    notifyListeners();
    return true;
  }

  /// Reset for testing / future Prestige (keeps Yellow Standard owned).
  Future<void> reset() async {
    _ownedForklifts = {ForkliftSkin.yellowStandard};
    _selectedForklift = ForkliftSkin.yellowStandard;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kOwnedKey,
      _ownedForklifts.map((s) => s.name).toList(growable: false),
    );
    await prefs.setString(_kSelectedKey, _selectedForklift.name);
  }

  static ForkliftSkin? _skinFromName(String name) {
    for (final s in ForkliftSkin.values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

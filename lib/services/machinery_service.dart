import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'warehouse_economy_service.dart';

/// Permanent warehouse equipment unlocks. Unlike forklifts (single equip
/// slot, cosmetic), each machine is owned forever once bought and stacks
/// its `incomeBonus` onto the global income multiplier. This is the
/// fifth growth source plugged into IncomeMultiplierService — the
/// "machinery opens new doors" leg of the accretive loop.
enum Machinery {
  palletJack,
  conveyorBelt,
  hydraulicLift,
  loadingDock,
  sortingRobot,
  droneFleet,
}

@immutable
class MachineryInfo {
  final Machinery id;
  final String displayName;
  final String description;
  final int cashCost;
  final int minWarehouseLevel;
  final double incomeBonus;
  final IconData icon;
  final Color accent;

  const MachineryInfo({
    required this.id,
    required this.displayName,
    required this.description,
    required this.cashCost,
    required this.minWarehouseLevel,
    required this.incomeBonus,
    required this.icon,
    required this.accent,
  });
}

enum MachineryPurchaseResult {
  success,
  alreadyOwned,
  warehouseLevelTooLow,
  insufficientCash,
}

/// Owns: which machinery the player has unlocked. Total income bonus
/// = sum of `incomeBonus` across all owned items. Caps implicit in
/// catalog design (6 items, +2.50× total at max).
class MachineryService extends ChangeNotifier {
  static final MachineryService _instance = MachineryService._internal();
  factory MachineryService() => _instance;
  MachineryService._internal();

  static const String _kOwnedKey = 'wh_machinery_owned_v1';

  /// v1.0 machinery catalog. Order = unlock order; each gate roughly
  /// matches the cash + WH-level the player has at that point in the
  /// L1-50 procedural curve.
  static const List<MachineryInfo> catalog = [
    MachineryInfo(
      id: Machinery.palletJack,
      displayName: 'Pallet Jack',
      description: 'Speeds up your dock crew. Every shipment earns 10% more.',
      cashCost: 300,
      minWarehouseLevel: 3,
      incomeBonus: 0.10,
      icon: Icons.shopping_basket_outlined,
      accent: Color(0xFF8BC34A),
    ),
    MachineryInfo(
      id: Machinery.conveyorBelt,
      displayName: 'Conveyor Belt',
      description: 'Auto-routes the easy crates. +20% income on every clear.',
      cashCost: 1500,
      minWarehouseLevel: 8,
      incomeBonus: 0.20,
      icon: Icons.conveyor_belt,
      accent: Color(0xFF03A9F4),
    ),
    MachineryInfo(
      id: Machinery.hydraulicLift,
      displayName: 'Hydraulic Lift',
      description: 'Doubles your stack height. +30% on every payout.',
      cashCost: 5000,
      minWarehouseLevel: 15,
      incomeBonus: 0.30,
      icon: Icons.elevator,
      accent: Color(0xFFFFC107),
    ),
    MachineryInfo(
      id: Machinery.loadingDock,
      displayName: 'Loading Dock Expansion',
      description: 'Opens a second receiving lane. +40% income on every shipment.',
      cashCost: 20000,
      minWarehouseLevel: 22,
      incomeBonus: 0.40,
      icon: Icons.warehouse,
      accent: Color(0xFFFF9800),
    ),
    MachineryInfo(
      id: Machinery.sortingRobot,
      displayName: 'Sorting Robot',
      description: 'The robot never sleeps. +50% income forever.',
      cashCost: 75000,
      minWarehouseLevel: 30,
      incomeBonus: 0.50,
      icon: Icons.precision_manufacturing,
      accent: Color(0xFFE91E63),
    ),
    MachineryInfo(
      id: Machinery.droneFleet,
      displayName: 'Autonomous Drone Fleet',
      description: 'Eyes on every shipment, every minute. +100% income.',
      cashCost: 250000,
      minWarehouseLevel: 40,
      incomeBonus: 1.00,
      icon: Icons.flight_takeoff,
      accent: Color(0xFF9C27B0),
    ),
  ];

  Set<Machinery> _owned = {};
  bool _initialized = false;

  Set<Machinery> get owned => Set.unmodifiable(_owned);
  bool get isInitialized => _initialized;

  bool isOwned(Machinery id) => _owned.contains(id);

  MachineryInfo infoFor(Machinery id) =>
      catalog.firstWhere((m) => m.id == id);

  /// Total income bonus contributed by owned machinery. Plugs into
  /// IncomeMultiplierService.computeMultiplier as one more bonus source.
  double get totalIncomeBonus {
    double sum = 0.0;
    for (final m in _owned) {
      sum += infoFor(m).incomeBonus;
    }
    return sum;
  }

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList(_kOwnedKey);
    if (names != null) {
      _owned = names.map(_fromName).whereType<Machinery>().toSet();
    }
    _initialized = true;
    notifyListeners();
  }

  /// Check whether a machine could be purchased right now. `success`
  /// means it's ready, but doesn't actually buy it.
  MachineryPurchaseResult checkPurchase(
    Machinery id,
    int currentCash,
    int warehouseLevel,
  ) {
    if (_owned.contains(id)) return MachineryPurchaseResult.alreadyOwned;
    final info = infoFor(id);
    if (warehouseLevel < info.minWarehouseLevel) {
      return MachineryPurchaseResult.warehouseLevelTooLow;
    }
    if (currentCash < info.cashCost) {
      return MachineryPurchaseResult.insufficientCash;
    }
    return MachineryPurchaseResult.success;
  }

  /// Attempt to buy a machine. Deducts cash and persists ownership.
  Future<MachineryPurchaseResult> purchase(Machinery id) async {
    final economy = WarehouseEconomyService();
    final info = infoFor(id);

    final precheck =
        checkPurchase(id, economy.cash, economy.warehouseLevel);
    if (precheck != MachineryPurchaseResult.success) return precheck;

    final spent = await economy.trySpend(info.cashCost);
    if (!spent) return MachineryPurchaseResult.insufficientCash;

    _owned.add(id);
    await _persist();
    notifyListeners();
    return MachineryPurchaseResult.success;
  }

  /// Reset for testing / future Prestige.
  Future<void> reset() async {
    _owned.clear();
    _initialized = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOwnedKey);
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kOwnedKey,
      _owned.map((m) => m.name).toList(growable: false),
    );
  }

  static Machinery? _fromName(String name) {
    for (final m in Machinery.values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

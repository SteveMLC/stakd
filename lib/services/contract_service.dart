import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_regional_levels.dart';

/// Immutable definition of a contract: a 5-level chain in one tier.
@immutable
class ContractDefinition {
  final int contractIndex;
  final String displayName;
  final String tagline;
  final BusinessTier tier;
  final int firstLevel;
  final int lastLevel;

  const ContractDefinition({
    required this.contractIndex,
    required this.displayName,
    required this.tagline,
    required this.tier,
    required this.firstLevel,
    required this.lastLevel,
  });

  int get totalLevels => lastLevel - firstLevel + 1;
  bool containsLevel(int level) => level >= firstLevel && level <= lastLevel;
}

/// Returned when a contract is completed (5/5 levels cleared).
@immutable
class ContractCompletion {
  final ContractDefinition contract;
  final int totalStars; // 5 levels × up to 3 stars = max 15
  final int cashBonus; // contract completion bonus

  const ContractCompletion({
    required this.contract,
    required this.totalStars,
    required this.cashBonus,
  });
}

/// Owns the contract-chain meta progression. Maps levels 1–30 to 6 contracts
/// (Local 1–3 + Regional 1–3). Tracks stars-per-level + which contracts are
/// completed, persists across launches.
class ContractService extends ChangeNotifier {
  static final ContractService _instance = ContractService._internal();
  factory ContractService() => _instance;
  ContractService._internal();

  static const String _kStarsKey = 'wh_contract_stars_v1';
  static const String _kCompletedKey = 'wh_contract_completed_v1';

  /// v1.0 catalog: 3 Local + 3 Regional contracts.
  static const List<ContractDefinition> contracts = [
    ContractDefinition(
      contractIndex: 0,
      displayName: 'Local Contract 1',
      tagline: 'Friendly faces, easy crates.',
      tier: BusinessTier.local,
      firstLevel: 1,
      lastLevel: 5,
    ),
    ContractDefinition(
      contractIndex: 1,
      displayName: 'Local Contract 2',
      tagline: 'Bigger trucks roll in.',
      tier: BusinessTier.local,
      firstLevel: 6,
      lastLevel: 10,
    ),
    ContractDefinition(
      contractIndex: 2,
      displayName: 'Local Contract 3',
      tagline: 'Frozen shipments arrive — thaw fast.',
      tier: BusinessTier.local,
      firstLevel: 11,
      lastLevel: 15,
    ),
    ContractDefinition(
      contractIndex: 3,
      displayName: 'Regional Contract 1',
      tagline: 'Five colors on the dock at once.',
      tier: BusinessTier.regional,
      firstLevel: 16,
      lastLevel: 20,
    ),
    ContractDefinition(
      contractIndex: 4,
      displayName: 'Regional Contract 2',
      tagline: 'More bays. Bigger payout.',
      tier: BusinessTier.regional,
      firstLevel: 21,
      lastLevel: 25,
    ),
    ContractDefinition(
      contractIndex: 5,
      displayName: 'Regional Contract 3',
      tagline: 'Six colors. Tight bays. Run it.',
      tier: BusinessTier.regional,
      firstLevel: 26,
      lastLevel: 30,
    ),
  ];

  final Map<int, int> _starsPerLevel = {}; // level (1..30) -> stars (0..3)
  final Set<int> _completedContractIndices = {};
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();

    final starsStrings = prefs.getStringList(_kStarsKey);
    if (starsStrings != null) {
      for (final pair in starsStrings) {
        final parts = pair.split(':');
        if (parts.length != 2) continue;
        final level = int.tryParse(parts[0]);
        final stars = int.tryParse(parts[1]);
        if (level != null && stars != null) {
          _starsPerLevel[level] = stars;
        }
      }
    }

    final completed = prefs.getStringList(_kCompletedKey);
    if (completed != null) {
      for (final s in completed) {
        final idx = int.tryParse(s);
        if (idx != null) _completedContractIndices.add(idx);
      }
    }

    _initialized = true;
    notifyListeners();
  }

  /// Find the contract that owns this level. Returns null past L30
  /// (procedural-generation territory).
  ContractDefinition? contractForLevel(int level) {
    for (final c in contracts) {
      if (c.containsLevel(level)) return c;
    }
    return null;
  }

  /// Best stars ever earned for `level` (0 if never cleared).
  int starsForLevel(int level) => _starsPerLevel[level] ?? 0;

  /// Total stars earned across the contract (sum of best stars per level).
  int totalStarsForContract(ContractDefinition c) {
    var total = 0;
    for (var l = c.firstLevel; l <= c.lastLevel; l++) {
      total += starsForLevel(l);
    }
    return total;
  }

  /// True if every level in the contract has at least 1 star.
  bool isContractCleared(ContractDefinition c) {
    for (var l = c.firstLevel; l <= c.lastLevel; l++) {
      if (starsForLevel(l) < 1) return false;
    }
    return true;
  }

  /// True if the player can play this contract right now. The first contract
  /// (index 0) is always unlocked; subsequent contracts require the previous
  /// one to be cleared.
  bool isContractUnlocked(ContractDefinition c) {
    if (c.contractIndex == 0) return true;
    final prev = contracts[c.contractIndex - 1];
    return isContractCleared(prev);
  }

  bool isContractCompleted(ContractDefinition c) =>
      _completedContractIndices.contains(c.contractIndex);

  /// Next level the player should play. Walks through contracts in order,
  /// returning the first level with 0 stars (or 1 past the last-cleared).
  /// Defaults to level 1 if no progress.
  int get nextSuggestedLevel {
    for (final c in contracts) {
      if (!isContractUnlocked(c)) return c.firstLevel;
      for (var l = c.firstLevel; l <= c.lastLevel; l++) {
        if (starsForLevel(l) < 1) return l;
      }
    }
    return contracts.last.lastLevel + 1; // proceed into procedural territory
  }

  /// Record level completion. Returns a `ContractCompletion` event if this
  /// just finished a contract for the first time (so callers can fire a
  /// celebration + bonus payout). Returns null otherwise.
  ///
  /// `cashBonusForContract` is computed via
  /// `ShipmentRewardCalculator.contractCompletionBonus` on the caller side —
  /// the contract service doesn't reach across into the economy service to
  /// keep the boundary clean.
  Future<ContractCompletion?> recordLevelComplete(
    int level,
    int stars, {
    required int cashBonusForContract,
  }) async {
    final clamped = stars.clamp(0, 3);
    final previousBest = starsForLevel(level);
    if (clamped > previousBest) {
      _starsPerLevel[level] = clamped;
      await _persistStars();
    }

    final contract = contractForLevel(level);
    if (contract == null) return null;

    // Check if all 5 levels in the contract now have ≥1 star.
    if (!isContractCleared(contract)) return null;

    // Already-marked contracts don't fire again.
    if (_completedContractIndices.contains(contract.contractIndex)) return null;

    _completedContractIndices.add(contract.contractIndex);
    await _persistCompleted();
    notifyListeners();

    return ContractCompletion(
      contract: contract,
      totalStars: totalStarsForContract(contract),
      cashBonus: cashBonusForContract,
    );
  }

  /// Reset all contract progress. Reserved for testing + future Prestige.
  Future<void> reset() async {
    _starsPerLevel.clear();
    _completedContractIndices.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStarsKey);
    await prefs.remove(_kCompletedKey);
    notifyListeners();
  }

  Future<void> _persistStars() async {
    final prefs = await SharedPreferences.getInstance();
    final entries =
        _starsPerLevel.entries.map((e) => '${e.key}:${e.value}').toList();
    await prefs.setStringList(_kStarsKey, entries);
  }

  Future<void> _persistCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kCompletedKey,
      _completedContractIndices.map((i) => i.toString()).toList(),
    );
  }
}

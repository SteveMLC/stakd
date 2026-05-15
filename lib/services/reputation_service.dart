import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reputation tiers — the named ladder for the first 9 tiers. Past
/// tier 9 (Legendary) the tier name becomes formulaic ("Legendary II",
/// "Legendary III", ...) so the ladder can climb forever without
/// running out of names. Players who reach tier 100+ are deep into
/// endgame; the name is decoration, the multiplier is what matters.
enum ReputationTier {
  none,        // Pre-Bronze, fresh install
  bronze,      // Tier 1, RP 5
  silver,      // Tier 2, RP 15
  gold,        // Tier 3, RP 30
  platinum,    // Tier 4, RP 50
  diamond,     // Tier 5, RP 75
  master,      // Tier 6, RP 105
  apex,        // Tier 7, RP 140
  mythic,      // Tier 8, RP 180
  legendary,   // Tier 9, RP 225
  // Past Legendary the tier is represented by an int via
  // `currentTierLevel` rather than this enum. `displayNameForLevel`
  // handles the naming.
}

/// Reputation is the infinite-scaling meta-currency for Warehouse Sort.
/// It replaces the deferred Prestige system from v0.3 with something
/// that runs forever: every District clear grants +1 RP, every Tier
/// promotion grants +0.10× permanent income multiplier with no upper
/// cap. Numbers stay manageable because each District costs ~10× the
/// prior to unlock, so the meta-economy paces itself naturally.
///
/// Tier thresholds follow an arithmetic progression with delta
/// increasing by 5 each tier:
///
///   Bronze    →  5 RP   (delta 5)
///   Silver    → 15 RP   (delta 10)
///   Gold      → 30 RP   (delta 15)
///   Platinum  → 50 RP   (delta 20)
///   Diamond   → 75 RP   (delta 25)
///   Master    → 105 RP  (delta 30)
///   Apex      → 140 RP  (delta 35)
///   Mythic    → 180 RP  (delta 40)
///   Legendary → 225 RP  (delta 45)
///   Tier N    → 5 × N × (N+1) / 2 RP  (closed form, infinite)
///
/// At tier 100 the threshold is 25,250 RP (~25,000 district clears at
/// +1 RP each). Far enough out that few players hit it; close enough
/// that no one runs out of next-goal.
class ReputationService extends ChangeNotifier {
  static final ReputationService _instance = ReputationService._();
  factory ReputationService() => _instance;
  ReputationService._();

  static const String _kTotalRpKey = 'wh_reputation_total_rp_v1';
  static const double perTierMultiplierBonus = 0.10;

  /// Named tiers 1-9. Index 0 = none (pre-Bronze).
  static const List<ReputationTier> _namedTiers = [
    ReputationTier.none,       // 0
    ReputationTier.bronze,     // 1
    ReputationTier.silver,     // 2
    ReputationTier.gold,       // 3
    ReputationTier.platinum,   // 4
    ReputationTier.diamond,    // 5
    ReputationTier.master,     // 6
    ReputationTier.apex,       // 7
    ReputationTier.mythic,     // 8
    ReputationTier.legendary,  // 9
  ];

  int _totalRp = 0;
  bool _initialized = false;

  int get totalRp => _totalRp;
  bool get isInitialized => _initialized;

  /// Compute the tier *level* (integer, 0-based for none, climbs to
  /// infinity) given the player's total RP. Solves the quadratic
  /// inverse of `thresholdForTier(N) = 5N(N+1)/2` to find the largest
  /// N where the threshold ≤ totalRp.
  ///
  /// `5N(N+1)/2 ≤ rp`  →  `N² + N - 2rp/5 ≤ 0`
  /// `N = floor((-1 + sqrt(1 + 8rp/5)) / 2)`
  int get currentTierLevel {
    if (_totalRp < 5) return 0; // Pre-Bronze
    final discriminant = 1 + (8 * _totalRp / 5);
    final n = ((-1 + _sqrt(discriminant)) / 2).floor();
    return n;
  }

  /// Newton-Raphson sqrt — `dart:math` import would be the
  /// straightforward path, but keeping zero-import services makes
  /// them easier to inline in test harnesses. Converges in <10
  /// iterations for any RP we'd realistically hit.
  double _sqrt(double x) {
    if (x <= 0) return 0;
    var guess = x / 2;
    for (var i = 0; i < 20; i++) {
      final next = (guess + x / guess) / 2;
      if ((next - guess).abs() < 1e-9) return next;
      guess = next;
    }
    return guess;
  }

  /// Current tier enum (named for 1-9, `ReputationTier.legendary` for
  /// 10+ since the enum doesn't extend). Use `displayName` for the
  /// player-facing tier name including the post-Legendary suffix.
  ReputationTier get currentTier {
    final level = currentTierLevel;
    if (level >= _namedTiers.length) return ReputationTier.legendary;
    return _namedTiers[level];
  }

  /// Player-facing tier name. Includes the post-Legendary cycle number
  /// for tiers 10+, e.g. "Legendary II", "Legendary III", ...
  String get displayName => displayNameForLevel(currentTierLevel);

  static String displayNameForLevel(int level) {
    if (level <= 0) return 'Unranked';
    if (level < _namedTiers.length) {
      return _tierName(_namedTiers[level]);
    }
    // Past Legendary: append a Roman-numeral-style cycle indicator.
    // Tier 10 = "Legendary II", tier 11 = "Legendary III", etc.
    final cycle = level - 8; // 10 → 2, 11 → 3, ...
    return 'Legendary ${_toRoman(cycle)}';
  }

  static String _tierName(ReputationTier tier) {
    switch (tier) {
      case ReputationTier.none:      return 'Unranked';
      case ReputationTier.bronze:    return 'Bronze';
      case ReputationTier.silver:    return 'Silver';
      case ReputationTier.gold:      return 'Gold';
      case ReputationTier.platinum:  return 'Platinum';
      case ReputationTier.diamond:   return 'Diamond';
      case ReputationTier.master:    return 'Master';
      case ReputationTier.apex:      return 'Apex';
      case ReputationTier.mythic:    return 'Mythic';
      case ReputationTier.legendary: return 'Legendary';
    }
  }

  /// Tiny Roman numeral converter for the post-Legendary cycle suffix.
  /// Handles 1-3999 which is more than enough — tier 4000 would
  /// require ~32M RP (impossible without serious idle automation).
  static String _toRoman(int n) {
    if (n <= 0) return '';
    if (n >= 4000) return n.toString(); // Past Roman range, fall back
    const numerals = [
      [1000, 'M'], [900, 'CM'], [500, 'D'], [400, 'CD'],
      [100, 'C'],  [90, 'XC'],  [50, 'L'],  [40, 'XL'],
      [10, 'X'],   [9, 'IX'],   [5, 'V'],   [4, 'IV'], [1, 'I'],
    ];
    final buf = StringBuffer();
    var remaining = n;
    for (final pair in numerals) {
      final value = pair[0] as int;
      final symbol = pair[1] as String;
      while (remaining >= value) {
        buf.write(symbol);
        remaining -= value;
      }
    }
    return buf.toString();
  }

  /// RP threshold needed to reach tier N (1-indexed). Uses the closed
  /// form `5 × N × (N+1) / 2`.
  static int thresholdForTier(int tierLevel) {
    if (tierLevel <= 0) return 0;
    return 5 * tierLevel * (tierLevel + 1) ~/ 2;
  }

  /// RP threshold for the player's NEXT tier promotion.
  int get rpForNextTier => thresholdForTier(currentTierLevel + 1);

  /// RP remaining until the next tier promotion. 0 if pre-Bronze and
  /// at exactly 0 RP (would otherwise read as "need 5 more").
  int get rpToNextTier {
    final target = rpForNextTier;
    final remaining = target - _totalRp;
    return remaining < 0 ? 0 : remaining;
  }

  /// Fraction of progress toward the next tier (0.0 → 1.0). Useful
  /// for the tier-progress bar in the HUD / promotion overlay.
  double get progressToNextTier {
    final prevThreshold = thresholdForTier(currentTierLevel);
    final nextThreshold = rpForNextTier;
    final range = nextThreshold - prevThreshold;
    if (range <= 0) return 1.0;
    final progress = (_totalRp - prevThreshold) / range;
    return progress.clamp(0.0, 1.0);
  }

  /// Permanent income multiplier bonus from Reputation tier. Each
  /// promotion grants +0.10× and stacks linearly forever — by tier 10
  /// the player has +1.00×, by tier 50 they have +5.00×, etc. This
  /// is the meta-currency that paces with infinite District scaling.
  double get tierMultiplierBonus =>
      currentTierLevel * perTierMultiplierBonus;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _totalRp = prefs.getInt(_kTotalRpKey) ?? 0;
    _initialized = true;
    notifyListeners();
  }

  /// Record an RP award (typically from clearing a District). Returns
  /// `true` if this award caused a tier promotion (caller should fire
  /// the promotion ceremony overlay).
  Future<bool> addReputation(int amount) async {
    if (amount <= 0) return false;
    final previousTier = currentTierLevel;
    _totalRp += amount;
    final newTier = currentTierLevel;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTotalRpKey, _totalRp);

    notifyListeners();
    return newTier > previousTier;
  }

  /// Reset RP to zero — testing + Prestige (future Phase D, if we
  /// add a "deep reset" loop that exchanges current RP for a higher
  /// permanent multiplier).
  Future<void> reset() async {
    _totalRp = 0;
    _initialized = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTotalRpKey);
    notifyListeners();
  }

  /// Convenience for the HUD reputation pill: a single-line
  /// description like "Bronze · 3/15". Returns "Unranked · 0/5" for
  /// fresh installs.
  String get hudLabel {
    if (currentTierLevel == 0) {
      return 'Unranked · $_totalRp/${thresholdForTier(1)}';
    }
    return '$displayName · $_totalRp/$rpForNextTier';
  }
}

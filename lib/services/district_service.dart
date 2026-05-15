import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Immutable definition of a District — the infinite-scaling
/// progression unit for Warehouse Sort. Each District is a 5-level
/// block with its own visual theme and gameplay wrinkle. D1-D6 map
/// onto the hand-tuned contract catalog; D7+ are procedurally composed
/// (theme + wrinkle from rotation pools, exponential cost curve).
@immutable
class DistrictDefinition {
  /// 1-indexed. D1 is the starter district (Local Dock).
  final int number;

  /// Player-facing name. Hand-tuned for D1-D6; "Industrial District N"
  /// or similar for procedural districts.
  final String displayName;

  /// One-line flavor.
  final String tagline;

  /// Theme palette + background pack key. Resolved by the renderer
  /// against a theme catalog (`lib/utils/district_themes.dart`, future).
  final String themeId;

  /// Gameplay wrinkles introduced in this district. Empty for D1-D2;
  /// 'frozen' from D3; 1 wrinkle per district through D9; mix-and-
  /// match (1-2 per district) past D9.
  final List<String> wrinkles;

  /// First level number in this district (inclusive). D1 starts at L1.
  final int firstLevel;

  /// Last level number in this district (inclusive). 5-level blocks.
  final int lastLevel;

  /// Cash cost to unlock. D1 is free (always unlocked). D2-D6 inherit
  /// the prior balance (gating is by clearing the previous district,
  /// not cash). D7+ have an exponential cash cost in addition to the
  /// "clear previous" gate.
  ///
  /// Stored as `double` to handle the infinite-scaling curve past D19
  /// (where int overflows at 9.22e18). The wider cash economy is
  /// still int-based today; conversion to double-cash is a separate
  /// refactor. For now, callers compare `currentCash.toDouble() >=
  /// unlockCost` and deduct via `.toInt()` once it lands in cash
  /// service.
  final double unlockCost;

  /// Reputation Points awarded on clearing the final level of this
  /// district. Hand-tuned D1-D6 give 1 RP; procedural D7+ scale up
  /// with district number to keep the RP rate climbing as districts
  /// take longer to clear.
  final int rpReward;

  /// True for D1-D6 (hand-tuned catalog with curated themes/wrinkles).
  /// False for procedural districts past D6.
  final bool isHandTuned;

  const DistrictDefinition({
    required this.number,
    required this.displayName,
    required this.tagline,
    required this.themeId,
    required this.wrinkles,
    required this.firstLevel,
    required this.lastLevel,
    required this.unlockCost,
    required this.rpReward,
    required this.isHandTuned,
  });

  int get totalLevels => lastLevel - firstLevel + 1;
  bool containsLevel(int level) => level >= firstLevel && level <= lastLevel;
}

/// Owns the infinite-scaling District progression. D1-D6 map to the
/// existing 6 contracts (Local 1-3 + Regional 1-3) so this service
/// can ship alongside `ContractService` without breaking the current
/// meta-loop; D7+ are procedurally composed with theme + wrinkle
/// rotation and an exponential cost curve.
///
/// Pacing target: each District costs ~10× the previous to unlock past
/// D6, and the player's income compounds via the Reputation tier
/// ladder (separate service) — so the next district is always ~30 min
/// to an hour of focused play away regardless of how deep you've gone.
class DistrictService extends ChangeNotifier {
  static final DistrictService _instance = DistrictService._internal();
  factory DistrictService() => _instance;
  DistrictService._internal();

  static const String _kClearedKey = 'wh_district_cleared_v1';
  static const String _kUnlockedKey = 'wh_district_unlocked_v1';

  /// First district where the procedural cost curve kicks in. D1-D6
  /// inherit existing balance (D1 free, D2-D3 clear-prev only, D4-D6
  /// gated by Regional tier purchase elsewhere).
  static const int firstProceduralDistrict = 7;

  /// Base cost for D7 (the first procedural district). The curve is
  /// `proceduralBaseCost × 10^(N - firstProceduralDistrict)` so D7 =
  /// $1.5M, D8 = $15M, D9 = $150M, D20 = $1.5e19, D50 = $1.5e49.
  /// Numbers get silly intentionally — the `formatCash` helper handles
  /// graceful display via K/M/B/T/Qa/Qi/.../Qid suffixes.
  static const double proceduralBaseCost = 1_500_000;

  /// Theme rotation pool for procedural districts. Cycles
  /// deterministically by `(N - firstProceduralDistrict) % pool.length`
  /// so the player never sees the same theme twice in a row but every
  /// theme reappears every ~12 districts.
  static const List<String> proceduralThemePool = [
    'maritime-deep',     // Deep-sea port, dark blue + ship lights
    'air-cargo-night',   // Runway, sodium-amber lighting
    'hazmat-green',      // Yellow + green radiation iconography
    'automated-cyan',    // Robotic warehouse, cyan + black
    'autonomous-violet', // AI dispatch, violet + cool grey
    'orbital-starfield', // Space cargo, midnight blue + stars
    'underground-rust',  // Mine/cavern, sepia + rust
    'arctic-pale',       // Frozen tundra, pale blue + white
    'tropical-jade',     // Sea-port jungle, jade + teak
    'desert-sand',       // Sun-bleached, sand + terracotta
    'megacity-neon',     // Cyberpunk dock, hot pink + electric blue
    'volcanic-ember',    // Industrial forge, ember + obsidian
  ];

  /// Wrinkle introduction cadence for procedural districts. The pool
  /// is consumed one new wrinkle per district through D14 (D7-D14
  /// each introduce a fresh mechanic), then past D14 it mixes 1-2
  /// wrinkles per district picked deterministically by district
  /// number.
  static const List<String> wrinklePool = [
    'frozen',          // 2-clear crates (D3 hand-tuned + D7 procedural reuse)
    'fragile',         // -$ penalty on wrong-color drop
    'priority',        // N-move countdown or fail
    'oversized',       // 2-layer slot crates
    'time-bomb',       // wallclock countdown
    'conveyor-drift',  // auto-shift right every 5s
    'gravity-flip',    // stacks invert mid-level
    'double-color',    // counts toward 2 stacks
  ];

  /// 6 hand-tuned districts mapping to the existing contract catalog.
  /// `unlockCost` mirrors the existing economy: only D7+ have an
  /// explicit cash gate (D2-D6 gate via clearing the prior district
  /// + the existing Regional tier purchase for D4-D6).
  static final List<DistrictDefinition> handTunedCatalog = [
    const DistrictDefinition(
      number: 1,
      displayName: 'Local Dock',
      tagline: 'Where every empire starts.',
      themeId: 'concrete-yellow',
      wrinkles: [],
      firstLevel: 1, lastLevel: 5,
      unlockCost: 0.0,
      rpReward: 1,
      isHandTuned: true,
    ),
    const DistrictDefinition(
      number: 2,
      displayName: 'Local Hub',
      tagline: 'Bigger trucks roll in.',
      themeId: 'steel-amber',
      wrinkles: [],
      firstLevel: 6, lastLevel: 10,
      unlockCost: 0.0,
      rpReward: 1,
      isHandTuned: true,
    ),
    const DistrictDefinition(
      number: 3,
      displayName: 'Cold Storage',
      tagline: 'Frozen shipments arrive — thaw fast.',
      themeId: 'frost-blue',
      wrinkles: ['frozen'],
      firstLevel: 11, lastLevel: 15,
      unlockCost: 0.0,
      rpReward: 1,
      isHandTuned: true,
    ),
    const DistrictDefinition(
      number: 4,
      displayName: 'Regional Sea Port',
      tagline: 'Five colors on the dock at once.',
      themeId: 'maritime-blue',
      wrinkles: [],
      firstLevel: 16, lastLevel: 20,
      unlockCost: 0.0,
      rpReward: 1,
      isHandTuned: true,
    ),
    const DistrictDefinition(
      number: 5,
      displayName: 'Regional Air Cargo',
      tagline: 'More bays. Bigger payout.',
      themeId: 'sky-gradient',
      wrinkles: [],
      firstLevel: 21, lastLevel: 25,
      unlockCost: 0.0,
      rpReward: 1,
      isHandTuned: true,
    ),
    const DistrictDefinition(
      number: 6,
      displayName: 'Regional Heavy Industry',
      tagline: 'Six colors. Tight bays. Run it.',
      themeId: 'industrial-rust',
      wrinkles: [],
      firstLevel: 26, lastLevel: 30,
      unlockCost: 0.0,
      rpReward: 1,
      isHandTuned: true,
    ),
  ];

  /// Total hand-tuned districts (currently 6).
  static int get handTunedCount => handTunedCatalog.length;

  // ---- Persistent state ----

  /// District numbers the player has CLEARED (every level inside the
  /// district has at least 1 star).
  final Set<int> _cleared = {};

  /// District numbers the player has explicitly UNLOCKED (paid the
  /// cash cost for procedural districts, or earned by clearing the
  /// prior district for hand-tuned).
  final Set<int> _unlocked = {1}; // D1 always unlocked

  bool _initialized = false;

  bool get isInitialized => _initialized;
  Set<int> get clearedDistricts => Set.unmodifiable(_cleared);
  Set<int> get unlockedDistricts => Set.unmodifiable(_unlocked);

  // ---- Definition lookup ----

  /// Get the definition for any district number (hand-tuned or
  /// procedural). N must be >= 1.
  DistrictDefinition definitionFor(int number) {
    assert(number >= 1, 'District numbers are 1-indexed');
    if (number <= handTunedCount) {
      return handTunedCatalog[number - 1];
    }
    return _composeProcedural(number);
  }

  /// Compose a procedural district past D6. Deterministic: same N
  /// always produces the same DistrictDefinition (no per-install
  /// randomization). Players see the same Industrial District 7 etc.
  DistrictDefinition _composeProcedural(int number) {
    final stepsPastHandTuned = number - firstProceduralDistrict;
    assert(stepsPastHandTuned >= 0);

    // Theme: deterministic cycle through the pool.
    final themeIdx = stepsPastHandTuned % proceduralThemePool.length;
    final themeId = proceduralThemePool[themeIdx];

    // Wrinkles: through D14 (first 8 procedural districts), introduce
    // one new wrinkle each. Past D14, mix 1-2 wrinkles picked by
    // (number % poolSize) and ((number * 7) % poolSize).
    List<String> wrinkles;
    if (stepsPastHandTuned < wrinklePool.length) {
      wrinkles = [wrinklePool[stepsPastHandTuned]];
    } else {
      final w1 = wrinklePool[number % wrinklePool.length];
      final w2 = wrinklePool[(number * 7) % wrinklePool.length];
      wrinkles = w1 == w2 ? [w1] : [w1, w2];
    }

    // Cost curve: 1.5M × 10^(N-7). Stored as double so D20+ (where
    // int overflows at 9.22e18) compose without clamping.
    final cost = proceduralBaseCost *
        math.pow(10.0, stepsPastHandTuned).toDouble();

    // RP reward scales gently with district number — D7 = 1, D17 = 2,
    // D27 = 3, ... — so the Reputation ladder doesn't stall when
    // districts get longer (in player wall-clock time) to clear.
    final rpReward = 1 + (stepsPastHandTuned ~/ 10);

    // 5-level block continues the existing pattern. D7 = L31-35.
    final firstLevel = (number - 1) * 5 + 1;
    final lastLevel = firstLevel + 4;

    return DistrictDefinition(
      number: number,
      displayName: 'District $number — ${_proceduralName(themeId)}',
      tagline: _proceduralTagline(themeId, wrinkles),
      themeId: themeId,
      wrinkles: wrinkles,
      firstLevel: firstLevel,
      lastLevel: lastLevel,
      unlockCost: cost,
      rpReward: rpReward,
      isHandTuned: false,
    );
  }

  static String _proceduralName(String themeId) {
    // Theme-derived flavor names so procedural districts read as
    // distinct places rather than "District 23".
    const names = {
      'maritime-deep': 'Deep-Water Port',
      'air-cargo-night': 'Night Cargo',
      'hazmat-green': 'Hazmat Yard',
      'automated-cyan': 'Auto-Dock',
      'autonomous-violet': 'Dispatch AI',
      'orbital-starfield': 'Orbital Terminal',
      'underground-rust': 'Underdock',
      'arctic-pale': 'Polar Hub',
      'tropical-jade': 'Equatorial Bay',
      'desert-sand': 'Sandhaul',
      'megacity-neon': 'Neon Dock',
      'volcanic-ember': 'Foundry Yard',
    };
    return names[themeId] ?? 'Procedural';
  }

  static String _proceduralTagline(String themeId, List<String> wrinkles) {
    if (wrinkles.isEmpty) return 'Run the floor. Earn the next district.';
    if (wrinkles.length == 1) {
      return 'Wrinkle: ${wrinkles.first}. Ship anyway.';
    }
    return 'Two wrinkles in play: ${wrinkles.join(' + ')}. Stay sharp.';
  }

  /// District covering a given level. Returns null if level < 1.
  DistrictDefinition? districtForLevel(int level) {
    if (level < 1) return null;
    // 5 levels per district means district = ceil(level / 5).
    final number = ((level - 1) ~/ 5) + 1;
    return definitionFor(number);
  }

  // ---- Lifecycle ----

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final clearedRaw = prefs.getStringList(_kClearedKey);
    if (clearedRaw != null) {
      for (final s in clearedRaw) {
        final n = int.tryParse(s);
        if (n != null) _cleared.add(n);
      }
    }
    final unlockedRaw = prefs.getStringList(_kUnlockedKey);
    if (unlockedRaw != null) {
      for (final s in unlockedRaw) {
        final n = int.tryParse(s);
        if (n != null) _unlocked.add(n);
      }
    }
    // D1 always unlocked.
    _unlocked.add(1);
    _initialized = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _kClearedKey, _cleared.map((n) => n.toString()).toList());
    await prefs.setStringList(
        _kUnlockedKey, _unlocked.map((n) => n.toString()).toList());
  }

  // ---- Query API ----

  bool isUnlocked(int number) => _unlocked.contains(number);
  bool isCleared(int number) => _cleared.contains(number);

  /// The highest district the player has unlocked (always >= 1).
  int get highestUnlocked =>
      _unlocked.isEmpty ? 1 : _unlocked.reduce(math.max);

  /// The highest district the player has cleared (0 if none yet).
  int get highestCleared =>
      _cleared.isEmpty ? 0 : _cleared.reduce(math.max);

  /// Next district to unlock — the one immediately after the highest
  /// unlocked. Always returns a value (the curve is infinite).
  DistrictDefinition get nextToUnlock => definitionFor(highestUnlocked + 1);

  // ---- Unlock + clear flow ----

  /// Whether the player has BOTH cleared the prior district AND has
  /// enough cash to pay any cost. For hand-tuned districts D2-D6 the
  /// cost is 0, so it's purely "clear prior". For procedural D7+ it
  /// requires both.
  bool canUnlock({required int number, required num currentCash}) {
    if (_unlocked.contains(number)) return false;
    if (number <= 1) return false;
    // Must have cleared the prior district.
    if (!_cleared.contains(number - 1)) return false;
    // Cost check (compare in double space; cash is int today, future
    // refactor moves it to double for true infinite scaling).
    final def = definitionFor(number);
    return currentCash.toDouble() >= def.unlockCost;
  }

  /// Mark a district as unlocked. Callers should `canUnlock` first
  /// and handle cash deduction in `WarehouseEconomyService`.
  Future<void> unlock(int number) async {
    if (_unlocked.contains(number)) return;
    _unlocked.add(number);
    await _persist();
    notifyListeners();
  }

  /// Mark a district as cleared. Returns the RP reward to grant
  /// (caller should pass to `ReputationService.addReputation`).
  /// Idempotent — clearing an already-cleared district returns 0.
  Future<int> markCleared(int number) async {
    if (_cleared.contains(number)) return 0;
    _cleared.add(number);
    // Auto-unlock the next district (gating-only side; cash gate is
    // still enforced separately for procedural).
    final next = number + 1;
    if (next <= handTunedCount) {
      _unlocked.add(next);
    }
    await _persist();
    notifyListeners();
    return definitionFor(number).rpReward;
  }

  /// Helper for the level-complete flow: given a level number that
  /// was just cleared with at least 1 star, returns the RP to award
  /// if the level was the LAST in its district AND the district isn't
  /// already cleared. Returns 0 otherwise.
  Future<int> onLevelComplete({
    required int level,
    required bool everyLevelInDistrictHasStar,
  }) async {
    final def = districtForLevel(level);
    if (def == null) return 0;
    if (level != def.lastLevel) return 0;
    if (!everyLevelInDistrictHasStar) return 0;
    return markCleared(def.number);
  }

  // ---- Testing / Reset ----

  Future<void> reset() async {
    _cleared.clear();
    _unlocked.clear();
    _unlocked.add(1);
    _initialized = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kClearedKey);
    await prefs.remove(_kUnlockedKey);
    notifyListeners();
  }
}

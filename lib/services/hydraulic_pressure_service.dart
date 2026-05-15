import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-session skill-expression burst meter — the "Hydraulic Pressure"
/// system. Fills with speed + combo + chain activity and lets the
/// player tap-vent for a 4-move "combo doesn't reset + 2× cash" burst.
///
/// Closes a real design gap: `GameState.getChainBonusMultiplier()`
/// existed but was decorative — chains never accreted into anything
/// that touched the cash formula. The pressure meter is where chains
/// (and tight tempo, and bay completions) finally turn into money.
///
/// State surface (singleton):
/// - `pressure` 0.0..1.0 — fluid level rendered by the gauge
/// - `isVenting` — true during the 4-move (or 8s wall-clock) burst
/// - `ventMovesRemaining` — countdown shown on the gauge during burst
/// - `canVent` — gauge shows VENT button when true (full + not venting)
///
/// Persistence: pressure carries between LEVELS within the same
/// CONTRACT only. Resets on contract change or level fail.
class HydraulicPressureService extends ChangeNotifier {
  static final HydraulicPressureService _instance =
      HydraulicPressureService._();
  factory HydraulicPressureService() => _instance;
  HydraulicPressureService._();

  // ---------------------------------------------------------------
  // Tunables — exposed as constants so tests + UI can reference them
  // without going through the singleton state.
  // ---------------------------------------------------------------
  static const double maxPressure = 1.0;
  static const int ventMovesGranted = 4;
  static const Duration ventDuration = Duration(seconds: 8);

  /// Per-move bonus when the player is moving fast — within 1.5s of
  /// the previous completed move. Rewards "in the groove" tempo.
  static const double speedBonusUnder1_5s = 0.06;

  /// Per-combo-step bonus added when a move landed a matching color.
  /// Stacks with the speed bonus.
  static const double comboStepBonus = 0.04;

  /// Chain bonuses — fired whenever 2+ stacks complete in a single move.
  static const double chainX2Bonus = 0.12;
  static const double chainX3Bonus = 0.20;
  static const double chainX4Bonus = 0.35;

  /// Per-bay-completion bonus. Smaller than chain bonus — bays complete
  /// often, chains are rare.
  static const double bayCompletionBonus = 0.03;

  /// Idle decay — pressure drops by this much per second of idle time
  /// past `idleThreshold`. Pressure can't drain while venting.
  static const double idleDecayPerSec = 0.01;
  static const Duration idleThreshold = Duration(seconds: 2);

  /// Cash multiplier applied while venting. Game-screen cash formula
  /// reads this via `ventCashMultiplier` at level complete.
  static const double ventCashMultiplier = 2.0;

  /// Visual: animations during vent play at 60% duration (≈40% faster).
  static const double ventAnimationSpeedFactor = 0.6;

  static const String _kPrefsKey = 'wh_hydraulic_pressure_v1';

  // ---------------------------------------------------------------
  // Mutable state
  // ---------------------------------------------------------------
  double _pressure = 0.0;
  int _activeVentMovesRemaining = 0;
  DateTime? _ventEndTime;
  DateTime? _lastMoveTime;
  String? _bankedContractId;
  double _bankedPressure = 0.0;
  String? _currentContractId;
  bool _initialized = false;

  // ---------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------
  double get pressure => _pressure;
  bool get isVenting => _activeVentMovesRemaining > 0;
  int get ventMovesRemaining => _activeVentMovesRemaining;
  bool get canVent => _pressure >= maxPressure && !isVenting;
  bool get isInitialized => _initialized;

  /// Load banked pressure from prefs. Called from main.dart's boot
  /// sequence. Idempotent.
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final cid = decoded['contractId'];
          final p = decoded['pressure'];
          if (cid is String && p is num) {
            _bankedContractId = cid;
            _bankedPressure = p.toDouble().clamp(0.0, maxPressure);
          }
        }
      } catch (_) {
        // Corrupt prefs — wipe.
        await prefs.remove(_kPrefsKey);
      }
    }
    _initialized = true;
    notifyListeners();
  }

  /// Called by game_state.dart whenever a move completes. Adds pressure
  /// based on speed (vs. _lastMoveTime), combo step, and bay completion.
  void onMove({
    required DateTime now,
    required int comboStep,
    required bool wasBayCompleted,
  }) {
    if (!isVenting && _pressure < maxPressure) {
      double add = 0.0;
      // Speed bonus — only if the previous move was logged AND came in
      // under 1.5s ago. First move of the level gets no speed bonus.
      final last = _lastMoveTime;
      if (last != null) {
        final dt = now.difference(last);
        if (dt < const Duration(milliseconds: 1500)) {
          add += speedBonusUnder1_5s;
        }
      }
      // Combo bonus — scales with combo depth, capped softly at 5.
      if (comboStep > 0) {
        final clamped = comboStep > 5 ? 5 : comboStep;
        add += clamped * comboStepBonus;
      }
      // Bay completion bonus — additive on top of any combo above.
      if (wasBayCompleted) {
        add += bayCompletionBonus;
      }
      if (add > 0) {
        _pressure = (_pressure + add).clamp(0.0, maxPressure);
      }
    }
    _lastMoveTime = now;

    // If a vent burst is active, count this move against the budget.
    if (isVenting) {
      _activeVentMovesRemaining--;
      if (_activeVentMovesRemaining <= 0) {
        _endVent();
      }
    }
    notifyListeners();
  }

  /// Called by game_state.dart whenever a chain of >=2 stacks completes
  /// from a single move. Adds a flat bonus per chain tier.
  void onChain(int chainLevel) {
    if (isVenting) {
      // Chains during a vent don't pump the meter — vent is already
      // burning excess pressure. Skip silently.
      return;
    }
    double bonus = 0.0;
    if (chainLevel >= 4) {
      bonus = chainX4Bonus;
    } else if (chainLevel == 3) {
      bonus = chainX3Bonus;
    } else if (chainLevel == 2) {
      bonus = chainX2Bonus;
    }
    if (bonus > 0) {
      _pressure = (_pressure + bonus).clamp(0.0, maxPressure);
      notifyListeners();
    }
  }

  /// Called from game_screen.dart when a new level loads. Restores
  /// banked pressure if the level belongs to the same contract;
  /// resets to zero otherwise.
  void onLevelStart(String contractId) {
    _currentContractId = contractId;
    if (_bankedContractId == contractId && _bankedPressure > 0) {
      _pressure = _bankedPressure.clamp(0.0, maxPressure);
    } else {
      _pressure = 0.0;
    }
    _activeVentMovesRemaining = 0;
    _ventEndTime = null;
    _lastMoveTime = null;
    notifyListeners();
  }

  /// Called from game_screen.dart on level complete. If we're not
  /// mid-vent, persist the current pressure so it carries into the
  /// next level of the same contract.
  Future<void> onLevelComplete() async {
    if (isVenting) {
      _endVent();
    }
    final cid = _currentContractId;
    if (cid != null) {
      _bankedContractId = cid;
      _bankedPressure = _pressure;
      await _persistBanked();
    }
    notifyListeners();
  }

  /// Called from game_screen.dart on level fail. Pressure resets to 0.
  Future<void> onLevelFail() async {
    _pressure = 0.0;
    _activeVentMovesRemaining = 0;
    _ventEndTime = null;
    _bankedPressure = 0.0;
    await _persistBanked();
    notifyListeners();
  }

  /// Called from the gauge's animation frame to decay pressure when
  /// the player is idle. Safe to call every tick — internally rate-
  /// limits via `_lastMoveTime`. Also enforces the 8s wallclock
  /// fallback on the vent burst (in case the player taps VENT but
  /// then stops moving entirely).
  void tickIdle(DateTime now) {
    // Wallclock fallback for vent: if the player burned the meter
    // but then stopped moving for the full ventDuration, force-end
    // the burst so cash multiplier doesn't linger forever.
    final ventEnd = _ventEndTime;
    if (isVenting && ventEnd != null && !now.isBefore(ventEnd)) {
      _endVent();
      notifyListeners();
      return;
    }
    if (isVenting) return;
    final last = _lastMoveTime;
    if (last == null) return;
    final idle = now.difference(last);
    if (idle <= idleThreshold) return;
    if (_pressure <= 0) return;
    // Compute the decay delta since the last call. We rebase
    // `_lastMoveTime` forward by the consumed window so the next
    // tick reads only the new idle slice. This makes the call
    // safe at any rate (60Hz or 4Hz).
    final pastThreshold = idle - idleThreshold;
    final seconds = pastThreshold.inMilliseconds / 1000.0;
    final decay = idleDecayPerSec * seconds;
    if (decay <= 0) return;
    _pressure = (_pressure - decay).clamp(0.0, maxPressure);
    _lastMoveTime = now.subtract(idleThreshold);
    notifyListeners();
  }

  /// Player tapped the VENT button. Returns true iff the burst started.
  bool tryActivateVent() {
    if (!canVent) return false;
    _activeVentMovesRemaining = ventMovesGranted;
    _ventEndTime = DateTime.now().add(ventDuration);
    _pressure = 0.0;
    notifyListeners();
    return true;
  }

  /// Optional explicit hook — game_state calls onMove for us, which
  /// already decrements the vent budget. Kept as a public alias so
  /// callers can wire it directly if they prefer.
  void onMoveDuringVent() {
    if (!isVenting) return;
    _activeVentMovesRemaining--;
    if (_activeVentMovesRemaining <= 0) {
      _endVent();
    }
    notifyListeners();
  }

  void _endVent() {
    _activeVentMovesRemaining = 0;
    _ventEndTime = null;
  }

  Future<void> _persistBanked() async {
    final cid = _bankedContractId;
    final prefs = await SharedPreferences.getInstance();
    if (cid == null || _bankedPressure <= 0) {
      await prefs.remove(_kPrefsKey);
      return;
    }
    final payload = jsonEncode({
      'contractId': cid,
      'pressure': _bankedPressure,
    });
    await prefs.setString(_kPrefsKey, payload);
  }

  /// Reset for testing. Wipes both in-memory and persisted state.
  Future<void> reset() async {
    _pressure = 0.0;
    _activeVentMovesRemaining = 0;
    _ventEndTime = null;
    _lastMoveTime = null;
    _bankedContractId = null;
    _bankedPressure = 0.0;
    _currentContractId = null;
    _initialized = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsKey);
    notifyListeners();
  }
}

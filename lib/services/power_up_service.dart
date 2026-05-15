import 'package:flutter/foundation.dart';
import 'storage_service.dart';
import 'currency_service.dart';

/// Power-up types available in the game
enum PowerUpType {
  colorBomb,  // 💣 Removes all blocks of a selected color
  shuffle,    // 🔀 Randomizes blocks into a new solvable configuration
  magnet,     // 🧲 Auto-completes a stack that's 1 block away
  hint,       // 💡 Shows the next optimal move (enhanced)
}

/// Extension for power-up metadata
extension PowerUpTypeExtension on PowerUpType {
  /// LEGACY: emoji glyph kept as fallback string in case any UI surface
  /// (e.g. accessibility tooltip, future text-only contexts) wants a
  /// 1-char representation. Visual buttons should use `iconAsset` below.
  String get icon {
    switch (this) {
      case PowerUpType.colorBomb:
        return '🧨';
      case PowerUpType.shuffle:
        return '🚚';
      case PowerUpType.magnet:
        return '🏗️';
      case PowerUpType.hint:
        return '👷';
    }
  }

  /// Custom illustrated icon — generated locally via FLUX.1-schnell,
  /// rembg'd, and WebP-encoded at `assets/icons_generated/webp/192/`.
  /// Replaces the emoji `icon` getter for all visual surfaces (power-up
  /// bar, info dialogs, achievement art). 192² source covers up to the
  /// 64dp power-up button on 3x retina with headroom.
  String get iconAsset {
    switch (this) {
      case PowerUpType.colorBomb:
        return 'assets/icons_generated/webp/192/dynamite_crate.webp';
      case PowerUpType.shuffle:
        return 'assets/icons_generated/webp/192/reroute_shipment.webp';
      case PowerUpType.magnet:
        return 'assets/icons_generated/webp/192/bay_crane.webp';
      case PowerUpType.hint:
        return 'assets/icons_generated/webp/192/foreman_advice.webp';
    }
  }

  String get name {
    switch (this) {
      case PowerUpType.colorBomb:
        return 'Dynamite Crate';
      case PowerUpType.shuffle:
        return 'Re-Route Shipment';
      case PowerUpType.magnet:
        return 'Bay Crane';
      case PowerUpType.hint:
        return "Foreman's Advice";
    }
  }

  /// Compact label rendered under the icon on the power-up bar so the
  /// player can read what each button does at a glance instead of
  /// memorising four illustrated WebPs. Keep ≤8 chars so the label
  /// fits inside the 64dp button width without ellipsis.
  String get shortLabel {
    switch (this) {
      case PowerUpType.colorBomb:
        return 'BURST';
      case PowerUpType.shuffle:
        return 'RE-ROUTE';
      case PowerUpType.magnet:
        return 'CRANE';
      case PowerUpType.hint:
        return 'HINT';
    }
  }

  String get description {
    switch (this) {
      case PowerUpType.colorBomb:
        return 'Blow up every crate of one color';
      case PowerUpType.shuffle:
        return 'Reroute every loose crate into new bays';
      case PowerUpType.magnet:
        return 'Auto-ship a bay missing one crate';
      case PowerUpType.hint:
        return 'Reveal the next best move';
    }
  }
}

/// Service for managing power-ups
class PowerUpService extends ChangeNotifier {
  static final PowerUpService _instance = PowerUpService._internal();
  factory PowerUpService() => _instance;
  PowerUpService._internal();

  final StorageService _storage = StorageService();

  // Default starting power-ups for new players
  static const Map<PowerUpType, int> _defaultCounts = {
    PowerUpType.colorBomb: 3,
    PowerUpType.shuffle: 3,
    PowerUpType.magnet: 3,
    PowerUpType.hint: 5,
  };

  /// Get the count for a specific power-up type
  int getCount(PowerUpType type) {
    return _storage.getPowerUpCount(type);
  }

  /// Get counts for all power-ups
  Map<PowerUpType, int> getAllCounts() {
    return {
      for (var type in PowerUpType.values)
        type: getCount(type),
    };
  }

  /// Add power-ups of a specific type
  Future<void> addPowerUp(PowerUpType type, int amount) async {
    final current = getCount(type);
    await _storage.setPowerUpCount(type, current + amount);
    notifyListeners();
  }

  /// Add multiple power-ups at once (for packs)
  Future<void> addPowerUps(Map<PowerUpType, int> amounts) async {
    for (final entry in amounts.entries) {
      final current = getCount(entry.key);
      await _storage.setPowerUpCount(entry.key, current + entry.value);
    }
    notifyListeners();
  }

  /// Use a power-up. Returns true if successful, false if none available.
  Future<bool> usePowerUp(PowerUpType type) async {
    final current = getCount(type);
    if (current <= 0) return false;
    
    await _storage.setPowerUpCount(type, current - 1);
    notifyListeners();
    return true;
  }

  /// Check if a power-up is available
  bool isAvailable(PowerUpType type) {
    return getCount(type) > 0;
  }

  /// Initialize default power-ups for new players
  Future<void> initializeDefaults() async {
    final initialized = _storage.getPowerUpsInitialized();
    if (!initialized) {
      for (final entry in _defaultCounts.entries) {
        await _storage.setPowerUpCount(entry.key, entry.value);
      }
      await _storage.setPowerUpsInitialized(true);
      notifyListeners();
    }
  }

  /// Award a random power-up (for rewarded ads)
  Future<PowerUpType> awardRandomPowerUp() async {
    final types = PowerUpType.values;
    final randomIndex = DateTime.now().millisecondsSinceEpoch % types.length;
    final type = types[randomIndex];
    await addPowerUp(type, 1);
    return type;
  }

  /// Award power-up pack
  Future<void> awardPack(int size) async {
    // Distribute evenly across all power-up types
    final perType = size ~/ PowerUpType.values.length;
    final remainder = size % PowerUpType.values.length;
    
    for (int i = 0; i < PowerUpType.values.length; i++) {
      final extra = i < remainder ? 1 : 0;
      await addPowerUp(PowerUpType.values[i], perType + extra);
    }
  }

  /// Buy a power-up with coins (50 coins each)
  Future<bool> buyPowerUp(PowerUpType type) async {
    const int cost = 50;
    final currency = CurrencyService();
    final success = await currency.spendCoins(cost);
    if (success) {
      await addPowerUp(type, 1);
      return true;
    }
    return false;
  }
}

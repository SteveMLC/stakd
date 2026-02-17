import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing soft currency (coins)
class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  static const String _coinsKey = 'player_coins';
  static const int _startingCoins = 0;

  SharedPreferences? _prefs;

  /// Initialize the currency service
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('CurrencyService init failed: $e');
      _prefs = null;
    }
  }

  /// Get current coin balance
  Future<int> getCoins() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      return _prefs?.getInt(_coinsKey) ?? _startingCoins;
    } catch (e) {
      debugPrint('CurrencyService getCoins failed: $e');
      return _startingCoins;
    }
  }

  /// Add coins to balance
  Future<void> addCoins(int amount) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final currentCoins = await getCoins();
      final newBalance = currentCoins + amount;
      await _prefs?.setInt(_coinsKey, newBalance);
      debugPrint('CurrencyService: Added $amount coins. New balance: $newBalance');
    } catch (e) {
      debugPrint('CurrencyService addCoins failed: $e');
    }
  }

  /// Spend coins if sufficient balance
  /// Returns true if successful, false if insufficient funds
  Future<bool> spendCoins(int amount) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final currentCoins = await getCoins();
      
      if (currentCoins < amount) {
        debugPrint('CurrencyService: Insufficient coins. Have $currentCoins, need $amount');
        return false;
      }
      
      final newBalance = currentCoins - amount;
      await _prefs?.setInt(_coinsKey, newBalance);
      debugPrint('CurrencyService: Spent $amount coins. New balance: $newBalance');
      return true;
    } catch (e) {
      debugPrint('CurrencyService spendCoins failed: $e');
      return false;
    }
  }

  /// Check if player can afford a purchase
  Future<bool> canAfford(int amount) async {
    final currentCoins = await getCoins();
    return currentCoins >= amount;
  }

  /// Reset coins (for testing)
  Future<void> resetCoins() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setInt(_coinsKey, _startingCoins);
    } catch (e) {
      debugPrint('CurrencyService resetCoins failed: $e');
    }
  }
}

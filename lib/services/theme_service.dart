import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/theme_data.dart';
import 'currency_service.dart';

/// Service for managing visual themes
class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _selectedThemeKey = 'selected_theme';
  static const String _ownedThemesKey = 'owned_themes';

  SharedPreferences? _prefs;
  GameTheme _currentTheme = defaultTheme;
  List<String> _ownedThemes = ['default'];
  bool _isInitialized = false;

  /// Current active theme
  GameTheme get currentTheme => _currentTheme;

  /// List of owned theme IDs
  List<String> get ownedThemes => List.unmodifiable(_ownedThemes);

  /// All available themes
  List<GameTheme> get allThemes => allGameThemes;

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the theme service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSavedState();
      _isInitialized = true;
    } catch (e) {
      debugPrint('ThemeService init failed: $e');
      _isInitialized = true; // Mark as initialized even on failure
    }
  }

  /// Load saved theme state from preferences
  Future<void> _loadSavedState() async {
    try {
      // Load owned themes
      final ownedJson = _prefs?.getString(_ownedThemesKey);
      if (ownedJson != null) {
        final List<dynamic> decoded = jsonDecode(ownedJson);
        _ownedThemes = decoded.cast<String>();
      }

      // Ensure default is always owned
      if (!_ownedThemes.contains('default')) {
        _ownedThemes.insert(0, 'default');
      }

      // Load selected theme
      final selectedId = _prefs?.getString(_selectedThemeKey) ?? 'default';
      final selectedTheme = getThemeById(selectedId);
      
      // If theme exists and is owned, use it; otherwise default
      if (selectedTheme != null && _ownedThemes.contains(selectedId)) {
        _currentTheme = selectedTheme;
      } else {
        _currentTheme = defaultTheme;
      }
    } catch (e) {
      debugPrint('ThemeService _loadSavedState failed: $e');
    }
  }

  /// Save current state to preferences
  Future<void> _saveState() async {
    try {
      await _prefs?.setString(_selectedThemeKey, _currentTheme.id);
      await _prefs?.setString(_ownedThemesKey, jsonEncode(_ownedThemes));
    } catch (e) {
      debugPrint('ThemeService _saveState failed: $e');
    }
  }

  /// Set the active theme (must be owned)
  Future<bool> setTheme(String themeId) async {
    if (!_ownedThemes.contains(themeId)) {
      debugPrint('ThemeService: Cannot set theme $themeId - not owned');
      return false;
    }

    final theme = getThemeById(themeId);
    if (theme == null) {
      debugPrint('ThemeService: Theme $themeId not found');
      return false;
    }

    _currentTheme = theme;
    await _saveState();
    notifyListeners();
    
    debugPrint('ThemeService: Set theme to ${theme.name}');
    return true;
  }

  /// Check if a theme is owned
  bool isOwned(String themeId) => _ownedThemes.contains(themeId);

  /// Check if a theme is selected
  bool isSelected(String themeId) => _currentTheme.id == themeId;

  /// Purchase a theme using coins
  /// Returns true if successful, false if insufficient funds or already owned
  Future<bool> purchaseTheme(String themeId) async {
    // Check if already owned
    if (_ownedThemes.contains(themeId)) {
      debugPrint('ThemeService: Theme $themeId already owned');
      return false;
    }

    // Get the theme
    final theme = getThemeById(themeId);
    if (theme == null) {
      debugPrint('ThemeService: Theme $themeId not found');
      return false;
    }

    // Free themes are auto-purchased
    if (theme.price == 0) {
      _ownedThemes.add(themeId);
      await _saveState();
      notifyListeners();
      return true;
    }

    // Try to spend coins
    final currencyService = CurrencyService();
    final success = await currencyService.spendCoins(theme.price);
    
    if (!success) {
      debugPrint('ThemeService: Cannot afford theme $themeId (costs ${theme.price})');
      return false;
    }

    // Add to owned themes
    _ownedThemes.add(themeId);
    await _saveState();
    notifyListeners();

    debugPrint('ThemeService: Purchased theme ${theme.name} for ${theme.price} coins');
    return true;
  }

  /// Get the price of a theme (0 if free or owned)
  int getPrice(String themeId) {
    if (_ownedThemes.contains(themeId)) return 0;
    return getThemeById(themeId)?.price ?? 0;
  }

  /// Reset to default theme (for testing)
  Future<void> resetToDefault() async {
    _currentTheme = defaultTheme;
    _ownedThemes = ['default'];
    await _saveState();
    notifyListeners();
  }

  /// Grant all themes (for testing/premium)
  Future<void> unlockAllThemes() async {
    _ownedThemes = allGameThemes.map((t) => t.id).toList();
    await _saveState();
    notifyListeners();
  }
}

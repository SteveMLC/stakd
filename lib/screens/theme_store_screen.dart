import 'package:flutter/material.dart';
import '../models/theme_data.dart';
import '../services/theme_service.dart';
import '../services/currency_service.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../utils/constants.dart';
import '../widgets/game_button.dart';

/// Theme store screen for purchasing and selecting visual themes
class ThemeStoreScreen extends StatefulWidget {
  const ThemeStoreScreen({super.key});

  @override
  State<ThemeStoreScreen> createState() => _ThemeStoreScreenState();
}

class _ThemeStoreScreenState extends State<ThemeStoreScreen> {
  final ThemeService _themeService = ThemeService();
  final CurrencyService _currencyService = CurrencyService();
  int _coins = 0;
  String? _previewThemeId;

  @override
  void initState() {
    super.initState();
    _loadCoins();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCoins() async {
    final coins = await _currencyService.getCoins();
    if (mounted) {
      setState(() => _coins = coins);
    }
  }

  Future<void> _purchaseTheme(GameTheme theme) async {
    // Check if can afford
    if (_coins < theme.price) {
      _showMessage('Not enough coins! Need ${theme.price - _coins} more.');
      return;
    }

    // Confirm purchase
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GameColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Purchase ${theme.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemePreviewMini(theme),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${theme.price} coins',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: GameColors.accent,
            ),
            child: const Text('Buy'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Attempt purchase
    final success = await _themeService.purchaseTheme(theme.id);
    if (success) {
      AudioService().playSuccess();
      haptics.success();
      await _loadCoins();
      _showMessage('${theme.name} unlocked! 🎉');
      
      // Auto-select the purchased theme
      await _themeService.setTheme(theme.id);
    } else {
      _showMessage('Purchase failed');
    }
  }

  Future<void> _selectTheme(GameTheme theme) async {
    if (!_themeService.isOwned(theme.id)) {
      await _purchaseTheme(theme);
      return;
    }

    final success = await _themeService.setTheme(theme.id);
    if (success) {
      AudioService().playTap();
      haptics.lightTap();
      setState(() => _previewThemeId = null);
    }
  }

  void _previewTheme(GameTheme theme) {
    setState(() {
      _previewThemeId = _previewThemeId == theme.id ? null : theme.id;
    });
    haptics.selectionTap();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: GameColors.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = _themeService.currentTheme;
    final themes = _themeService.allThemes;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              currentTheme.backgroundColor,
              currentTheme.backgroundGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GameIconButton(
                      icon: Icons.arrow_back,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Theme Store',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: currentTheme.textColor,
                      ),
                    ),
                    const Spacer(),
                    // Coin display
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: currentTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_coins',
                            style: TextStyle(
                              color: currentTheme.textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Theme preview (if one is being previewed)
              if (_previewThemeId != null)
                _buildPreviewSection(getThemeById(_previewThemeId!)!),

              // Theme grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: themes.length,
                  itemBuilder: (context, index) {
                    final theme = themes[index];
                    return _buildThemeCard(theme);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewSection(GameTheme theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.accentColor.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            '${theme.icon} ${theme.name} Preview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildThemePreviewBoard(theme),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_themeService.isOwned(theme.id))
                ElevatedButton.icon(
                  onPressed: () => _purchaseTheme(theme),
                  icon: const Icon(Icons.monetization_on, size: 18),
                  label: Text('Buy for ${theme.price}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: theme.textColor,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _selectTheme(theme),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    _themeService.isSelected(theme.id) ? 'Selected' : 'Select',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _themeService.isSelected(theme.id)
                        ? Colors.green
                        : theme.accentColor,
                    foregroundColor: theme.textColor,
                  ),
                ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _previewThemeId = null),
                child: Text(
                  'Close',
                  style: TextStyle(color: theme.textMutedColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemePreviewBoard(GameTheme theme) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.backgroundColor, theme.backgroundGradientEnd],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Sample stacks with blocks
          for (int i = 0; i < 4; i++)
            Container(
              width: 36,
              height: 80,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: theme.emptySlotColor,
                borderRadius: BorderRadius.circular(theme.blockBorderRadius / 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (int j = 0; j < 3; j++)
                    Container(
                      width: 28,
                      height: 18,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: theme.blockGradients[(i + j) % theme.blockGradients.length],
                        ),
                        borderRadius: BorderRadius.circular(theme.blockBorderRadius / 2),
                        boxShadow: theme.hasBlockGlow
                            ? [
                                BoxShadow(
                                  color: theme.blockPalette[(i + j) % theme.blockPalette.length]
                                      .withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThemePreviewMini(GameTheme theme) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.backgroundColor, theme.backgroundGradientEnd],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < 5; i++)
            Container(
              width: 24,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: theme.emptySlotColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (int j = 0; j < 2; j++)
                    Container(
                      width: 18,
                      height: 12,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: theme.blockGradients[(i + j) % theme.blockGradients.length],
                        ),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: theme.hasBlockGlow
                            ? [
                                BoxShadow(
                                  color: theme.blockPalette[(i + j) % theme.blockPalette.length]
                                      .withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(GameTheme theme) {
    final isOwned = _themeService.isOwned(theme.id);
    final isSelected = _themeService.isSelected(theme.id);
    final isPreviewing = _previewThemeId == theme.id;

    return GestureDetector(
      onTap: () => _previewTheme(theme),
      onDoubleTap: () => _selectTheme(theme),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.green
                : isPreviewing
                    ? theme.accentColor
                    : theme.emptySlotColor,
            width: isSelected || isPreviewing ? 3 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Theme preview
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [theme.backgroundColor, theme.backgroundGradientEnd],
                        ),
                      ),
                    ),
                    // Block samples
                    Center(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: List.generate(6, (i) {
                          return Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: theme.blockGradients[i % theme.blockGradients.length],
                              ),
                              borderRadius: BorderRadius.circular(theme.blockBorderRadius / 2),
                              boxShadow: theme.hasBlockGlow
                                  ? [
                                      BoxShadow(
                                        color: theme.blockPalette[i % theme.blockPalette.length]
                                            .withValues(alpha: 0.6),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),
                    ),
                    // Selected indicator
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    // Owned badge
                    if (isOwned && !isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'OWNED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Theme info
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        theme.icon,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          theme.name,
                          style: TextStyle(
                            color: theme.textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (isOwned)
                    Text(
                      isSelected ? '✓ Active' : 'Tap to preview',
                      style: TextStyle(
                        color: isSelected ? Colors.green : theme.textMutedColor,
                        fontSize: 11,
                      ),
                    )
                  else
                    Row(
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          color: Colors.amber,
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${theme.price}',
                          style: TextStyle(
                            color: theme.textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

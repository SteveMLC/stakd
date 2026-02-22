import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../services/storage_service.dart';
import '../services/theme_service.dart';
import '../utils/constants.dart';
import '../widgets/game_button.dart';
import '../utils/route_transitions.dart';
import 'theme_store_screen.dart';

/// Settings screen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _textureSkinsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final storage = StorageService();
    setState(() {
      _soundEnabled = storage.getSoundEnabled();
      _hapticsEnabled = storage.getHapticsEnabled();
      _textureSkinsEnabled = storage.getTextureSkinsEnabled();
    });
  }

  Future<void> _toggleSound() async {
    final storage = StorageService();
    final audio = AudioService();

    setState(() => _soundEnabled = !_soundEnabled);
    await storage.setSoundEnabled(_soundEnabled);
    audio.setSoundEnabled(_soundEnabled);

    if (_soundEnabled) {
      audio.playTap();
    }
  }

  Future<void> _toggleHaptics() async {
    final storage = StorageService();
    final nextValue = !_hapticsEnabled;

    setState(() => _hapticsEnabled = nextValue);
    await storage.setHapticsEnabled(nextValue);

    if (nextValue) {
      haptics.lightTap();
    }
  }

  Future<void> _toggleTextureSkins() async {
    final storage = StorageService();
    final nextValue = !_textureSkinsEnabled;

    setState(() => _textureSkinsEnabled = nextValue);
    await storage.setTextureSkinsEnabled(nextValue);

    if (_soundEnabled) {
      AudioService().playTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [GameColors.backgroundDark, GameColors.backgroundMid],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
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
                      'Settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSectionTitle('Audio'),
                    _buildToggleTile(
                      icon: Icons.volume_up,
                      title: 'Sound',
                      value: _soundEnabled,
                      onToggle: _toggleSound,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Feedback'),
                    _buildToggleTile(
                      icon: Icons.vibration,
                      title: 'Haptics',
                      value: _hapticsEnabled,
                      onToggle: _toggleHaptics,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Visuals'),
                    _buildToggleTile(
                      icon: Icons.texture,
                      title: 'Texture Skins',
                      value: _textureSkinsEnabled,
                      onToggle: _toggleTextureSkins,
                    ),
                    const SizedBox(height: 8),
                    _buildThemeButton(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: GameColors.accent,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required bool value,
    required VoidCallback onToggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GameColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: GameColors.accent),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
          Switch(
            value: value,
            onChanged: (_) => onToggle(),
            activeThumbColor: GameColors.accent,
            activeTrackColor: GameColors.accent.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeButton() {
    final themeService = ThemeService();
    final currentTheme = themeService.currentTheme;

    return GestureDetector(
      onTap: () {
        haptics.lightTap();
        Navigator.of(context).push(
          fadeSlideRoute(const ThemeStoreScreen()),
        ).then((_) {
          // Refresh when returning from theme store
          if (mounted) setState(() {});
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GameColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              currentTheme.icon,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Theme',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    currentTheme.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: GameColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: GameColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

}

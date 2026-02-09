import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/game_button.dart';

/// Settings screen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
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
                    _buildSectionTitle('Ads'),
                    Center(
                      child: GameButton(
                        text: 'Remove Ads',
                        icon: Icons.block,
                        isDisabled: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Coming soon',
                        style: TextStyle(
                          color: GameColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
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
}

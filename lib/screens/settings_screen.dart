import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import '../widgets/game_button.dart';

/// Settings screen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _adsRemoved = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final storage = StorageService();
    setState(() {
      _soundEnabled = storage.getSoundEnabled();
      _musicEnabled = storage.getMusicEnabled();
      _adsRemoved = storage.getAdsRemoved();
    });
  }

  void _toggleSound() async {
    final storage = StorageService();
    final audio = AudioService();
    
    setState(() => _soundEnabled = !_soundEnabled);
    await storage.setSoundEnabled(_soundEnabled);
    audio.setSoundEnabled(_soundEnabled);
    
    if (_soundEnabled) {
      audio.playTap();
    }
  }

  void _toggleMusic() async {
    final storage = StorageService();
    final audio = AudioService();
    
    setState(() => _musicEnabled = !_musicEnabled);
    await storage.setMusicEnabled(_musicEnabled);
    audio.setMusicEnabled(_musicEnabled);
  }

  void _removeAds() {
    // TODO: Implement IAP
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming soon!'),
      ),
    );
  }

  void _rateApp() async {
    const url = 'https://play.google.com/store/apps/details?id=com.go7studio.stakd';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = StorageService().getStats();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
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
                    // Audio section
                    _buildSectionTitle('Audio'),
                    _buildToggleTile(
                      icon: Icons.volume_up,
                      title: 'Sound Effects',
                      value: _soundEnabled,
                      onToggle: _toggleSound,
                    ),
                    _buildToggleTile(
                      icon: Icons.music_note,
                      title: 'Music',
                      value: _musicEnabled,
                      onToggle: _toggleMusic,
                    ),
                    const SizedBox(height: 24),
                    
                    // Ads section
                    _buildSectionTitle('Ads'),
                    _buildActionTile(
                      icon: Icons.remove_circle_outline,
                      title: 'Remove Ads',
                      subtitle: _adsRemoved ? 'Purchased' : '\$3.99',
                      onTap: _adsRemoved ? null : _removeAds,
                    ),
                    const SizedBox(height: 24),
                    
                    // Stats section
                    _buildSectionTitle('Stats'),
                    _buildStatTile(
                      icon: Icons.emoji_events,
                      title: 'Highest Level',
                      value: '${stats['highestLevel']}',
                    ),
                    _buildStatTile(
                      icon: Icons.check_circle,
                      title: 'Levels Completed',
                      value: '${stats['completedCount']}',
                    ),
                    _buildStatTile(
                      icon: Icons.touch_app,
                      title: 'Total Moves',
                      value: '${stats['totalMoves']}',
                    ),
                    const SizedBox(height: 24),
                    
                    // About section
                    _buildSectionTitle('About'),
                    _buildActionTile(
                      icon: Icons.star,
                      title: 'Rate App',
                      subtitle: 'Love Stakd? Leave a review!',
                      onTap: _rateApp,
                    ),
                    _buildStatTile(
                      icon: Icons.info_outline,
                      title: 'Version',
                      value: '1.0.0',
                    ),
                    const SizedBox(height: 16),
                    
                    // Credits
                    Center(
                      child: Text(
                        'Made with ❤️ by Go7Studio',
                        style: TextStyle(
                          color: GameColors.textMuted,
                          fontSize: 14,
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
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Switch(
            value: value,
            onChanged: (_) => onToggle(),
            activeColor: GameColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: GameColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right,
                color: GameColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String title,
    required String value,
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
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: GameColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

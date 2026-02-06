import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../widgets/game_button.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';

/// Main menu screen
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final highestLevel = storage.getHighestLevel();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                
                // Logo / Title
                _buildLogo(),
                const SizedBox(height: 16),
                
                // Tagline
                Text(
                  'Color Sort Puzzle',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: GameColors.textMuted,
                    letterSpacing: 2,
                  ),
                ),
                
                const Spacer(flex: 2),
                
                // Play button
                GameButton(
                  text: 'Play',
                  icon: Icons.play_arrow,
                  onPressed: () => _startGame(context, highestLevel),
                ),
                const SizedBox(height: 16),
                
                // Level Select button
                GameButton(
                  text: 'Select Level',
                  icon: Icons.grid_view,
                  isPrimary: false,
                  onPressed: () => _openLevelSelect(context),
                ),
                const SizedBox(height: 16),
                
                // Settings button
                GameButton(
                  text: 'Settings',
                  icon: Icons.settings,
                  isPrimary: false,
                  isSmall: true,
                  onPressed: () => _openSettings(context),
                ),
                
                const Spacer(flex: 3),
                
                // Level indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: GameColors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: GameColors.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Level $highestLevel',
                        style: const TextStyle(
                          color: GameColors.text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // Animated stacks icon
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final colors = [
              GameColors.palette[0],
              GameColors.palette[1],
              GameColors.palette[2],
            ];
            return Container(
              width: 40,
              height: 80,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: GameColors.empty,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: List.generate(3, (layerIndex) {
                  return Container(
                    width: 32,
                    height: 20,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: colors[(index + layerIndex) % 3],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        // Title
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              GameColors.accent,
              GameColors.palette[1],
              GameColors.accent,
            ],
          ).createShader(bounds),
          child: const Text(
            'STAKD',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 8,
            ),
          ),
        ),
      ],
    );
  }

  void _startGame(BuildContext context, int level) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(level: level),
      ),
    );
  }

  void _openLevelSelect(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LevelSelectScreen(),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }
}

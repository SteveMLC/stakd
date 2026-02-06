import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../widgets/game_button.dart';
import 'game_screen.dart';

/// Level selection screen
class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final highestLevel = storage.getHighestLevel();
    final completedLevels = storage.getCompletedLevels();

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
                      'Select Level',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),

              // Level grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: 100, // Show first 100 levels
                    itemBuilder: (context, index) {
                      final level = index + 1;
                      final isCompleted = completedLevels.contains(level);
                      final isUnlocked = level <= highestLevel;
                      final isCurrent = level == highestLevel;

                      return _LevelButton(
                        level: level,
                        isCompleted: isCompleted,
                        isUnlocked: isUnlocked,
                        isCurrent: isCurrent,
                        onTap: isUnlocked
                            ? () => _startLevel(context, level)
                            : null,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startLevel(BuildContext context, int level) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(level: level)),
    );
  }
}

class _LevelButton extends StatelessWidget {
  final int level;
  final bool isCompleted;
  final bool isUnlocked;
  final bool isCurrent;
  final VoidCallback? onTap;

  const _LevelButton({
    required this.level,
    required this.isCompleted,
    required this.isUnlocked,
    required this.isCurrent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isCurrent
              ? GameColors.accent
              : isUnlocked
              ? GameColors.surface
              : GameColors.empty,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? GameColors.accent
                : isCompleted
                ? GameColors.palette[2]
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: GameColors.accent.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Level number
            Center(
              child: Text(
                '$level',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isUnlocked
                      ? GameColors.text
                      : GameColors.textMuted.withValues(alpha: 0.5),
                ),
              ),
            ),

            // Completed checkmark
            if (isCompleted)
              const Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.check_circle,
                  size: 16,
                  color: GameColors.accent,
                ),
              ),

            // Locked icon
            if (!isUnlocked)
              Center(
                child: Icon(
                  Icons.lock,
                  size: 20,
                  color: GameColors.textMuted.withValues(alpha: 0.3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

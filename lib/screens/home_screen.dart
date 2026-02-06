import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../widgets/game_button.dart';
import '../widgets/daily_streak_badge.dart';
import 'daily_challenge_screen.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';

/// Main menu screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isDailyCompleted = false;
  int _dailyStreak = 0;
  bool _highlightStreak = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadDailyData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _loadDailyData() {
    final storage = StorageService();
    final todayKey = _formatDateKey(DateTime.now().toUtc());
    final completed = storage.isDailyChallengeCompleted(todayKey);
    final streak = storage.getDailyChallengeStreak();

    setState(() {
      _isDailyCompleted = completed;
      _dailyStreak = streak;
    });

    _updatePulseAnimation();
  }

  void _updatePulseAnimation() {
    if (_isDailyCompleted) {
      _pulseController.stop();
      _pulseController.value = 1.0;
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  Future<void> _openDailyChallenge(BuildContext context) async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DailyChallengeScreen()));

    if (!mounted) return;

    final milestone = result is Map && result['milestone'] == true;
    _loadDailyData();

    if (milestone) {
      setState(() => _highlightStreak = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _highlightStreak = false);
        }
      });
    } else {
      setState(() => _highlightStreak = false);
    }
  }

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
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                _buildLogo(),
                const SizedBox(height: 16),
                Text(
                  'Color Sort Puzzle',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: GameColors.textMuted,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(flex: 2),
                GameButton(
                  text: 'Play',
                  icon: Icons.play_arrow,
                  onPressed: () => _startGame(context, highestLevel),
                ),
                const SizedBox(height: 16),
                _buildDailyChallengeSection(context),
                const SizedBox(height: 16),
                GameButton(
                  text: 'Select Level',
                  icon: Icons.grid_view,
                  isPrimary: false,
                  onPressed: () => _openLevelSelect(context),
                ),
                const SizedBox(height: 16),
                GameButton(
                  text: 'Settings',
                  icon: Icons.settings,
                  isPrimary: false,
                  isSmall: true,
                  onPressed: () => _openSettings(context),
                ),
                const Spacer(flex: 3),
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

  Widget _buildDailyChallengeSection(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final scale = _isDailyCompleted ? 1.0 : _pulseAnimation.value;
            final glowOpacity = _isDailyCompleted
                ? 0.0
                : (_pulseAnimation.value - 1.0) * 3.0;

            return Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: glowOpacity <= 0
                      ? null
                      : [
                          BoxShadow(
                            color: GameColors.accent.withValues(
                              alpha: glowOpacity,
                            ),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                ),
                child: child,
              ),
            );
          },
          child: GameButton(
            text: 'Daily Challenge',
            icon: Icons.today,
            onPressed: () => _openDailyChallenge(context),
          ),
        ),
        const SizedBox(height: 10),
        if (_dailyStreak > 0)
          DailyStreakBadge(streak: _dailyStreak, highlight: _highlightStreak),
      ],
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => GameScreen(level: level)));
  }

  void _openLevelSelect(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LevelSelectScreen()));
  }

  void _openSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  String _formatDateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }
}

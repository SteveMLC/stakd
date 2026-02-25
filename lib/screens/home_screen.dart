import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../services/daily_challenge_service.dart';
import '../services/daily_rewards_service.dart';
import '../services/currency_service.dart';
import '../widgets/game_button.dart';
import '../widgets/daily_streak_badge.dart';
import '../widgets/daily_rewards_popup.dart';
import 'daily_challenge_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';
import 'zen_mode_screen.dart';
import 'zen_garden_screen.dart';
import 'leaderboard_screen.dart';
import '../utils/route_transitions.dart';
import 'theme_store_screen.dart';

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
  bool _hasUnclaimedReward = false;
  int _coinBalance = 0;
  bool _dailyRewardsShown = false;

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
    _checkDailyRewards();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadDailyData() async {
    final service = DailyChallengeService();
    final completed = await service.isTodayCompleted();
    final streak = await service.getStreak();

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

  Future<void> _checkDailyRewards() async {
    final rewardsService = DailyRewardsService();
    final currencyService = CurrencyService();
    await rewardsService.init();
    await currencyService.init();

    final canClaim = await rewardsService.canClaimToday();
    final coins = await currencyService.getCoins();

    if (!mounted) return;

    setState(() {
      _hasUnclaimedReward = canClaim;
      _coinBalance = coins;
    });

    // Show popup automatically if reward is available (only once per session)
    if (canClaim && !_dailyRewardsShown) {
      _dailyRewardsShown = true;
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await DailyRewardsPopup.show(context);
        // Refresh after popup closes
        await _refreshAfterRewards();
      }
    }
  }

  void _openDailyRewards() {
    DailyRewardsPopup.show(context).then((_) {
      _refreshAfterRewards();
    });
  }

  Future<void> _refreshAfterRewards() async {
    final rewardsService = DailyRewardsService();
    final currencyService = CurrencyService();
    await rewardsService.init();
    await currencyService.init();
    final canClaim = await rewardsService.canClaimToday();
    final coins = await currencyService.getCoins();
    if (mounted) {
      setState(() {
        _hasUnclaimedReward = canClaim;
        _coinBalance = coins;
      });
    }
  }

  Future<void> _openDailyChallenge(BuildContext context) async {
    final result = await Navigator.of(
      context,
    ).push(fadeSlideRoute(const DailyChallengeScreen()));

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
      body: AnimatedBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                _buildTopBar(),
                const SizedBox(height: 16),
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
                _buildZenModeButton(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(child: _buildDailyChallengeSection(context)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSecondaryButton(
                        text: 'Level Challenge',
                        icon: Icons.flag,
                        badge: 'Lv $highestLevel',
                        onPressed: () => _openLevelSelect(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GameButton(
                      text: 'Leaderboards',
                      icon: Icons.leaderboard,
                      isPrimary: false,
                      isSmall: true,
                      onPressed: () => _openLeaderboards(context),
                    ),
                    const SizedBox(width: 16),
                    GameButton(
                      text: 'Themes',
                      icon: Icons.palette,
                      isPrimary: false,
                      isSmall: true,
                      onPressed: () => _openThemeStore(context),
                    ),
                    const SizedBox(width: 16),
                    GameButton(
                      text: 'Settings',
                      icon: Icons.settings,
                      isPrimary: false,
                      isSmall: true,
                      onPressed: () => _openSettings(context),
                    ),
                  ],
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Coin balance
          GestureDetector(
            onTap: _openDailyRewards,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: GameColors.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Color(0xFFFFD700),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_coinBalance',
                    style: TextStyle(
                      color: GameColors.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Daily rewards button
          GestureDetector(
            onTap: _openDailyRewards,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GameColors.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hasUnclaimedReward
                          ? GameColors.accent.withValues(alpha: 0.5)
                          : GameColors.textMuted.withValues(alpha: 0.2),
                    ),
                    boxShadow: _hasUnclaimedReward
                        ? [
                            BoxShadow(
                              color: GameColors.accent.withValues(alpha: 0.3),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.card_giftcard,
                    color: _hasUnclaimedReward
                        ? GameColors.accent
                        : GameColors.textMuted,
                    size: 24,
                  ),
                ),
                // Notification badge
                if (_hasUnclaimedReward)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: GameColors.errorGlow,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: GameColors.background,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyChallengeSection(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
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
              child: SizedBox(
                width: double.infinity,
                child: GameButton(
                  text: 'Daily Challenge',
                  icon: Icons.calendar_today,
                  isPrimary: false,
                  isSmall: true,
                  onPressed: () => _openDailyChallenge(context),
                ),
              ),
            ),
            // Notification dot if not completed
            if (!_isDailyCompleted)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: GameColors.errorGlow,
                    shape: BoxShape.circle,
                    border: Border.all(color: GameColors.background, width: 2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_dailyStreak > 0)
          DailyStreakBadge(streak: _dailyStreak, highlight: _highlightStreak),
      ],
    );
  }

  Widget _buildZenModeButton() {
    return GestureDetector(
      onTap: _showZenDifficultyPicker,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              GameColors.accent,
              GameColors.accent.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: GameColors.accent.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.spa, size: 32, color: GameColors.text),
            SizedBox(width: 12),
            Text(
              'ZEN MODE',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: GameColors.text,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
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
              color: GameColors.text,
              letterSpacing: 8,
            ),
          ),
        ),
      ],
    );
  }

  void _openLevelSelect(BuildContext context) {
    Navigator.of(context).push(fadeSlideRoute(const LevelSelectScreen()));
  }

  void _startZen(String difficulty) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      fadeSlideRoute(ZenModeScreen(difficulty: difficulty)),
    );
  }

  void _openGarden(BuildContext context) {
    Navigator.of(context).push(fadeSlideRoute(const ZenGardenScreen()));
  }

  void _openThemeStore(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ThemeStoreScreen()));
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(fadeSlideRoute(const SettingsScreen()));
  }

  void _openLeaderboards(BuildContext context) {
    Navigator.of(context).push(fadeSlideRoute(const LeaderboardScreen()));
  }

  void _showZenDifficultyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: GameColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: GameColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose Your Vibe',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Zen mode adapts to your pace',
                style: TextStyle(color: GameColors.textMuted),
              ),
              const SizedBox(height: 24),
              _buildDifficultyOption(
                title: 'Easy',
                subtitle: '4 colors • Relaxed',
                icon: Icons.wb_sunny,
                onTap: () => _startZen('easy'),
              ),
              _buildDifficultyOption(
                title: 'Medium',
                subtitle: '5 colors • Focused',
                icon: Icons.cloud,
                onTap: () => _startZen('medium'),
              ),
              _buildDifficultyOption(
                title: 'Hard',
                subtitle: '6 colors • Challenge',
                icon: Icons.bolt,
                onTap: () => _startZen('hard'),
              ),
              _buildDifficultyOption(
                title: 'Ultra',
                subtitle: '7 colors • For masters',
                icon: Icons.whatshot,
                onTap: () => _startZen('ultra'),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  _openGarden(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: GameColors.zen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.park_outlined, color: GameColors.zen.withValues(alpha: 0.8), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'View My Garden',
                        style: TextStyle(
                          color: GameColors.zen.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDifficultyOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: GameColors.background.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: GameColors.accent.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: GameColors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: GameColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: GameColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: GameColors.textMuted.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    String? badge,
  }) {
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          child: GameButton(
            text: text,
            icon: icon,
            isPrimary: false,
            isSmall: true,
            onPressed: onPressed,
          ),
        ),
        if (badge != null)
          Positioned(
            top: -8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: GameColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: GameColors.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AnimatedBackground extends StatefulWidget {
  final Widget child;

  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    final random = Random();
    _stars = List.generate(
      30,
      (index) => _Star(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 2 + 1,
        speed: random.nextDouble() * 0.02 + 0.01,
        opacity: random.nextDouble() * 0.3 + 0.1,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                GameColors.backgroundDark,
                GameColors.backgroundMid,
                GameColors.backgroundLight,
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _StarFieldPainter(_stars, _controller.value),
              size: Size.infinite,
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class _Star {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;

  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class _StarFieldPainter extends CustomPainter {
  final List<_Star> stars;
  final double progress;

  const _StarFieldPainter(this.stars, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final dy = (star.y + progress * star.speed) % 1.0;
      final offset = Offset(star.x * size.width, dy * size.height);
      final paint = Paint()
        ..color = GameColors.text.withValues(alpha: star.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(offset, star.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.stars != stars;
  }
}

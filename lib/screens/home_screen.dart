import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/daily_challenge_service.dart';
import '../services/daily_rewards_service.dart';
import '../services/currency_service.dart';
import '../services/storage_service.dart';
import '../widgets/game_button.dart';
import '../widgets/daily_streak_badge.dart';
import '../widgets/daily_rewards_popup.dart';
import '../widgets/next_milestone_banner.dart';
import '../widgets/warehouse_decorations.dart';
import '../widgets/warehouse_hud.dart';
import 'contract_select_screen.dart';
import 'daily_challenge_screen.dart';
import 'settings_screen.dart';
import 'leaderboard_screen.dart';
import '../utils/route_transitions.dart';
import 'achievements_screen.dart';
import 'forklift_shop_screen.dart';
import 'machinery_shop_screen.dart';

/// Main menu screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isDailyCompleted = false;
  int _dailyStreak = 0;
  bool _highlightStreak = false;
  bool _hasUnclaimedReward = false;
  int _coinBalance = 0;

  // Logo animation
  late AnimationController _logoController;
  bool _logoWiggling = false;

  @override
  void initState() {
    super.initState();
    // Staggered bounce-in on load
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _loadDailyData();
    _checkDailyRewards();
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _loadDailyData() async {
    final service = DailyChallengeService();
    final completed = await service.isTodayCompleted();
    
    // Get daily rewards streak (unified with popup display)
    final rewardsService = DailyRewardsService();
    await rewardsService.init();
    final currentDay = await rewardsService.getCurrentDay();
    final lastClaim = await rewardsService.getLastClaimDate();
    
    // Streak = days claimed so far in current cycle
    // If currentDay = 5 and lastClaim exists, we've claimed days 1-4, so streak = 4
    // If we haven't claimed anything yet, streak = 0
    int streak = 0;
    if (lastClaim != null) {
      final canClaim = await rewardsService.canClaimToday();
      // If we can claim today, streak = currentDay - 1 (days already claimed)
      // If we can't claim (already claimed today), streak = currentDay (including today)
      streak = canClaim ? currentDay - 1 : currentDay;
      // Cap at 7 (full cycle)
      if (streak > 7) streak = 0; // Reset after cycle completes
    }

    setState(() {
      _isDailyCompleted = completed;
      _dailyStreak = streak;
    });
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

    // Show the popup automatically only AFTER the player has cleared at
    // least one level. First-launch UX should let the player see PLAY,
    // not be ambushed by a rewards modal. Once cleared, daily popups
    // fire once per day on home screen entry like before.
    final storage = StorageService();
    final cleared = storage.getLevelStars(1) > 0 ||
        storage.getLevelStars(2) > 0 ||
        storage.getLevelStars(3) > 0;
    if (canClaim && cleared) {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
      final lastShown = prefs.getString('daily_rewards_last_shown');
      if (lastShown != today) {
        await prefs.setString('daily_rewards_last_shown', today);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          await DailyRewardsPopup.show(context);
          await _refreshAfterRewards();
        }
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
                const SizedBox(height: 12),
                Text(
                  'Sort the crates. Build the empire.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: GameColors.textMuted,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                const WarehouseHud(),
                const NextMilestoneBanner(),
                const Spacer(flex: 2),
                _buildPlayButton(),
                const SizedBox(height: 24),
                _buildDailyChallengeSection(context),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: GameButton(
                          text: 'Contracts',
                          icon: Icons.assignment_outlined,
                          isPrimary: false,
                          isSmall: true,
                          onPressed: () => _openLevelSelect(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GameButton(
                          text: 'Machinery',
                          icon: Icons.precision_manufacturing,
                          isPrimary: false,
                          isSmall: true,
                          onPressed: () => _openMachineryShop(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: GameButton(
                          text: 'Achievements',
                          icon: Icons.emoji_events,
                          isPrimary: false,
                          isSmall: true,
                          onPressed: () => _openAchievements(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GameButton(
                          text: 'Leaderboards',
                          icon: Icons.leaderboard,
                          isPrimary: false,
                          isSmall: true,
                          onPressed: () => _openLeaderboards(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: GameButton(
                          text: 'Forklifts',
                          icon: Icons.local_shipping,
                          isPrimary: false,
                          isSmall: true,
                          onPressed: () => _openForkliftShop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GameButton(
                          text: 'Settings',
                          icon: Icons.settings,
                          isPrimary: false,
                          isSmall: true,
                          onPressed: () => _openSettings(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 3),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Coin balance (secondary currency — power-ups + cosmetics).
              GestureDetector(
                behavior: HitTestBehavior.opaque,
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
                      const Text('🪙', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        '$_coinBalance',
                        style: const TextStyle(
                          color: GameColors.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Daily rewards button (warehouse meta progress lives in
              // WarehouseHud below, so the old rank/XP-bar widgets are gone).
              GestureDetector(
                behavior: HitTestBehavior.opaque,
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
        ],
      ),
    );
  }

  Widget _buildDailyChallengeSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: GameButton(
              text: _isDailyCompleted ? 'Daily Complete' : 'Daily Contract',
              icon: Icons.calendar_today,
              isPrimary: false,
              isSmall: true,
              onPressed: () => _openDailyChallenge(context),
            ),
          ),
          if (_dailyStreak > 0) ...[
            const SizedBox(height: 8),
            DailyStreakBadge(streak: _dailyStreak, highlight: _highlightStreak),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openLevelSelect(context),
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
            Icon(Icons.local_shipping, size: 32, color: GameColors.text),
            SizedBox(width: 12),
            Text(
              'PLAY',
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

  void _onLogoTap() {
    if (_logoWiggling) return;
    _logoWiggling = true;
    HapticFeedback.lightImpact();
    _logoController.reset();
    _logoController.forward().then((_) {
      _logoWiggling = false;
    });
  }

  Widget _buildLogo() {
    return GestureDetector(
      onTap: _onLogoTap,
      child: AnimatedBuilder(
        animation: _logoController,
        builder: (context, child) {
          // Bounce-in from above, then gentle wiggle on tap.
          final t = Interval(0.0, 0.7, curve: Curves.easeOutBack)
              .transform(_logoController.value)
              .clamp(0.0, 1.0);
          final isWiggle = _logoWiggling && _logoController.value > 0;
          final wiggleAngle = isWiggle
              ? sin(_logoController.value * 6 * pi) *
                  0.04 *
                  (1.0 - _logoController.value)
              : 0.0;
          return Transform.translate(
            offset: Offset(0, (1.0 - t) * -30),
            child: Transform.rotate(
              angle: wiggleAngle,
              child: Opacity(opacity: t, child: child),
            ),
          );
        },
        child: const _WarehousePlacard(),
      ),
    );
  }

  void _openLevelSelect(BuildContext context) {
    Navigator.of(context).push(fadeSlideRoute(const ContractSelectScreen()));
  }


  void _openForkliftShop(BuildContext context) {
    Navigator.of(context).push(fadeSlideRoute(const ForkliftShopScreen()));
  }

  void _openMachineryShop(BuildContext context) {
    Navigator.of(context).push(fadeSlideRoute(const MachineryShopScreen()));
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(fadeSlideRoute(const SettingsScreen()));
  }

  void _openLeaderboards(BuildContext context) {
    Navigator.of(context).push(fadeSlideRoute(const LeaderboardScreen()));
  }

  void _openAchievements(BuildContext context) {
    Navigator.of(context).push(fadeSlideRoute(const AchievementsScreen()));
  }

}

/// The home wordmark, framed like a printed shipping placard: stamped
/// WAREHOUSE / SORT text on cardboard-tan, rivets at the corners, a
/// hazard-tape band across the top, and a small forklift idling on
/// the right that hauls a tiny stack of crates. Replaces the previous
/// rectangle-stack logo with something that actually reads "warehouse".
class _WarehousePlacard extends StatelessWidget {
  const _WarehousePlacard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF252B36),
              Color(0xFF1A1F26),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: GameColors.accent.withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top hazard band.
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: HazardStripe(height: 8, stripeWidth: 12),
            ),
            // Bottom hazard band.
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: HazardStripe(height: 6, stripeWidth: 10),
            ),
            // Corner rivets.
            const Positioned(
                left: 6, top: 14, child: _CornerRivet()),
            const Positioned(
                right: 6, top: 14, child: _CornerRivet()),
            const Positioned(
                left: 6, bottom: 12, child: _CornerRivet()),
            const Positioned(
                right: 6, bottom: 12, child: _CornerRivet()),
            // Main content.
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // "WAYBILL / EST. 2026" tiny header strip — reads like
                  // a printed manifest stub.
                  Text(
                    'WAYBILL · GO7STUDIO · EST. 2026',
                    style: TextStyle(
                      color: GameColors.textMuted.withValues(alpha: 0.85),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      fontFamily: 'Courier',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        GameColors.accent,
                        const Color(0xFFFFE082),
                        GameColors.accent,
                      ],
                    ).createShader(bounds),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'WAREHOUSE\nSORT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          color: GameColors.text,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(
                              color: Color(0xAA000000),
                              blurRadius: 3,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Bottom "stamp" row: status pill + tiny forklift glyph.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color:
                                const Color(0xFF4CAF50).withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'CLEARED FOR DISPATCH',
                          style: TextStyle(
                            color: const Color(0xFF4CAF50),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                            fontFamily: 'Courier',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const StencilForklift(width: 38, height: 22),
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

class _CornerRivet extends StatelessWidget {
  const _CornerRivet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF9099A8), Color(0xFF2A303A)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 1.5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class AnimatedBackground extends StatefulWidget {
  final Widget child;

  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> {
  // No more animations — warehouse background is a static dock grid +
  // safety stripes, which reads as "warehouse" much better than the old
  // SortBloom drifting star field.

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
        const RepaintBoundary(
          child: CustomPaint(
            painter: _WarehouseDockPainter(),
            size: Size.infinite,
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Paints a subtle warehouse "dock floor" pattern: a grid of dark
/// rectangles + faint yellow safety stripes near the top and bottom
/// edges. Static — no animation cost.
class _WarehouseDockPainter extends CustomPainter {
  const _WarehouseDockPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Grid lines (faint warm gray on top of bg gradient).
    final gridPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.025)
      ..strokeWidth = 1;
    const spacing = 48.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Yellow safety hatching at very top + very bottom edges.
    final hatchPaint = Paint()
      ..color = const Color(0xFFFFC107).withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    const hatchHeight = 8.0;
    const hatchStripe = 16.0;
    void hatchBand(double y) {
      for (var x = -hatchHeight; x < size.width; x += hatchStripe) {
        final path = Path()
          ..moveTo(x, y)
          ..lineTo(x + hatchHeight, y)
          ..lineTo(x + hatchHeight + hatchHeight, y + hatchHeight)
          ..lineTo(x + hatchHeight, y + hatchHeight)
          ..close();
        canvas.drawPath(path, hatchPaint);
      }
    }
    hatchBand(0);
    hatchBand(size.height - hatchHeight);
  }

  @override
  bool shouldRepaint(covariant _WarehouseDockPainter oldDelegate) => false;
}

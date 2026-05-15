import 'dart:async';
import 'dart:math' as math;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/audio_service.dart';
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
    // Music start is fired from main.dart after runApp so the
    // audioplayers `FramePositionUpdater` doesn't leave a transient
    // scheduler callback when integration tests (which bypass main)
    // tear down between cases.
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
        ambient: true,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                _buildTopBar(),
                const SizedBox(height: 12),
                _buildLogo(),
                const SizedBox(height: 10),
                // Tagline shows ONLY on fresh-install / pre-first-clear.
                // Once the player has cleared L1 it's wasted real estate —
                // hide it forever so the HUD + Next-Milestone banner +
                // PLAY get more breathing room (Kimi audit 2026-05-15,
                // Lovart mockup independently confirmed).
                if (StorageService().getLevelStars(1) == 0) ...[
                  Text(
                    'Sort the crates. Build the empire.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: GameColors.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const WarehouseHud(),
                const NextMilestoneBanner(),
                const Spacer(flex: 2),
                _buildPlayButton(),
                const SizedBox(height: 24),
                _buildDailyChallengeSection(context),
                const SizedBox(height: 16),
                // Bottom menu cluster — Kimi audit 2026-05-15 cut:
                //   - Contracts button DELETED (redundant with PLAY which
                //     already routes through `_openLevelSelect`)
                //   - Settings MOVED to top-bar gear icon
                //   - 7 pills → 4 (Machinery + Forklifts in row 1, the
                //     two shop destinations paired; Achievements +
                //     Leaderboards in row 2 as social/browse pair)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: GameButton(
                          text: 'Machinery',
                          icon: Icons.precision_manufacturing,
                          isPrimary: false,
                          isSmall: true,
                          iconColor: const Color(0xFFE91E63), // hot pink
                          onPressed: () => _openMachineryShop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GameButton(
                          text: 'Forklifts',
                          icon: Icons.local_shipping,
                          isPrimary: false,
                          isSmall: true,
                          iconColor: const Color(0xFFFFA726), // forklift orange
                          onPressed: () => _openForkliftShop(context),
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
                          iconColor: const Color(0xFFFFD24A), // trophy gold
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
                          iconColor: const Color(0xFF66BB6A), // green
                          onPressed: () => _openLeaderboards(context),
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
              // Coin balance — gold chip with circular coin icon
              // (was the 🪙 emoji which rendered as a "?" tofu on some
              // iOS font sets).
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openDailyRewards,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF3A4250),
                        Color(0xFF252B36),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFFFFD700).withValues(alpha: 0.20),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [
                              Color(0xFFFFEB7A),
                              Color(0xFFFFC107),
                              Color(0xFFB8860B),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFF8B6914),
                            width: 1,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'C',
                            style: TextStyle(
                              color: Color(0xFF6B4F00),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_coinBalance',
                        style: const TextStyle(
                          color: GameColors.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Settings gear — moved here from the bottom menu cluster
              // (Kimi audit 2026-05-15). Universal mobile top-right
              // pattern for "set once" utility. Same square-icon
              // styling as the daily-rewards gift below for visual
              // consistency.
              Builder(builder: (context) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openSettings(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: GameColors.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: GameColors.textMuted.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.settings,
                      color: GameColors.textMuted,
                      size: 24,
                    ),
                  ),
                );
              }),

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
              icon: _isDailyCompleted
                  ? Icons.check_circle
                  : Icons.calendar_today,
              isPrimary: false,
              isSmall: true,
              iconColor: _isDailyCompleted
                  ? const Color(0xFF4CAF50) // green when complete
                  : const Color(0xFFFFC107), // accent yellow daily reminder
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
    return _JuicyPlayButton(onTap: () => _openLevelSelect(context));
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
        // Shrunk 340 → 280 (Kimi audit 2026-05-15). The placard was
        // out-massing PLAY for visual weight on the 6.7" iPhone. Smaller
        // placard lets PLAY win the eye while keeping the warehouse-
        // brand wordmark legible at scale.
        constraints: const BoxConstraints(maxWidth: 280),
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
                          // Shrunk 38 → 32 (Kimi audit). Combined with
                          // the smaller placard maxWidth, the wordmark
                          // now sits as a secondary identity element
                          // rather than competing with PLAY for the
                          // primary visual anchor.
                          fontSize: 32,
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
                      const _DispatchStatusPill(),
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

/// The home screen's hero PLAY button — pulses, glows, and idle-shakes
/// like a forklift revving its engine. Press-down squashes it, release
/// pops with overshoot. The truck icon also bobs subtly inside the
/// button so even at idle the menu feels alive.
class _JuicyPlayButton extends StatefulWidget {
  final VoidCallback onTap;
  const _JuicyPlayButton({required this.onTap});

  @override
  State<_JuicyPlayButton> createState() => _JuicyPlayButtonState();
}

class _JuicyPlayButtonState extends State<_JuicyPlayButton>
    with TickerProviderStateMixin {
  // Slow breath: 1.0 → 1.04 → 1.0 over 2.0s, repeating.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);
  // Forklift bob: tiny up-down on the truck icon.
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);
  // Tap squash: scale to 0.95 on press, snap back.
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
  );
  // Idle micro-wiggle every ~5s so the eye keeps returning.
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  Timer? _wiggleTimer;

  @override
  void initState() {
    super.initState();
    _wiggleTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!mounted) return;
        _wiggle.forward(from: 0);
      },
    );
  }

  @override
  void deactivate() {
    // Stop tickers before the ancestor restructure so TickerMode
    // lookups don't fire against a deactivated parent.
    _breath.stop();
    _bob.stop();
    _press.stop();
    _wiggle.stop();
    _wiggleTimer?.cancel();
    super.deactivate();
  }

  @override
  void dispose() {
    _wiggleTimer?.cancel();
    _breath.dispose();
    _bob.dispose();
    _press.dispose();
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        HapticFeedback.mediumImpact();
        AudioService().playTap();
        widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_breath, _bob, _press, _wiggle]),
        builder: (context, _) {
          // Breath scale: 1.00 → 1.04 with the cosine of the controller
          // so the curve is smooth at top and bottom of the cycle.
          final breath = 1.0 + 0.04 * (1.0 - math.cos(_breath.value * math.pi)) / 2.0;
          // Press squash + wiggle nudge stack onto the breath.
          final squash = 1.0 - _press.value * 0.06;
          final wiggleX = math.sin(_wiggle.value * math.pi * 3) *
              4.0 *
              (1.0 - _wiggle.value);
          final bob = math.sin(_bob.value * math.pi) * 2.5;

          return Transform.translate(
            offset: Offset(wiggleX, 0),
            child: Transform.scale(
              scale: breath * squash,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.symmetric(
                  vertical: 22,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFD24A),
                      GameColors.accent,
                      Color(0xFFE6A800),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    // Outer glow — pulses with the breath.
                    BoxShadow(
                      color: GameColors.accent
                          .withValues(alpha: 0.35 + (breath - 1.0) * 6),
                      blurRadius: 28,
                      spreadRadius: 2 + (breath - 1.0) * 12,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(0, bob),
                      child: const Icon(
                        Icons.local_shipping,
                        size: 34,
                        color: GameColors.text,
                        shadows: [
                          Shadow(
                            color: Color(0x77000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'PLAY',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: GameColors.text,
                        letterSpacing: 4,
                        shadows: [
                          Shadow(
                            color: Color(0x88000000),
                            blurRadius: 3,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The green "CLEARED FOR DISPATCH" pill — pulses a faint LED dot on
/// the left + breathes the border so the placard reads as a "system
/// online" indicator instead of a static stamp. Lifecycle-safe (stops
/// in deactivate so it doesn't fire during navigation tear-down).
class _DispatchStatusPill extends StatefulWidget {
  const _DispatchStatusPill();

  @override
  State<_DispatchStatusPill> createState() => _DispatchStatusPillState();
}

class _DispatchStatusPillState extends State<_DispatchStatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void deactivate() {
    _ctrl.stop();
    super.deactivate();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF4CAF50);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // 0..1 → 0.5..1.0 brightness via sine.
        final t = _ctrl.value;
        final pulse = 0.5 + 0.5 * math.sin(t * math.pi);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: green.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: green.withValues(alpha: 0.4 + pulse * 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: green.withValues(alpha: pulse * 0.30),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // LED dot — brightest when pulse is at 1.
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: green.withValues(alpha: 0.6 + pulse * 0.4),
                  boxShadow: [
                    BoxShadow(
                      color: green.withValues(alpha: pulse * 0.6),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'CLEARED FOR DISPATCH',
                style: TextStyle(
                  color: green,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  fontFamily: 'Courier',
                ),
              ),
            ],
          ),
        );
      },
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
  /// When true, also paint the ambient drifting motes + idle forklift
  /// pass. Off by default so screens with their own foreground (game
  /// board, contract list) don't compete with background ambience.
  final bool ambient;

  const AnimatedBackground({
    super.key,
    required this.child,
    this.ambient = false,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> {
  // Ambient animations live in _WarehouseAmbience (its own State) so the
  // tickers aren't owned by the screen background — they tear down
  // cleanly during navigation without dragging the parent's TickerMode
  // lookup into the deactivate path.

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
        // Ambient ticker-driven motes + idle forklift live in their
        // own State so they don't share TickerMode with the rest of
        // the screen tree.
        if (widget.ambient) const Positioned.fill(child: _WarehouseAmbience()),
        widget.child,
      ],
    );
  }
}

/// Owns the ambient drifting-mote + periodic forklift animations.
/// Wrapped in its own State so the tickers are isolated from the
/// AnimatedBackground / Scaffold tree — when the home screen tears
/// down during navigation, this widget tears down too, but its
/// tickers don't trigger TickerMode lookups in any ancestor that's
/// also being deactivated. Stops cleanly via the standard
/// AnimationController.dispose flow.
class _WarehouseAmbience extends StatefulWidget {
  const _WarehouseAmbience();

  @override
  State<_WarehouseAmbience> createState() => _WarehouseAmbienceState();
}

class _WarehouseAmbienceState extends State<_WarehouseAmbience>
    with TickerProviderStateMixin {
  late final AnimationController _moteCtrl;
  late final AnimationController _forkliftCtrl;
  Timer? _forkliftTimer;

  @override
  void initState() {
    super.initState();
    _moteCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
    _forkliftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _forkliftCtrl.forward(from: 0);
    });
    _forkliftTimer = Timer.periodic(const Duration(seconds: 18), (_) {
      if (!mounted) return;
      _forkliftCtrl.forward(from: 0);
    });
  }

  @override
  void deactivate() {
    // Stop tickers BEFORE the ancestor tree restructure happens —
    // otherwise the next tick lookup of TickerMode triggers the
    // "deactivated widget's ancestor" assertion.
    _moteCtrl.stop();
    _forkliftCtrl.stop();
    _forkliftTimer?.cancel();
    super.deactivate();
  }

  @override
  void dispose() {
    _moteCtrl.dispose();
    _forkliftCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _moteCtrl,
              builder: (context, _) => CustomPaint(
                painter: _DustMotesPainter(progress: _moteCtrl.value),
                size: Size.infinite,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _forkliftCtrl,
            builder: (context, _) {
              if (_forkliftCtrl.value == 0) return const SizedBox.shrink();
              return CustomPaint(
                size: Size.infinite,
                painter: _AmbientForkliftPainter(
                  progress: _forkliftCtrl.value,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Slow-drifting dust motes (tiny dim circles) across the screen.
/// Cheap — 30 motes, redrawn at the controller's animation rate.
class _DustMotesPainter extends CustomPainter {
  final double progress;
  static const _seed = 71;
  static const _count = 28;

  const _DustMotesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(_seed);
    final paint = Paint()..color = const Color(0xFFFFC107).withValues(alpha: 0.10);
    for (var i = 0; i < _count; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.4 + rng.nextDouble() * 0.6;
      final radius = 1.0 + rng.nextDouble() * 1.6;
      // Slow horizontal drift; wraps around screen width.
      final dx = (baseX + progress * size.width * speed) % size.width;
      // Tiny vertical bob via sine wave.
      final dy = baseY +
          math.sin((progress + i / _count) * math.pi * 2) * 8.0;
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DustMotesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Tiny ambient forklift that drives left → right across the bottom
/// quarter of the screen. Same stencil silhouette as the splash but
/// shrunk + drawn directly on the background so it puts a small life
/// signal on the home without competing with the menu.
class _AmbientForkliftPainter extends CustomPainter {
  final double progress; // 0..1
  const _AmbientForkliftPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = 60.0;
    final h = 38.0;
    // Move from off-screen left to off-screen right.
    final x = -w + progress * (size.width + w * 2);
    // Sit in lower third of the screen (above bottom nav padding).
    final y = size.height * 0.68;
    canvas.save();
    canvas.translate(x, y);

    final body = Paint()..color = const Color(0xFFFFC107).withValues(alpha: 0.55);
    final dark = Paint()..color = const Color(0xFF1A1F26).withValues(alpha: 0.65);

    // Forks
    canvas.drawRect(Rect.fromLTWH(0, h * 0.62, w * 0.22, h * 0.07), dark);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.78, w * 0.22, h * 0.07), dark);
    // Mast
    canvas.drawRect(Rect.fromLTWH(w * 0.05, h * 0.12, w * 0.06, h * 0.62), dark);
    // Cab
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.22, h * 0.28, w * 0.55, h * 0.48),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(8),
      ),
      body,
    );
    // Counterweight
    canvas.drawRect(Rect.fromLTWH(w * 0.78, h * 0.45, w * 0.20, h * 0.32), body);
    // Wheels
    canvas.drawCircle(Offset(w * 0.35, h * 0.84), h * 0.13, dark);
    canvas.drawCircle(Offset(w * 0.80, h * 0.84), h * 0.16, dark);
    // Red beacon
    canvas.drawCircle(
      Offset(w * 0.52, h * 0.22),
      h * 0.05,
      Paint()..color = const Color(0xFFE53935).withValues(alpha: 0.8),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AmbientForkliftPainter oldDelegate) =>
      oldDelegate.progress != progress;
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

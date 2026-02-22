import 'package:flutter/material.dart';
import '../models/daily_reward.dart';
import '../services/daily_rewards_service.dart';
import '../services/currency_service.dart';
import '../services/haptic_service.dart';
import '../utils/constants.dart';
import 'particles/confetti_overlay.dart';

/// Daily rewards calendar popup widget
class DailyRewardsPopup extends StatefulWidget {
  final VoidCallback? onClose;
  final bool showOnlyIfClaimable;

  const DailyRewardsPopup({
    super.key,
    this.onClose,
    this.showOnlyIfClaimable = false,
  });

  /// Show the popup as a dialog
  static Future<void> show(BuildContext context, {bool onlyIfClaimable = false}) async {
    final service = DailyRewardsService();
    await service.init();
    
    if (onlyIfClaimable) {
      final canClaim = await service.canClaimToday();
      if (!canClaim) return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => DailyRewardsPopup(
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  State<DailyRewardsPopup> createState() => _DailyRewardsPopupState();
}

class _DailyRewardsPopupState extends State<DailyRewardsPopup>
    with TickerProviderStateMixin {
  final DailyRewardsService _service = DailyRewardsService();
  final CurrencyService _currencyService = CurrencyService();
  
  late AnimationController _pulseController;
  late AnimationController _claimController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _claimScaleAnimation;
  
  Map<int, RewardStatus> _statuses = {};
  int _currentDay = 1;
  bool _canClaim = false;
  bool _showConfetti = false;
  bool _isLoading = true;
  int _coinBalance = 0;
  DailyReward? _claimedReward;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _claimController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _claimScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _claimController, curve: Curves.elasticOut),
    );
    
    _loadData();
  }

  Future<void> _loadData() async {
    await _service.init();
    await _currencyService.init();
    
    final statuses = await _service.getRewardStatuses();
    final currentDay = await _service.getCurrentDay();
    final canClaim = await _service.canClaimToday();
    final coins = await _currencyService.getCoins();
    
    if (!mounted) return;
    
    setState(() {
      _statuses = statuses;
      _currentDay = currentDay;
      _canClaim = canClaim;
      _coinBalance = coins;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _claimController.dispose();
    super.dispose();
  }

  Future<void> _claimReward() async {
    if (!_canClaim) return;
    
    // Haptic feedback
    haptics.successPattern();
    
    // Claim it
    final claimedReward = await _service.claimReward();
    
    if (claimedReward != null) {
      // Play claim animation
      _claimController.forward();
      
      // Show confetti
      setState(() {
        _showConfetti = true;
        _claimedReward = claimedReward;
      });
      
      // Reload data after a short delay
      await Future.delayed(const Duration(milliseconds: 600));
      await _loadData();
      
      // Reset animation
      _claimController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main content
          Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: GameColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: GameColors.accent.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: GameColors.accent.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                _buildCoinBalance(),
                _buildRewardGrid(),
                _buildClaimButton(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          
          // Close button
          Positioned(
            top: -12,
            right: -12,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: GameColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: GameColors.textMuted.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.close,
                  color: GameColors.textMuted,
                  size: 20,
                ),
              ),
            ),
          ),
          
          // Confetti overlay
          if (_showConfetti)
            Positioned.fill(
              child: IgnorePointer(
                child: ConfettiOverlay(
                  duration: const Duration(seconds: 2),
                  colors: GameColors.palette,
                  confettiCount: 30,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            GameColors.accent.withValues(alpha: 0.2),
            GameColors.accent.withValues(alpha: 0.05),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month,
            color: GameColors.accent,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            'Daily Rewards',
            style: TextStyle(
              color: GameColors.text,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinBalance() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: GameColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on,
            color: Color(0xFFFFD700),
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            '$_coinBalance',
            style: TextStyle(
              color: GameColors.text,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardGrid() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: CircularProgressIndicator(color: GameColors.accent),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate item width based on available space
          final itemWidth = (constraints.maxWidth - 48) / 7; // 7 items with spacing
          final clampedWidth = itemWidth.clamp(40.0, 52.0);
          
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 12,
            children: List.generate(7, (index) {
              final day = index + 1;
              final reward = dailyRewards[index];
              final status = _statuses[day] ?? RewardStatus.locked;
              
              return SizedBox(
                width: clampedWidth,
                child: _buildRewardDay(day, reward, status),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildRewardDay(int day, DailyReward reward, RewardStatus status) {
    final isCurrent = status == RewardStatus.current;
    final isClaimed = status == RewardStatus.claimed;
    // isLocked is implicit (not current, not claimed)
    final isPremium = day == 7;
    
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Day label
        Text(
          'Day $day',
          style: TextStyle(
            color: isClaimed 
                ? GameColors.textMuted 
                : isCurrent 
                    ? GameColors.text 
                    : GameColors.textMuted.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        
        // Reward box
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 52,
          decoration: BoxDecoration(
            color: isClaimed
                ? GameColors.background.withValues(alpha: 0.3)
                : isCurrent
                    ? reward.type.color.withValues(alpha: 0.15)
                    : GameColors.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isClaimed
                  ? GameColors.successGlow.withValues(alpha: 0.5)
                  : isCurrent
                      ? reward.type.color
                      : GameColors.textMuted.withValues(alpha: 0.2),
              width: isCurrent ? 2 : 1,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: reward.type.color.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildRewardIcon(reward, status, isPremium),
            ],
          ),
        ),
        
        const SizedBox(height: 4),
        
        // Amount label
        Text(
          isClaimed ? '✓' : '${reward.amount}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isClaimed
                ? GameColors.successGlow
                : isCurrent
                    ? reward.type.color
                    : GameColors.textMuted.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Reward type label
        if (!isClaimed)
          Text(
            reward.type.displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: GameColors.textMuted.withValues(alpha: 0.5),
              fontSize: 8,
            ),
          ),
      ],
    );
    
    // Add pulse animation to current day
    if (isCurrent && _canClaim) {
      content = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          );
        },
        child: content,
      );
    }
    
    return content;
  }

  Widget _buildRewardIcon(DailyReward reward, RewardStatus status, bool isPremium) {
    final isClaimed = status == RewardStatus.claimed;
    final isLocked = status == RewardStatus.locked;
    
    if (isClaimed) {
      return Icon(
        Icons.check_circle,
        color: GameColors.successGlow.withValues(alpha: 0.7),
        size: 24,
      );
    }
    
    if (isLocked) {
      return Icon(
        Icons.lock,
        color: GameColors.textMuted.withValues(alpha: 0.3),
        size: 20,
      );
    }
    
    // Current or available
    return Icon(
      reward.type.icon,
      color: reward.type.color,
      size: isPremium ? 28 : 24,
    );
  }

  Widget _buildClaimButton() {
    if (_isLoading) return const SizedBox.shrink();
    
    final currentReward = getRewardForDay(_currentDay);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          if (_claimedReward != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: GameColors.successGlow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GameColors.successGlow.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.celebration,
                    color: GameColors.successGlow,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Claimed: ${_claimedReward!.description}',
                    style: const TextStyle(
                      color: GameColors.successGlow,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          AnimatedBuilder(
            animation: _claimScaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _claimScaleAnimation.value,
                child: child,
              );
            },
            child: GestureDetector(
              onTap: _canClaim ? _claimReward : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: _canClaim
                      ? LinearGradient(
                          colors: [
                            GameColors.accent,
                            GameColors.accent.withValues(alpha: 0.8),
                          ],
                        )
                      : null,
                  color: _canClaim ? null : GameColors.background.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _canClaim
                      ? [
                          BoxShadow(
                            color: GameColors.accent.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _canClaim ? Icons.card_giftcard : Icons.timer,
                        color: _canClaim ? GameColors.text : GameColors.textMuted,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _canClaim 
                              ? 'CLAIM ${currentReward.description.toUpperCase()}'
                              : 'COME BACK TOMORROW',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _canClaim ? GameColors.text : GameColors.textMuted,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

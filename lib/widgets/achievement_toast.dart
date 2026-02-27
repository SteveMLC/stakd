import 'package:flutter/material.dart';

class AchievementToast extends StatefulWidget {
  final String achievementName;
  final int xpReward;
  final int coinReward;
  final VoidCallback? onDismiss;

  const AchievementToast({
    super.key,
    required this.achievementName,
    required this.xpReward,
    required this.coinReward,
    this.onDismiss,
  });

  @override
  State<AchievementToast> createState() => _AchievementToastState();
}

class _AchievementToastState extends State<AchievementToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Slide in
    _controller.forward();

    // Hold for 3 seconds, then slide out
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      left: MediaQuery.of(context).size.width / 2 - 140,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1622),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFFD700),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ).createShader(bounds),
                    child: const Text(
                      'ACHIEVEMENT UNLOCKED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Achievement name
              Text(
                widget.achievementName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Rewards
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildReward('⭐', widget.xpReward, const Color(0xFF4CAF50)),
                  const SizedBox(width: 16),
                  _buildReward('🪙', widget.coinReward, const Color(0xFFFFD700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReward(String emoji, int amount, Color color) {
    return Row(
      children: [
        Text(
          '+$amount',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(emoji, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

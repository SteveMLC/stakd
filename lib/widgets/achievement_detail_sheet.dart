import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/achievement.dart';
import '../screens/achievements_screen.dart';

/// Bottom sheet showing achievement details
class AchievementDetailSheet extends StatefulWidget {
  final Achievement achievement;

  const AchievementDetailSheet({
    super.key,
    required this.achievement,
  });

  @override
  State<AchievementDetailSheet> createState() => _AchievementDetailSheetState();
}

class _AchievementDetailSheetState extends State<AchievementDetailSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    if (widget.achievement.isUnlocked) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;
    final rarity = a.rarity;
    final color = RarityColors.primary(rarity);
    final isCompleted = a.isUnlocked;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header gradient + icon
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.18),
                  color.withValues(alpha: 0.06),
                  Colors.white,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Column(
              children: [
                // Icon circle with glow
                _buildDetailIcon(color, isCompleted),
                const SizedBox(height: 12),
                // Title
                Text(
                  a.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 8),
                // Rarity badge — filled
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    RarityColors.label(rarity),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              a.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF666666),
                height: 1.4,
              ),
            ),
          ),

          // Completion info
          if (isCompleted && a.unlockedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                '✅ Earned on ${DateFormat('MMM d, y').format(a.unlockedAt!)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2ECC71),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Divider(color: Color(0xFFEEEEEE), thickness: 1),
          ),

          const SizedBox(height: 12),

          // Reward pill
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF3CD), Color(0xFFFFE082)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFE6A800),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  '+${a.ppReward} PP',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B6914),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Share button
          Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Share functionality
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.share, size: 18),
                label: const Text(
                  'Share Achievement',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailIcon(Color color, bool isCompleted) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: isCompleted
                  ? [
                      color.withValues(alpha: 0.2),
                      color.withValues(alpha: 0.5),
                    ]
                  : [
                      const Color(0xFFE8E8E8),
                      const Color(0xFFCCCCCC),
                    ],
              center: Alignment.center,
              radius: 0.8,
            ),
            border: Border.all(
              color: isCompleted ? color : const Color(0xFFCCCCCC),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: isCompleted
                    ? color.withValues(alpha: _glowAnimation.value * 0.3)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                spreadRadius: isCompleted ? 4 : 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            RarityColors.categoryIcon(widget.achievement.category),
            color: isCompleted ? color : const Color(0xFFBBBBBB),
            size: 36,
          ),
        );
      },
    );
  }
}

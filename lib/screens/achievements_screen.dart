import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/achievement.dart';
import '../data/achievement_definitions.dart';
import '../services/achievement_service.dart';
import '../widgets/achievement_detail_sheet.dart';

/// Rarity color helpers used across achievement UI
class RarityColors {
  static Color primary(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return const Color(0xFF2ECC71);
      case AchievementRarity.rare:
        return const Color(0xFF3498DB);
      case AchievementRarity.epic:
        return const Color(0xFFF39C12);
      case AchievementRarity.legendary:
        return const Color(0xFFFFD700);
    }
  }

  static Color lightTint(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return const Color(0xFFE8F5E9);
      case AchievementRarity.rare:
        return const Color(0xFFE3F2FD);
      case AchievementRarity.epic:
        return const Color(0xFFFFF8E1);
      case AchievementRarity.legendary:
        return const Color(0xFFFFFDE7);
    }
  }

  static String label(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return 'BASIC';
      case AchievementRarity.rare:
        return 'RARE';
      case AchievementRarity.epic:
        return 'MILESTONE';
      case AchievementRarity.legendary:
        return 'PP';
    }
  }

  static IconData categoryIcon(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.gameplay:
        return Icons.emoji_events;
      case AchievementCategory.speed:
        return Icons.timer;
      case AchievementCategory.collection:
        return Icons.collections_bookmark;
      case AchievementCategory.mastery:
        return Icons.star;
      case AchievementCategory.social:
        return Icons.people;
      case AchievementCategory.special:
        return Icons.auto_awesome;
    }
  }
}

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late List<Achievement> _achievements;
  final AchievementService _service = AchievementService();

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  void _loadAchievements() {
    final defaults = getDefaultAchievements();
    _achievements = defaults.map((a) {
      final unlocked = _service.isUnlocked(a.id);
      if (unlocked) {
        return a.copyWith(
          isUnlocked: true,
          unlockedAt: _getUnlockDate(a.id),
        );
      }
      return a;
    }).toList();
  }

  DateTime? _getUnlockDate(String id) {
    // The service stores dates as ISO strings in SharedPreferences
    // For now return a placeholder; the service could expose this
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _achievements.where((a) => a.isUnlocked).length;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Achievements',
          style: TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$unlocked/${_achievements.length}',
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: _achievements.length,
          itemBuilder: (context, index) {
            return _AchievementCard(
              achievement: _achievements[index],
              onTap: () => _showDetail(_achievements[index]),
            );
          },
        ),
      ),
    );
  }

  void _showDetail(Achievement achievement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AchievementDetailSheet(achievement: achievement),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback onTap;

  const _AchievementCard({
    required this.achievement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rarity = achievement.rarity;
    final color = RarityColors.primary(rarity);
    final tint = RarityColors.lightTint(rarity);
    final isCompleted = achievement.isUnlocked;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isCompleted ? tint : const Color(0xFFF5F5F5),
          gradient: isCompleted
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tint,
                    tint.withValues(alpha: 0.5),
                    Colors.white,
                  ],
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: isCompleted
                  ? color.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: isCompleted ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon circle with depth
                  _buildIconCircle(color, isCompleted),
                  const SizedBox(height: 10),
                  // Title
                  Text(
                    achievement.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isCompleted
                          ? const Color(0xFF333333)
                          : const Color(0xFFAAAAAA),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Rarity tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isCompleted ? 1.0 : 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      RarityColors.label(rarity),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color:
                            isCompleted ? Colors.white : color.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Completion date
                  if (isCompleted && achievement.unlockedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        DateFormat('MMM d').format(achievement.unlockedAt!),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF999999),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Checkmark badge for completed
            if (isCompleted)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF2ECC71),
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconCircle(Color color, bool isCompleted) {
    final icon = RarityColors.categoryIcon(achievement.category);

    Widget iconWidget = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isCompleted
              ? [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.4),
                ]
              : [
                  const Color(0xFFE0E0E0),
                  const Color(0xFFBDBDBD),
                ],
          center: Alignment.center,
          radius: 0.8,
        ),
        border: Border.all(
          color: isCompleted ? color.withValues(alpha: 0.5) : const Color(0xFFD0D0D0),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isCompleted
                ? color.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            spreadRadius: 1,
          ),
          // Outer glow ring for completed
          if (isCompleted)
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 16,
              spreadRadius: 4,
            ),
        ],
      ),
      child: Icon(
        icon,
        color: isCompleted ? color : const Color(0xFFBBBBBB),
        size: 26,
      ),
    );

    // Greyscale filter for locked cards
    if (!isCompleted) {
      iconWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}

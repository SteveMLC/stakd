import 'package:flutter/material.dart';
import '../models/achievement.dart';

/// Achievement toast theme colors and sizes
class AchievementToastTheme {
  // Core colors
  static const Color goldAccent = Color(0xFFFFD700);
  static const Color goldBorder = Color(0x50FFD700); // 50% opacity
  static const Color charcoalDark = Color(0xFF1A1A1A);
  static const Color charcoalMid = Color(0xFF2D2D2D);
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70% opacity
  
  // Rarity tints (applied as gradient overlay)
  static const Color rarityCommon = Color(0xFF2D2D2D);
  static const Color rarityRare = Color(0xFF1E3A5F); // Blue tint
  static const Color rarityEpic = Color(0xFF3D1F5C); // Purple tint
  static const Color rarityLegendary = Color(0xFF4A3D00); // Gold tint
  
  // Rarity glow colors
  static const Color glowCommon = Color(0x00000000); // No glow
  static const Color glowRare = Color(0x401E90FF); // Blue glow
  static const Color glowEpic = Color(0x40A855EA); // Purple glow
  static const Color glowLegendary = Color(0x60FFD700); // Gold glow
  
  // Sizes
  static const double cardWidth = 320.0;
  static const double cardMinWidth = 300.0;
  static const double cardMaxWidth = 340.0;
  static const double iconSize = 44.0;
  static const double iconBorderWidth = 2.0;
  static const double borderRadius = 12.0;
  static const double cardBorderWidth = 1.0;
  static const double chipBorderRadius = 16.0;
  
  // Padding
  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: 12.0,
    vertical: 10.0,
  );
  
  // Typography
  static const double titleSize = 16.0;
  static const double subtitleSize = 12.0;
  static const double chipTextSize = 13.0;
  
  /// Get background color for rarity
  static Color getBackgroundColor(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return rarityCommon;
      case AchievementRarity.rare:
        return rarityRare;
      case AchievementRarity.epic:
        return rarityEpic;
      case AchievementRarity.legendary:
        return rarityLegendary;
    }
  }
  
  /// Get glow color for rarity
  static Color getGlowColor(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return glowCommon;
      case AchievementRarity.rare:
        return glowRare;
      case AchievementRarity.epic:
        return glowEpic;
      case AchievementRarity.legendary:
        return glowLegendary;
    }
  }
  
  /// Get border color for rarity
  static Color getBorderColor(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return goldBorder;
      case AchievementRarity.rare:
        return const Color(0x501E90FF);
      case AchievementRarity.epic:
        return const Color(0x50A855EA);
      case AchievementRarity.legendary:
        return goldAccent.withValues(alpha: 0.6);
    }
  }
}

/// A toast card displaying an unlocked achievement
/// 
/// Layout:
/// ┌──────────────────────────────────────────┐
/// │ [🏆]  Achievement Title        [+10 PP] │
/// │  ↑     Optional subtitle line      ↑    │
/// │ 44px                            chip    │
/// │ icon                                    │
/// └──────────────────────────────────────────┘
class AchievementToastCard extends StatelessWidget {
  /// The achievement to display
  final Achievement achievement;
  
  /// Called when the card is tapped
  final VoidCallback onTap;
  
  /// Called when the close button is tapped (optional)
  final VoidCallback? onClose;

  const AchievementToastCard({
    super.key,
    required this.achievement,
    required this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final rarity = achievement.rarity;
    final backgroundColor = AchievementToastTheme.getBackgroundColor(rarity);
    final glowColor = AchievementToastTheme.getGlowColor(rarity);
    final borderColor = AchievementToastTheme.getBorderColor(rarity);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: AchievementToastTheme.cardWidth,
        constraints: const BoxConstraints(
          minWidth: AchievementToastTheme.cardMinWidth,
          maxWidth: AchievementToastTheme.cardMaxWidth,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AchievementToastTheme.borderRadius),
          border: Border.all(
            color: borderColor,
            width: AchievementToastTheme.cardBorderWidth,
          ),
          boxShadow: [
            // Elevation shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            // Rarity glow
            if (glowColor != Colors.transparent)
              BoxShadow(
                color: glowColor,
                blurRadius: 16,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: AchievementToastTheme.cardPadding,
              child: Row(
                children: [
                  // Left: Icon
                  _buildIcon(),
                  const SizedBox(width: 12),
                  // Center: Text
                  Expanded(child: _buildText()),
                  const SizedBox(width: 8),
                  // Right: PP Chip
                  _buildRewardChip(),
                ],
              ),
            ),
            // Close button (optional)
            if (onClose != null)
              Positioned(
                top: 4,
                right: 4,
                child: _buildCloseButton(),
              ),
          ],
        ),
      ),
    );
  }

  /// Build the circular icon with gold ring
  Widget _buildIcon() {
    return Container(
      width: AchievementToastTheme.iconSize,
      height: AchievementToastTheme.iconSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AchievementToastTheme.goldAccent,
          width: AchievementToastTheme.iconBorderWidth,
        ),
        gradient: RadialGradient(
          colors: [
            AchievementToastTheme.charcoalMid,
            AchievementToastTheme.charcoalDark,
          ],
          center: Alignment.topLeft,
          radius: 1.2,
        ),
        boxShadow: [
          // Inner shadow effect via gradient
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          _getCategoryIcon(),
          color: AchievementToastTheme.goldAccent,
          size: 22,
        ),
      ),
    );
  }

  /// Get icon based on achievement category
  IconData _getCategoryIcon() {
    switch (achievement.category) {
      case AchievementCategory.gameplay:
        return Icons.emoji_events; // Trophy
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

  /// Build the title and subtitle text
  Widget _buildText() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          achievement.title,
          style: const TextStyle(
            fontSize: AchievementToastTheme.titleSize,
            fontWeight: FontWeight.w600,
            color: AchievementToastTheme.textPrimary,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        // Subtitle
        Text(
          achievement.description,
          style: const TextStyle(
            fontSize: AchievementToastTheme.subtitleSize,
            fontWeight: FontWeight.w400,
            color: AchievementToastTheme.textSecondary,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Build the PP reward chip
  Widget _buildRewardChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AchievementToastTheme.charcoalDark,
        borderRadius: BorderRadius.circular(AchievementToastTheme.chipBorderRadius),
        border: Border.all(
          color: AchievementToastTheme.goldAccent.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // PP icon (diamond)
          const Icon(
            Icons.diamond,
            color: AchievementToastTheme.goldAccent,
            size: 14,
          ),
          const SizedBox(width: 4),
          // PP amount
          Text(
            '+${achievement.ppReward}',
            style: const TextStyle(
              fontSize: AchievementToastTheme.chipTextSize,
              fontWeight: FontWeight.w700,
              color: AchievementToastTheme.goldAccent,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the close button
  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: onClose,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.close,
          color: AchievementToastTheme.textSecondary,
          size: 14,
        ),
      ),
    );
  }
}

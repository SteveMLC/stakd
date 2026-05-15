import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../utils/constants.dart';
import 'warehouse_decorations.dart';

/// Achievement toast theme — warehouse manifest vocabulary.
///
/// Renders an unlocked achievement as a "DISPATCH STAMPED" notice
/// instead of a generic gold trophy banner. Top hazard stripe, brushed-
/// steel body, Courier monospace header strip, stamped-certificate PP
/// chip. Reads consistently with the SHIPMENT RECEIPT + dispatch
/// vocabulary used everywhere else in the app.
class AchievementToastTheme {
  // Core warehouse palette — anchored to GameColors.
  static const Color accent = GameColors.accent;            // safety yellow
  static const Color accentSoft = Color(0x55FFC107);         // border tint
  static const Color steelDark = Color(0xFF1A1F26);          // background base
  static const Color steelMid = Color(0xFF252B36);           // surface
  static const Color steelLight = Color(0xFF3A4250);         // top of gradient

  // Text colors.
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70% opacity

  // Rarity tints — kept distinct so legendary still feels special, but
  // pulled toward the warehouse palette so they no longer look like a
  // different app. Common = steel mid; rare/epic/legendary blend an
  // industrial accent into the steel base.
  static const Color rarityCommon = steelMid;
  static const Color rarityRare = Color(0xFF1F3038);          // dock-blue tint
  static const Color rarityEpic = Color(0xFF2E2540);          // dispatch-purple
  static const Color rarityLegendary = Color(0xFF3A2E14);     // burnt-amber

  // Rarity glow colors — accent-yellow for legendary so it matches the
  // multiplier reveal pulse + the hazard stripe motif.
  static const Color glowCommon = Color(0x00000000); // No glow
  static const Color glowRare = Color(0x405DADE2);    // dock blue glow
  static const Color glowEpic = Color(0x40A855EA);    // dispatch purple
  static const Color glowLegendary = Color(0x60FFC107); // safety yellow
  
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
  
  /// Get border color for rarity — all anchored to the accent-yellow
  /// safety palette so the toast reads as a warehouse notice, with
  /// rarity-specific tinting layered on top.
  static Color getBorderColor(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return accentSoft;
      case AchievementRarity.rare:
        return const Color(0x705DADE2);
      case AchievementRarity.epic:
        return const Color(0x70A855EA);
      case AchievementRarity.legendary:
        return accent.withValues(alpha: 0.75);
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
    final tint = AchievementToastTheme.getBackgroundColor(rarity);
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
          // Brushed-steel 3-stop gradient with rarity tint blended into
          // the mid stop — keeps the warehouse vocabulary while still
          // distinguishing legendary from common visually.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AchievementToastTheme.steelLight,
              Color.lerp(AchievementToastTheme.steelMid, tint, 0.55)!,
              AchievementToastTheme.steelDark,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius:
              BorderRadius.circular(AchievementToastTheme.borderRadius),
          border: Border.all(
            color: borderColor,
            width: AchievementToastTheme.cardBorderWidth,
          ),
          boxShadow: [
            // Elevation shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
            // Rarity glow
            if (glowColor != Colors.transparent)
              BoxShadow(
                color: glowColor,
                blurRadius: 18,
                spreadRadius: 2,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(AchievementToastTheme.borderRadius),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top hazard stripe — same vocabulary as receipt +
                  // achievement detail sheet headers.
                  const HazardStripe(height: 4, stripeWidth: 10),
                  // Courier-stenciled "DISPATCH STAMPED" header strip.
                  _buildDispatchHeader(rarity),
                  // Main row: icon + title/desc + PP chip.
                  Padding(
                    padding: AchievementToastTheme.cardPadding,
                    child: Row(
                      children: [
                        _buildIcon(),
                        const SizedBox(width: 12),
                        Expanded(child: _buildText()),
                        const SizedBox(width: 8),
                        _buildRewardChip(),
                      ],
                    ),
                  ),
                ],
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
      ),
    );
  }

  /// Stenciled "DISPATCH STAMPED" header strip beneath the top hazard
  /// band. Includes the rarity label on the right so a legendary toast
  /// reads "DISPATCH STAMPED · LEGENDARY" — sells the moment.
  Widget _buildDispatchHeader(AchievementRarity rarity) {
    final rarityLabel = RarityColors.label(rarity).toUpperCase();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border(
          bottom: BorderSide(
            color: AchievementToastTheme.accent.withValues(alpha: 0.30),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 11,
            color: AchievementToastTheme.accent.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 6),
          const Text(
            'DISPATCH STAMPED',
            style: TextStyle(
              color: AchievementToastTheme.accent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              fontFamily: 'Courier',
            ),
          ),
          const Spacer(),
          Text(
            rarityLabel,
            style: TextStyle(
              color: AchievementToastTheme.accent.withValues(alpha: 0.75),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              fontFamily: 'Courier',
            ),
          ),
        ],
      ),
    );
  }

  /// Build the embossed brushed-steel circular icon. Reads as a riveted
  /// metal medallion (same vocabulary as MetalNameplate) rather than a
  /// gold trophy ring.
  Widget _buildIcon() {
    return Container(
      width: AchievementToastTheme.iconSize,
      height: AchievementToastTheme.iconSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AchievementToastTheme.accent,
          width: AchievementToastTheme.iconBorderWidth,
        ),
        gradient: const RadialGradient(
          colors: [
            Color(0xFF4A525E),       // brushed steel highlight
            Color(0xFF2A2F38),       // mid
            Color(0xFF14181E),       // shadow base
          ],
          center: Alignment(-0.4, -0.5),
          radius: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 5,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          _getCategoryIcon(),
          color: AchievementToastTheme.accent,
          size: 22,
        ),
      ),
    );
  }

  /// Get icon based on achievement category — Material outlined glyphs
  /// chosen to match the warehouse-tool / dispatch vocabulary used
  /// across the rest of the app (machinery shop, forklift shop, HUD).
  IconData _getCategoryIcon() {
    switch (achievement.category) {
      case AchievementCategory.gameplay:
        return Icons.precision_manufacturing_outlined; // forklift-adjacent
      case AchievementCategory.speed:
        return Icons.bolt_outlined;                    // dispatch-speed
      case AchievementCategory.collection:
        return Icons.inventory_2_outlined;             // crate stack
      case AchievementCategory.mastery:
        return Icons.workspace_premium_outlined;       // certified medallion
      case AchievementCategory.social:
        return Icons.groups_outlined;                  // dock crew
      case AchievementCategory.special:
        return Icons.local_shipping_outlined;          // special dispatch
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

  /// Build the PP reward chip as a stamped-certificate badge — accent
  /// border + Courier label + tiny "PP" stencil suffix instead of a
  /// pip+number layout. Matches the achievement-detail-sheet PP badge.
  Widget _buildRewardChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AchievementToastTheme.steelDark.withValues(alpha: 0.85),
        borderRadius:
            BorderRadius.circular(AchievementToastTheme.chipBorderRadius),
        border: Border.all(
          color: AchievementToastTheme.accent.withValues(alpha: 0.65),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AchievementToastTheme.accent.withValues(alpha: 0.18),
            blurRadius: 4,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // Reward amount — slightly larger, w900 Courier so it reads
          // like a stamped value field on a waybill.
          Text(
            '+${achievement.ppReward}',
            style: const TextStyle(
              fontSize: AchievementToastTheme.chipTextSize,
              fontWeight: FontWeight.w900,
              color: AchievementToastTheme.accent,
              fontFamily: 'Courier',
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 3),
          // "PP" suffix in a smaller Courier — same vocabulary as the
          // detail-sheet reward badge.
          Text(
            'PP',
            style: TextStyle(
              fontSize: AchievementToastTheme.chipTextSize - 3,
              fontWeight: FontWeight.w900,
              color: AchievementToastTheme.accent.withValues(alpha: 0.7),
              fontFamily: 'Courier',
              letterSpacing: 1.0,
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/business_tier_service.dart';
import '../services/income_multiplier_service.dart';
import '../services/machinery_service.dart';
import '../services/reputation_service.dart';
import '../services/warehouse_economy_service.dart';
import '../utils/constants.dart';
import '../utils/number_format.dart';
import 'warehouse_decorations.dart';

/// Lightweight HUD showing cash + warehouse level + XP progress.
/// Drop on the top of any screen that wants the player's meta-state in view.
class WarehouseHud extends StatelessWidget {
  final bool showTierBadge;
  final EdgeInsetsGeometry padding;

  const WarehouseHud({
    super.key,
    this.showTierBadge = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<WarehouseEconomyService>();
    final tiers = context.watch<BusinessTierService>();
    final incomeMul = context.watch<IncomeMultiplierService>();
    // Watch machinery so the multiplier pill repaints when a player buys
    // a new machine — MachineryService is the 5th input into computeMultiplier.
    context.watch<MachineryService>();
    // Watch reputation so the second-row strip + the multiplier pill
    // both repaint when a tier promotion fires.
    final reputation = context.watch<ReputationService>();
    final mul = incomeMul.computeMultiplier(
      warehouseLevel: economy.warehouseLevel,
    );

    return Padding(
      padding: padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: GameColors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: GameColors.accent.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top hazard band — instantly signals "industrial".
              const HazardStripe(height: 4, stripeWidth: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    _CashChip(amount: economy.cash),
                    const SizedBox(width: 10),
                    _MultiplierPill(multiplier: mul),
                    const SizedBox(width: 12),
                    Expanded(child: _LevelBar(economy: economy)),
                    if (showTierBadge) ...[
                      const SizedBox(width: 10),
                      _TierBadge(info: tiers.selectedTierInfo),
                    ],
                  ],
                ),
              ),
              // Second-row "REPUTATION" strip — the infinite-scaling
              // tier ladder readout. Always visible (reads "Unranked
              // · 0/5" at fresh install so the next-goal beat is
              // explicit). Compact 24dp tall — doesn't crowd the
              // gameplay screen below.
              _ReputationStrip(reputation: reputation),
            ],
          ),
        ),
      ),
    );
  }
}

class _MultiplierPill extends StatelessWidget {
  final double multiplier;
  const _MultiplierPill({required this.multiplier});

  @override
  Widget build(BuildContext context) {
    // Only show the pill once the player has earned anything above base.
    if (multiplier <= 1.001) return const SizedBox.shrink();
    final color = multiplier >= 3.0
        ? const Color(0xFFFF6B35) // hot — flames-y red-orange
        : multiplier >= 2.0
            ? const Color(0xFFFFC107) // mid — safety yellow
            : const Color(0xFF4CAF50); // starting — green growth
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            '×${multiplier.toStringAsFixed(multiplier >= 10 ? 0 : 1)}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashChip extends StatefulWidget {
  final int amount;
  const _CashChip({required this.amount});

  @override
  State<_CashChip> createState() => _CashChipState();
}

class _CashChipState extends State<_CashChip> {
  late int _displayed = widget.amount;
  int _from = 0;

  @override
  void didUpdateWidget(covariant _CashChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount) {
      _from = _displayed;
      // _displayed updates inside the builder via the tween value.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Gold dollar disc — matches the home coin chip styling so the
        // currency vocabulary is consistent across the HUD and top
        // bar. The flat Icons.attach_money felt like a placeholder.
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
            border: Border.all(color: const Color(0xFF8B6914), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.45),
                blurRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '\$',
              style: TextStyle(
                color: Color(0xFF6B4F00),
                fontWeight: FontWeight.w900,
                fontSize: 13,
                height: 1.1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        TweenAnimationBuilder<double>(
          // Tween from previous value to new value; format as we go for
          // a satisfying "numbers go UP" ticker.
          tween: Tween<double>(
            begin: _from.toDouble(),
            end: widget.amount.toDouble(),
          ),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          onEnd: () => _displayed = widget.amount,
          builder: (context, value, _) {
            final shown = value.round();
            // Route through the shared `formatCashCompact` helper —
            // K/M/B/T/Qa/Qi/.../Qid suffix progression to 10^48, then
            // scientific notation. Replaces the old custom _format
            // that capped at billions with lowercase 'k'. Compact
            // 1-decimal variant fits the HUD chip width across the
            // whole infinite-scaling range.
            return Text(
              formatCashCompact(shown),
              style: const TextStyle(
                color: GameColors.text,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: 0.5,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LevelBar extends StatefulWidget {
  final WarehouseEconomyService economy;
  const _LevelBar({required this.economy});

  @override
  State<_LevelBar> createState() => _LevelBarState();
}

class _LevelBarState extends State<_LevelBar> {
  // Smoothly tween the progress bar fill so XP gains read as a
  // satisfying "moving forward" beat instead of an instant snap.
  late double _displayed;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _displayed = widget.economy.levelProgressFraction;
  }

  @override
  void didUpdateWidget(covariant _LevelBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.economy.levelProgressFraction;
    if (next != _displayed) {
      _from = _displayed;
      _displayed = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.economy.warehouseLevel;
    final inLevel = widget.economy.xpInCurrentLevel;
    final needed = widget.economy.xpNeededForCurrentLevel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: GameColors.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: GameColors.accent.withValues(alpha: 0.45),
                  width: 0.8,
                ),
              ),
              child: Text(
                'WH Lv $level',
                style: const TextStyle(
                  color: GameColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '$inLevel/$needed XP',
              style: const TextStyle(
                color: GameColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Animated tween fill — wraps the LinearProgressIndicator in
        // a 700ms easeOutCubic tween so XP gains slide rather than
        // snap. The bar itself stays the same shape so we can swap
        // in a fancier custom painter later without API changes.
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: _from, end: _displayed),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Stack(
              children: [
                LinearProgressIndicator(
                  value: value,
                  minHeight: 7,
                  backgroundColor:
                      GameColors.background.withValues(alpha: 0.5),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    GameColors.accent,
                  ),
                ),
                // Bright leading-edge highlight on the fill so the
                // tween reads as "advancing" not "lengthening".
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            GameColors.accent.withValues(alpha: 0.0),
                            GameColors.accent.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.55),
                          ],
                          stops: const [0.0, 0.85, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TierBadge extends StatelessWidget {
  final BusinessTierInfo info;
  const _TierBadge({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: GameColors.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: GameColors.accent.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_shipping, size: 12, color: GameColors.text),
          const SizedBox(width: 4),
          Text(
            info.shortName,
            style: const TextStyle(
              color: GameColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Second-row HUD strip showing the player's Reputation tier + progress
/// toward the next promotion. The infinite-scaling meta-economy lives
/// here — every district cleared grants RP, every tier promotion grants
/// +0.10× permanent income, the ladder runs forever (Bronze → Silver
/// → ... → Legendary → Legendary II → Legendary III → ...).
///
/// Compact ~24dp tall: short Courier label on the left, progress bar
/// in the middle, RP count on the right. Always rendered (reads
/// "Unranked · 0/5 RP" at fresh install so the next-goal beat is
/// explicit and the player learns the system exists before they earn
/// their first RP).
class _ReputationStrip extends StatelessWidget {
  final ReputationService reputation;
  const _ReputationStrip({required this.reputation});

  @override
  Widget build(BuildContext context) {
    final progress = reputation.progressToNextTier;
    final rp = reputation.totalRp;
    final next = reputation.rpForNextTier;
    final tierName = reputation.displayName;
    final isUnranked = reputation.currentTierLevel == 0;

    // Compact layout: total height ≈ 14dp (2 top + 4 bar + 2 bottom +
    // label/text overlap). Original 24dp variant overflowed the home
    // screen's fixed Column by 15px — this slimmer pass fits cleanly
    // inside the existing HUD container without forcing a home_screen
    // layout refactor.
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: GameColors.accent.withValues(alpha: 0.18),
            width: 0.6,
          ),
        ),
      ),
      child: Row(
        children: [
          // Tier label — Courier stencil, accent border. Reads as a
          // dock-floor rank stamp. Dimmed at "Unranked" so the player
          // notices when it lights up on first Bronze promotion.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: isUnranked
                  ? GameColors.textMuted.withValues(alpha: 0.12)
                  : GameColors.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: isUnranked
                    ? GameColors.textMuted.withValues(alpha: 0.45)
                    : GameColors.accent.withValues(alpha: 0.55),
                width: 0.8,
              ),
            ),
            child: Text(
              tierName.toUpperCase(),
              style: TextStyle(
                color: isUnranked ? GameColors.textMuted : GameColors.accent,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontFamily: 'Courier',
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Progress bar — thin accent fill, matches WH level bar
          // shape so the player reads them as related.
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor:
                    GameColors.background.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isUnranked
                      ? GameColors.textMuted.withValues(alpha: 0.7)
                      : GameColors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // RP count — "{current}/{nextThreshold}" in tight Courier.
          Text(
            '$rp/$next',
            style: const TextStyle(
              color: GameColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              fontFamily: 'Courier',
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

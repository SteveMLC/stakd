import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/business_tier_service.dart';
import '../services/income_multiplier_service.dart';
import '../services/machinery_service.dart';
import '../services/warehouse_economy_service.dart';
import '../utils/constants.dart';
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
            return Text(
              _format(shown),
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

  static String _format(int n) {
    if (n < 1000) return n.toString();
    if (n < 1000000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k >= 100 ? 0 : 1)}k';
    }
    if (n < 1000000000) {
      final m = n / 1000000;
      return '${m.toStringAsFixed(m >= 100 ? 0 : 1)}M';
    }
    final b = n / 1000000000;
    return '${b.toStringAsFixed(b >= 100 ? 0 : 1)}B';
  }
}

class _LevelBar extends StatelessWidget {
  final WarehouseEconomyService economy;
  const _LevelBar({required this.economy});

  @override
  Widget build(BuildContext context) {
    final level = economy.warehouseLevel;
    final fraction = economy.levelProgressFraction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'WH Lv $level',
              style: const TextStyle(
                color: GameColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Text(
              '${economy.xpInCurrentLevel}/${economy.xpNeededForCurrentLevel} XP',
              style: const TextStyle(
                color: GameColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: GameColors.background.withValues(alpha: 0.4),
            valueColor: const AlwaysStoppedAnimation<Color>(GameColors.accent),
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

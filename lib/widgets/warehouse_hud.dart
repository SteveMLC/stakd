import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/business_tier_service.dart';
import '../services/warehouse_economy_service.dart';
import '../utils/constants.dart';

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

    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: GameColors.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: GameColors.accent.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _CashChip(amount: economy.cash),
            const SizedBox(width: 14),
            Expanded(child: _LevelBar(economy: economy)),
            if (showTierBadge) ...[
              const SizedBox(width: 12),
              _TierBadge(info: tiers.selectedTierInfo),
            ],
          ],
        ),
      ),
    );
  }
}

class _CashChip extends StatelessWidget {
  final int amount;
  const _CashChip({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.attach_money, size: 18, color: Color(0xFFFFD24A)),
        const SizedBox(width: 2),
        Text(
          _format(amount),
          style: const TextStyle(
            color: GameColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
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
    final m = n / 1000000;
    return '${m.toStringAsFixed(m >= 100 ? 0 : 1)}M';
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

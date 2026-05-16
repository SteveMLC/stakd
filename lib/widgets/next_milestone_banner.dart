import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/local_regional_levels.dart';
import '../services/business_tier_service.dart';
import '../services/contract_service.dart';
import '../services/cosmetic_service.dart';
import '../services/machinery_service.dart';
import '../services/warehouse_economy_service.dart';
import '../utils/constants.dart';

/// The "next thing to chase" line shown right under the WarehouseHud on
/// the home screen. Always shows ONE milestone — the lowest-hanging one
/// the player is closest to. Powers the accretive feel — the player
/// always sees a goal in arm's reach.
///
/// Slowly pulses + rotates the milestone icon so the "next reward
/// dangling for you" banner has a heartbeat. Cheap — one
/// StatefulWidget, one ticker, no per-frame allocation.
class _MilestoneIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const _MilestoneIcon({required this.icon, required this.color});

  @override
  State<_MilestoneIcon> createState() => _MilestoneIconState();
}

class _MilestoneIconState extends State<_MilestoneIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        // Scale 1.0 → 1.18, rotate ±0.1 rad.
        final scale = 1.0 + 0.18 * math.sin(t * math.pi);
        final rot = 0.1 * math.sin(t * math.pi * 2);
        return Transform.rotate(
          angle: rot,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.18),
                border: Border.all(
                  color: widget.color
                      .withValues(alpha: 0.4 + 0.6 * math.sin(t * math.pi)),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(
                      alpha: 0.15 + 0.35 * math.sin(t * math.pi),
                    ),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(widget.icon, size: 14, color: widget.color),
            ),
          ),
        );
      },
    );
  }
}

/// Priority order (first match wins):
///   1. Frozen crates unlock at Warehouse Level 5 (until reached)
///   2. Regional Hub purchase ($5,000 + Lv 10)
///   3. Next un-completed contract overall
///   4. Cheapest reachable machinery (income bump)
///   5. First Forklift skin ($500 + Lv 15)
///   6. Endless mode banner past L30
class NextMilestoneBanner extends StatelessWidget {
  const NextMilestoneBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<WarehouseEconomyService>();
    final tiers = context.watch<BusinessTierService>();
    final contracts = context.watch<ContractService>();
    final cosmetics = context.watch<CosmeticService>();
    final machinery = context.watch<MachineryService>();

    final m = _pickMilestone(
      economy: economy,
      tiers: tiers,
      contracts: contracts,
      cosmetics: cosmetics,
      machinery: machinery,
    );
    if (m == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: GameColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: GameColors.accent.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Static glowing chip (animated version caused
            // TickerProvider re-creation during navigation finalize
            // — pulled out, swap back in once we own the widget
            // lifecycle properly).
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GameColors.accent.withValues(alpha: 0.18),
                border: Border.all(
                  color: GameColors.accent.withValues(alpha: 0.55),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: GameColors.accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(m.icon, size: 14, color: GameColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Next: ${m.title}',
                    style: const TextStyle(
                      color: GameColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    m.subtitle,
                    style: const TextStyle(
                      color: GameColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (m.progress != null)
              SizedBox(
                width: 56,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.progress!,
                      style: const TextStyle(
                        color: GameColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  _Milestone? _pickMilestone({
    required WarehouseEconomyService economy,
    required BusinessTierService tiers,
    required ContractService contracts,
    required CosmeticService cosmetics,
    required MachineryService machinery,
  }) {
    final whLevel = economy.warehouseLevel;

    // 1. Frozen crates first appear in District 3 (Cold Storage =
    // contract levels 11-15) so the home milestone banner advertises
    // the *contract* threshold, not the warehouse level. The previous
    // copy ("unlock at Lv 5") was misleading per the special-blocks
    // audit — Lv 5 has zero frozen probability; D3 = Lv 11 is the
    // first puzzle where a frozen crate can show up.
    if (whLevel < 11) {
      return _Milestone(
        title: 'Frozen Crates unlock at Lv 11',
        subtitle: 'Cold Storage shipments pay more',
        icon: Icons.ac_unit,
        progress: 'Lv $whLevel',
      );
    }

    // 2. Regional Hub purchase
    final regional = tiers.infoFor(BusinessTier.regional);
    if (!tiers.isOwned(BusinessTier.regional)) {
      final levelOk = whLevel >= regional.minWarehouseLevel;
      final cashOk = economy.cash >= regional.cashCost;
      return _Milestone(
        title: 'Regional Hub: ${tiers.infoFor(BusinessTier.regional).tagline}',
        subtitle: levelOk && cashOk
            ? 'You can buy this now — tap PLAY'
            : levelOk
                ? '\$${economy.cash} / \$${regional.cashCost}'
                : 'Reach Lv ${regional.minWarehouseLevel} first '
                    '(at Lv $whLevel)',
        icon: Icons.warehouse_outlined,
        progress: '\$${regional.cashCost}',
      );
    }

    // 3. Next contract to clear (any uncleared)
    final nextSuggested = contracts.nextSuggestedLevel;
    final nextContract = contracts.contractForLevel(nextSuggested);
    if (nextContract != null && !contracts.isContractCleared(nextContract)) {
      final cleared = _starsInContract(contracts, nextContract);
      final total = nextContract.totalLevels;
      return _Milestone(
        title: nextContract.displayName,
        subtitle: nextContract.tagline,
        icon: Icons.assignment_outlined,
        progress: '$cleared/$total ★',
      );
    }

    // 4. Cheapest reachable machinery — the next income bump.
    //    Only surface machines the player can actually unlock soon
    //    (within 5 WH levels of current) so we don't dangle a $250K
    //    Drone Fleet at a Lv 3 player.
    final unownedMachine = MachineryService.catalog
        .where((m) =>
            !machinery.isOwned(m.id) &&
            m.minWarehouseLevel <= whLevel + 5)
        .toList()
      ..sort((a, b) => a.cashCost.compareTo(b.cashCost));
    if (unownedMachine.isNotEmpty) {
      final next = unownedMachine.first;
      final levelOk = whLevel >= next.minWarehouseLevel;
      final cashOk = economy.cash >= next.cashCost;
      return _Milestone(
        title: '${next.displayName} (+${next.incomeBonus.toStringAsFixed(2)}× income)',
        subtitle: levelOk && cashOk
            ? 'You can install this now — tap Machinery'
            : levelOk
                ? '\$${economy.cash} / \$${next.cashCost}'
                : 'Reach Lv ${next.minWarehouseLevel} first '
                    '(at Lv $whLevel)',
        icon: next.icon,
        progress: '\$${next.cashCost}',
      );
    }

    // 5. First Forklift skin
    final unowned = CosmeticService.catalog
        .where((f) => !cosmetics.isOwned(f.skin))
        .toList()
      ..sort((a, b) => a.cashCost.compareTo(b.cashCost));
    if (unowned.isNotEmpty) {
      final next = unowned.first;
      return _Milestone(
        title: '${next.displayName} forklift',
        subtitle: next.description,
        icon: Icons.local_shipping_outlined,
        progress: '\$${next.cashCost}',
      );
    }

    // 6. Procedural mode past L30
    if (nextSuggested > 30) {
      return _Milestone(
        title: 'Endless mode',
        subtitle: 'Procedural contracts — earn forever',
        icon: Icons.all_inclusive,
        progress: 'Lv $whLevel',
      );
    }

    // 6. Generic next-level pointer
    return _Milestone(
      title: 'Next contract level',
      subtitle: 'Keep stacking those crates',
      icon: Icons.arrow_forward,
      progress: 'L$nextSuggested',
    );
  }

  int _starsInContract(ContractService svc, ContractDefinition c) {
    var cleared = 0;
    for (var l = c.firstLevel; l <= c.lastLevel; l++) {
      if (svc.starsForLevel(l) > 0) cleared++;
    }
    return cleared;
  }
}

class _Milestone {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? progress;

  const _Milestone({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.progress,
  });
}

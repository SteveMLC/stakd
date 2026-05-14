import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/local_regional_levels.dart';
import '../services/business_tier_service.dart';
import '../services/contract_service.dart';
import '../services/cosmetic_service.dart';
import '../services/warehouse_economy_service.dart';
import '../utils/constants.dart';

/// The "next thing to chase" line shown right under the WarehouseHud on
/// the home screen. Always shows ONE milestone — the lowest-hanging one
/// the player is closest to. Powers the accretive feel — the player
/// always sees a goal in arm's reach.
///
/// Priority order (first match wins):
///   1. Next Local Contract to clear (if any have stars < total)
///   2. Frozen crates unlock at Warehouse Level 5 (until reached)
///   3. Regional Hub purchase ($5,000 + Lv 10)
///   4. First Forklift skin ($500 + Lv 15)
///   5. Next un-completed contract overall
///   6. Procedural play past L30 if everything in v1.0 is cleared
class NextMilestoneBanner extends StatelessWidget {
  const NextMilestoneBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<WarehouseEconomyService>();
    final tiers = context.watch<BusinessTierService>();
    final contracts = context.watch<ContractService>();
    final cosmetics = context.watch<CosmeticService>();

    final m = _pickMilestone(
      economy: economy,
      tiers: tiers,
      contracts: contracts,
      cosmetics: cosmetics,
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
            Icon(m.icon, size: 18, color: GameColors.accent),
            const SizedBox(width: 10),
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
  }) {
    final whLevel = economy.warehouseLevel;

    // 1. Frozen crates unlock at L5
    if (whLevel < 5) {
      return _Milestone(
        title: 'Frozen Crates unlock at Lv 5',
        subtitle: 'Sub-zero shipments pay more',
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

    // 4. First Forklift skin
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

    // 5. Procedural mode past L30
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

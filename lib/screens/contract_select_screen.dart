import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/local_regional_levels.dart';
import '../services/business_tier_service.dart';
import '../services/contract_service.dart';
import '../services/warehouse_economy_service.dart';
import '../utils/constants.dart';
import '../utils/route_transitions.dart';
import '../widgets/game_button.dart';
import '../widgets/warehouse_hud.dart';
import 'game_screen.dart';
import 'home_screen.dart' show AnimatedBackground;

/// Contract-chain selection screen. Surfaces the 6 v1.0 contracts in catalog
/// order and gates them behind previous-contract clears + Regional Hub tier
/// purchase.
class ContractSelectScreen extends StatelessWidget {
  const ContractSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                GameIconButton(icon: Icons.arrow_back, onPressed: () => Navigator.of(context).pop()),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Contracts',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ]),
            ),
            const WarehouseHud(),
            Expanded(
              child: Consumer3<ContractService, BusinessTierService, WarehouseEconomyService>(
                builder: (context, contracts, tiers, economy, _) => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: ContractService.contracts.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ContractCard(
                      definition: ContractService.contracts[i],
                      contracts: contracts,
                      tiers: tiers,
                      economy: economy,
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

enum _LockState { unlocked, needsPreviousClear, needsRegionalTier }

class _ContractCard extends StatelessWidget {
  final ContractDefinition definition;
  final ContractService contracts;
  final BusinessTierService tiers;
  final WarehouseEconomyService economy;

  const _ContractCard({
    required this.definition,
    required this.contracts,
    required this.tiers,
    required this.economy,
  });

  _LockState get _state {
    if (definition.tier == BusinessTier.regional && !tiers.isOwned(BusinessTier.regional)) {
      return _LockState.needsRegionalTier;
    }
    if (!contracts.isContractUnlocked(definition)) return _LockState.needsPreviousClear;
    return _LockState.unlocked;
  }

  Color get _accent => definition.tier == BusinessTier.local
      ? GameColors.palette[2]
      : GameColors.palette[4];

  /// First level in this contract with <1 star, or `firstLevel` if all cleared.
  int get _nextInContract {
    for (var l = definition.firstLevel; l <= definition.lastLevel; l++) {
      if (contracts.starsForLevel(l) < 1) return l;
    }
    return definition.firstLevel;
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final unlocked = state == _LockState.unlocked;
    final completed = contracts.isContractCompleted(definition);
    final tierLabel = definition.tier == BusinessTier.local ? 'Local' : 'Regional';

    return Container(
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: unlocked ? 0.92 : 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? _accent.withValues(alpha: 0.55) : GameColors.textMuted.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: unlocked
            ? [BoxShadow(color: _accent.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(definition.displayName, style: const TextStyle(
                    color: GameColors.text, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5,
                  )),
                  const SizedBox(height: 2),
                  Text('Lv ${definition.firstLevel}–${definition.lastLevel}', style: const TextStyle(
                    color: GameColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5,
                  )),
                ]),
              ),
              const SizedBox(width: 8),
              _Pill(label: tierLabel, color: _accent),
              if (completed) ...[const SizedBox(width: 6), const _CompletedBadge()],
            ]),
            const SizedBox(height: 6),
            Text(definition.tagline, style: TextStyle(
              color: GameColors.textMuted.withValues(alpha: unlocked ? 1.0 : 0.6),
              fontSize: 13,
              fontStyle: FontStyle.italic,
            )),
            const SizedBox(height: 12),
            _buildStarsRow(),
            const SizedBox(height: 12),
            _buildCta(context, state, completed),
          ],
        ),
      ),
    );
  }

  Widget _buildStarsRow() {
    final children = <Widget>[];
    for (var l = definition.firstLevel; l <= definition.lastLevel; l++) {
      children.add(_LevelStars(level: l, stars: contracts.starsForLevel(l)));
      if (l != definition.lastLevel) children.add(const SizedBox(width: 8));
    }
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: children);
  }

  Widget _buildCta(BuildContext context, _LockState state, bool completed) {
    switch (state) {
      case _LockState.unlocked:
        return SizedBox(
          width: double.infinity,
          child: GameButton(
            text: completed ? 'PLAY AGAIN' : 'PLAY NEXT',
            icon: Icons.play_arrow,
            isPrimary: true,
            isSmall: true,
            onPressed: () => _onPlay(context),
          ),
        );
      case _LockState.needsPreviousClear:
        final prev = ContractService.contracts[definition.contractIndex - 1];
        return Row(children: [
          Icon(Icons.lock, size: 16, color: GameColors.textMuted.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Clear ${prev.displayName} first',
              style: TextStyle(
                color: GameColors.textMuted.withValues(alpha: 0.85),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ]);
      case _LockState.needsRegionalTier:
        return _buildRegionalCta(context);
    }
  }

  Widget _buildRegionalCta(BuildContext context) {
    final info = tiers.infoFor(BusinessTier.regional);
    final precheck = tiers.checkPurchase(BusinessTier.regional, economy.cash, economy.warehouseLevel);

    late final String label;
    late final bool actionable;
    switch (precheck) {
      case PurchaseResult.success:
        label = 'Unlock Regional Hub (\$${_cash(info.cashCost)} + Lv ${info.minWarehouseLevel})';
        actionable = true;
      case PurchaseResult.warehouseLevelTooLow:
        label = 'Regional Hub needs Lv ${info.minWarehouseLevel} (you: Lv ${economy.warehouseLevel})';
        actionable = false;
      case PurchaseResult.insufficientCash:
        label = 'Need \$${_cash(info.cashCost)} for Regional Hub (you: \$${_cash(economy.cash)})';
        actionable = false;
      case PurchaseResult.alreadyOwned:
        label = 'Regional Hub unlocked';
        actionable = false;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.lock, size: 16, color: GameColors.textMuted.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        const Text('Regional Hub required', style: TextStyle(
          color: GameColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600,
        )),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: GameButton(
          text: label,
          icon: Icons.lock_open,
          isPrimary: actionable,
          isSmall: true,
          onPressed: actionable ? () => _onPurchaseRegional(context) : null,
        ),
      ),
    ]);
  }

  Future<void> _onPurchaseRegional(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await tiers.purchase(BusinessTier.regional);
    if (!context.mounted) return;
    final text = switch (result) {
      PurchaseResult.success => 'Regional Hub unlocked. Welcome to the big leagues.',
      PurchaseResult.alreadyOwned => 'You already own Regional Hub.',
      PurchaseResult.warehouseLevelTooLow => 'Reach Warehouse Level 10 to unlock Regional Hub.',
      PurchaseResult.insufficientCash => 'Need \$5,000 to unlock Regional Hub.',
    };
    messenger.showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 3),
      backgroundColor: GameColors.surface,
    ));
  }

  void _onPlay(BuildContext context) {
    final suggested = contracts.nextSuggestedLevel;
    final level = definition.containsLevel(suggested) ? suggested : _nextInContract;
    Navigator.of(context).push(fadeSlideRoute(GameScreen(level: level)));
  }

  static String _cash(int n) {
    if (n < 1000) return n.toString();
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _LevelStars extends StatelessWidget {
  final int level;
  final int stars;
  const _LevelStars({required this.level, required this.stars});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('L$level', style: const TextStyle(
        color: GameColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.4,
      )),
      const SizedBox(height: 2),
      Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
        final earned = i < stars;
        return Icon(
          earned ? Icons.star : Icons.star_border,
          size: 12,
          color: earned ? const Color(0xFFFFD24A) : GameColors.textMuted.withValues(alpha: 0.45),
        );
      })),
    ]);
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Text(label, style: const TextStyle(
        color: GameColors.text, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6,
      )),
    );
  }
}

class _CompletedBadge extends StatelessWidget {
  const _CompletedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: GameColors.successGlow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GameColors.successGlow.withValues(alpha: 0.6), width: 1),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle, size: 11, color: GameColors.successGlow),
        SizedBox(width: 3),
        Text('DONE', style: TextStyle(
          color: GameColors.successGlow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6,
        )),
      ]),
    );
  }
}

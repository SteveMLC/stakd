import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/local_regional_levels.dart';
import '../services/business_tier_service.dart';
import '../services/contract_service.dart';
import '../services/district_service.dart';
import '../services/warehouse_economy_service.dart';
import '../utils/constants.dart';
import '../utils/number_format.dart';
import '../utils/route_transitions.dart';
import '../widgets/game_button.dart';
import '../widgets/warehouse_decorations.dart';
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
                const Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: MetalNameplate(
                      text: 'CONTRACTS',
                      icon: Icons.assignment_outlined,
                      fontSize: 15,
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
    // The "next contract to play" — the first unlocked-but-not-cleared
    // one — gets the active pulse so the player knows where to head.
    final isActiveNext = unlocked && !completed;

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hazard-tape header — only on unlocked contracts (locked
            // ones get a muted divider line instead so they look like
            // dispatched-but-not-yet-cleared manifests).
            if (unlocked)
              const HazardStripe(height: 5, stripeWidth: 10)
            else
              Container(
                height: 5,
                color: GameColors.textMuted.withValues(alpha: 0.18),
              ),
            // Manifest stub row.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: const Color(0xFF1A1F26).withValues(alpha: 0.55),
              child: Row(
                children: [
                  Text(
                    'CONTRACT NO.',
                    style: TextStyle(
                      color: GameColors.textMuted.withValues(alpha: 0.75),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      fontFamily: 'Courier',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'WH-${(definition.contractIndex + 1).toString().padLeft(3, '0')}',
                    style: TextStyle(
                      color: unlocked ? GameColors.text : GameColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                      fontFamily: 'Courier',
                    ),
                  ),
                  // District suffix: " · D{N}" so the player learns the
                  // contract-to-district mapping at a glance. Same
                  // service that powers procedural districts past D6 —
                  // contracts 0..5 map 1:1 to D1..D6.
                  Text(
                    ' · D${definition.contractIndex + 1}',
                    style: TextStyle(
                      color: GameColors.accent
                          .withValues(alpha: unlocked ? 0.9 : 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      fontFamily: 'Courier',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    completed
                        ? 'CLEARED'
                        : unlocked
                            ? 'ACTIVE'
                            : state == _LockState.needsRegionalTier
                                ? 'REGIONAL ONLY'
                                : 'AWAITING',
                    style: TextStyle(
                      color: completed
                          ? const Color(0xFF4CAF50)
                          : unlocked
                              ? GameColors.accent
                              : GameColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      fontFamily: 'Courier',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
                        // District name + level range — surfaces the
                        // theme identity that the infinite-scaling
                        // ladder uses ("Local Dock", "Cold Storage",
                        // procedural "Deep-Water Port" past D6). For
                        // hand-tuned D1-D6 this maps from the
                        // contract index; for procedural D7+ the
                        // displayName already carries the District N
                        // prefix from the composer.
                        Builder(builder: (_) {
                          final district = DistrictService()
                              .definitionFor(definition.contractIndex + 1);
                          return Text(
                            '${district.displayName.toUpperCase()}  ·  Lv ${definition.firstLevel}–${definition.lastLevel}',
                            style: TextStyle(
                              color: GameColors.accent
                                  .withValues(alpha: unlocked ? 0.85 : 0.45),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              fontFamily: 'Courier',
                            ),
                          );
                        }),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    _Pill(label: tierLabel, color: _accent),
                    if (completed) ...[const SizedBox(width: 6), const _CompletedBadge()],
                    // Wrinkle pill — only renders for districts that
                    // introduce a gameplay modifier. D3 Cold Storage
                    // gets "FROZEN"; procedural districts get
                    // whatever the composer assigned. Surface this
                    // BEFORE the player starts the contract so the
                    // wrinkle isn't a surprise mid-level.
                    Builder(builder: (_) {
                      final district = DistrictService()
                          .definitionFor(definition.contractIndex + 1);
                      if (district.wrinkles.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _Pill(
                          label: district.wrinkles.first.toUpperCase(),
                          color: const Color(0xFF5DADE2), // dock blue
                        ),
                      );
                    }),
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
          ],
        ),
      ),
    );

    // The next-playable contract breathes its tier-accent so the
    // player's eye locks onto it as the "go here" card.
    if (isActiveNext) {
      return _ActiveContractPulse(color: _accent, child: card);
    }
    return card;
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
        // Manifest-style lock copy: a stenciled "AWAITING CLEARANCE"
        // status stamp + a human-readable explainer that names the
        // gating contract. Reads like a paper waybill flagged "hold".
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock,
              size: 16,
              color: GameColors.textMuted.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AWAITING CLEARANCE',
                    style: TextStyle(
                      color: GameColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                      fontFamily: 'Courier',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Finish ${prev.displayName} first',
                    style: TextStyle(
                      color: GameColors.textMuted.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
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
      // Manifest-style gate header: a "REGIONAL DESK REQUIRED" stamp +
      // explainer instead of the prior bare "Regional Hub required" so
      // the lock state reads consistently with awaiting-clearance copy.
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lock,
            size: 16, color: GameColors.textMuted.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'REGIONAL DESK REQUIRED',
                style: TextStyle(
                  color: GameColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                  fontFamily: 'Courier',
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Upgrade your dispatch tier',
                style: TextStyle(
                  color: GameColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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
    final regionalInfo =
        BusinessTierService().infoFor(BusinessTier.regional);
    final result = await tiers.purchase(BusinessTier.regional);
    if (!context.mounted) return;
    // Insufficient-cash message reads the live cost from
    // BusinessTierService rather than hardcoding $5,000 (was stale
    // after the 2026-05-14 balance patch dropped Regional to $3,000).
    final text = switch (result) {
      PurchaseResult.success => 'Regional Hub unlocked. Welcome to the big leagues.',
      PurchaseResult.alreadyOwned => 'You already own Regional Hub.',
      PurchaseResult.warehouseLevelTooLow =>
        'Reach Warehouse Level ${regionalInfo.minWarehouseLevel} to unlock Regional Hub.',
      PurchaseResult.insufficientCash =>
        'Need \$${_cash(regionalInfo.cashCost)} to unlock Regional Hub.',
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

  /// Delegates to the shared `formatCash` helper for K/M/B/T/Qa
  /// scaling on tier-unlock cost displays. Today only Regional Hub
  /// ($3K) is gated by cash, but Districts D7+ will gate by
  /// exponential cash costs (D7=$1.5M, D8=$15M, ...) so this needs
  /// to scale cleanly when district-unlock prices land in the
  /// contract-select UI.
  static String _cash(int n) => formatCash(n);
}

/// Slow breathing glow used on the "next playable" contract card —
/// pulses the tier-accent halo so the player's eye anchors on the
/// card they're meant to tap next.
class _ActiveContractPulse extends StatefulWidget {
  final Color color;
  final Widget child;
  const _ActiveContractPulse({required this.color, required this.child});

  @override
  State<_ActiveContractPulse> createState() => _ActiveContractPulseState();
}

class _ActiveContractPulseState extends State<_ActiveContractPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void deactivate() {
    _ctrl.stop();
    super.deactivate();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        final brightness = 0.5 - 0.5 * (t - 0.5).abs() * 2;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.color
                    .withValues(alpha: 0.18 + brightness * 0.30),
                blurRadius: 20 + brightness * 10,
                spreadRadius: brightness * 3,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
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

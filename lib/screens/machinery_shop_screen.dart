import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/machinery_service.dart';
import '../services/warehouse_economy_service.dart';
import '../utils/constants.dart';
import '../widgets/game_button.dart';
import '../widgets/warehouse_decorations.dart';
import '../widgets/warehouse_hud.dart';
import 'home_screen.dart' show AnimatedBackground;

/// Permanent equipment shop. Each purchase stacks a permanent income
/// bonus into IncomeMultiplierService. Once bought, machines stay
/// bought — there's no equip slot like the forklift shop.
class MachineryShopScreen extends StatelessWidget {
  const MachineryShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                GameIconButton(
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: MetalNameplate(
                      text: 'MACHINERY',
                      icon: Icons.precision_manufacturing,
                      fontSize: 15,
                    ),
                  ),
                ),
              ]),
            ),
            const WarehouseHud(),
            const _MachineryBonusBanner(),
            Expanded(
              child: Consumer2<MachineryService, WarehouseEconomyService>(
                builder: (context, machinery, economy, _) => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: MachineryService.catalog.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MachineryCard(
                      info: MachineryService.catalog[i],
                      machinery: machinery,
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

/// Headline showing the current total machinery income bonus + how many
/// machines are owned out of the catalog total. Gives the player a clear
/// "you're at +X.XX× from your dock crew" feedback loop.
class _MachineryBonusBanner extends StatelessWidget {
  const _MachineryBonusBanner();

  @override
  Widget build(BuildContext context) {
    return Consumer<MachineryService>(builder: (context, machinery, _) {
      final owned = machinery.owned.length;
      final total = MachineryService.catalog.length;
      final bonus = machinery.totalIncomeBonus;
      final hasBonus = bonus > 0.001;

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: GameColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasBonus
                ? const Color(0xFF4CAF50).withValues(alpha: 0.55)
                : GameColors.textMuted.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(children: [
          Icon(
            Icons.factory_outlined,
            size: 22,
            color: hasBonus ? const Color(0xFF4CAF50) : GameColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasBonus
                        ? 'Income bonus: +${bonus.toStringAsFixed(2)}×'
                        : 'No machinery yet — start with a Pallet Jack.',
                    style: TextStyle(
                      color: hasBonus
                          ? const Color(0xFF4CAF50)
                          : GameColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$owned / $total machines owned',
                    style: const TextStyle(
                      color: GameColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ]),
          ),
        ]),
      );
    });
  }
}

class _MachineryCard extends StatelessWidget {
  final MachineryInfo info;
  final MachineryService machinery;
  final WarehouseEconomyService economy;

  const _MachineryCard({
    required this.info,
    required this.machinery,
    required this.economy,
  });

  bool get _isOwned => machinery.isOwned(info.id);

  @override
  Widget build(BuildContext context) {
    final precheck =
        machinery.checkPurchase(info.id, economy.cash, economy.warehouseLevel);
    final actionable = _isOwned || precheck == MachineryPurchaseResult.success;

    final card = Container(
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: actionable ? 0.92 : 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: actionable
              ? info.accent.withValues(alpha: 0.55)
              : GameColors.textMuted.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: actionable
            ? [
                BoxShadow(
                  color: info.accent.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _MachineIcon(
                icon: info.icon,
                color: info.accent,
                dimmed: !actionable,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.displayName,
                        style: const TextStyle(
                          color: GameColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        info.description,
                        style: TextStyle(
                          color: GameColors.textMuted
                              .withValues(alpha: actionable ? 1.0 : 0.6),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ]),
              ),
              const SizedBox(width: 8),
              if (_isOwned) const _OwnedBadge(),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _Pill(
                label: '+${info.incomeBonus.toStringAsFixed(2)}× income',
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 6),
              if (!_isOwned) ...[
                _Pill(label: '\$${_cash(info.cashCost)}', color: info.accent),
                const SizedBox(width: 6),
              ],
              _Pill(
                  label: 'Lv ${info.minWarehouseLevel}+',
                  color: GameColors.textMuted),
            ]),
            const SizedBox(height: 12),
            _buildCta(context, precheck),
          ],
        ),
      ),
    );

    // Owned machines breathe their accent — the player should *see*
    // the income engine running on their shelf.
    if (_isOwned) {
      return _BreathingGlow(color: info.accent, child: card);
    }
    return card;
  }

  Widget _buildCta(BuildContext context, MachineryPurchaseResult precheck) {
    if (_isOwned) {
      return Row(children: [
        const Icon(Icons.check_circle,
            size: 16, color: GameColors.successGlow),
        const SizedBox(width: 8),
        Text(
          'Permanent — earning forever',
          style: TextStyle(
            color: GameColors.successGlow.withValues(alpha: 0.95),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ]);
    }
    return switch (precheck) {
      MachineryPurchaseResult.success => SizedBox(
          width: double.infinity,
          child: GameButton(
            text: 'BUY (\$${_cash(info.cashCost)})',
            icon: Icons.shopping_cart,
            isPrimary: true,
            isSmall: true,
            onPressed: () => _onPurchase(context),
          ),
        ),
      MachineryPurchaseResult.warehouseLevelTooLow =>
        _lockedRow('Warehouse Level ${info.minWarehouseLevel} required'),
      MachineryPurchaseResult.insufficientCash =>
        _lockedRow('Need \$${_cash(info.cashCost - economy.cash)} more'),
      MachineryPurchaseResult.alreadyOwned => _lockedRow('Owned'),
    };
  }

  Widget _lockedRow(String label) {
    return Row(children: [
      Icon(Icons.lock,
          size: 16, color: GameColors.textMuted.withValues(alpha: 0.7)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: GameColors.textMuted.withValues(alpha: 0.85),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ]);
  }

  Future<void> _onPurchase(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await machinery.purchase(info.id);
    if (!context.mounted) return;
    final text = switch (result) {
      MachineryPurchaseResult.success =>
        '${info.displayName} online! +${info.incomeBonus.toStringAsFixed(2)}× income permanently.',
      MachineryPurchaseResult.alreadyOwned =>
        'You already own ${info.displayName}.',
      MachineryPurchaseResult.warehouseLevelTooLow =>
        'Reach Warehouse Level ${info.minWarehouseLevel} to install ${info.displayName}.',
      MachineryPurchaseResult.insufficientCash =>
        'Need \$${_cash(info.cashCost)} to install ${info.displayName}.',
    };
    messenger.showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 3),
      backgroundColor: GameColors.surface,
    ));
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

/// Slow breathing glow shell for "owned" / "active" shop cards. Same
/// pattern as the forklift shop's variant — copied here to keep the
/// shop screens self-contained.
class _BreathingGlow extends StatefulWidget {
  final Color color;
  final Widget child;
  const _BreathingGlow({required this.color, required this.child});

  @override
  State<_BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<_BreathingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
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
                    .withValues(alpha: 0.15 + brightness * 0.25),
                blurRadius: 18 + brightness * 8,
                spreadRadius: brightness * 2,
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

class _MachineIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool dimmed;
  const _MachineIcon({
    required this.icon,
    required this.color,
    required this.dimmed,
  });

  @override
  Widget build(BuildContext context) {
    final tint = dimmed ? color.withValues(alpha: 0.45) : color;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Icon(icon, size: 26, color: tint),
    );
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
      child: Text(
        label,
        style: const TextStyle(
          color: GameColors.text,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _OwnedBadge extends StatelessWidget {
  const _OwnedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: GameColors.successGlow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: GameColors.successGlow.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle, size: 11, color: GameColors.successGlow),
        SizedBox(width: 3),
        Text(
          'OWNED',
          style: TextStyle(
            color: GameColors.successGlow,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ]),
    );
  }
}

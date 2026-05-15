import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/audio_service.dart';
import '../services/cosmetic_service.dart';
import '../services/warehouse_economy_service.dart';
import '../utils/constants.dart';
import '../widgets/game_button.dart';
import '../widgets/warehouse_decorations.dart';
import '../widgets/warehouse_hud.dart';
import 'home_screen.dart' show AnimatedBackground;

/// Per-skin accent color for card border tint + icon hue. Order matches the
/// catalog in `CosmeticService`.
const Map<ForkliftSkin, Color> _kSkinAccent = <ForkliftSkin, Color>{
  ForkliftSkin.yellowStandard: Color(0xFFFFC107),
  ForkliftSkin.redSport: Color(0xFFE53935),
  ForkliftSkin.blueHeavy: Color(0xFF1E88E5),
  ForkliftSkin.goldPremium: Color(0xFFFFB300),
};

/// Forklift cosmetic shop. Surfaces the 4 v1.0 skins in catalog order and
/// gates them behind Warehouse Level + cash. Owned skins can be tap-equipped.
class ForkliftShopScreen extends StatelessWidget {
  const ForkliftShopScreen({super.key});

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
                      text: 'FORKLIFTS',
                      icon: Icons.local_shipping,
                      fontSize: 15,
                    ),
                  ),
                ),
              ]),
            ),
            const WarehouseHud(),
            Expanded(
              child: Consumer2<CosmeticService, WarehouseEconomyService>(
                builder: (context, cosmetics, economy, _) => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: CosmeticService.catalog.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ForkliftCard(
                      info: CosmeticService.catalog[i],
                      cosmetics: cosmetics,
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

class _ForkliftCard extends StatelessWidget {
  final ForkliftSkinInfo info;
  final CosmeticService cosmetics;
  final WarehouseEconomyService economy;

  const _ForkliftCard({
    required this.info,
    required this.cosmetics,
    required this.economy,
  });

  Color get _accent => _kSkinAccent[info.skin] ?? GameColors.accent;

  bool get _isOwned => cosmetics.isOwned(info.skin);
  bool get _isEquipped => cosmetics.selectedForklift == info.skin;

  @override
  Widget build(BuildContext context) {
    final precheck =
        cosmetics.checkPurchase(info.skin, economy.cash, economy.warehouseLevel);
    final actionable = _isOwned || precheck == CosmeticPurchaseResult.success;

    // Equipped cards get a slow accent breath so the player sees
    // their picked skin "running" on the shelf. Other actionable
    // cards just glow steadily; locked ones go fully muted.
    final card = Container(
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: actionable ? 0.92 : 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: actionable ? _accent.withValues(alpha: 0.55) : GameColors.textMuted.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: actionable
            ? [BoxShadow(color: _accent.withValues(alpha: 0.20), blurRadius: 14, offset: const Offset(0, 4))]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SkinIcon(color: _accent, dimmed: !actionable, equipped: _isEquipped),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(info.displayName, style: const TextStyle(
                    color: GameColors.text, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5,
                  )),
                  const SizedBox(height: 2),
                  Text(info.description, style: TextStyle(
                    color: GameColors.textMuted.withValues(alpha: actionable ? 1.0 : 0.6),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  )),
                ]),
              ),
              const SizedBox(width: 8),
              if (_isEquipped) const _EquippedBadge(),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              if (info.cashCost > 0) ...[
                _Pill(label: '\$${_cash(info.cashCost)}', color: _accent),
                const SizedBox(width: 6),
              ],
              _Pill(label: 'Lv ${info.minWarehouseLevel}+', color: GameColors.textMuted),
            ]),
            const SizedBox(height: 12),
            _buildCta(context, precheck),
          ],
        ),
      ),
    );

    // Wrap equipped cards in a slow breathing glow effect.
    if (_isEquipped) {
      return _BreathingGlow(color: _accent, child: card);
    }
    return card;
  }

  Widget _buildCta(BuildContext context, CosmeticPurchaseResult precheck) {
    if (_isEquipped) {
      return Row(children: [
        const Icon(Icons.check_circle, size: 16, color: GameColors.successGlow),
        const SizedBox(width: 8),
        Text('Equipped', style: TextStyle(
          color: GameColors.successGlow.withValues(alpha: 0.95),
          fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6,
        )),
      ]);
    }
    if (_isOwned) {
      return SizedBox(
        width: double.infinity,
        child: GameButton(
          text: 'OWNED - TAP TO EQUIP',
          icon: Icons.check,
          isPrimary: false,
          isSmall: true,
          onPressed: () => _onEquip(context),
        ),
      );
    }
    return switch (precheck) {
      CosmeticPurchaseResult.success => SizedBox(
          width: double.infinity,
          child: GameButton(
            text: 'BUY (\$${_cash(info.cashCost)})',
            icon: Icons.shopping_cart,
            isPrimary: true,
            isSmall: true,
            onPressed: () => _onPurchase(context),
          ),
        ),
      CosmeticPurchaseResult.warehouseLevelTooLow =>
        _lockedRow('Warehouse Level ${info.minWarehouseLevel} required'),
      CosmeticPurchaseResult.insufficientCash =>
        _lockedRow('Need \$${_cash(info.cashCost - economy.cash)} more'),
      CosmeticPurchaseResult.alreadyOwned => _lockedRow('Owned'),
    };
  }

  Widget _lockedRow(String label) {
    return Row(children: [
      Icon(Icons.lock, size: 16, color: GameColors.textMuted.withValues(alpha: 0.7)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(label, style: TextStyle(
          color: GameColors.textMuted.withValues(alpha: 0.85),
          fontSize: 13, fontWeight: FontWeight.w600,
        )),
      ),
    ]);
  }

  Future<void> _onEquip(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await cosmetics.selectForklift(info.skin);
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? '${info.displayName} equipped.' : 'Could not equip ${info.displayName}.'),
      duration: const Duration(seconds: 2),
      backgroundColor: GameColors.surface,
    ));
  }

  Future<void> _onPurchase(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await cosmetics.purchase(info.skin);
    if (!context.mounted) return;
    if (result == CosmeticPurchaseResult.success) {
      AudioService().playCoin();
    }
    final text = switch (result) {
      CosmeticPurchaseResult.success => '${info.displayName} unlocked and equipped.',
      CosmeticPurchaseResult.alreadyOwned => 'You already own ${info.displayName}.',
      CosmeticPurchaseResult.warehouseLevelTooLow =>
        'Reach Warehouse Level ${info.minWarehouseLevel} to unlock ${info.displayName}.',
      CosmeticPurchaseResult.insufficientCash =>
        'Need \$${_cash(info.cashCost)} to unlock ${info.displayName}.',
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

class _SkinIcon extends StatelessWidget {
  final Color color;
  final bool dimmed;
  final bool equipped;
  const _SkinIcon({
    required this.color,
    required this.dimmed,
    this.equipped = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = dimmed ? color.withValues(alpha: 0.45) : color;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            tint.withValues(alpha: equipped ? 0.35 : 0.15),
            tint.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.55), width: 1.2),
        boxShadow: equipped
            ? [
                BoxShadow(
                  color: tint.withValues(alpha: 0.45),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Icon(Icons.local_shipping, size: 26, color: tint),
    );
  }
}

/// Wraps any child in a slow breathing glow on the supplied accent
/// colour. Used to make "owned/equipped" shop cards feel alive
/// without animating their content.
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
        // Cosine-eased 0..1 for smooth glow.
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

class _EquippedBadge extends StatelessWidget {
  const _EquippedBadge();

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
        Text('EQUIPPED', style: TextStyle(
          color: GameColors.successGlow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6,
        )),
      ]),
    );
  }
}

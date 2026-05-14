import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/currency_service.dart';
import '../services/haptic_service.dart';
import '../services/warehouse_economy_service.dart';
import '../utils/constants.dart';
import 'game_button.dart';

/// Action returned by [JamRecoveryModal.show]. The modal handles its own
/// side effects for [watchAd], [undo], and [skip]; the caller is responsible
/// only for re-seeding on [restart] or advancing on [skip].
enum JamRecoveryAction { watchAd, undo, restart, skip, dismissed }

/// Warm-amber "DOCK JAMMED" recovery dialog (GDD §2.2 + §6).
/// Style matches `CompletionOverlay` / `MultiGrabHintOverlay`: blurred
/// barrier, dark surface card, accent border, scale-in animation.
class JamRecoveryModal extends StatefulWidget {
  const JamRecoveryModal._();

  static Future<JamRecoveryAction> show(BuildContext context) async {
    final result = await showGeneralDialog<JamRecoveryAction>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Dock jammed',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) => const JamRecoveryModal._(),
    );
    return result ?? JamRecoveryAction.dismissed;
  }

  @override
  State<JamRecoveryModal> createState() => _JamRecoveryModalState();
}

class _JamRecoveryModalState extends State<JamRecoveryModal>
    with TickerProviderStateMixin {
  static const Color _amber = Color(0xFFFFB347);
  static const Color _amberDeep = Color(0xFFFF8C42);

  late final AnimationController _fadeController;
  late final AnimationController _scaleController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _fadeController.forward();
    _scaleController.forward();

    AudioService().playError();
    haptics.mediumImpact();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _onWatchAd() async {
    if (_busy) return;
    setState(() => _busy = true);

    final adService = AdService();
    final gameState = context.read<GameState>();
    final rewarded = adService.isRewardedAdReady()
        ? await adService.showRewardedAd()
        : true; // Test mode / no fill: gracefully grant the bay.

    if (!mounted) return;
    if (rewarded) {
      final added = gameState.addEmptyTube();
      if (!added && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bay Crane already used this level.')),
        );
      }
      Navigator.of(context).pop(JamRecoveryAction.watchAd);
    } else {
      setState(() => _busy = false);
    }
  }

  void _onUndo() {
    if (_busy) return;
    final gameState = context.read<GameState>();
    // Use forceUndo if the budget is empty — the jam is the trap, not the
    // player; Undo must always be a viable escape per §2.2 design rule.
    if (gameState.canUndo) {
      gameState.undo();
    } else {
      gameState.forceUndo();
    }
    Navigator.of(context).pop(JamRecoveryAction.undo);
  }

  void _onRestart() {
    if (_busy) return;
    Navigator.of(context).pop(JamRecoveryAction.restart);
  }

  Future<void> _onSkip() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Try soft-currency coins first; fall back to warehouse cash.
    var spent = await CurrencyService().spendCoins(100);
    if (!spent) spent = await WarehouseEconomyService().trySpend(100);
    if (!mounted) return;
    if (spent) {
      Navigator.of(context).pop(JamRecoveryAction.skip);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins to skip (need 100).')),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, _) {
        final t = _fade.value;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {}, // Modal is intentionally blocking.
                behavior: HitTestBehavior.opaque,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8 * t, sigmaY: 8 * t),
                  child: Container(
                    color: _amber.withValues(alpha: 0.18 * t),
                    foregroundDecoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45 * t),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: ScaleTransition(
                scale: _scale,
                child: FadeTransition(opacity: _fade, child: _buildCard()),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: GameColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _amber.withValues(alpha: 0.65), width: 2),
        boxShadow: [
          BoxShadow(
            color: _amberDeep.withValues(alpha: 0.35),
            blurRadius: 28,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.report_problem_rounded, size: 44, color: _amber),
          const SizedBox(height: 10),
          const Text(
            'DOCK JAMMED',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: _amber,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No legal moves left. Pick how to break it open.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: GameColors.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          _btn(Icons.play_circle_fill, 'Watch Ad  +1 Bay', _onWatchAd,
              primary: true),
          const SizedBox(height: 10),
          _btn(Icons.undo, 'Undo Last Move', _onUndo),
          const SizedBox(height: 10),
          _btn(Icons.refresh, 'Restart Level', _onRestart),
          const SizedBox(height: 10),
          _btn(Icons.skip_next, 'Skip  100 \u{1FA99}', _onSkip),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, String label, VoidCallback onTap,
      {bool primary = false}) {
    return SizedBox(
      width: double.infinity,
      child: GameButton(
        text: label,
        icon: icon,
        onPressed: _busy ? null : onTap,
        isPrimary: primary,
        isDisabled: _busy,
        backgroundColor: primary ? _amberDeep : null,
        borderColor: primary ? _amber : _amber.withValues(alpha: 0.4),
      ),
    );
  }
}

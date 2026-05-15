import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/number_format.dart';

/// Animated "+\$X" pill that pops at center-bottom of the screen on
/// level completion, then flies up toward the top-left HUD cash chip
/// and fades out. Optionally shows a "+Y XP" line underneath.
///
/// Wire from game_screen.dart on level-complete:
///   CashPayoutOverlay.show(context, cash: 175, xp: 87)
class CashPayoutOverlay extends StatefulWidget {
  final int cash;
  final int xp;
  final int? newWarehouseLevel; // non-null = level-up flash banner

  const CashPayoutOverlay({
    super.key,
    required this.cash,
    required this.xp,
    this.newWarehouseLevel,
  });

  static OverlayEntry? _activeEntry;

  /// Show the overlay above the current screen for ~1.4 seconds.
  /// Multiple calls in flight stack — the latest one paints on top.
  static void show(
    BuildContext context, {
    required int cash,
    required int xp,
    int? newWarehouseLevel,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (ctx) => CashPayoutOverlay(
        cash: cash,
        xp: xp,
        newWarehouseLevel: newWarehouseLevel,
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (_activeEntry == entry) {
        entry.remove();
        _activeEntry = null;
      }
    });
  }

  @override
  State<CashPayoutOverlay> createState() => _CashPayoutOverlayState();
}

class _CashPayoutOverlayState extends State<CashPayoutOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleIn;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleIn = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem(
        tween: Tween(begin: 0.4, end: 1.15)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 25,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 35),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.6)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_controller);

    _slide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: Offset.zero),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(-0.6, -3.0))
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 40,
      ),
    ]).animate(_controller);

    _fade = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 32,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              // Center-bottom payout pill that flies toward top-left.
              Positioned.fill(
                child: FractionalTranslation(
                  translation: _slide.value,
                  child: Align(
                    alignment: const Alignment(0, 0.25),
                    child: Opacity(
                      opacity: _fade.value,
                      child: Transform.scale(
                        scale: _scaleIn.value,
                        child: _PayoutPill(
                          cash: widget.cash,
                          xp: widget.xp,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Level-up banner (when set), separate animation slot.
              if (widget.newWarehouseLevel != null)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.18,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: _fade.value,
                    child: Center(
                      child: _LevelUpBanner(level: widget.newWarehouseLevel!),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PayoutPill extends StatelessWidget {
  final int cash;
  final int xp;
  const _PayoutPill({required this.cash, required this.xp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFEB7A),
            GameColors.accent,
            Color(0xFFE6A800),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: GameColors.accent.withValues(alpha: 0.7),
            blurRadius: 32,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.35),
            blurRadius: 14,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // Route through formatCashWithSymbol so post-D10 payouts
            // ($1M, $1B, $1Qa) read cleanly instead of stretching the
            // pill or overflowing.
            '+${formatCashWithSymbol(cash)}',
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1F26),
              letterSpacing: 1.2,
              shadows: [
                Shadow(
                  color: Color(0x44FFFFFF),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
          if (xp > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '+${formatXp(xp)} XP',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1F26),
                  letterSpacing: 1.0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LevelUpBanner extends StatelessWidget {
  final int level;
  const _LevelUpBanner({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F26).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: GameColors.accent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: GameColors.accent.withValues(alpha: 0.6),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'WAREHOUSE LEVEL UP',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: GameColors.accent,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lv $level',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: GameColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

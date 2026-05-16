import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../utils/crate_assets.dart';
import '../utils/theme_colors.dart';

/// "LOADING DOCK" goal panel rendered above the playfield, matching the
/// Lovart loading-dock reference design. Shows one crate slot per
/// distinct color in the puzzle. Each slot lights up + checks off when
/// at least one stack of that color reaches max-depth full-color
/// completion. The big checkmark on the right flips on when the entire
/// puzzle is solved.
class LoadingDockBanner extends StatelessWidget {
  final GameState gameState;
  const LoadingDockBanner({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    // Distinct colors in this puzzle (ordered by first appearance for
    // visual stability across moves).
    final seen = <int>{};
    final colors = <int>[];
    for (final stack in gameState.stacks) {
      for (final layer in stack.layers) {
        if (seen.add(layer.colorIndex)) {
          colors.add(layer.colorIndex);
        }
      }
    }
    if (colors.isEmpty) return const SizedBox.shrink();

    // Which colors are "delivered" (at least one stack fully matches).
    final delivered = <int>{};
    for (final stack in gameState.stacks) {
      if (stack.isComplete && stack.layers.isNotEmpty) {
        delivered.add(stack.layers.first.colorIndex);
      }
    }

    final allDelivered = delivered.length >= colors.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC0E1422),
            Color(0xCC050810),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF2E5A8C).withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Header label — small caps to read as "system panel" not body text.
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: RotatedBox(
              quarterTurns: 0,
              child: Text(
                'LOADING\nDOCK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  height: 1.05,
                  color: Color(0xFF7BB3FF),
                ),
              ),
            ),
          ),
          // Color-targets row — one chip per distinct color in the
          // puzzle. Crate face dims when undelivered; brightens +
          // gets a check overlay once the color is sorted.
          Expanded(
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: colors.map((c) {
                  final done = delivered.contains(c);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _ColorTarget(colorIndex: c, delivered: done),
                  );
                }).toList(),
              ),
            ),
          ),
          // Big right-side checkmark — flips to filled cyan when every
          // color in the puzzle has been delivered.
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: allDelivered
                  ? const Color(0xFF2EE0C0).withValues(alpha: 0.18)
                  : Colors.transparent,
              border: Border.all(
                color: allDelivered
                    ? const Color(0xFF2EE0C0)
                    : const Color(0xFF2E5A8C).withValues(alpha: 0.6),
                width: 1.8,
              ),
              boxShadow: allDelivered
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2EE0C0).withValues(alpha: 0.55),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 24,
              color: allDelivered
                  ? const Color(0xFF2EE0C0)
                  : const Color(0xFF2E5A8C).withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorTarget extends StatelessWidget {
  final int colorIndex;
  final bool delivered;
  const _ColorTarget({required this.colorIndex, required this.delivered});

  @override
  Widget build(BuildContext context) {
    final asset = CrateAssets.assetForColorIndex(colorIndex);
    final gradient = ThemeColors.getGradient(colorIndex);

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Crate face — Lovart asset over a soft color-matched halo
          // so the chip reads as a recognisable goal cargo even when
          // it's "undelivered" / dim.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradient
                    .map((c) => c.withValues(alpha: delivered ? 0.9 : 0.32))
                    .toList(),
              ),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: gradient.first.withValues(
                  alpha: delivered ? 0.95 : 0.45,
                ),
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Opacity(
                opacity: delivered ? 1.0 : 0.55,
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
          // Delivered overlay: small cyan check at the corner so the
          // player can scan the dock panel and see at-a-glance which
          // cargos have already been sorted.
          if (delivered)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2EE0C0),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2EE0C0).withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: Color(0xFF0B0E16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

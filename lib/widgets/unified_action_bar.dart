import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import '../services/power_up_service.dart';
import '../utils/constants.dart';

/// Single-row bottom control widget per Steve's 2026-05-15 direction:
///   "The icons on the button need to be consolidated, the + button for
///   add a silo and the other buttons should be inline. You have icons
///   below that are stacked on each other, move them inline along the
///   bottom in a single control widget."
///
/// Inline order, left → right:
///   [restart] [undo+badge] [+TUBE] [BURST] [RE-ROUTE] [CRANE] [HINT]
///
/// Each cell is a 44dp circle with a thin neon ring matching the
/// power-up palette (or a steel grey for control buttons). Badges
/// (undo count, power-up count, add-tube cost) sit at the bottom-right
/// of each cell. The whole bar is a single chrome panel with a thin
/// glow underline so it reads as the bottom-of-screen control deck —
/// not two stacked rows like the previous power-up-bar + bottom-controls
/// split.
class UnifiedActionBar extends StatelessWidget {
  final VoidCallback onRestart;
  final VoidCallback onUndo;
  final VoidCallback onAddTube;
  final VoidCallback onColorBomb;
  final VoidCallback onShuffle;
  final VoidCallback onMagnet;
  final VoidCallback onHint;
  final bool addTubeAvailable;
  final bool selectionMode;
  final PowerUpType? activeSelection;

  const UnifiedActionBar({
    super.key,
    required this.onRestart,
    required this.onUndo,
    required this.onAddTube,
    required this.onColorBomb,
    required this.onShuffle,
    required this.onMagnet,
    required this.onHint,
    required this.addTubeAvailable,
    this.selectionMode = false,
    this.activeSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<GameState, PowerUpService>(
      builder: (context, gameState, powerUps, _) {
        return Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1422).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFF2E5A8C).withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFF2EE0C0).withValues(alpha: 0.10),
                blurRadius: 14,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ActionCell(
                icon: Icons.refresh,
                ringHex: 0xFFFFC107,
                onTap: onRestart,
              ),
              _ActionCell(
                icon: Icons.undo,
                ringHex: 0xFF7BB3FF,
                badge: gameState.undosRemaining > 0
                    ? '${gameState.undosRemaining}'
                    : null,
                disabled: !gameState.canUndo,
                onTap: onUndo,
              ),
              _ActionCell(
                icon: Icons.add_circle_outline,
                ringHex: 0xFF2EE0C0,
                badge: '100',
                badgeIcon: Icons.attach_money,
                disabled: !addTubeAvailable,
                onTap: onAddTube,
              ),
              _PowerUpCell(
                type: PowerUpType.colorBomb,
                count: powerUps.getCount(PowerUpType.colorBomb),
                active: activeSelection == PowerUpType.colorBomb,
                selectionMode: selectionMode,
                onTap: onColorBomb,
              ),
              _PowerUpCell(
                type: PowerUpType.shuffle,
                count: powerUps.getCount(PowerUpType.shuffle),
                active: activeSelection == PowerUpType.shuffle,
                selectionMode: selectionMode,
                onTap: onShuffle,
              ),
              _PowerUpCell(
                type: PowerUpType.magnet,
                count: powerUps.getCount(PowerUpType.magnet),
                active: activeSelection == PowerUpType.magnet,
                selectionMode: selectionMode,
                onTap: onMagnet,
              ),
              _PowerUpCell(
                type: PowerUpType.hint,
                count: powerUps.getCount(PowerUpType.hint),
                active: activeSelection == PowerUpType.hint,
                selectionMode: selectionMode,
                onTap: onHint,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Plain control cell — restart / undo / +tube. Material icon inside
/// a neon ring; optional bottom-right badge for count/price.
class _ActionCell extends StatelessWidget {
  final IconData icon;
  final int ringHex;
  final String? badge;
  final IconData? badgeIcon;
  final bool disabled;
  final VoidCallback onTap;

  const _ActionCell({
    required this.icon,
    required this.ringHex,
    this.badge,
    this.badgeIcon,
    this.disabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ring = Color(ringHex);
    return Opacity(
      opacity: disabled ? 0.42 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 46,
          height: 50,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0B0E16),
                  border: Border.all(
                    color: ring.withValues(alpha: 0.85),
                    width: 1.6,
                  ),
                  boxShadow: disabled
                      ? null
                      : [
                          BoxShadow(
                            color: ring.withValues(alpha: 0.28),
                            blurRadius: 8,
                            spreadRadius: 0.5,
                          ),
                        ],
                ),
                child: Icon(icon, color: ring, size: 22),
              ),
              if (badge != null)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 16,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0E16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ring.withValues(alpha: 0.85),
                        width: 0.9,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (badgeIcon != null)
                          Icon(badgeIcon, size: 9, color: ring),
                        Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: ring,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Power-up cell — illustrated WebP icon inside a neon ring color-coded
/// by power-up type. Count badge at bottom-right. Active state pops a
/// brighter outer halo.
class _PowerUpCell extends StatelessWidget {
  final PowerUpType type;
  final int count;
  final bool active;
  final bool selectionMode;
  final VoidCallback onTap;

  const _PowerUpCell({
    required this.type,
    required this.count,
    required this.active,
    required this.selectionMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ring = Color(type.neonHex);
    final disabled = selectionMode;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 46,
        height: 50,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0B0E16),
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    ring.withValues(alpha: active ? 0.55 : 0.22),
                    const Color(0xFF0B0E16),
                  ],
                  stops: const [0.0, 1.0],
                ),
                border: Border.all(
                  color: ring.withValues(alpha: active ? 0.95 : 0.78),
                  width: active ? 2.2 : 1.6,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: ring.withValues(alpha: 0.65),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: ring.withValues(alpha: 0.30),
                          blurRadius: 8,
                          spreadRadius: 0.5,
                        ),
                      ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Opacity(
                  opacity: count <= 0 ? 0.42 : 1.0,
                  child: Image.asset(
                    type.iconAsset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0E16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ring.withValues(alpha: 0.85),
                    width: 0.9,
                  ),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: count <= 0
                        ? GameColors.textMuted
                        : ring,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

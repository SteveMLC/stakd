import 'package:flutter/material.dart';

import '../models/game_state.dart';

/// Bottom-of-playfield progress bar matching the Lovart loading-dock
/// reference: cyan→magenta gradient sweep that fills as the player
/// completes stacks in the current puzzle. Reads as the "wagon
/// loading" beat — when full, the puzzle is shipped.
class ContractProgressBar extends StatelessWidget {
  final GameState gameState;
  const ContractProgressBar({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    final total = gameState.totalStacks;
    final completed = gameState.completedStackCount;
    final progress = total <= 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'CONTRACT PROGRESS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: const Color(0xFFFFFFFF).withValues(alpha: 0.75),
              shadows: const [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Track + fill — cyan→magenta gradient sweep that "loads"
          // left to right as stacks clear.
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF0B0E16),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF2E5A8C).withValues(alpha: 0.55),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  heightFactor: 1.0,
                  widthFactor: progress,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFF2EE0C0),
                          Color(0xFFD24CFF),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD24CFF)
                              .withValues(alpha: 0.45),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

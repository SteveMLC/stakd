import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/garden_service.dart';
import '../widgets/themes/zen_garden_scene.dart';

class ZenGardenScreen extends StatelessWidget {
  const ZenGardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = GardenService.state;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ZenGardenScene(showStats: true, interactive: true),
          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: GameColors.text),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: GameColors.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${state.stageIcon} ${state.stageName}  •  ${state.totalPuzzlesSolved} puzzles',
                    style: const TextStyle(
                      color: GameColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

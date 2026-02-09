import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/themes/zen_garden_scene.dart';

class ZenGardenScreen extends StatelessWidget {
  const ZenGardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const ZenGardenScene(),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: GameColors.text),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                'Your Garden',
                style: TextStyle(
                  color: GameColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 10, color: GameColors.backgroundDark)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

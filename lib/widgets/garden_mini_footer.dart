import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Compact garden progress footer shown during puzzle gameplay
/// Shows current garden stage, progress bar, and puzzle counter
class GardenMiniFooter extends StatefulWidget {
  final int gardenStage;
  final double progress; // 0.0 - 1.0 to next stage
  final String stageName;
  final bool justSolved; // triggers celebration animation
  final int puzzlesSolvedInStage;
  final int puzzlesNeededForNextStage;

  const GardenMiniFooter({
    super.key,
    required this.gardenStage,
    required this.progress,
    required this.stageName,
    this.justSolved = false,
    required this.puzzlesSolvedInStage,
    required this.puzzlesNeededForNextStage,
  });

  @override
  State<GardenMiniFooter> createState() => _GardenMiniFooterState();
}

class _GardenMiniFooterState extends State<GardenMiniFooter>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(GardenMiniFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger glow animation when puzzle is solved
    if (widget.justSolved && !oldWidget.justSolved) {
      _glowController.forward(from: 0.0).then((_) {
        if (mounted) {
          _glowController.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Color _getProgressColor() {
    // Use green for early stages, transitioning to warm colors for later stages
    if (widget.gardenStage <= 2) {
      return const Color(0xFF2ED573); // Green
    } else if (widget.gardenStage <= 5) {
      return const Color(0xFF2FB9B3); // Teal
    } else if (widget.gardenStage <= 7) {
      return const Color(0xFFA55EEA); // Purple
    } else {
      return const Color(0xFFFFD93D); // Gold for late stages
    }
  }

  String _getStageIcon() {
    const icons = [
      '🌑', // Empty Canvas
      '🌱', // First Signs
      '🌿', // Taking Root
      '🌲', // Growth
      '🌸', // Flourishing
      '🌺', // Bloom
      '🏮', // Harmony
      '⛩️', // Sanctuary
      '🌙', // Transcendence
      '✨', // Infinite
    ];
    return icons[widget.gardenStage.clamp(0, 9)];
  }

  @override
  Widget build(BuildContext context) {
    final progressColor = _getProgressColor();
    final stageIcon = _getStageIcon();

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glowIntensity = _glowAnimation.value;
        
        return Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border(
              top: BorderSide(
                color: GameColors.zen.withOpacity(0.15),
                width: 1,
              ),
            ),
            boxShadow: glowIntensity > 0
                ? [
                    BoxShadow(
                      color: progressColor.withOpacity(0.4 * glowIntensity),
                      blurRadius: 20 * glowIntensity,
                      spreadRadius: 5 * glowIntensity,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Garden icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: GameColors.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: progressColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      stageIcon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Stage info and progress
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Stage name
                      Text(
                        widget.stageName,
                        style: TextStyle(
                          color: GameColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      
                      // Progress bar
                      Stack(
                        children: [
                          // Background bar
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: GameColors.empty.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          // Progress fill
                          FractionallySizedBox(
                            widthFactor: widget.progress.clamp(0.0, 1.0),
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: progressColor,
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: progressColor.withOpacity(0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Counter
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${widget.puzzlesSolvedInStage}/${widget.puzzlesNeededForNextStage}',
                      style: TextStyle(
                        color: progressColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'to next',
                      style: TextStyle(
                        color: GameColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

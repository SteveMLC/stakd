import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'particles/confetti_overlay.dart';

/// Celebration overlay shown when level is complete
class CelebrationOverlay extends StatefulWidget {
  final int moveCount;
  final VoidCallback onNextLevel;
  final VoidCallback onHome;

  const CelebrationOverlay({
    super.key,
    required this.moveCount,
    required this.onNextLevel,
    required this.onHome,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          // Confetti behind everything
          const Positioned.fill(
            child: ConfettiOverlay(
              duration: Duration(seconds: 3),
              colors: GameColors.palette,
              confettiCount: 50,
            ),
          ),
          
          // Dark overlay and content
          Container(
            color: Colors.black.withValues(alpha: 0.7),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Star icon
                  const Icon(
                    Icons.star,
                    size: 80,
                    color: GameColors.accent,
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    'Level Complete!',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: GameColors.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Move count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: GameColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.touch_app,
                          color: GameColors.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.moveCount} moves',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Next Level button
                  ElevatedButton.icon(
                    onPressed: widget.onNextLevel,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next Level'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Home button
                  TextButton.icon(
                    onPressed: widget.onHome,
                    icon: const Icon(Icons.home),
                    label: const Text('Home'),
                    style: TextButton.styleFrom(
                      foregroundColor: GameColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

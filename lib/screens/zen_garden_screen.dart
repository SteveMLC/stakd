import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../models/garden_archetype.dart';
import '../services/garden_service.dart';
import '../widgets/themes/zen_garden_scene.dart';

class ZenGardenScreen extends StatefulWidget {
  const ZenGardenScreen({super.key});

  @override
  State<ZenGardenScreen> createState() => _ZenGardenScreenState();
}

class _ZenGardenScreenState extends State<ZenGardenScreen>
    with SingleTickerProviderStateMixin {
  bool _showArchetypeReveal = false;
  late AnimationController _revealController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeInOut),
    );
    _checkFirstView();
  }

  Future<void> _checkFirstView() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenReveal = prefs.getBool('garden_archetype_revealed') ?? false;
    
    if (!hasSeenReveal && mounted) {
      setState(() {
        _showArchetypeReveal = true;
      });
      await _revealController.forward();
      await Future.delayed(const Duration(seconds: 3));
      await _revealController.reverse();
      if (mounted) {
        setState(() {
          _showArchetypeReveal = false;
        });
      }
      await prefs.setBool('garden_archetype_revealed', true);
    }
  }

  String _getArchetypeEmoji(GardenArchetype archetype) {
    switch (archetype) {
      case GardenArchetype.minimalist:
        return '⚪';
      case GardenArchetype.stoneKeeper:
        return '🪨';
      case GardenArchetype.lanternGarden:
        return '🏮';
      case GardenArchetype.waterGarden:
        return '💧';
      case GardenArchetype.bloomGarden:
        return '🌸';
      case GardenArchetype.wildZen:
        return '🌿';
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final state = GardenService.state;
    final archetype = state.gardenArchetype;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: const Color(0xFF1A1A1A),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: (index) {
            if (index == 1) {
              // Navigate to zen/puzzle mode
              Navigator.pop(context);
            } else {
              setState(() => _selectedTab = index);
            }
          },
          selectedItemColor: const Color(0xFFFFB7C5),
          unselectedItemColor: Colors.white54,
          backgroundColor: const Color(0xFF1A1A1A),
          items: const [
            BottomNavigationBarItem(
              icon: Text('🌸', style: TextStyle(fontSize: 20)),
              activeIcon: Text('🌸', style: TextStyle(fontSize: 24)),
              label: 'Garden',
            ),
            BottomNavigationBarItem(
              icon: Text('🧩', style: TextStyle(fontSize: 20)),
              activeIcon: Text('🧩', style: TextStyle(fontSize: 24)),
              label: 'Puzzle',
            ),
          ],
        ),
      ),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${state.stageIcon} ${state.stageName}  •  ${state.totalPuzzlesSolved} puzzles',
                        style: const TextStyle(
                          color: GameColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        state.gardenArchetype.displayName,
                        style: const TextStyle(
                          color: GameColors.textMuted,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),
          // Archetype reveal overlay
          if (_showArchetypeReveal)
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, _) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.6),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getArchetypeEmoji(archetype),
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Your garden spirit:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              archetype.displayName.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              archetype.description,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../services/level_generator.dart';
import '../services/storage_service.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../widgets/game_board.dart';
import '../widgets/game_button.dart';
import '../widgets/celebration_overlay.dart';

/// Main gameplay screen
class GameScreen extends StatefulWidget {
  final int level;

  const GameScreen({
    super.key,
    required this.level,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late int _currentLevel;
  final LevelGenerator _levelGenerator = LevelGenerator();
  bool _showingAd = false;

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.level;
    _loadLevel();
  }

  void _loadLevel() {
    final stacks = _levelGenerator.generateSolvableLevel(_currentLevel);
    context.read<GameState>().initGame(stacks, _currentLevel);
  }

  void _onLevelComplete() async {
    final storage = StorageService();
    final adService = AdService();

    // Save progress
    await storage.markLevelCompleted(_currentLevel);
    await storage.addMoves(context.read<GameState>().moveCount);

    // Track for ads
    adService.onLevelComplete();
  }

  void _nextLevel() async {
    final adService = AdService();

    // Show interstitial if needed
    if (adService.shouldShowInterstitial()) {
      setState(() => _showingAd = true);
      await adService.showInterstitialIfReady();
      setState(() => _showingAd = false);
    }

    setState(() {
      _currentLevel++;
    });
    _loadLevel();
  }

  void _restartLevel() {
    _loadLevel();
  }

  void _onUndo() {
    final gameState = context.read<GameState>();
    if (gameState.canUndo) {
      AudioService().playTap();
      gameState.undo();
    }
  }

  void _onUndoWithAd() async {
    final adService = AdService();
    final gameState = context.read<GameState>();

    if (adService.isRewardedAdReady()) {
      final rewarded = await adService.showRewardedAd();
      if (rewarded) {
        gameState.addUndo();
      }
    }
  }

  void _goHome() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<GameState>(
            builder: (context, gameState, child) {
              return Stack(
                children: [
                  Column(
                    children: [
                      // Top bar
                      _buildTopBar(gameState),
                      
                      // Game board
                      Expanded(
                        child: GameBoard(
                          gameState: gameState,
                          onTap: () => AudioService().playTap(),
                          onMove: () => AudioService().playSlide(),
                          onClear: () => AudioService().playClear(),
                        ),
                      ),
                      
                      // Bottom controls
                      _buildBottomControls(gameState),
                    ],
                  ),
                  
                  // Win overlay
                  if (gameState.isComplete)
                    CelebrationOverlay(
                      moveCount: gameState.moveCount,
                      onNextLevel: () {
                        _onLevelComplete();
                        _nextLevel();
                      },
                      onHome: _goHome,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(GameState gameState) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Back button
          GameIconButton(
            icon: Icons.arrow_back,
            onPressed: _goHome,
          ),
          const Spacer(),
          
          // Level indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: GameColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Level $_currentLevel',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          
          // Move counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: GameColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.touch_app, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${gameState.moveCount}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(GameState gameState) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Restart button
          GameIconButton(
            icon: Icons.refresh,
            onPressed: _restartLevel,
          ),
          const SizedBox(width: 16),
          
          // Undo button
          GameIconButton(
            icon: Icons.undo,
            badge: gameState.undosRemaining > 0
                ? '${gameState.undosRemaining}'
                : null,
            isDisabled: !gameState.canUndo,
            onPressed: gameState.canUndo ? _onUndo : _onUndoWithAd,
          ),
          const SizedBox(width: 16),
          
          // Hint button (future feature)
          GameIconButton(
            icon: Icons.lightbulb_outline,
            onPressed: () {
              final hint = gameState.getHint();
              if (hint != null) {
                // TODO: Highlight hint stacks
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Move from stack ${hint.$1 + 1} to ${hint.$2 + 1}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

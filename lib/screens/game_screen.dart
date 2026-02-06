import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../services/level_generator.dart';
import '../services/storage_service.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/review_service.dart';
import '../services/tutorial_service.dart';
import '../utils/constants.dart';
import '../widgets/game_board.dart';
import '../widgets/game_button.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/review_prompt_dialog.dart';
import '../widgets/tutorial_overlay.dart';

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
  final TutorialService _tutorialService = TutorialService();
  final Map<int, GlobalKey> _stackKeys = {};
  final GlobalKey _undoButtonKey = GlobalKey();
  bool _showingAd = false;
  bool _showingHint = false;
  bool _showTutorial = false;
  bool _tutorialInitialized = false;
  int _hintSourceIndex = -1;
  int _hintDestIndex = -1;
  int? _previousSelectedStack;
  int _previousMoveCount = 0;

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.level;
    _checkTutorial();
    _loadLevel();
  }

  void _checkTutorial() {
    final storage = StorageService();
    if (!storage.getTutorialCompleted() && widget.level == 1) {
      _showTutorial = true;
    }
  }

  void _initTutorial() {
    if (!_tutorialInitialized && _showTutorial) {
      _tutorialInitialized = true;
      
      // Wait for first frame to get stack keys
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Find first non-empty stack
        final gameState = context.read<GameState>();
        int? firstNonEmptyStack;
        for (int i = 0; i < gameState.stacks.length; i++) {
          if (gameState.stacks[i].layers.isNotEmpty) {
            firstNonEmptyStack = i;
            break;
          }
        }
        
        if (firstNonEmptyStack != null && mounted) {
          _tutorialService.setTarget(
            firstNonEmptyStack,
            _stackKeys[firstNonEmptyStack],
          );
          _tutorialService.start();
        }
      });
    }
  }

  void _updateTutorialTargets(GameState gameState) {
    if (!_tutorialService.isActive) return;

    final currentStep = _tutorialService.currentStep;

    // Update target based on current step
    if (currentStep == TutorialStep.selectStack) {
      // Highlight first non-empty stack
      for (int i = 0; i < gameState.stacks.length; i++) {
        if (gameState.stacks[i].layers.isNotEmpty) {
          _tutorialService.setTarget(i, _stackKeys[i]);
          break;
        }
      }
    } else if (currentStep == TutorialStep.moveLayer) {
      // Highlight valid destination after selection
      if (gameState.selectedStackIndex != null) {
        // Find a valid destination
        for (int i = 0; i < gameState.stacks.length; i++) {
          if (i != gameState.selectedStackIndex &&
              gameState.canMoveTo(gameState.selectedStackIndex!, i)) {
            _tutorialService.setTarget(i, _stackKeys[i]);
            break;
          }
        }
      }
    } else if (currentStep == TutorialStep.undo) {
      // Highlight undo button
      _tutorialService.setTarget(null, _undoButtonKey);
    } else {
      // Clear target for message steps
      _tutorialService.setTarget(null, null);
    }
  }

  void _handleGameStateChange(GameState gameState) {
    if (!_tutorialService.isActive) return;

    // Detect stack selection
    if (gameState.selectedStackIndex != null &&
        _previousSelectedStack != gameState.selectedStackIndex) {
      _tutorialService.onStackSelected(gameState.selectedStackIndex!);
      _previousSelectedStack = gameState.selectedStackIndex;
      
      // Update targets for next step
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateTutorialTargets(gameState);
        }
      });
    }

    // Detect move (move count increased)
    if (gameState.moveCount > _previousMoveCount) {
      _tutorialService.onLayerMoved();
      _previousMoveCount = gameState.moveCount;
      
      // Update targets for next step
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateTutorialTargets(gameState);
        }
      });
    }

    // Detect stack clear
    if (gameState.recentlyCleared.isNotEmpty) {
      _tutorialService.onStackCleared();
    }
  }

  void _onTutorialComplete() async {
    final storage = StorageService();
    await storage.setTutorialCompleted(true);
    setState(() {
      _showTutorial = false;
    });
  }

  void _onTutorialSkip() async {
    await _onTutorialComplete();
  }

  void _loadLevel() {
    final stacks = _levelGenerator.generateSolvableLevel(_currentLevel);
    context.read<GameState>().initGame(stacks, _currentLevel);
    
    // Reset hint state
    setState(() {
      _showingHint = false;
      _stackKeys.clear();
      _previousMoveCount = 0;
      _previousSelectedStack = null;
    });

    // Initialize tutorial if needed
    _initTutorial();
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
      
      // Track undo for tutorial
      if (_tutorialService.isActive) {
        _tutorialService.onUndoUsed();
      }
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

  void _showHint() {
    final gameState = context.read<GameState>();
    final hint = gameState.getHint();
    
    if (hint != null && !_showingHint) {
      setState(() {
        _showingHint = true;
        _hintSourceIndex = hint.$1;
        _hintDestIndex = hint.$2;
      });
      AudioService().playTap();
    }
  }

  void _dismissHint() {
    setState(() {
      _showingHint = false;
    });
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
              // Handle game state changes for tutorial
              _handleGameStateChange(gameState);

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
                          stackKeys: _stackKeys,
                          onTap: () => AudioService().playTap(),
                          onMove: () => AudioService().playSlide(),
                          onClear: () => AudioService().playClear(),
                        ),
                      ),
                      
                      // Bottom controls
                      _buildBottomControls(gameState),
                    ],
                  ),
                  
                  // Hint overlay
                  if (_showingHint && 
                      _stackKeys.containsKey(_hintSourceIndex) && 
                      _stackKeys.containsKey(_hintDestIndex))
                    Positioned.fill(
                      child: HintOverlay(
                        sourceIndex: _hintSourceIndex,
                        destIndex: _hintDestIndex,
                        sourceKey: _stackKeys[_hintSourceIndex]!,
                        destKey: _stackKeys[_hintDestIndex]!,
                        onDismiss: _dismissHint,
                      ),
                    ),
                  
                  // Tutorial overlay
                  if (_showTutorial && _tutorialService.isActive)
                    Positioned.fill(
                      child: TutorialOverlay(
                        tutorialService: _tutorialService,
                        onComplete: _onTutorialComplete,
                        onSkip: _onTutorialSkip,
                      ),
                    ),
                  
                  // Win overlay
                  if (gameState.isComplete)
                    CelebrationOverlay(
                      moveCount: gameState.moveCount,
                      maxCombo: gameState.maxCombo,
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
          
          // Undo button (with key for tutorial)
          GameIconButton(
            key: _undoButtonKey,
            icon: Icons.undo,
            badge: gameState.undosRemaining > 0
                ? '${gameState.undosRemaining}'
                : null,
            isDisabled: !gameState.canUndo,
            onPressed: gameState.canUndo ? _onUndo : _onUndoWithAd,
          ),
          const SizedBox(width: 16),
          
          // Hint button
          GameIconButton(
            icon: Icons.lightbulb_outline,
            onPressed: _showHint,
          ),
        ],
      ),
    );
  }
}

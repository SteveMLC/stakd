import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/game_state.dart';
import '../services/level_generator.dart';
import '../services/storage_service.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/tutorial_service.dart';
import '../services/haptic_service.dart';
import '../utils/constants.dart';
import '../widgets/game_board.dart';
import '../widgets/game_button.dart';
import '../widgets/completion_overlay.dart';
import '../widgets/hint_overlay.dart';
import '../widgets/multi_grab_hint_overlay.dart';
import '../widgets/tutorial_overlay.dart';
import 'settings_screen.dart';

/// Main gameplay screen
class GameScreen extends StatefulWidget {
  final int level;

  const GameScreen({super.key, required this.level});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late int _currentLevel;
  final LevelGenerator _levelGenerator = LevelGenerator();
  final TutorialService _tutorialService = TutorialService();
  final Map<int, GlobalKey> _stackKeys = {};
  final GlobalKey _undoButtonKey = GlobalKey();
  bool _showingHint = false;
  bool _showTutorial = false;
  bool _tutorialInitialized = false;
  int _hintSourceIndex = -1;
  int _hintDestIndex = -1;
  int? _previousSelectedStack;
  int _previousMoveCount = 0;
  bool _showMultiGrabHint = false;
  bool _multiGrabHintScheduled = false;
  DateTime? _levelStartTime;
  Duration? _completionDuration;

  IapService? _iapService;

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.level;
    _checkTutorial();
    _loadLevel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iapService == null) {
      _iapService = context.read<IapService>();
      _iapService!.addListener(_onIapChanged);
    }
  }

  @override
  void dispose() {
    _iapService?.removeListener(_onIapChanged);
    super.dispose();
  }

  void _onIapChanged() {
    final iap = _iapService;
    if (iap == null) return;
    final message = iap.errorMessage;
    if (message != null && mounted) {
      iap.clearError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
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
      final selectedIndex = gameState.selectedStackIndex;
      if (selectedIndex >= 0) {
        // Find first valid destination (empty stack or compatible)
        for (int i = 0; i < gameState.stacks.length; i++) {
          if (i != selectedIndex) {
            final fromStack = gameState.stacks[selectedIndex];
            final toStack = gameState.stacks[i];
            if (!fromStack.isEmpty && toStack.canAccept(fromStack.topLayer!)) {
              _tutorialService.setTarget(i, _stackKeys[i]);
              break;
            }
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
    final currentSelected = gameState.selectedStackIndex >= 0
        ? gameState.selectedStackIndex
        : null;
    if (currentSelected != null && _previousSelectedStack != currentSelected) {
      _tutorialService.onStackSelected(currentSelected);
      _previousSelectedStack = currentSelected;

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

  void _captureCompletionTime(GameState gameState) {
    if (!gameState.isComplete || _completionDuration != null) return;
    final startTime = _levelStartTime;
    if (startTime == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _completionDuration != null) return;
      setState(() {
        _completionDuration = DateTime.now().difference(startTime);
      });
      // Heavy haptic impact on level complete
      HapticFeedback.heavyImpact();
      // Follow with success pattern for extra juice
      Future.delayed(const Duration(milliseconds: 100), () {
        haptics.levelWinPattern();
      });
    });
  }

  void _onTutorialComplete() async {
    final storage = StorageService();
    await storage.setTutorialCompleted(true);
    setState(() {
      _showTutorial = false;
    });
  }

  void _onTutorialSkip() {
    _onTutorialComplete();
  }

  void _loadLevel() {
    final (stacks, par) = _levelGenerator.generateLevelWithPar(_currentLevel);
    context.read<GameState>().initGame(stacks, _currentLevel, par: par);
    _levelStartTime = DateTime.now();
    _completionDuration = null;

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
    final moveCount = context.read<GameState>().moveCount;

    // Save progress
    await storage.markLevelCompleted(_currentLevel);
    await storage.addMoves(moveCount);

    // Track for ads
    adService.onLevelComplete();
  }

  void _nextLevel() async {
    final adService = AdService();

    // Show interstitial if needed
    if (adService.shouldShowInterstitial()) {
      await adService.showInterstitialIfReady();
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

  void _goToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _showHint() {
    final iap = context.read<IapService>();
    if (iap.hintCount <= 0) {
      _showHintPurchaseDialog(iap);
      return;
    }

    final gameState = context.read<GameState>();
    final hint = gameState.getHint();

    if (hint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid moves right now.')),
      );
      return;
    }

    if (!iap.consumeHint()) {
      _showHintPurchaseDialog(iap);
      return;
    }

    if (!_showingHint) {
      setState(() {
        _showingHint = true;
        _hintSourceIndex = hint.$1;
        _hintDestIndex = hint.$2;
      });
      AudioService().playTap();
    }
  }

  void _showHintPurchaseDialog(IapService iap) {
    if (!iap.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store unavailable.')),
      );
      return;
    }

    final price = iap.hintPackPrice ?? '\$1.99';

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Out of hints'),
          content: Text('Get 10 more hints for $price?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: iap.isLoading
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      iap.buyHintPack();
                    },
              child: const Text('Buy'),
            ),
          ],
        );
      },
    );
  }

  void _dismissHint() {
    setState(() {
      _showingHint = false;
    });
  }

  void _dismissMultiGrabHint() {
    setState(() {
      _showMultiGrabHint = false;
    });
  }

  void _maybeShowMultiGrabHint(GameState gameState) {
    if (_showMultiGrabHint || _multiGrabHintScheduled) return;
    final storage = StorageService();
    if (!storage.getMultiGrabHintsEnabled()) return;
    if (storage.hasSeenMultiGrabHint() || storage.hasUsedMultiGrab()) return;

    final hasOpportunity =
        gameState.stacks.any((stack) => stack.topGroupSize >= 2);
    if (!hasOpportunity) return;

    _multiGrabHintScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _multiGrabHintScheduled = false;
        return;
      }
      if (_showMultiGrabHint) return;
      setState(() {
        _showMultiGrabHint = true;
        _multiGrabHintScheduled = false;
      });
      storage.setMultiGrabHintSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final iap = context.watch<IapService>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: Consumer<GameState>(
            builder: (context, gameState, child) {
              // Handle game state changes for tutorial
              _handleGameStateChange(gameState);
              _maybeShowMultiGrabHint(gameState);
              _captureCompletionTime(gameState);

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
                      
                      // Banner ad
                      _buildBannerAd(),
                      
                      // Bottom controls
                      _buildBottomControls(gameState, iap),
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
                  if (_showMultiGrabHint)
                    MultiGrabHintOverlay(onDismiss: _dismissMultiGrabHint),

                  // Win overlay
                  if (gameState.isComplete)
                    CompletionOverlay(
                      moves: gameState.moveCount,
                      time: _completionDuration ?? Duration.zero,
                      onNextPuzzle: () {
                        _onLevelComplete();
                        _nextLevel();
                      },
                      onHome: _goHome,
                    ),
                  if (iap.isLoading) _buildBlockingOverlay(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBlockingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Processing purchase...'),
            ],
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
          GameIconButton(icon: Icons.arrow_back, onPressed: _goHome),
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const Spacer(),

          // Move counter with par
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: GameColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: gameState.par != null
                      ? Border.all(
                          color: gameState.isUnderPar
                              ? Colors.green.withValues(alpha: 0.6)
                              : gameState.moveCount > (gameState.par! + 5)
                                  ? Colors.red.withValues(alpha: 0.4)
                                  : Colors.transparent,
                          width: 2,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      gameState.par != null
                          ? '${gameState.moveCount}/${gameState.par}'
                          : '${gameState.moveCount}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: gameState.par != null && gameState.isUnderPar
                            ? Colors.green
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${gameState.completedStackCount}/${gameState.totalStacks}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: GameColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: GameColors.palette[2].withValues(alpha: 0.7),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Settings button
          GameIconButton(icon: Icons.settings, onPressed: _goToSettings),
        ],
      ),
    );
  }

  Widget _buildBannerAd() {
    final adService = AdService();
    final bannerAd = adService.bannerAd;

    // Don't show if ads are disabled (premium user)
    if (!adService.shouldShowAds || bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: bannerAd.size.width.toDouble(),
      height: bannerAd.size.height.toDouble(),
      child: AdWidget(ad: bannerAd),
    );
  }

  Widget _buildBottomControls(GameState gameState, IapService iap) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Restart button
          GameIconButton(icon: Icons.refresh, onPressed: _restartLevel),
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
            badge: '${iap.hintCount}',
            onPressed: _showHint,
          ),
        ],
      ),
    );
  }
}

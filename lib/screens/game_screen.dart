import 'package:flutter/material.dart';
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
import '../services/achievement_service.dart';
import '../services/leaderboard_service.dart';
import '../services/currency_service.dart';
import '../utils/constants.dart';
import '../utils/route_transitions.dart';
import '../widgets/game_board.dart';
import '../widgets/game_button.dart';
import '../widgets/completion_overlay.dart';
import '../widgets/hint_overlay.dart';
import '../widgets/multi_grab_hint_overlay.dart';
import '../widgets/tutorial_overlay.dart';
import '../widgets/power_up_bar.dart';
import '../widgets/power_up_effects.dart';
import '../services/power_up_service.dart';
import '../widgets/achievement_toast_overlay.dart';
import 'settings_screen.dart';

/// Main gameplay screen
class GameScreen extends StatefulWidget {
  final int level;

  const GameScreen({super.key, required this.level});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with AchievementToastMixin {
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
  int _hintsRemainingThisPuzzle = 3;
  int? _previousSelectedStack;
  int _previousMoveCount = 0;
  bool _showMultiGrabHint = false;
  bool _multiGrabHintScheduled = false;
  DateTime? _levelStartTime;
  Duration? _completionDuration;
  int _earnedStars = 0;
  int _coinsEarned = 0;
  bool _isNewStarRecord = false;

  // Power-up state
  bool _colorBombSelectionMode = false;
  bool _magnetSelectionMode = false;
  List<int> _magnetEligibleStacks = [];
  List<Offset> _colorBombEffectPositions = [];
  Color? _colorBombEffectColor;
  bool _showColorBombEffect = false;
  bool _showShuffleEffect = false;
  List<Offset> _shuffleBlockPositions = [];
  List<Color> _shuffleBlockColors = [];
  bool _showMagnetEffect = false;
  Offset? _magnetSourcePos;
  Offset? _magnetTargetPos;
  Color? _magnetBlockColor;

  IapService? _iapService;
  PowerUpService? _powerUpService;

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
    _powerUpService ??= context.read<PowerUpService>();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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

      // Wait for first frame so stack keys are ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final gameState = context.read<GameState>();
        _tutorialService.start();
        _updateTutorialTargets(gameState);
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _completionDuration != null) return;

      // Calculate stars
      final stars = gameState.calculateStars();
      final storage = StorageService();
      final isNewRecord = await storage.setLevelStars(_currentLevel, stars);

      // Check for star-based achievements
      await AchievementService().checkStarAchievements();

      // Award coins based on stars earned (10 coins per star)
      final coinsEarned = stars * 10;
      await CurrencyService().addCoins(coinsEarned);

      setState(() {
        _completionDuration = DateTime.now().difference(startTime);
        _earnedStars = stars;
        _coinsEarned = coinsEarned;
        _isNewStarRecord = isNewRecord;
      });
      // Play win sound
      AudioService().playWin();
      // Heavy haptic impact on level complete
      haptics.heavyImpact();
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
      _hintsRemainingThisPuzzle = 3;
      _stackKeys.clear();
      _previousMoveCount = 0;
      _previousSelectedStack = null;
      _earnedStars = 0;
      _isNewStarRecord = false;
    });

    // Initialize tutorial if needed
    _initTutorial();
  }

  void _onLevelComplete() async {
    final storage = StorageService();
    final adService = AdService();
    final leaderboardService = LeaderboardService();
    final gameState = context.read<GameState>();
    final moveCount = gameState.moveCount;

    // Save progress
    await storage.markLevelCompleted(_currentLevel);
    await storage.addMoves(moveCount);

    // Track for ads
    adService.onLevelComplete();

    // Submit to leaderboards
    final totalStars = storage.getTotalStars();
    final maxCombo = gameState.maxCombo;

    // Submit all-time stars
    if (totalStars > 0) {
      leaderboardService.submitAllTimeStars(totalStars);
      leaderboardService.submitWeeklyStars(totalStars);
    }

    // Submit best combo if it's a record
    if (maxCombo > 1) {
      leaderboardService.submitBestCombo(maxCombo);
    }
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

  void _onChainReaction(int chainLevel) {
    // Persist chain statistics
    final storage = StorageService();
    storage.updateMaxChain(chainLevel);
    storage.incrementTotalChains();

    // Check and unlock chain achievements
    final gameState = context.read<GameState>();
    AchievementService().checkChainAchievements(
      chainLevel,
      gameState.maxChainLevel,
    );
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

  void _retriggerTutorial() {
    setState(() {
      _showTutorial = true;
      _tutorialInitialized = false;
    });
    _initTutorial();
  }

  void _goToSettings() {
    Navigator.of(context).push(fadeSlideRoute(const SettingsScreen()));
  }

  void _showHint() {
    if (_hintsRemainingThisPuzzle <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hints remaining for this puzzle.')),
      );
      return;
    }

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
        _hintsRemainingThisPuzzle--;
      });
      AudioService().playTap();
    }
  }

  void _showHintPurchaseDialog(IapService iap) {
    if (!iap.isAvailable) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Store unavailable.')));
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

    final hasOpportunity = gameState.stacks.any(
      (stack) => stack.topGroupSize >= 2,
    );
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

  // ============== POWER-UP METHODS ==============

  void _onColorBombPressed() {
    final powerUpService = _powerUpService;
    if (powerUpService == null ||
        !powerUpService.isAvailable(PowerUpType.colorBomb)) {
      _showPowerUpPurchaseDialog();
      return;
    }

    // Enter selection mode
    setState(() {
      _colorBombSelectionMode = true;
      _magnetSelectionMode = false;
    });
    AudioService().playTap();
  }

  void _onColorBombColorSelected(int colorIndex) async {
    final powerUpService = _powerUpService;
    final gameState = context.read<GameState>();

    if (powerUpService == null) return;

    // Consume the power-up
    final success = await powerUpService.usePowerUp(PowerUpType.colorBomb);
    if (!success) return;

    // Get positions of blocks to remove for animation
    final positions = <Offset>[];
    for (int stackIdx = 0; stackIdx < gameState.stacks.length; stackIdx++) {
      final stack = gameState.stacks[stackIdx];
      final stackKey = _stackKeys[stackIdx];
      if (stackKey?.currentContext == null) continue;

      final renderBox =
          stackKey!.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;

      final stackPos = renderBox.localToGlobal(Offset.zero);

      for (int layerIdx = 0; layerIdx < stack.layers.length; layerIdx++) {
        final layer = stack.layers[layerIdx];
        if (layer.colorIndex == colorIndex && !layer.isLocked) {
          final layerY =
              stackPos.dy +
              (stack.layers.length - 1 - layerIdx) *
                  (GameSizes.layerHeight + GameSizes.layerMargin);
          positions.add(
            Offset(
              stackPos.dx + GameSizes.stackWidth / 2,
              layerY + GameSizes.layerHeight / 2,
            ),
          );
        }
      }
    }

    // Activate the effect
    setState(() {
      _colorBombSelectionMode = false;
      _colorBombEffectPositions = positions;
      _colorBombEffectColor = GameColors.getColor(colorIndex);
      _showColorBombEffect = true;
    });

    // Apply the color bomb
    gameState.activateColorBomb(colorIndex);
    AudioService().playClear();
    haptics.heavyImpact();
  }

  void _cancelColorBombSelection() {
    setState(() {
      _colorBombSelectionMode = false;
    });
  }

  void _onColorBombEffectComplete() {
    setState(() {
      _showColorBombEffect = false;
      _colorBombEffectPositions = [];
      _colorBombEffectColor = null;
    });
  }

  void _onShufflePressed() async {
    final powerUpService = _powerUpService;
    final gameState = context.read<GameState>();

    if (powerUpService == null ||
        !powerUpService.isAvailable(PowerUpType.shuffle)) {
      _showPowerUpPurchaseDialog();
      return;
    }

    // Consume the power-up
    final success = await powerUpService.usePowerUp(PowerUpType.shuffle);
    if (!success) return;

    // Collect current block positions and colors for animation
    final positions = <Offset>[];
    final colors = <Color>[];

    for (int stackIdx = 0; stackIdx < gameState.stacks.length; stackIdx++) {
      final stack = gameState.stacks[stackIdx];
      final stackKey = _stackKeys[stackIdx];
      if (stackKey?.currentContext == null) continue;

      final renderBox =
          stackKey!.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;

      final stackPos = renderBox.localToGlobal(Offset.zero);

      for (int layerIdx = 0; layerIdx < stack.layers.length; layerIdx++) {
        final layer = stack.layers[layerIdx];
        final layerY =
            stackPos.dy +
            (stack.layers.length - 1 - layerIdx) *
                (GameSizes.layerHeight + GameSizes.layerMargin);
        positions.add(
          Offset(
            stackPos.dx + GameSizes.stackWidth / 2,
            layerY + GameSizes.layerHeight / 2,
          ),
        );
        colors.add(layer.color);
      }
    }

    setState(() {
      _shuffleBlockPositions = positions;
      _shuffleBlockColors = colors;
      _showShuffleEffect = true;
    });

    AudioService().playTap();
    haptics.mediumImpact();
  }

  void _onShuffleEffectComplete() {
    final gameState = context.read<GameState>();
    gameState.activateShuffle();

    setState(() {
      _showShuffleEffect = false;
      _shuffleBlockPositions = [];
      _shuffleBlockColors = [];
    });

    AudioService().playClear();
  }

  void _onMagnetPressed() {
    final powerUpService = _powerUpService;
    final gameState = context.read<GameState>();

    if (powerUpService == null ||
        !powerUpService.isAvailable(PowerUpType.magnet)) {
      _showPowerUpPurchaseDialog();
      return;
    }

    // Find eligible stacks
    final eligible = gameState.findMagnetEligibleStacks();
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No stacks eligible for Magnet. Need stacks with only 1 mismatched block.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _magnetSelectionMode = true;
      _colorBombSelectionMode = false;
      _magnetEligibleStacks = eligible.map((e) => e.$1).toList();
    });
    AudioService().playTap();
  }

  void _onMagnetStackSelected(int stackIndex) async {
    final powerUpService = _powerUpService;
    final gameState = context.read<GameState>();

    if (powerUpService == null) return;
    if (!_magnetEligibleStacks.contains(stackIndex)) return;

    // Consume the power-up
    final success = await powerUpService.usePowerUp(PowerUpType.magnet);
    if (!success) return;

    // Get source position for animation
    final stackKey = _stackKeys[stackIndex];
    Offset? sourcePos;

    if (stackKey?.currentContext != null) {
      final renderBox =
          stackKey!.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final stackPos = renderBox.localToGlobal(Offset.zero);
        sourcePos = Offset(
          stackPos.dx + GameSizes.stackWidth / 2,
          stackPos.dy + GameSizes.stackHeight / 2,
        );
      }
    }

    // Apply the magnet (get removed layer info)
    final result = gameState.activateMagnet(stackIndex);

    if (result != null && sourcePos != null) {
      setState(() {
        _magnetSelectionMode = false;
        _magnetEligibleStacks = [];
        _showMagnetEffect = true;
        _magnetSourcePos = sourcePos;
        _magnetTargetPos = Offset(
          sourcePos!.dx,
          sourcePos.dy - 150,
        ); // Fly away
        _magnetBlockColor = result.$2.color;
      });
      AudioService().playClear();
      haptics.mediumImpact();
    } else {
      setState(() {
        _magnetSelectionMode = false;
        _magnetEligibleStacks = [];
      });
    }
  }

  void _cancelMagnetSelection() {
    setState(() {
      _magnetSelectionMode = false;
      _magnetEligibleStacks = [];
    });
  }

  void _onMagnetEffectComplete() {
    setState(() {
      _showMagnetEffect = false;
      _magnetSourcePos = null;
      _magnetTargetPos = null;
      _magnetBlockColor = null;
    });
  }

  void _onEnhancedHintPressed() {
    if (_hintsRemainingThisPuzzle <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hints remaining for this puzzle.')),
      );
      return;
    }

    final powerUpService = _powerUpService;
    if (powerUpService == null ||
        !powerUpService.isAvailable(PowerUpType.hint)) {
      _showPowerUpPurchaseDialog();
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

    // Consume power-up only if we have a valid hint
    powerUpService.usePowerUp(PowerUpType.hint);

    setState(() {
      _showingHint = true;
      _hintSourceIndex = hint.$1;
      _hintDestIndex = hint.$2;
      _hintsRemainingThisPuzzle--;
    });
    AudioService().playTap();
  }

  void _showPowerUpPurchaseDialog() {
    final iap = context.read<IapService>();
    if (!iap.isAvailable) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Store unavailable.')));
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: GameColors.surface,
          title: const Text(
            'Get More Power-Ups',
            style: TextStyle(color: GameColors.text),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPackOption(
                '5 Power-Ups',
                iap.powerUpPack5Price ?? '\$0.99',
                () {
                  Navigator.of(context).pop();
                  iap.buyPowerUpPack5();
                },
              ),
              const SizedBox(height: 8),
              _buildPackOption(
                '20 Power-Ups',
                iap.powerUpPack20Price ?? '\$2.99',
                () {
                  Navigator.of(context).pop();
                  iap.buyPowerUpPack20();
                },
              ),
              const SizedBox(height: 8),
              _buildPackOption(
                '50 Power-Ups',
                iap.powerUpPack50Price ?? '\$4.99',
                () {
                  Navigator.of(context).pop();
                  iap.buyPowerUpPack50();
                },
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final messenger = ScaffoldMessenger.of(context);
                  final adService = AdService();
                  if (adService.isRewardedAdReady()) {
                    final rewarded = await adService.showRewardedAd();
                    if (!mounted) return;
                    if (rewarded) {
                      final awarded = await _powerUpService
                          ?.awardRandomPowerUp();
                      if (!mounted) return;
                      if (awarded != null) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('You earned 1 ${awarded.name}!'),
                          ),
                        );
                      }
                    }
                  } else {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('No ad available right now.'),
                      ),
                    );
                  }
                },
                icon: const Icon(
                  Icons.play_circle_outline,
                  color: GameColors.accent,
                ),
                label: const Text(
                  'Watch Ad for 1 Free',
                  style: TextStyle(color: GameColors.accent),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: GameColors.textMuted),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPackOption(String title, String price, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: GameColors.backgroundLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: GameColors.textMuted.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: GameColors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              price,
              style: TextStyle(
                color: GameColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Handle stack tap for power-up selection modes
  void _handlePowerUpStackTap(int stackIndex) {
    final gameState = context.read<GameState>();

    if (_colorBombSelectionMode) {
      // Get the color of the tapped stack's top block
      final stack = gameState.stacks[stackIndex];
      if (stack.isEmpty) return;

      final topLayer = stack.topLayer!;
      if (!topLayer.isLocked) {
        _onColorBombColorSelected(topLayer.colorIndex);
      }
    } else if (_magnetSelectionMode) {
      if (_magnetEligibleStacks.contains(stackIndex)) {
        _onMagnetStackSelected(stackIndex);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final iap = context.watch<IapService>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [GameColors.backgroundDark, GameColors.backgroundMid],
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
                          onChain: _onChainReaction,
                          onStackTapOverride:
                              (_colorBombSelectionMode || _magnetSelectionMode)
                              ? _handlePowerUpStackTap
                              : null,
                          highlightedStacks: _magnetSelectionMode
                              ? _magnetEligibleStacks
                              : null,
                        ),
                      ),

                      // Power-up bar
                      PowerUpBar(
                        onColorBomb: _onColorBombPressed,
                        onShuffle: _onShufflePressed,
                        onMagnet: _onMagnetPressed,
                        onHint: _onEnhancedHintPressed,
                        isSelectionMode:
                            _colorBombSelectionMode || _magnetSelectionMode,
                        activeSelection: _colorBombSelectionMode
                            ? PowerUpType.colorBomb
                            : _magnetSelectionMode
                            ? PowerUpType.magnet
                            : null,
                      ),

                      // Banner ad
                      _buildBannerAd(),

                      // Bottom controls
                      _buildBottomControls(gameState, iap),
                    ],
                  ),

                  // Power-up selection overlays
                  if (_colorBombSelectionMode)
                    ColorBombSelectionOverlay(
                      onCancel: _cancelColorBombSelection,
                    ),
                  if (_magnetSelectionMode)
                    MagnetSelectionOverlay(onCancel: _cancelMagnetSelection),

                  // Power-up effects
                  if (_showColorBombEffect && _colorBombEffectColor != null)
                    Positioned.fill(
                      child: ColorBombEffect(
                        blockPositions: _colorBombEffectPositions,
                        explosionColor: _colorBombEffectColor!,
                        onComplete: _onColorBombEffectComplete,
                      ),
                    ),
                  if (_showShuffleEffect)
                    Positioned.fill(
                      child: ShuffleEffect(
                        blockPositions: _shuffleBlockPositions,
                        blockColors: _shuffleBlockColors,
                        onComplete: _onShuffleEffectComplete,
                      ),
                    ),
                  if (_showMagnetEffect &&
                      _magnetSourcePos != null &&
                      _magnetTargetPos != null)
                    Positioned.fill(
                      child: MagnetEffect(
                        sourcePos: _magnetSourcePos!,
                        targetPos: _magnetTargetPos!,
                        blockColor: _magnetBlockColor ?? GameColors.accent,
                        onComplete: _onMagnetEffectComplete,
                      ),
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
                      par: gameState.par,
                      stars: _earnedStars,
                      coinsEarned: _coinsEarned,
                      isNewRecord: _isNewStarRecord,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                    style: TextStyle(fontSize: 14, color: GameColors.textMuted),
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

          // Tutorial help button
          GameIconButton(
            icon: Icons.help_outline,
            onPressed: _retriggerTutorial,
          ),
          const SizedBox(width: 8),

          // Hint button
          GameIconButton(
            icon: Icons.lightbulb_outline,
            badge: '$_hintsRemainingThisPuzzle',
            isDisabled: _hintsRemainingThisPuzzle <= 0,
            onPressed: _hintsRemainingThisPuzzle > 0 ? _showHint : null,
          ),
          const SizedBox(width: 8),

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
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        bottomPad > 0 ? bottomPad + 16 : 16,
      ),
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

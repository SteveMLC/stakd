import 'dart:math' as math;

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
import '../services/warehouse_economy_service.dart';
import '../services/business_tier_service.dart';
import '../services/contract_service.dart';
import '../services/income_multiplier_service.dart';
import '../services/hydraulic_pressure_service.dart';
import '../services/district_service.dart';
import '../services/reputation_service.dart';
import '../data/local_regional_levels.dart';
import '../utils/constants.dart';
import '../utils/route_transitions.dart';
import '../widgets/game_board.dart';
import '../widgets/game_button.dart';
import '../widgets/completion_overlay.dart';
import '../widgets/hint_overlay.dart';
import '../widgets/cash_payout_overlay.dart';
import '../widgets/hydraulic_pressure_gauge.dart';
import '../widgets/jam_recovery_modal.dart';
import '../widgets/multi_grab_hint_overlay.dart';
import '../widgets/warehouse_hud.dart';
import '../widgets/tutorial_overlay.dart';
import '../widgets/power_up_bar.dart';
import '../widgets/power_up_effects.dart';
import '../services/power_up_service.dart';
import '../widgets/achievement_toast_overlay.dart';
import '../widgets/particles/confetti_overlay.dart';
import '../widgets/color_flash_overlay.dart';
import '../widgets/warehouse_decorations.dart';
import '../widgets/promotion_ceremony_overlay.dart';
import '../utils/game_assets.dart';
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
  // Income multiplier snapshot around the rewards step. If `_incomeMulAfter`
  // > `_incomeMulBefore`, the SHIPMENT RECEIPT shows a ticker beat:
  //   "INCOME MULTIPLIER  2.10×  →  2.20×"
  // — i.e. this clear permanently raised the floor on all future earnings
  // (a contract finished, a WH level past 5 was crossed, or an income-bump
  // achievement just unlocked). The reveal sells the "accretive growth"
  // loop in the moment it pays out.
  double _incomeMulBefore = 1.0;
  double _incomeMulAfter = 1.0;
  // District clear + Reputation award snapshot, captured around the
  // district-clear path. Non-zero `_rpAwarded` triggers the inline RP
  // beat on the SHIPMENT RECEIPT; `_tierPromoted` true makes that
  // beat read as "TIER UP · BRONZE" with a pulse halo.
  int _rpAwarded = 0;
  bool _tierPromoted = false;
  String? _newTierName;
  String? _districtDisplayName;
  // Set to true once the player taps ACKNOWLEDGE on the promotion
  // ceremony overlay, OR reset whenever a new level starts. Keeps the
  // overlay from re-firing on rebuild after dismiss.
  bool _promotionAcknowledged = false;

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

  // Puzzle solve effects
  bool _showSolveConfetti = false;
  bool _showSolveFlash = false;

  // Inter-puzzle forklift transit. When the player taps "Next Puzzle"
  // on the receipt, a yellow forklift drives left → right across the
  // screen carrying a crate. The actual level swap happens at the
  // midpoint of the drive (behind the forklift) so the transition
  // reads as "this delivery just rolled off, here comes the next one"
  // — a tactile beat that makes the warehouse feel alive between
  // puzzles instead of a flat instant cut.
  bool _showTransit = false;

  IapService? _iapService;
  PowerUpService? _powerUpService;

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.level;
    _checkTutorial();
    // Defer to the next frame: _loadLevel calls
    // GameState.initGame -> notifyListeners, which would mark a parent
    // _InheritedProviderScope dirty during build (initState runs during
    // the build phase) and assert. The first paint will draw an empty
    // board for one frame, which is fine.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadLevel();
    });
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

  bool _showingCompletion = false; // SNAPPY FIX: Prevent duplicate menus
  bool _showingJamModal = false; // Re-armed when the jam clears.

  /// Watch for dock-jam state after every move (GDD §2.2). The detector
  /// lives on GameState.isJammed; this surfaces the recovery modal exactly
  /// once per jammed snapshot — re-arming when the player escapes.
  void _maybeShowJamModal(GameState gameState) {
    // Re-arm once the jam clears so the next jam fires fresh.
    if (!gameState.isJammed) {
      if (_showingJamModal) _showingJamModal = false;
      return;
    }
    if (gameState.isComplete) return; // Win path takes precedence.
    if (_showingCompletion) return;
    if (_showingJamModal) return;
    if (_showTutorial) return; // Don't preempt tutorial.

    _showingJamModal = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _showingJamModal = false;
        return;
      }
      final action = await JamRecoveryModal.show(context);
      if (!mounted) return;
      switch (action) {
        case JamRecoveryAction.restart:
          _loadLevel();
          break;
        case JamRecoveryAction.skip:
          _nextLevel();
          break;
        case JamRecoveryAction.watchAd:
        case JamRecoveryAction.undo:
        case JamRecoveryAction.dismissed:
          // Modal already mutated game state (or no-op'd). The next
          // notifyListeners pass will re-evaluate isJammed and either
          // re-fire the modal (if still jammed) or re-arm the flag.
          _showingJamModal = false;
          break;
      }
    });
  }

  void _captureCompletionTime(GameState gameState) {
    // SNAPPY FIX: Multiple guards to prevent duplicate completion
    if (!gameState.isComplete) return;
    if (_completionDuration != null) return;
    if (_showingCompletion) return; // Prevent race condition
    
    _showingCompletion = true; // Lock immediately
    
    final startTime = _levelStartTime;
    if (startTime == null) {
      _showingCompletion = false;
      return;
    }
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

      // Warehouse meta-loop reward (v0.3 §3 economy):
      //   cash = seed.baseCashReward × tier multiplier × star multiplier
      //   xp   = cash ÷ 2
      // Levels past 30 (procedural) extend smoothly from the L30 seed's
      // base (~$970) at +$100 per level — uncapped, so endless mode
      // earnings grow forever. Combined with the GROWTH-LOOP multiplier
      // (contract clears, tier purchases, achievement bumps, WH levels
      // past Lv5), late-game shipments pay 50× a fresh L1 clear.
      final seed = _seedForWarehouseLevel(_currentLevel);
      final tier = seed?.tier ?? BusinessTier.regional;
      final tierMul = BusinessTierService().multiplierFor(tier);
      final starMul = ShipmentRewardCalculator.starMultiplier(stars);
      final whLevel = WarehouseEconomyService().warehouseLevel;
      final incomeMul =
          IncomeMultiplierService().computeMultiplier(warehouseLevel: whLevel);
      final baseCash =
          seed?.baseCashReward ?? (970 + 100 * (_currentLevel - 30));
      // Hydraulic Pressure vent multiplier — if the player is mid-burst
      // when they finish the level, the receipt pays 2×. Single-source-
      // of-truth lookup so polish work later (e.g. flashing the receipt
      // when ventMul > 1) stays consistent.
      final ventMul = HydraulicPressureService().isVenting
          ? HydraulicPressureService.ventCashMultiplier
          : 1.0;
      final cashEarned =
          (baseCash * tierMul * starMul * incomeMul * ventMul).floor();
      final xpEarned = (cashEarned / 2).floor();
      final levelUp = await WarehouseEconomyService().awardReward(
        ShipmentReward(cash: cashEarned, xp: xpEarned),
      );

      // Contract progress: +50% of cumulative levels' base on completion.
      final contractBonusBase = baseCash * 5;
      final completedContract = await ContractService().recordLevelComplete(
        _currentLevel,
        stars,
        cashBonusForContract:
            ShipmentRewardCalculator.contractCompletionBonus(contractBonusBase),
      );
      if (completedContract != null && completedContract.cashBonus > 0) {
        await WarehouseEconomyService().grantCash(completedContract.cashBonus);
      }
      debugPrint(
        'Warehouse reward: +\$$cashEarned, +$xpEarned XP, '
        'levelUp=$levelUp, contract=${completedContract?.contract.displayName}',
      );

      // District clear + Reputation award. Fires when this level is
      // the LAST in its district (D1-D6 = the final level of the
      // matching contract; D7+ = procedural, every 5 levels past L30)
      // AND every level inside the district has at least 1 star.
      // Cleared districts grant RP, which feeds the infinite-scaling
      // Reputation tier ladder (+0.10× permanent income per tier
      // promotion, no cap).
      int districtRpAwarded = 0;
      bool districtTierPromoted = false;
      String? districtNewTierName;
      String? districtClearedName;
      final district = DistrictService().districtForLevel(_currentLevel);
      if (district != null && _currentLevel == district.lastLevel) {
        // Verify every level in this district has >= 1 star (the
        // current level was just awarded its stars above via
        // ContractService.recordLevelComplete).
        var allCleared = true;
        for (var l = district.firstLevel; l <= district.lastLevel; l++) {
          if (ContractService().starsForLevel(l) < 1) {
            allCleared = false;
            break;
          }
        }
        final rpAwarded = await DistrictService().onLevelComplete(
          level: _currentLevel,
          everyLevelInDistrictHasStar: allCleared,
        );
        if (rpAwarded > 0) {
          final promoted = await ReputationService().addReputation(rpAwarded);
          districtRpAwarded = rpAwarded;
          districtTierPromoted = promoted;
          districtNewTierName = ReputationService().displayName;
          districtClearedName = district.displayName;
          debugPrint(
            'District ${district.number} (${district.displayName}) cleared '
            '— +$rpAwarded RP, promoted=$promoted, '
            'newTier=${ReputationService().displayName}',
          );
          // Achievement credit for the meta-loop milestones. The
          // service's check methods are idempotent — calling them on
          // every district clear is fine, they no-op when the
          // achievement is already unlocked. Toast firing is handled
          // by the existing achievement-toast overlay subscription.
          AchievementService()
              .checkDistrictMilestones(districtNumber: district.number);
          if (promoted) {
            AchievementService().checkReputationTier(
              newTierLevel: ReputationService().currentTierLevel,
            );
          }
          // The inline RP badge on the SHIPMENT RECEIPT + the
          // PromotionCeremonyOverlay (when `promoted` is true) carry
          // the in-flight celebration; the achievement toasts pop
          // separately via the AchievementToastOverlay.
        }
      }

      // Snapshot the income multiplier AFTER all the reward + contract
      // wiring so any of (a) a WH level past 5, (b) a contract clear, or
      // (c) an income-bump achievement unlocked by checkStarAchievements
      // contributes to the post-clear value. `incomeMul` (line 321) was
      // already the pre-clear value, used to compute this payout's cash.
      final whLevelAfter = WarehouseEconomyService().warehouseLevel;
      final incomeMulAfter =
          IncomeMultiplierService().computeMultiplier(warehouseLevel: whLevelAfter);

      setState(() {
        _completionDuration = DateTime.now().difference(startTime);
        _earnedStars = stars;
        _coinsEarned = coinsEarned;
        _isNewStarRecord = isNewRecord;
        _incomeMulBefore = incomeMul;
        _incomeMulAfter = incomeMulAfter;
        _rpAwarded = districtRpAwarded;
        _tierPromoted = districtTierPromoted;
        _newTierName = districtNewTierName;
        _districtDisplayName = districtClearedName;
        // Reset the ceremony-acknowledged flag so the overlay fires
        // if this clear caused a promotion. Falls back to false on
        // non-promotion clears (overlay won't render anyway since the
        // `_tierPromoted` gate is false).
        _promotionAcknowledged = false;
      });
      // Cash-flies-to-wallet animation (warehouse meta payout). Includes
      // optional level-up banner when awardReward returned a new level.
      if (mounted) {
        CashPayoutOverlay.show(
          context,
          cash: cashEarned + (completedContract?.cashBonus ?? 0),
          xp: xpEarned,
          newWarehouseLevel: levelUp,
        );
      }
      // Play win sound (forklift horn + chime). If the player also
      // levelled up their warehouse, layer the heavier level-up
      // fanfare ~250ms after — gives the level-up its own beat.
      AudioService().playWin();
      if (levelUp != null) {
        Future.delayed(const Duration(milliseconds: 600), () {
          AudioService().playLevelUp();
        });
      }
      // Coin ding fires when the cash payout pill appears so the
      // "money flying" beat has its own bell.
      Future.delayed(const Duration(milliseconds: 250), () {
        AudioService().playCoin();
      });

      // Screen flash (white, 200ms)
      setState(() {
        _showSolveFlash = true;
        _showSolveConfetti = true;
      });

      // Haptic: success pattern (3 quick taps)
      haptics.heavyImpact();
      Future.delayed(const Duration(milliseconds: 80), () {
        haptics.mediumImpact();
      });
      Future.delayed(const Duration(milliseconds: 160), () {
        haptics.mediumImpact();
      });

      // Auto-hide confetti
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showSolveConfetti = false;
          });
        }
      });
    });
  }

  /// Look up a hand-tuned launch seed for this level. Returns null past L30
  /// (procedural-generation territory).
  WarehouseLevelSeed? _seedForWarehouseLevel(int level) {
    for (final s in localRegionalLevelSeeds) {
      if (s.level == level) return s;
    }
    return null;
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
    _showingCompletion = false; // SNAPPY FIX: Reset completion lock
    _showingJamModal = false; // Re-arm jam modal for the new level.

    // Hand the Hydraulic Pressure meter the current contract id so it
    // can either restore banked pressure (same contract) or zero out
    // (new contract or procedural levels past L30).
    final contract = ContractService().contractForLevel(_currentLevel);
    final contractId = contract?.displayName ?? 'procedural';
    HydraulicPressureService().onLevelStart(contractId);

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

    // Bank pressure so it carries into the next level of this contract.
    // Safe to call even if not initialized — service is a singleton with
    // sane defaults.
    await HydraulicPressureService().onLevelComplete();

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

  /// Plays the forklift-drives-across-the-screen transition between
  /// the previous level's receipt and the next puzzle. Returns when
  /// the forklift has fully exited screen right. The actual `_nextLevel`
  /// swap is done HALFWAY through (behind the forklift) so the
  /// transition reads as continuous.
  Future<void> _runForkliftTransit() async {
    if (_showTransit) return; // Idempotent — guard re-entry.
    setState(() => _showTransit = true);
    // Forklift drive duration is set inside the overlay widget; we
    // wait for it to clear the screen before doing the swap.
    await Future.delayed(const Duration(milliseconds: 1150));
    if (!mounted) return;
    setState(() => _showTransit = false);
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

  // ignore: unused_element
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

  /// Map a wrinkle id to a 1-char fallback glyph when we don't yet have
  /// an illustrated pictogram for it. Keeps the district badge from
  /// rendering empty on new wrinkles the asset catalog hasn't caught up
  /// to (e.g. conveyor-drift, gravity-flip, double-color, time-bomb
  /// before their dedicated Flux gens).
  String _wrinkleFallbackGlyph(String wrinkleId) {
    switch (wrinkleId) {
      case 'frozen':
        return '❄';
      case 'priority':
      case 'time-bomb':
        return '⏱';
      case 'fragile':
        return '⚠';
      case 'oversized':
        return '⬛';
      case 'conveyor-drift':
        return '↔';
      case 'gravity-flip':
        return '↕';
      case 'double-color':
        return '◐';
      default:
        return '✦';
    }
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

  Future<void> _onAddTubePressed(GameState gameState) async {
    if (gameState.addTubeUsed) return;
    final currency = CurrencyService();
    final coins = await currency.getCoins();
    if (!mounted) return;
    if (coins < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins! Need 100 coins.')),
      );
      return;
    }
    final success = await currency.spendCoins(100);
    if (success) {
      gameState.addEmptyTube();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empty tube added! 🧪')),
        );
      }
    }
  }

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
    AudioService().playPowerUp();

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
    AudioService().playPowerUp();

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
    AudioService().playPowerUp();

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
    AudioService().playPowerUp();

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
              _maybeShowJamModal(gameState);

              return Stack(
                children: [
                  Column(
                    children: [
                      // Top bar (wrapped in RepaintBoundary to avoid repaints during drag/animation)
                      RepaintBoundary(child: _buildTopBar(gameState)),

                      // Warehouse meta HUD: cash + WH level + XP + tier badge.
                      const RepaintBoundary(
                        child: WarehouseHud(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      ),

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

                      // Add Tube button
                      if (!gameState.addTubeUsed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _AddTubeButton(
                            onTap: () => _onAddTubePressed(gameState),
                          ),
                        ),

                      // Banner ad (wrapped in RepaintBoundary)
                      RepaintBoundary(child: _buildBannerAd()),

                      // Bottom controls (wrapped in RepaintBoundary)
                      RepaintBoundary(child: _buildBottomControls(gameState, iap)),
                    ],
                  ),

                  // Hydraulic Pressure gauge — anchored to the left edge
                  // of the board area. Player taps the VENT button on it
                  // to trigger a 4-move burst (combo doesn't reset, 2×
                  // cash on the next clear). Listens to its own
                  // singleton service so it repaints independently.
                  const Positioned(
                    left: 12,
                    top: 100,
                    bottom: 100,
                    child: HydraulicPressureGauge(),
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

                  // Solve flash overlay
                  if (_showSolveFlash)
                    Positioned.fill(
                      child: ColorFlashOverlay(
                        color: Colors.white.withValues(alpha: 0.3),
                        duration: const Duration(milliseconds: 200),
                        onComplete: () {
                          setState(() {
                            _showSolveFlash = false;
                          });
                        },
                      ),
                    ),
                  // Solve confetti
                  if (_showSolveConfetti)
                    Positioned.fill(
                      child: ConfettiOverlay(
                        colors: GameColors.palette,
                        confettiCount: 40,
                        duration: const Duration(seconds: 2),
                      ),
                    ),
                  // Win overlay
                  if (gameState.isComplete)
                    CompletionOverlay(
                      moves: gameState.moveCount,
                      time: _completionDuration ?? Duration.zero,
                      par: gameState.par,
                      stars: _earnedStars,
                      coinsEarned: _coinsEarned,
                      isNewRecord: _isNewStarRecord,
                      incomeMulBefore: _incomeMulBefore,
                      incomeMulAfter: _incomeMulAfter,
                      rpAwarded: _rpAwarded,
                      tierPromoted: _tierPromoted,
                      newTierName: _newTierName,
                      districtDisplayName: _districtDisplayName,
                      onNextPuzzle: () async {
                        // Kick the forklift transit FIRST so the
                        // receipt is masked while we swap levels.
                        // Stagger _onLevelComplete + _nextLevel a hair
                        // into the drive so they happen "behind" the
                        // moving forklift.
                        final transit = _runForkliftTransit();
                        await Future.delayed(
                            const Duration(milliseconds: 380));
                        _onLevelComplete();
                        _nextLevel();
                        await transit;
                      },
                      onHome: _goHome,
                      onReplay: _restartLevel,
                    ),
                  // Forklift transit overlay — drives across once
                  // every "Next Puzzle" tap. Lives above the receipt
                  // so it masks the level swap.
                  if (_showTransit)
                    const Positioned.fill(
                      child: IgnorePointer(child: _ForkliftTransitOverlay()),
                    ),
                  // Promotion ceremony overlay — fires on top of the
                  // SHIPMENT RECEIPT when a District clear pushed the
                  // player across a Reputation tier boundary. Rare,
                  // loud. Player must tap ACKNOWLEDGE to continue.
                  if (gameState.isComplete &&
                      _tierPromoted &&
                      !_promotionAcknowledged &&
                      _newTierName != null)
                    PromotionCeremonyOverlay(
                      newTierName: _newTierName!,
                      reputationMultiplierBonus:
                          ReputationService().tierMultiplierBonus,
                      onAcknowledge: () {
                        setState(() => _promotionAcknowledged = true);
                      },
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          // Back button
          GameIconButton(icon: Icons.arrow_back, onPressed: _goHome),
          const SizedBox(width: 8),

          // Level indicator — branded waybill stub, accent border so
          // it reads as "current contract" rather than a chip. Adds a
          // tiny district sub-line below "Lv N" so the player keeps
          // the infinite-scaling district identity in view during play
          // (e.g. "D3 · COLD STORAGE" under "Lv 12"). District lookup
          // is via the procedural composer — hand-tuned D1-D6 produce
          // their curated displayNames; D7+ produce the
          // "District N — Theme Flavor" composer output.
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: GameColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: GameColors.accent.withValues(alpha: 0.45),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    size: 14,
                    color: GameColors.accent,
                  ),
                  const SizedBox(width: 5),
                  Builder(builder: (_) {
                    final district = DistrictService()
                        .districtForLevel(_currentLevel);
                    // Compact district readout: `D{N}` only (the
                    // contract-select cards already carry the full
                    // "LOCAL DOCK / COLD STORAGE" display). Tiny
                    // wrinkle hint suffix if the district has one
                    // — single character so the badge stays under
                    // the constrained 75dp top-bar slot.
                    final firstWrinkle = district != null &&
                            district.wrinkles.isNotEmpty
                        ? district.wrinkles.first
                        : null;
                    final wrinkleAsset = wrinkleGlyphAsset(firstWrinkle);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lv $_currentLevel',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            height: 1.0,
                          ),
                        ),
                        if (district != null) ...[
                          const SizedBox(height: 1),
                          // Compact district readout — `D{N}` text +
                          // optional illustrated wrinkle pictogram for
                          // an active wrinkle (frozen / priority /
                          // fragile / oversized / etc). Falls back to
                          // a Unicode snowflake when no asset matches
                          // the wrinkle id yet so brand-new wrinkles
                          // don't render empty.
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'D${district.number}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                  fontFamily: 'Courier',
                                  color: GameColors.accent
                                      .withValues(alpha: 0.85),
                                  height: 1.0,
                                ),
                              ),
                              if (wrinkleAsset != null) ...[
                                const SizedBox(width: 3),
                                Image.asset(
                                  wrinkleAsset,
                                  width: 10,
                                  height: 10,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ] else if (firstWrinkle != null) ...[
                                // Fallback: no asset yet for this wrinkle
                                // id — use a tiny accent glyph so the
                                // district badge still signals active
                                // modifier.
                                Text(
                                  ' ${_wrinkleFallbackGlyph(firstWrinkle)}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: GameColors.accent
                                        .withValues(alpha: 0.85),
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Move counter with par — colour-codes by performance:
          // under par → green, near par → yellow, over par → red.
          Flexible(
            child: _MoveCounterChip(gameState: gameState),
          ),
          const SizedBox(width: 8),

          // Hint button (most-used during play — keep visible).
          GameIconButton(
            icon: Icons.lightbulb_outline,
            badge: '$_hintsRemainingThisPuzzle',
            isDisabled: _hintsRemainingThisPuzzle <= 0,
            onPressed: _hintsRemainingThisPuzzle > 0 ? _showHint : null,
          ),
          const SizedBox(width: 6),

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

/// Add Tube power-up button
/// Game-screen move/par pill with traffic-light colour coding:
/// green when the player is under par, yellow as they approach it,
/// red once they've overshot by ≥5. The colour transitions live in
/// an AnimatedContainer so the change isn't a jarring snap.
class _MoveCounterChip extends StatelessWidget {
  final GameState gameState;
  const _MoveCounterChip({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final par = gameState.par;
    final moves = gameState.moveCount;
    final hasParTarget = par != null;
    final isUnder = hasParTarget && moves <= par;
    final isOver = hasParTarget && moves > par + 4;
    final accent = isUnder
        ? const Color(0xFF4CAF50) // green
        : isOver
            ? const Color(0xFFE53935) // red
            : const Color(0xFFFFC107); // yellow / accent

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: GameColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isUnder || isOver ? 0.30 : 0.12),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app, size: 14, color: accent),
          const SizedBox(width: 4),
          Text(
            hasParTarget ? '$moves/$par' : '$moves',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTubeButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTubeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: GameColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: GameColors.zen.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GameColors.zen.withValues(alpha: 0.2),
                border: Border.all(
                  color: GameColors.zen,
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.add,
                color: GameColors.zen,
                size: 14,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Add Tube',
              style: TextStyle(
                color: GameColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '100🪙',
              style: TextStyle(
                color: GameColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drives a yellow `StencilForklift` carrying a cardboard crate
/// from off-screen left to off-screen right over ~1100ms. Layered
/// above the receipt + below the IAP blocking overlay; we use it
/// to mask the `_nextLevel` swap so the puzzle-to-puzzle handoff
/// reads as one continuous shot ("delivery completed, here comes
/// the next one") instead of an instant cut.
class _ForkliftTransitOverlay extends StatefulWidget {
  const _ForkliftTransitOverlay();

  @override
  State<_ForkliftTransitOverlay> createState() =>
      _ForkliftTransitOverlayState();
}

class _ForkliftTransitOverlayState extends State<_ForkliftTransitOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Forklift sized for warehouse credibility: ~38% screen wide.
    final forkliftW = (screenWidth * 0.38).clamp(140.0, 220.0);
    final forkliftH = forkliftW * 0.66;
    // Crate sits above the forks, slightly behind the body.
    final crateSize = forkliftH * 0.62;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Drive position eases in/out so the forklift "accelerates"
        // off-screen left and decelerates off-screen right.
        final drive = Curves.easeInOutQuad.transform(t);
        // Span: from -forkliftW (fully off-screen left) to screenWidth
        // (fully off-screen right). Total travel = screenWidth + forkliftW.
        final x = -forkliftW + drive * (screenWidth + forkliftW * 1.5);
        // Brief suspension bounce — 2 cycles of a soft sine over the
        // whole drive. Reads as the forklift rolling over the dock.
        final bounce = math.sin(t * math.pi * 4) * 3.0;
        // Backdrop dims at the midpoint (~peak transit obscuration)
        // to mask the level swap; transparent at the edges.
        final dimAlpha = 4 * t * (1 - t) * 0.55;

        return Stack(
          children: [
            // Dim sheet behind the forklift.
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: dimAlpha),
              ),
            ),
            // Forklift + crate, vertically centered.
            Positioned(
              left: x,
              top: 0,
              bottom: 0,
              child: Center(
                child: Transform.translate(
                  offset: Offset(0, bounce),
                  child: SizedBox(
                    width: forkliftW,
                    height: forkliftH + crateSize * 0.7,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // The crate sits on top of the forks (left side).
                        Positioned(
                          left: forkliftW * 0.02,
                          top: forkliftH * 0.10,
                          child: _TransitCrate(size: crateSize),
                        ),
                        // The forklift itself — mirror it so the forks
                        // lead the drive direction (point right).
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.diagonal3Values(-1, 1, 1),
                            child: StencilForklift(
                              width: forkliftW,
                              height: forkliftH,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A tiny cardboard-style crate to sit on the forklift's forks during
/// the transit. Hand-rolled rather than reusing the gameplay layer
/// widget so it stays decoration (no game-state coupling).
class _TransitCrate extends StatelessWidget {
  final double size;
  const _TransitCrate({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB8895A), Color(0xFF8A6638)],
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF5A4426),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Diagonal packing tape strap.
          Positioned(
            left: 0,
            right: 0,
            top: size * 0.42,
            child: Container(
              height: size * 0.14,
              color: const Color(0xFFE6C68C).withValues(alpha: 0.7),
            ),
          ),
          // Fragile-style stencil glyph in the middle.
          Center(
            child: Icon(
              Icons.inventory_2_outlined,
              color: const Color(0xFF3A2912).withValues(alpha: 0.75),
              size: size * 0.42,
            ),
          ),
        ],
      ),
    );
  }
}

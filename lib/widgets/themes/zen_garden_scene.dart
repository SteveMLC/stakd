import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/garden_state.dart';
import '../../models/garden_archetype.dart';
import '../../services/zen_audio_service.dart';
import '../../services/garden_service.dart';
import '../../utils/garden_variation.dart';
import '../garden/garden_element.dart';
import '../garden/growth_milestone.dart';
import 'base_theme_scene.dart';

class ZenGardenScene extends BaseThemeScene {
  final bool enableAudio;
  final bool enableMilestones;
  
  const ZenGardenScene({
    super.key,
    super.showStats = false,
    super.interactive = false,
    this.enableAudio = true,
    this.enableMilestones = true,
  });

  @override
  State<ZenGardenScene> createState() => _ZenGardenSceneState();
}

class _ZenGardenSceneState extends BaseThemeSceneState<ZenGardenScene>
    with TickerProviderStateMixin {
  late AnimationController _ambientController;
  late List<Offset> _fireflySeeds;
  late List<Offset> _petalSeeds;
  final ZenAudioService _audioService = ZenAudioService();
  int _lastStage = -1;
  bool _hadWater = false;
  late GardenVariation _variation;
  
  // Milestone tracking
  bool _showingMilestone = false;
  int? _milestoneStage;
  String? _milestoneStageName;

  // Cached particle unlock flags (updated once per build, not per animation frame)
  bool _hasButterfly = false;
  bool _hasPetals = false;
  bool _hasFireflies = false;
  bool _hasBirds = false;
  bool _hasDragonflies = false;

  // Draggable element positions
  final Map<String, Offset> _customPositions = {};

  // Archetype accessor
  GardenArchetype get _archetype => gardenState.gardenArchetype;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    // Add listener for audio updates instead of calling in build()
    _ambientController.addListener(_onAmbientTick);

    final rng = math.Random(42);
    _fireflySeeds = List.generate(8, (_) {
      return Offset(rng.nextDouble(), rng.nextDouble());
    });
    _petalSeeds = List.generate(6, (_) {
      return Offset(rng.nextDouble(), rng.nextDouble());
    });

    // Initialize variation with user seed
    _variation = GardenVariation(GardenService.state.userSeed);

    // Set up milestone listener
    if (widget.enableMilestones) {
      GardenService.onStageAdvanced = _onStageAdvanced;
    }

    // Listen for gentle rebuild signals from GardenService
    GardenService.rebuildNotifier.addListener(_onGardenRebuild);

    // Initialize with current stage
    _lastStage = gardenState.currentStage;

    // Start ambient audio
    if (widget.enableAudio) {
      _initAudio();
    }

    // Load saved positions
    _loadPositions();
  }

  int _lastAudioCheckFrame = -1;

  void _onAmbientTick() {
    // Check audio at most once per second (every ~60 frames at 60fps)
    final frame = (_ambientController.value * 600).floor(); // 10s * 60fps
    final second = frame ~/ 60;
    if (second != _lastAudioCheckFrame) {
      _lastAudioCheckFrame = second;
      _checkAudioUpdates();
    }
  }
  
  void _onStageAdvanced(int newStage, String stageName) {
    if (!mounted) return;
    setState(() {
      _showingMilestone = true;
      _milestoneStage = newStage;
      _milestoneStageName = stageName;
    });
  }
  
  void _onMilestoneComplete() {
    if (!mounted) return;
    setState(() {
      _showingMilestone = false;
      _milestoneStage = null;
      _milestoneStageName = null;
    });
  }

  Future<void> _initAudio() async {
    await _audioService.init();
    final isNight = gardenState.currentStage >= 6;
    final hasWater = isUnlocked('pond_full');
    await _audioService.startAmbience(isNight: isNight, hasWater: hasWater);
    _hadWater = hasWater;
    _lastStage = gardenState.currentStage;
  }

  void _checkAudioUpdates() {
    if (!widget.enableAudio) return;
    
    final state = gardenState;
    
    if (state.currentStage > _lastStage && _lastStage >= 0) {
      _audioService.playStageAdvance();
      _lastStage = state.currentStage;
    }
    
    final shouldBeNight = state.currentStage >= 6;
    if (shouldBeNight != _audioService.isNightMode) {
      _audioService.setNightMode(shouldBeNight);
    }
    
    final hasWater = isUnlocked('pond_full');
    if (hasWater && !_hadWater) {
      _audioService.setWaterEnabled(true);
      _audioService.playWaterDrop();
      _hadWater = true;
    }
  }

  void _onGardenRebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    GardenService.rebuildNotifier.removeListener(_onGardenRebuild);
    _ambientController.removeListener(_onAmbientTick);
    _ambientController.dispose();
    if (widget.enableAudio) {
      _audioService.stopAmbience();
    }
    GardenService.onStageAdvanced = null;
    super.dispose();
  }

  // ── Draggable position management ──

  Future<void> _loadPositions() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('garden_pos_'));
    for (final key in keys) {
      final id = key.replaceFirst('garden_pos_', '');
      final parts = prefs.getString(key)?.split(',');
      if (parts != null && parts.length == 2) {
        final dx = double.tryParse(parts[0]);
        final dy = double.tryParse(parts[1]);
        if (dx != null && dy != null) {
          _customPositions[id] = Offset(dx, dy);
        }
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _savePosition(String elementId, Offset pos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('garden_pos_$elementId', '${pos.dx},${pos.dy}');
  }

  Future<void> _resetAllPositions() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('garden_pos_')).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
    setState(() { _customPositions.clear(); });
  }

  /// Wraps a garden element as a draggable Positioned widget.
  /// [elementId] is used to persist position.
  /// [defaultLeft]/[defaultBottom] are the default layout positions.
  Widget _draggablePositioned({
    required String elementId,
    required double defaultLeft,
    required double defaultBottom,
    required Widget child,
    bool useRight = false,
    double? defaultRight,
  }) {
    final customPos = _customPositions[elementId];
    
    if (customPos != null) {
      // Custom position stored as (left, top)
      return Positioned(
        left: customPos.dx,
        top: customPos.dy,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              final old = _customPositions[elementId]!;
              _customPositions[elementId] = Offset(
                old.dx + details.delta.dx,
                old.dy + details.delta.dy,
              );
            });
          },
          onPanEnd: (_) {
            final pos = _customPositions[elementId];
            if (pos != null) _savePosition(elementId, pos);
          },
          child: child,
        ),
      );
    }

    // Default position: convert bottom-based to a key-based Positioned
    // We use a LayoutBuilder in the parent to know actual size, but for simplicity
    // we wrap in a builder that converts on first drag.
    if (useRight && defaultRight != null) {
      return Positioned(
        bottom: defaultBottom,
        right: defaultRight,
        child: GestureDetector(
          onPanStart: (details) {
            // Convert to absolute position on first drag
            final renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final globalPos = details.globalPosition;
              final localPos = renderBox.globalToLocal(globalPos);
              _customPositions[elementId] = Offset(localPos.dx - 20, localPos.dy - 20);
              setState(() {});
            }
          },
          child: child,
        ),
      );
    }

    return Positioned(
      bottom: defaultBottom,
      left: defaultLeft,
      child: GestureDetector(
        onPanStart: (details) {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final globalPos = details.globalPosition;
            final localPos = renderBox.globalToLocal(globalPos);
            _customPositions[elementId] = Offset(localPos.dx - 20, localPos.dy - 20);
            setState(() {});
          }
        },
        child: child,
      ),
    );
  }

  Widget _withVariation(String elementId, Widget child) {
    final rotation = _variation.rotationFor(elementId);
    final scale = _variation.scaleFor(elementId);
    final offset = _variation.positionOffsetFor(elementId);
    
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = gardenState;
    
    // Cache particle unlock flags once per build
    _hasButterfly = isUnlocked('butterfly');
    _hasPetals = isUnlocked('petals');
    _hasFireflies = isUnlocked('fireflies');
    _hasBirds = isUnlocked('birds');
    _hasDragonflies = isUnlocked('dragonflies');

    final groundAssets = _buildGroundAssetsList();
    final waterList = (isUnlocked('pond_empty') || isUnlocked('pond_full')) ? _buildWaterList() : <Widget>[];
    final floraList = _buildFloraList(state.currentStage);
    final structuresList = _buildStructuresList();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 0: Sky/background
        _buildSky(state.currentStage),

        // Layer 1: Distant background
        if (isUnlocked('mountain')) _buildDistantBackground(),

        // Ground assets
        ...groundAssets,

        // Water features
        ...waterList,

        // Flora
        ...floraList,

        // Structures
        ...structuresList,

        // Particles - only particles rebuild on animation tick
        AnimatedBuilder(
          animation: _ambientController,
          builder: (context, child) => _buildParticles(),
        ),

        // Mist overlay (stage 8+)
        if (state.currentStage >= 8) _buildMistOverlay(),

        // Stats overlay with reset button
        if (widget.showStats)
          Positioned(
            bottom: 20,
            left: 20,
            child: _buildStatsCard(state),
          ),
        
        // Milestone celebration
        if (_showingMilestone && _milestoneStage != null && _milestoneStageName != null)
          GrowthMilestone(
            stage: _milestoneStage!,
            stageName: _milestoneStageName!,
            onComplete: _onMilestoneComplete,
          ),
      ],
    );
  }

  Widget _buildSky(int stage) {
    final isNight = stage >= 6;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/backgrounds/slate_bg.jpg',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
        
        if (isNight)
          Container(
            color: const Color(0xFF0D1321).withValues(alpha: 0.65),
          ),
        
        if (isNight) _buildStars(),
        
        if (isUnlocked('moon')) 
          _buildMoon()
        else if (!isNight && stage >= 3)
          _buildSun(),
      ],
    );
  }

  Widget _buildStars() {
    final rng = math.Random(123);
    return Stack(
      children: List.generate(30, (i) {
        final x = rng.nextDouble();
        final y = rng.nextDouble() * 0.6;
        final size = 1.0 + rng.nextDouble() * 2;
        final twinkle = rng.nextDouble();
        
        return Positioned(
          left: x * MediaQuery.of(context).size.width,
          top: y * MediaQuery.of(context).size.height,
          child: AnimatedBuilder(
            animation: _ambientController,
            builder: (context, child) {
              final opacity = 0.3 + 0.7 * ((math.sin(
                _ambientController.value * 2 * math.pi + twinkle * 10
              ) + 1) / 2);
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildMoon() {
    return Positioned(
      top: 40,
      right: 30,
      child: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFFAE6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFFAE6).withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSun() {
    return Positioned(
      top: 35,
      right: 40,
      child: AnimatedBuilder(
        animation: _ambientController,
        builder: (context, child) {
          final glow = 10 + math.sin(_ambientController.value * 2 * math.pi) * 3;
          return Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF9C4),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFEB3B).withValues(alpha: 0.4),
                  blurRadius: glow,
                  spreadRadius: 3,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDistantBackground() {
    return Positioned(
      bottom: 340,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 200,
        child: Stack(
          children: [
            CustomPaint(
              size: const Size(double.infinity, 200),
              painter: MountainPainter(),
            ),
            if (isUnlocked('clouds')) _buildClouds(),
          ],
        ),
      ),
    );
  }

  Widget _buildClouds() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _ambientController,
        builder: (context, child) {
          final drift = _ambientController.value * 40;
          return Stack(
            children: [
              _cloud(left: 20 + drift, top: 20, scale: 0.9),
              _cloud(right: 40 - drift, top: 50, scale: 1.1),
            ],
          );
        },
      ),
    );
  }

  Widget _cloud({double? left, double? right, required double top, double scale = 1}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 90,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  // ── Water features ──

  List<Widget> _buildWaterList() {
    final elements = <Widget>[];
    final waterScale = _archetype.scaleMultiplierFor('water');

    // Pond empty
    if (isUnlocked('pond_empty') && !isUnlocked('pond_full')) {
      elements.add(
        _draggablePositioned(
          elementId: 'pond_empty',
          defaultLeft: 0, defaultBottom: 200, useRight: true, defaultRight: 20,
          child: _withVariation('pond_empty', GardenElement(
            elementId: 'pond_empty',
            revealType: GardenRevealType.rippleIn,
            child: Image.asset(
              'assets/images/zen-garden/zen_pond_empty.png',
              width: (150 * waterScale).round().toDouble(),
              height: (90 * waterScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Pond full — right side of garden
    if (isUnlocked('pond_full')) {
      elements.add(
        _draggablePositioned(
          elementId: 'pond_full',
          defaultLeft: 0, defaultBottom: 200, useRight: true, defaultRight: 20,
          child: _withVariation('pond_full', GardenElement(
            elementId: 'pond_full',
            revealType: GardenRevealType.rippleIn,
            child: Image.asset(
              'assets/images/zen-garden/zen_pond.png',
              width: (170 * waterScale).round().toDouble(),
              height: (100 * waterScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Lily pads on pond
    if (isUnlocked('lily_pads')) {
      elements.add(
        _draggablePositioned(
          elementId: 'lily_pads',
          defaultLeft: 0, defaultBottom: 230, useRight: true, defaultRight: 50,
          child: _withVariation('lily_pads', GardenElement(
            elementId: 'lily_pads',
            revealType: GardenRevealType.bloomOut,
            child: Image.asset(
              'assets/images/zen-garden/zen_lily_pads.png',
              width: (90 * waterScale).round().toDouble(),
              height: (55 * waterScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Waterfall/stream — left side
    if (isUnlocked('stream')) {
      elements.add(
        _draggablePositioned(
          elementId: 'stream',
          defaultLeft: 0, defaultBottom: 280,
          child: _withVariation('stream', GardenElement(
            elementId: 'stream',
            revealType: GardenRevealType.rippleIn,
            child: Image.asset(
              'assets/images/zen-garden/zen_waterfall.png',
              width: (120 * waterScale).round().toDouble(),
              height: (170 * waterScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Koi fish (animated, not draggable — lives on the pond)
    if (isUnlocked('koi_fish') && isUnlocked('pond_full')) {
      elements.add(
        Positioned(
          bottom: 200,
          right: 20,
          child: GardenElement(
            elementId: 'koi_fish',
            revealType: GardenRevealType.rippleIn,
            showParticles: false,
            child: SizedBox(
              width: 170,
              height: 100,
              child: AnimatedBuilder(
                animation: _ambientController,
                builder: (context, child) {
                  return Stack(
                    children: [
                      _koiFish(
                        progress: _ambientController.value,
                        startX: 20,
                        startY: 35,
                        color: const Color(0xFFFF6B00),
                      ),
                      _koiFish(
                        progress: (_ambientController.value + 0.5) % 1.0,
                        startX: 60,
                        startY: 25,
                        color: const Color(0xFFFFFFFF),
                        reverse: true,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    return elements;
  }

  Widget _koiFish({
    required double progress,
    required double startX,
    required double startY,
    required Color color,
    bool reverse = false,
  }) {
    final t = progress * 2 * math.pi;
    final x = startX + math.sin(t) * 30 * (reverse ? -1 : 1);
    final y = startY + math.sin(t * 2) * 10;
    final angle = math.atan2(
      math.cos(t * 2) * 10,
      math.cos(t) * 30 * (reverse ? -1 : 1),
    );

    return Positioned(
      left: x,
      top: y,
      child: Transform.rotate(
        angle: angle + (reverse ? math.pi : 0),
        child: SizedBox(
          width: 16,
          height: 8,
          child: CustomPaint(
            painter: KoiFishPainter(color: color),
          ),
        ),
      ),
    );
  }

  // ── Flora ──

  List<Widget> _buildFloraList(int stage) => _buildFloraElements(stage);
  
  List<Widget> _buildFloraElements(int stage) {
    final elements = <Widget>[];
    final floraScale = _archetype.scaleMultiplierFor('flora');

    // Grass base — left edge
    if (isUnlocked('grass_base')) {
      elements.add(
        _draggablePositioned(
          elementId: 'grass_base',
          defaultLeft: 5, defaultBottom: 120,
          child: _withVariation('grass_base', GardenElement(
            elementId: 'grass_base',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_grass_base.png',
              width: (100 * floraScale).round().toDouble(),
              height: (70 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Shrub — right of sand plate
    if (isUnlocked('bush_small')) {
      elements.add(
        _draggablePositioned(
          elementId: 'bush_small',
          defaultLeft: 300, defaultBottom: 180,
          child: _withVariation('bush_small', GardenElement(
            elementId: 'bush_small',
            revealType: GardenRevealType.bloomOut,
            child: Image.asset(
              'assets/images/zen-garden/zen_shrub.png',
              width: (75 * floraScale).round().toDouble(),
              height: (55 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }
    
    // Grass 2 — left side
    if (isUnlocked('grass_2')) {
      elements.add(
        _draggablePositioned(
          elementId: 'grass_2',
          defaultLeft: 5, defaultBottom: 250,
          child: _withVariation('grass_2', GardenElement(
            elementId: 'grass_2',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_grass_2.png',
              width: (70 * floraScale).round().toDouble(),
              height: (95 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Grass 2b — right edge
    if (isUnlocked('grass_2_b')) {
      elements.add(
        _draggablePositioned(
          elementId: 'grass_2_b',
          defaultLeft: 340, defaultBottom: 240,
          child: _withVariation('grass_2_b', GardenElement(
            elementId: 'grass_2_b',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_grass_2_b.png',
              width: (65 * floraScale).round().toDouble(),
              height: (85 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // White flowers — clustered near center-left
    if (isUnlocked('flowers_white')) {
      elements.add(
        _draggablePositioned(
          elementId: 'flowers_white',
          defaultLeft: 100, defaultBottom: 210,
          child: _withVariation('flowers_white', GardenElement(
            elementId: 'flowers_white',
            revealType: GardenRevealType.bloomOut,
            child: Image.asset(
              'assets/images/zen-garden/zen_flowers_white.png',
              width: (55 * floraScale).round().toDouble(),
              height: (65 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Yellow flowers — near center
    if (isUnlocked('flowers_yellow')) {
      elements.add(
        _draggablePositioned(
          elementId: 'flowers_yellow',
          defaultLeft: 160, defaultBottom: 200,
          child: _withVariation('flowers_yellow', GardenElement(
            elementId: 'flowers_yellow',
            revealType: GardenRevealType.bloomOut,
            child: Image.asset(
              'assets/images/zen-garden/zen_flowers_yellow.png',
              width: (60 * floraScale).round().toDouble(),
              height: (65 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Purple flowers — near center-right
    if (isUnlocked('flowers_purple')) {
      elements.add(
        _draggablePositioned(
          elementId: 'flowers_purple',
          defaultLeft: 230, defaultBottom: 215,
          child: _withVariation('flowers_purple', GardenElement(
            elementId: 'flowers_purple',
            revealType: GardenRevealType.bloomOut,
            child: Image.asset(
              'assets/images/zen-garden/zen_flowers_purple.png',
              width: (55 * floraScale).round().toDouble(),
              height: (70 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Grass 3 (tall) — far left edge
    if (isUnlocked('grass_3')) {
      elements.add(
        _draggablePositioned(
          elementId: 'grass_3',
          defaultLeft: 0, defaultBottom: 310,
          child: _withVariation('grass_3', GardenElement(
            elementId: 'grass_3',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_grass_3.png',
              width: (75 * floraScale).round().toDouble(),
              height: (110 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Young tree — back left
    if (isUnlocked('tree_young')) {
      elements.add(
        _draggablePositioned(
          elementId: 'tree_young',
          defaultLeft: 30, defaultBottom: 380,
          child: _withVariation('tree_young', GardenElement(
            elementId: 'tree_young',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_tree_young.png',
              width: (110 * floraScale).round().toDouble(),
              height: (140 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Autumn tree — back right
    if (isUnlocked('tree_autumn')) {
      elements.add(
        _draggablePositioned(
          elementId: 'tree_autumn',
          defaultLeft: 270, defaultBottom: 400,
          child: _withVariation('tree_autumn', GardenElement(
            elementId: 'tree_autumn',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_tree_autumn.png',
              width: (120 * floraScale).round().toDouble(),
              height: (150 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Bamboo — back left
    if (stage >= 3) {
      elements.add(
        _draggablePositioned(
          elementId: 'zen_bamboo',
          defaultLeft: 10, defaultBottom: 350,
          child: _withVariation('zen_bamboo', GardenElement(
            elementId: 'zen_bamboo',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_bamboo.png',
              width: (50 * floraScale).round().toDouble(),
              height: (150 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }
    
    // Cherry blossoms — back right
    if (isUnlocked('tree_cherry')) {
      elements.add(
        _draggablePositioned(
          elementId: 'tree_cherry',
          defaultLeft: 0, defaultBottom: 360, useRight: true, defaultRight: 10,
          child: _withVariation('tree_cherry', GardenElement(
            elementId: 'tree_cherry',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_blossoms_a.png',
              width: (120 * floraScale).round().toDouble(),
              height: (150 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Additional blossoms — center back
    if (stage >= 5) {
      elements.add(
        _draggablePositioned(
          elementId: 'zen_blossoms_b',
          defaultLeft: 170, defaultBottom: 340,
          child: _withVariation('zen_blossoms_b', GardenElement(
            elementId: 'zen_blossoms_b',
            revealType: GardenRevealType.bloomOut,
            child: Image.asset(
              'assets/images/zen-garden/zen_blossoms_b.png',
              width: (100 * floraScale).round().toDouble(),
              height: (120 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Bonsai — center hero piece
    if (stage >= 6) {
      elements.add(
        _draggablePositioned(
          elementId: 'zen_bonsai',
          defaultLeft: 130, defaultBottom: 240,
          child: _withVariation('zen_bonsai', GardenElement(
            elementId: 'zen_bonsai',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_bonsai.png',
              width: (140 * floraScale).round().toDouble(),
              height: (180 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    return elements;
  }

  // ── Structures ──

  List<Widget> _buildStructuresList() {
    final elements = <Widget>[];
    final structureScale = _archetype.scaleMultiplierFor('structure');

    // Bench — on the sand, right side
    if (isUnlocked('bench')) {
      elements.add(
        _draggablePositioned(
          elementId: 'bench',
          defaultLeft: 240, defaultBottom: 140,
          child: _withVariation('bench', GardenElement(
            elementId: 'bench',
            revealType: GardenRevealType.fadeScale,
            child: Image.asset(
              'assets/images/zen-garden/zen_bench.png',
              width: (90 * structureScale).round().toDouble(),
              height: (55 * structureScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Pagoda — center-left, behind flora
    if (isUnlocked('pagoda')) {
      elements.add(
        _draggablePositioned(
          elementId: 'pagoda',
          defaultLeft: 60, defaultBottom: 280,
          child: _withVariation('pagoda', GardenElement(
            elementId: 'pagoda',
            revealType: GardenRevealType.fadeScale,
            child: Image.asset(
              'assets/images/zen-garden/zen_pagoda.png',
              width: (70 * structureScale).round().toDouble(),
              height: (110 * structureScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Lantern — near pond, right side
    if (isUnlocked('lantern')) {
      elements.add(
        _draggablePositioned(
          elementId: 'lantern',
          defaultLeft: 0, defaultBottom: 230, useRight: true, defaultRight: 10,
          child: _withVariation('lantern', GardenElement(
            elementId: 'lantern',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_lantern.png',
              width: (45 * structureScale).round().toDouble(),
              height: (90 * structureScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Shrine/Torii gate — center back
    if (isUnlocked('torii_gate')) {
      elements.add(
        _draggablePositioned(
          elementId: 'torii_gate',
          defaultLeft: 155, defaultBottom: 300,
          child: _withVariation('torii_gate', GardenElement(
            elementId: 'torii_gate',
            revealType: GardenRevealType.growUp,
            revealDuration: const Duration(milliseconds: 2000),
            child: Image.asset(
              'assets/images/zen-garden/zen_shrine.png',
              width: (75 * structureScale).round().toDouble(),
              height: (100 * structureScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Bridge — over stream/pond, center
    if (isUnlocked('bridge')) {
      elements.add(
        _draggablePositioned(
          elementId: 'bridge',
          defaultLeft: 120, defaultBottom: 170,
          child: _withVariation('bridge', GardenElement(
            elementId: 'bridge',
            revealType: GardenRevealType.fadeScale,
            child: Image.asset(
              'assets/images/zen-garden/zen_bridge.png',
              width: (100 * structureScale).round().toDouble(),
              height: (60 * structureScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Wind chime (CustomPainter, animated)
    if (isUnlocked('wind_chime')) {
      elements.add(
        _draggablePositioned(
          elementId: 'wind_chime',
          defaultLeft: 0, defaultBottom: 350, useRight: true, defaultRight: 60,
          child: GardenElement(
            elementId: 'wind_chime',
            revealType: GardenRevealType.growUp,
            child: SizedBox(
              width: 44,
              height: 70,
              child: AnimatedBuilder(
                animation: _ambientController,
                builder: (context, _) => CustomPaint(
                  painter: WindChimePainter(
                    animationValue: _ambientController.value,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return elements;
  }

  Widget _buildParticles() {
    final particles = <Widget>[];

    if (_hasButterfly) {
      particles.add(
        AnimatedBuilder(
          animation: _ambientController,
          builder: (context, _) {
            final top = 150.0 + math.sin(_ambientController.value * 2 * math.pi) * 10;
            final left = 100.0 + math.cos(_ambientController.value * 2 * math.pi) * 15;
            return Positioned(
              top: top,
              left: left,
              child: GardenElement(
                elementId: 'butterfly',
                revealType: GardenRevealType.fadeScale,
                showParticles: false,
                child: const Icon(
                  Icons.flutter_dash,
                  size: 18,
                  color: Color(0xFFB388FF),
                ),
              ),
            );
          },
        ),
      );
    }

    if (_hasPetals) {
      for (var i = 0; i < _petalSeeds.length; i++) {
        final seed = _petalSeeds[i];
        final offset = _ambientController.value * 200 + i * 60;
        final y = offset % 420;
        final x = 40 + seed.dx * 260 + math.sin(offset / 50) * 20;
        final rotation = _ambientController.value * 2 * math.pi + seed.dx * math.pi;
        final size = 6 + seed.dy * 4;
        final opacity = 0.5 + 0.3 * math.sin(offset / 30);
        
        particles.add(
          Positioned(
            top: y,
            left: x,
            child: Transform.rotate(
              angle: rotation,
              child: Opacity(
                opacity: opacity.clamp(0.3, 0.8),
                child: Container(
                  width: size,
                  height: size * 1.3,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFB7C5),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    if (_hasFireflies) {
      for (var i = 0; i < _fireflySeeds.length; i++) {
        final seed = _fireflySeeds[i];
        final baseX = 40 + seed.dx * 280;
        final baseY = 120 + seed.dy * 100;
        
        final time = _ambientController.value * 2 * math.pi;
        final x = baseX + math.sin(time + i * 0.5) * 25 + math.cos(time * 0.3 + i) * 15;
        final y = baseY + math.cos(time + i * 0.7) * 30 + math.sin(time * 0.5 + i) * 20;
        
        final pulse = (math.sin(time * 2 + i * 1.3) + 1) / 2;
        final opacity = 0.4 + pulse * 0.6;
        final glowRadius = 6 + pulse * 4;
        
        particles.add(
          Positioned(
            top: y,
            left: x,
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Color.lerp(
                  const Color(0xFFFFEB3B),
                  const Color(0xFFFFF59D),
                  pulse,
                )!.withValues(alpha: opacity),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFEB3B).withValues(alpha: opacity * 0.6),
                    blurRadius: glowRadius,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    if (_hasBirds) {
      const vFormation = [
        Offset(0, 0),
        Offset(-26, 18),
        Offset(-52, 36),
        Offset(26, 18),
        Offset(52, 36),
      ];

      final t = _ambientController.value;
      final leadX = -80.0 + t * 500;
      final leadY = 60.0 + math.sin(t * 2 * math.pi) * 15;

      final birdWidgets = <Widget>[
        for (var i = 0; i < vFormation.length; i++)
          Positioned(
            top: leadY + vFormation[i].dy,
            left: leadX + vFormation[i].dx,
            child: SizedBox(
              width: 18,
              height: 10,
              child: CustomPaint(
                painter: BirdPainter(
                  flapProgress: (t * 3.5 + i * 0.18) % 1.0,
                ),
              ),
            ),
          ),
      ];

      particles.add(
        GardenElement(
          elementId: 'birds',
          revealType: GardenRevealType.fadeScale,
          showParticles: false,
          child: Stack(children: birdWidgets),
        ),
      );
    }

    if (_hasDragonflies) {
      for (var i = 0; i < 2; i++) {
        final baseX = 200.0 + i * 60;
        final baseY = 160.0;
        
        final time = _ambientController.value * 2 * math.pi;
        final dart = math.sin(time * 4 + i * 3).abs();
        final hoverX = baseX + math.sin(time + i * 2) * 25 * (1 + dart * 0.5);
        final hoverY = baseY + math.cos(time * 1.5 + i) * 15;
        final angle = math.atan2(
          math.cos(time * 1.5 + i) * 15,
          math.sin(time + i * 2) * 25,
        ) + math.pi / 2;
        
        particles.add(
          Positioned(
            top: hoverY,
            left: hoverX,
            child: Transform.rotate(
              angle: angle,
              child: Opacity(
                opacity: 0.8 + dart * 0.2,
                child: SizedBox(
                  width: 20,
                  height: 16,
                  child: CustomPaint(
                    painter: DragonflyPainter(
                      color: i == 0 ? const Color(0xFF64B5F6) : const Color(0xFF81C784),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Stack(children: particles);
  }

  // ── Ground assets ──

  List<Widget> _buildGroundAssetsList() => _buildGroundAssetsElements();

  List<Widget> _buildGroundAssetsElements() {
    final elements = <Widget>[];
    final rocksScale = _archetype.scaleMultiplierFor('rocks');

    // Sand plate — centered foundation
    if (isUnlocked('ground')) {
      elements.add(
        _draggablePositioned(
          elementId: 'ground',
          defaultLeft: 30, defaultBottom: 80,
          child: _withVariation('ground', GardenElement(
            elementId: 'ground',
            revealType: GardenRevealType.fadeScale,
            child: Image.asset(
              'assets/images/zen-garden/zen_sand_plate.png',
              width: 340,
              height: 230,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(width: 340, height: 230, color: Colors.red.withValues(alpha: 0.5));
              },
            ),
          )),
        ),
      );
    }

    // Small rocks — on the sand, center-left
    if (isUnlocked('small_stones')) {
      elements.add(
        _draggablePositioned(
          elementId: 'small_stones',
          defaultLeft: 80, defaultBottom: 160,
          child: _withVariation('small_stones', GardenElement(
            elementId: 'small_stones',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_rocks_small.png',
              width: (75 * rocksScale).round().toDouble(),
              height: (50 * rocksScale).round().toDouble(),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(width: 75, height: 50, color: Colors.red.withValues(alpha: 0.5));
              },
            ),
          )),
        ),
      );
    }

    // Stepping stones — on the sand path
    if (isUnlocked('pebble_path')) {
      elements.add(
        _draggablePositioned(
          elementId: 'pebble_path',
          defaultLeft: 130, defaultBottom: 110,
          child: _withVariation('pebble_path', GardenElement(
            elementId: 'pebble_path',
            revealType: GardenRevealType.fadeScale,
            child: Image.asset(
              'assets/images/zen-garden/zen_stepping_stones.png',
              width: (150 * rocksScale).round().toDouble(),
              height: (50 * rocksScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Sand swirls — on the sand
    if (gardenState.currentStage >= 2) {
      elements.add(
        _draggablePositioned(
          elementId: 'zen_sand_swirl',
          defaultLeft: 180, defaultBottom: 100,
          child: _withVariation('zen_sand_swirl', GardenElement(
            elementId: 'zen_sand_swirl',
            revealType: GardenRevealType.bloomOut,
            child: Image.asset(
              'assets/images/zen-garden/zen_sand_swirl.png',
              width: 120,
              height: 80,
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Grass base 2 — right edge
    if (isUnlocked('grass_base_2')) {
      elements.add(
        _draggablePositioned(
          elementId: 'grass_base_2',
          defaultLeft: 320, defaultBottom: 100,
          child: _withVariation('grass_base_2', GardenElement(
            elementId: 'grass_base_2',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_grass_base_2.png',
              width: 85,
              height: 60,
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Grass base 3 — bottom right
    if (isUnlocked('grass_base_3')) {
      elements.add(
        _draggablePositioned(
          elementId: 'grass_base_3',
          defaultLeft: 0, defaultBottom: 60, useRight: true, defaultRight: 5,
          child: _withVariation('grass_base_3', GardenElement(
            elementId: 'grass_base_3',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_grass_base_3.png',
              width: 90,
              height: 65,
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Grass 1 — left edge
    if (isUnlocked('grass_1')) {
      elements.add(
        _draggablePositioned(
          elementId: 'grass_1',
          defaultLeft: 0, defaultBottom: 180,
          child: _withVariation('grass_1', GardenElement(
            elementId: 'grass_1',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_grass_1.png',
              width: 60,
              height: 75,
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Grass 1b — right edge
    if (isUnlocked('grass_1_b')) {
      elements.add(
        _draggablePositioned(
          elementId: 'grass_1_b',
          defaultLeft: 0, defaultBottom: 160, useRight: true, defaultRight: 0,
          child: _withVariation('grass_1_b', GardenElement(
            elementId: 'grass_1_b',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_grass_1_b.png',
              width: 55,
              height: 70,
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Medium rocks — on the sand, right of center
    if (isUnlocked('sapling')) {
      elements.add(
        _draggablePositioned(
          elementId: 'sapling',
          defaultLeft: 220, defaultBottom: 150,
          child: _withVariation('sapling', GardenElement(
            elementId: 'sapling',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_rocks_medium.png',
              width: 110,
              height: 75,
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    return elements;
  }

  Widget _buildMistOverlay() {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.3,
        child: Image.asset(
          'assets/images/zen-garden/zen_mist.png',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildStatsCard(GardenState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            state.stageName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${state.totalPuzzlesSolved} puzzles solved',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _resetAllPositions,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Text(
                    'Reset Layout',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
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

// ── Custom Painters ──

class MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A5568).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.3, size.height * 0.3)
      ..lineTo(size.width * 0.5, size.height * 0.6)
      ..lineTo(size.width * 0.7, size.height * 0.2)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class KoiFishPainter extends CustomPainter {
  final Color color;

  KoiFishPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final bodyPath = Path()
      ..moveTo(size.width * 0.8, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.5, 0, size.width * 0.15, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.5, size.height, size.width * 0.8, size.height * 0.5)
      ..close();

    canvas.drawPath(bodyPath, paint);

    final tailPath = Path()
      ..moveTo(size.width * 0.8, size.height * 0.5)
      ..lineTo(size.width, size.height * 0.2)
      ..lineTo(size.width, size.height * 0.8)
      ..close();

    canvas.drawPath(tailPath, paint);

    canvas.drawCircle(
      Offset(size.width * 0.25, size.height * 0.4),
      1.5,
      Paint()..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(covariant KoiFishPainter oldDelegate) =>
      oldDelegate.color != color;
}

class WindChimePainter extends CustomPainter {
  final double animationValue;

  WindChimePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final barPaint = Paint()
      ..color = const Color(0xFF8B7355)
      ..style = PaintingStyle.fill;

    final tubePaint = Paint()
      ..color = const Color(0xFFB8A898)
      ..style = PaintingStyle.fill;

    final tubeShine = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final stringPaint = Paint()
      ..color = const Color(0xFF6D5643).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height * 0.13),
      stringPaint,
    );

    final barY = size.height * 0.15;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width / 2, barY), width: size.width * 0.9, height: 4),
        const Radius.circular(2),
      ),
      barPaint,
    );

    const tubeData = [
      (0.15, 0.40, 3.5, 0.0),
      (0.35, 0.58, 4.5, 1.3),
      (0.58, 0.66, 5.0, 2.5),
      (0.78, 0.48, 4.0, 0.7),
      (0.92, 0.35, 3.0, 1.9),
    ];

    final barBottom = barY + 2;

    for (final (xRatio, lengthRatio, tubeWidth, phase) in tubeData) {
      final swayAngle = math.sin(animationValue * 2 * math.pi + phase) * 0.12;
      final x = size.width * xRatio;
      final tubeHeight = size.height * lengthRatio;
      final swayOffsetTop = math.sin(swayAngle) * tubeHeight * 0.15;
      final swayOffsetMid = math.sin(swayAngle) * tubeHeight * 0.35;

      canvas.drawLine(
        Offset(x, barBottom),
        Offset(x + swayOffsetTop, barBottom + size.height * 0.06),
        stringPaint,
      );

      final tubeCenterY = barBottom + size.height * 0.06 + tubeHeight / 2;
      final tubeRect = Rect.fromCenter(
        center: Offset(x + swayOffsetMid, tubeCenterY),
        width: tubeWidth,
        height: tubeHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(tubeRect, const Radius.circular(2)),
        tubePaint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + swayOffsetMid - 1, tubeCenterY),
            width: 1.5,
            height: tubeHeight * 0.6,
          ),
          const Radius.circular(1),
        ),
        tubeShine,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WindChimePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

class BirdPainter extends CustomPainter {
  final double flapProgress;

  BirdPainter({required this.flapProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2C3E50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final flapAngle = math.sin(flapProgress * 2 * math.pi);
    final wingLift = size.height * 0.45 * flapAngle;
    final cx = size.width / 2;
    final cy = size.height * 0.65;

    final path = Path()
      ..moveTo(0, cy)
      ..quadraticBezierTo(cx * 0.5, cy - wingLift, cx, cy * 0.6)
      ..quadraticBezierTo(cx * 1.5, cy - wingLift, size.width, cy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BirdPainter oldDelegate) =>
      oldDelegate.flapProgress != flapProgress;
}

class DragonflyPainter extends CustomPainter {
  final Color color;

  DragonflyPainter({this.color = const Color(0xFF64B5F6)});

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()..color = color..style = PaintingStyle.fill;
    final wingPaint = Paint()..color = Colors.white.withValues(alpha: 0.6)..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.5, size.height * 0.5), width: size.width * 0.6, height: size.height * 0.2),
      bodyPaint,
    );

    canvas.drawOval(Rect.fromLTWH(size.width * 0.1, size.height * 0.1, size.width * 0.35, size.height * 0.3), wingPaint);
    canvas.drawOval(Rect.fromLTWH(size.width * 0.55, size.height * 0.1, size.width * 0.35, size.height * 0.3), wingPaint);
    canvas.drawOval(Rect.fromLTWH(size.width * 0.1, size.height * 0.55, size.width * 0.35, size.height * 0.3), wingPaint);
    canvas.drawOval(Rect.fromLTWH(size.width * 0.55, size.height * 0.55, size.width * 0.35, size.height * 0.3), wingPaint);
  }

  @override
  bool shouldRepaint(covariant DragonflyPainter oldDelegate) =>
      oldDelegate.color != color;
}

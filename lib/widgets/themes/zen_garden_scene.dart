import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/garden_state.dart';
import '../../models/garden_archetype.dart';
// Registry no longer needed in main scene file
import '../../services/zen_audio_service.dart';
import '../../services/garden_service.dart';
import '../../utils/garden_variation.dart';
// Progression base available for reuse: import '../../progression/reward_scene_base.dart';
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

  // Archetype accessor
  GardenArchetype get _archetype => gardenState.gardenArchetype;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

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

    // Listen for gentle rebuild signals from GardenService (avoids KeyedSubtree teardown)
    GardenService.rebuildNotifier.addListener(_onGardenRebuild);

    // Initialize with current stage
    _lastStage = gardenState.currentStage;

    // Start ambient audio
    if (widget.enableAudio) {
      _initAudio();
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
    
    // Check for stage advance
    if (state.currentStage > _lastStage && _lastStage >= 0) {
      _audioService.playStageAdvance();
      _lastStage = state.currentStage;
    }
    
    // Check night mode transition (stage 6+)
    final shouldBeNight = state.currentStage >= 6;
    if (shouldBeNight != _audioService.isNightMode) {
      _audioService.setNightMode(shouldBeNight);
    }
    
    // Check water unlock
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
    _ambientController.dispose();
    if (widget.enableAudio) {
      _audioService.stopAmbience();
    }
    GardenService.onStageAdvanced = null;
    super.dispose();
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
    
    // Cache particle unlock flags once per build (not per animation frame)
    _hasButterfly = isUnlocked('butterfly');
    _hasPetals = isUnlocked('petals');
    _hasFireflies = isUnlocked('fireflies');
    _hasBirds = isUnlocked('birds');
    _hasDragonflies = isUnlocked('dragonflies');
    
    // Check for audio updates on each build
    _checkAudioUpdates();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer -1: Guaranteed fallback gradient (always visible even if assets fail)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2C3E50),
                Color(0xFF1A2530),
              ],
            ),
          ),
        ),
        // Layer 0: Sky gradient
        _buildSky(state.currentStage),

          // Layer 1: Distant background
          if (isUnlocked('mountain')) _buildDistantBackground(),

          // FLATTEN: Ground assets directly in outer Stack instead of nested Stack
          ..._buildGroundAssetsList(),

          // Layer 3: Water features (flattened)
          if (isUnlocked('pond_empty') || isUnlocked('pond_full'))
            ..._buildWaterList(),

          // FLATTEN: Flora directly in outer Stack
          ..._buildFloraList(state.currentStage),

          // Layer 5: Structures (flattened)
          ..._buildStructuresList(),

          // Layer 6: Particles
          AnimatedBuilder(
            animation: _ambientController,
            builder: (context, child) => _buildParticles(),
          ),

          // Layer 7: Mist overlay (stage 8)
          if (state.currentStage >= 8) _buildMistOverlay(),

          // Layer 8: Silhouette previews for next-stage unlocks
          _buildSilhouettePreviews(state.currentStage),

          // Stats overlay
          if (widget.showStats)
            Positioned(
              bottom: 20,
              left: 20,
              child: _buildStatsCard(state),
            ),
          
          // Milestone celebration overlay
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
        // Default: slate texture background
        Image.asset(
          'assets/images/backgrounds/slate_bg.jpg',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
        
        // Night mode: darken slate with semi-transparent overlay
        if (isNight)
          Container(
            color: const Color(0xFF0D1321).withValues(alpha: 0.65),
          ),
        
        // Stars (night only, stage 6+) — only show in night mode
        if (isNight) _buildStars(),
        
        // Moon (night, stage 8+) or Sun (day)
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
        final y = rng.nextDouble() * 0.6; // Stars in upper 60%
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
      top: 60,
      right: 50,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFFAE6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFFAE6).withValues(alpha: 0.4),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSun() {
    return Positioned(
      top: 50,
      right: 60,
      child: AnimatedBuilder(
        animation: _ambientController,
        builder: (context, child) {
          final glow = 15 + math.sin(_ambientController.value * 2 * math.pi) * 5;
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF9C4),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFEB3B).withValues(alpha: 0.5),
                  blurRadius: glow,
                  spreadRadius: 5,
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

  Widget _buildGround(int stage) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 420,
      child: CustomPaint(
        painter: GroundPainter(stage: stage),
      ),
    );
  }

  List<Widget> _buildWaterList() {
    final elements = <Widget>[];
    final waterScale = _archetype.scaleMultiplierFor('water');

    // Pond empty (before full pond unlocks)
    if (isUnlocked('pond_empty') && !isUnlocked('pond_full')) {
      elements.add(
        Positioned(
          bottom: 160,
          right: 40,
          child: _withVariation('pond_empty', GardenElement(
            elementId: 'pond_empty',
            revealType: GardenRevealType.rippleIn,
            child: Image.asset(
              'assets/images/zen-garden/zen_pond_empty.png',
              width: (180 * waterScale).round().toDouble(),
              height: (110 * waterScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 4: Pond
    if (isUnlocked('pond_full')) {
      elements.add(
        Positioned(
          bottom: 160,
          right: 40,
          child: _withVariation('pond_full', GardenElement(
            elementId: 'pond_full',
            revealType: GardenRevealType.rippleIn,
            child: Image.asset(
              'assets/images/zen-garden/zen_pond.png',
              width: (210 * waterScale).round().toDouble(),
              height: (125 * waterScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 4: Lily pads on pond
    if (isUnlocked('lily_pads')) {
      elements.add(
        Positioned(
          bottom: 200,
          right: 70,
          child: _withVariation('lily_pads', GardenElement(
            elementId: 'lily_pads',
            revealType: GardenRevealType.bloomOut,
            child: Image.asset(
              'assets/images/zen-garden/zen_lily_pads.png',
              width: (120 * waterScale).round().toDouble(),
              height: (75 * waterScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 7: Waterfall/stream
    if (isUnlocked('stream')) {
      elements.add(
        Positioned(
          bottom: 120,
          left: 0,
          child: _withVariation('stream', GardenElement(
            elementId: 'stream',
            revealType: GardenRevealType.rippleIn,
            child: Image.asset(
              'assets/images/zen-garden/zen_waterfall.png',
              width: (160 * waterScale).round().toDouble(),
              height: (220 * waterScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Keep koi fish as CustomPainter (animated)
    if (isUnlocked('koi_fish') && isUnlocked('pond_full')) {
      elements.add(
        Positioned(
          bottom: 160,
          right: 40,
          child: GardenElement(
            elementId: 'koi_fish',
            revealType: GardenRevealType.rippleIn,
            showParticles: false,
            child: SizedBox(
              width: 210,
              height: 125,
              child: AnimatedBuilder(
                animation: _ambientController,
                builder: (context, child) {
                  return Stack(
                    children: [
                      _koiFish(
                        progress: _ambientController.value,
                        startX: 20,
                        startY: 45,
                        color: const Color(0xFFFF6B00),
                      ),
                      _koiFish(
                        progress: (_ambientController.value + 0.5) % 1.0,
                        startX: 80,
                        startY: 30,
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

  // Old CustomPainter lily pad method removed - using image assets now

  Widget _koiFish({
    required double progress,
    required double startX,
    required double startY,
    required Color color,
    bool reverse = false,
  }) {
    // Simple fish swimming in a figure-8 pattern
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

  // Flattened version: returns List<Widget> for direct spread into outer Stack
  List<Widget> _buildFloraList(int stage) => _buildFloraElements(stage);
  
  List<Widget> _buildFloraElements(int stage) {
    final elements = <Widget>[];
    final floraScale = _archetype.scaleMultiplierFor('flora');

    // Stage 0: Foundation grass base
    if (isUnlocked('grass_base')) {
      elements.add(
        Positioned(
          bottom: 140,
          left: 15,
          child: _withVariation('grass_base', GardenElement(
            elementId: 'grass_base',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_grass_base.png',
              width: (130 * floraScale).round().toDouble(),
              height: (95 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 2: Small shrub
    if (isUnlocked('bush_small')) {
      elements.add(
        Positioned(
          bottom: 145,
          left: 180,
          child: _withVariation('bush_small', GardenElement(
            elementId: 'bush_small',
            revealType: GardenRevealType.bloomOut,
            child: Image.asset(
              'assets/images/zen-garden/zen_shrub.png',
              width: (95 * floraScale).round().toDouble(),
              height: (70 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }
    
    // Stage 2: Grass 2
    if (isUnlocked('grass_2')) {
      elements.add(
        Positioned(
          bottom: 200,
          left: 50,
          child: _withVariation('grass_2', GardenElement(
            elementId: 'grass_2',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_grass_2.png',
              width: (90 * floraScale).round().toDouble(),
              height: (120 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 2: Grass 2b
    if (isUnlocked('grass_2_b')) {
      elements.add(
        Positioned(
          bottom: 190,
          left: 300,
          child: _withVariation('grass_2_b', GardenElement(
            elementId: 'grass_2_b',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_grass_2_b.png',
              width: (85 * floraScale).round().toDouble(),
              height: (110 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 2: White flowers
    if (isUnlocked('flowers_white')) {
      elements.add(
        Positioned(
          bottom: 180,
          left: 130,
          child: _withVariation('flowers_white', GardenElement(
            elementId: 'flowers_white',
            revealType: GardenRevealType.bloomOut,
            child: Image.asset(
              'assets/images/zen-garden/zen_flowers_white.png',
              width: (70 * floraScale).round().toDouble(),
              height: (80 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 2: Yellow flowers
    if (isUnlocked('flowers_yellow')) {
      elements.add(
        Positioned(
          bottom: 170,
          left: 230,
          child: _withVariation('flowers_yellow', GardenElement(
            elementId: 'flowers_yellow',
            revealType: GardenRevealType.bloomOut,
            child: Image.asset(
              'assets/images/zen-garden/zen_flowers_yellow.png',
              width: (75 * floraScale).round().toDouble(),
              height: (85 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 2: Purple flowers
    if (isUnlocked('flowers_purple')) {
      elements.add(
        Positioned(
          bottom: 220,
          left: 260,
          child: _withVariation('flowers_purple', GardenElement(
            elementId: 'flowers_purple',
            revealType: GardenRevealType.bloomOut,
            child: Image.asset(
              'assets/images/zen-garden/zen_flowers_purple.png',
              width: (70 * floraScale).round().toDouble(),
              height: (90 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 2: Grass 3 (tall)
    if (isUnlocked('grass_3')) {
      elements.add(
        Positioned(
          bottom: 250,
          left: 10,
          child: _withVariation('grass_3', GardenElement(
            elementId: 'grass_3',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_grass_3.png',
              width: (100 * floraScale).round().toDouble(),
              height: (150 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 3: Young tree
    if (isUnlocked('tree_young')) {
      elements.add(
        Positioned(
          bottom: 300,
          left: 60,
          child: _withVariation('tree_young', GardenElement(
            elementId: 'tree_young',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_tree_young.png',
              width: (140 * floraScale).round().toDouble(),
              height: (180 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 4: Autumn tree
    if (isUnlocked('tree_autumn')) {
      elements.add(
        Positioned(
          bottom: 350,
          left: 250,
          child: _withVariation('tree_autumn', GardenElement(
            elementId: 'tree_autumn',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_tree_autumn.png',
              width: (160 * floraScale).round().toDouble(),
              height: (200 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 3: Bamboo (replacing old sapling)
    if (stage >= 3) {
      elements.add(
        Positioned(
          bottom: 160,
          left: 40,
          child: _withVariation('zen_bamboo', GardenElement(
            elementId: 'zen_bamboo',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_bamboo.png',
              width: (65 * floraScale).round().toDouble(),
              height: (190 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }
    
    // Stage 5: Cherry blossoms
    if (isUnlocked('tree_cherry')) {
      elements.add(
        Positioned(
          bottom: 180,
          right: 60,
          child: _withVariation('tree_cherry', GardenElement(
            elementId: 'tree_cherry',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_blossoms_a.png',
              width: (160 * floraScale).round().toDouble(),
              height: (200 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 5: Additional blossoms
    if (stage >= 5) {
      elements.add(
        Positioned(
          bottom: 155,
          left: 260,
          child: _withVariation('zen_blossoms_b', GardenElement(
            elementId: 'zen_blossoms_b',
            revealType: GardenRevealType.bloomOut,
            child: Image.asset(
              'assets/images/zen-garden/zen_blossoms_b.png',
              width: (130 * floraScale).round().toDouble(),
              height: (160 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 6: Bonsai (hero piece)
    if (stage >= 6) {
      elements.add(
        Positioned(
          bottom: 180,
          left: 120,
          child: _withVariation('zen_bonsai', GardenElement(
            elementId: 'zen_bonsai',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_bonsai.png',
              width: (180 * floraScale).round().toDouble(),
              height: (240 * floraScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    return elements;
  }

  Widget _buildFlora(int stage) {
    return Stack(children: _buildFloraElements(stage));
  }

  // Old CustomPainter grass method removed - using image assets now

  // Old CustomPainter base grass method removed - using image assets now
  // Old CustomPainter bush method removed - using image assets now

  // Old CustomPainter flower method removed - using image assets now

  // Old CustomPainter tree method removed - using image assets now

  List<Widget> _buildStructuresList() {
    final elements = <Widget>[];
    final structureScale = _archetype.scaleMultiplierFor('structure');

    // Bench
    if (isUnlocked('bench')) {
      elements.add(
        Positioned(
          bottom: 120,
          left: 200,
          child: _withVariation('bench', GardenElement(
            elementId: 'bench',
            revealType: GardenRevealType.fadeScale,
            child: Image.asset(
              'assets/images/zen-garden/zen_bench.png',
              width: (120 * structureScale).round().toDouble(),
              height: (70 * structureScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Pagoda
    if (isUnlocked('pagoda')) {
      elements.add(
        Positioned(
          bottom: 200,
          left: 150,
          child: _withVariation('pagoda', GardenElement(
            elementId: 'pagoda',
            revealType: GardenRevealType.fadeScale,
            child: Image.asset(
              'assets/images/zen-garden/zen_pagoda.png',
              width: (90 * structureScale).round().toDouble(),
              height: (140 * structureScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 5: Lantern
    if (isUnlocked('lantern')) {
      elements.add(
        Positioned(
          bottom: 170,
          right: 30,
          child: _withVariation('lantern', GardenElement(
            elementId: 'lantern',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_lantern.png',
              width: (60 * structureScale).round().toDouble(),
              height: (120 * structureScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 6: Shrine/Torii gate
    if (isUnlocked('torii_gate')) {
      elements.add(
        Positioned(
          bottom: 175,
          left: 200,
          child: _withVariation('torii_gate', GardenElement(
            elementId: 'torii_gate',
            revealType: GardenRevealType.growUp,
            revealDuration: const Duration(milliseconds: 2000),
            child: Image.asset(
              'assets/images/zen-garden/zen_shrine.png',
              width: (95 * structureScale).round().toDouble(),
              height: (125 * structureScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 7: Bridge
    if (isUnlocked('bridge')) {
      elements.add(
        Positioned(
          bottom: 155,
          left: 70,
          child: _withVariation('bridge', GardenElement(
            elementId: 'bridge',
            revealType: GardenRevealType.fadeScale,
            child: Image.asset(
              'assets/images/zen-garden/zen_bridge.png',
              width: (130 * structureScale).round().toDouble(),
              height: (80 * structureScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Keep wind chime as CustomPainter (not in asset registry)
    if (isUnlocked('wind_chime')) {
      elements.add(
        Positioned(
          bottom: 280,
          right: 90,
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

  // Old CustomPainter bench and lantern methods removed - using image assets now

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
      // More petals with varied sizes and rotation
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
      // Enhanced fireflies with better glow and movement
      for (var i = 0; i < _fireflySeeds.length; i++) {
        final seed = _fireflySeeds[i];
        final baseX = 40 + seed.dx * 280;
        final baseY = 120 + seed.dy * 100;
        
        // Create more organic movement pattern
        final time = _ambientController.value * 2 * math.pi;
        final x = baseX + math.sin(time + i * 0.5) * 25 + math.cos(time * 0.3 + i) * 15;
        final y = baseY + math.cos(time + i * 0.7) * 30 + math.sin(time * 0.5 + i) * 20;
        
        // Pulsing glow effect
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

    // Birds flock flying across the sky (stage 8+)
    if (_hasBirds) {
      // V-formation offsets from the lead bird
      const vFormation = [
        Offset(0, 0),       // Lead bird
        Offset(-26, 18),    // Left wing 1
        Offset(-52, 36),    // Left wing 2
        Offset(26, 18),     // Right wing 1
        Offset(52, 36),     // Right wing 2
      ];

      final t = _ambientController.value;
      // Fly across the screen; looping every 10 s ambient cycle
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

    // Dragonflies near water (stage 7+)
    if (_hasDragonflies) {
      for (var i = 0; i < 2; i++) {
        final baseX = 200.0 + i * 60;
        final baseY = 160.0;
        
        // More realistic darting movement
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

  List<Widget> _buildGroundAssetsList() => _buildGroundAssetsElements();

  Widget _buildGroundAssets() {
    return Stack(children: _buildGroundAssetsElements());
  }

  List<Widget> _buildGroundAssetsElements() {
    final elements = <Widget>[];
    final rocksScale = _archetype.scaleMultiplierFor('rocks');

    // Stage 0: Sand foundation
    if (isUnlocked('ground')) {
      elements.add(
        Positioned(
          bottom: 20,
          left: 30,
          child: _withVariation('ground', GardenElement(
            elementId: 'ground',
            revealType: GardenRevealType.fadeScale,
            child: Image.asset(
              'assets/images/zen-garden/zen_sand_plate.png',
              width: 380,
              height: 280,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('GARDEN_IMG_ERROR: zen_sand_plate.png: $error');
                return Container(width: 380, height: 280, color: Colors.red.withValues(alpha: 0.5));
              },
            ),
          )),
        ),
      );
    }

    // Stage 1: Small rocks/stones
    if (isUnlocked('small_stones')) {
      elements.add(
        Positioned(
          bottom: 140,
          left: 100,
          child: _withVariation('small_stones', GardenElement(
            elementId: 'small_stones',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_rocks_small.png',
              width: (95 * rocksScale).round().toDouble(),
              height: (65 * rocksScale).round().toDouble(),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('GARDEN_IMG_ERROR: zen_rocks_small.png: $error');
                return Container(width: 95, height: 65, color: Colors.red.withValues(alpha: 0.5));
              },
            ),
          )),
        ),
      );
    }

    // Stage 1: Stepping stones path
    if (isUnlocked('pebble_path')) {
      elements.add(
        Positioned(
          bottom: 100,
          left: 160,
          child: _withVariation('pebble_path', GardenElement(
            elementId: 'pebble_path',
            revealType: GardenRevealType.fadeScale,
            child: Image.asset(
              'assets/images/zen-garden/zen_stepping_stones.png',
              width: (190 * rocksScale).round().toDouble(),
              height: (65 * rocksScale).round().toDouble(),
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 2: Sand swirls
    if (gardenState.currentStage >= 2) {
      elements.add(
        Positioned(
          bottom: 60,
          right: 80,
          child: _withVariation('zen_sand_swirl', GardenElement(
            elementId: 'zen_sand_swirl',
            revealType: GardenRevealType.bloomOut,
            child: Image.asset(
              'assets/images/zen-garden/zen_sand_swirl.png',
              width: 160,
              height: 110,
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 0: Grass base 2
    if (isUnlocked('grass_base_2')) {
      elements.add(
        Positioned(
          bottom: 30,
          left: 200,
          child: _withVariation('grass_base_2', GardenElement(
            elementId: 'grass_base_2',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_grass_base_2.png',
              width: 110,
              height: 80,
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 0: Grass base 3
    if (isUnlocked('grass_base_3')) {
      elements.add(
        Positioned(
          bottom: 25,
          left: 310,
          child: _withVariation('grass_base_3', GardenElement(
            elementId: 'grass_base_3',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_grass_base_3.png',
              width: 120,
              height: 90,
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 1: Grass patch 1
    if (isUnlocked('grass_1')) {
      elements.add(
        Positioned(
          bottom: 150,
          left: 20,
          child: _withVariation('grass_1', GardenElement(
            elementId: 'grass_1',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_grass_1.png',
              width: 80,
              height: 100,
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 1: Grass patch 1b
    if (isUnlocked('grass_1_b')) {
      elements.add(
        Positioned(
          bottom: 130,
          left: 280,
          child: _withVariation('grass_1_b', GardenElement(
            elementId: 'grass_1_b',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_grass_1_b.png',
              width: 75,
              height: 95,
              fit: BoxFit.contain,
            ),
          )),
        ),
      );
    }

    // Stage 3: Medium rocks (replaces sapling)
    if (isUnlocked('sapling')) {
      elements.add(
        Positioned(
          bottom: 145,
          left: 280,
          child: _withVariation('sapling', GardenElement(
            elementId: 'sapling',
            revealType: GardenRevealType.growUp,
            child: Image.asset(
              'assets/images/zen-garden/zen_rocks_medium.png',
              width: 140,
              height: 95,
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

  // Mapping of element IDs to their image asset paths and approximate positions
  static const _silhouetteAssets = <String, String>{
    'grass_base_2': 'assets/images/zen-garden/zen_grass_base_2.png',
    'grass_base_3': 'assets/images/zen-garden/zen_grass_base_3.png',
    'grass_1': 'assets/images/zen-garden/zen_grass_1.png',
    'grass_1_b': 'assets/images/zen-garden/zen_grass_1_b.png',
    'grass_2': 'assets/images/zen-garden/zen_grass_2.png',
    'grass_2_b': 'assets/images/zen-garden/zen_grass_2_b.png',
    'grass_3': 'assets/images/zen-garden/zen_grass_3.png',
    'flowers_white': 'assets/images/zen-garden/zen_flowers_white.png',
    'flowers_yellow': 'assets/images/zen-garden/zen_flowers_yellow.png',
    'flowers_purple': 'assets/images/zen-garden/zen_flowers_purple.png',
    'tree_young': 'assets/images/zen-garden/zen_tree_young.png',
    'tree_autumn': 'assets/images/zen-garden/zen_tree_autumn.png',
    'bench': 'assets/images/zen-garden/zen_bench.png',
    'pagoda': 'assets/images/zen-garden/zen_pagoda.png',
    'pond_empty': 'assets/images/zen-garden/zen_pond_empty.png',
    'bush_small': 'assets/images/zen-garden/zen_shrub.png',
    'zen_bamboo': 'assets/images/zen-garden/zen_bamboo.png',
    'pond_full': 'assets/images/zen-garden/zen_pond.png',
    'tree_cherry': 'assets/images/zen-garden/zen_blossoms_a.png',
    'lantern': 'assets/images/zen-garden/zen_lantern.png',
    'torii_gate': 'assets/images/zen-garden/zen_shrine.png',
    'zen_bonsai': 'assets/images/zen-garden/zen_bonsai.png',
    'bridge': 'assets/images/zen-garden/zen_bridge.png',
    'stream': 'assets/images/zen-garden/zen_waterfall.png',
  };

  // Positions and sizes for silhouette previews (bottom, left, width, height)
  static const _silhouetteLayout = <String, List<double>>{
    'grass_base_2': [30, 200, 110, 80],
    'grass_base_3': [25, 310, 120, 90],
    'grass_1': [150, 20, 80, 100],
    'grass_1_b': [130, 280, 75, 95],
    'grass_2': [200, 50, 90, 120],
    'grass_2_b': [190, 300, 85, 110],
    'grass_3': [250, 10, 100, 150],
    'flowers_white': [180, 130, 70, 80],
    'flowers_yellow': [170, 230, 75, 85],
    'flowers_purple': [220, 260, 70, 90],
    'tree_young': [300, 60, 140, 180],
    'tree_autumn': [350, 250, 160, 200],
    'bench': [120, 200, 120, 70],
    'pagoda': [200, 150, 90, 140],
    'pond_empty': [160, 200, 180, 110],
    'bush_small': [145, 180, 95, 70],
    'zen_bamboo': [160, 40, 65, 190],
    'pond_full': [160, 200, 210, 125],
    'tree_cherry': [180, 260, 160, 200],
    'lantern': [170, 300, 60, 120],
    'torii_gate': [175, 200, 95, 125],
    'zen_bonsai': [180, 120, 180, 240],
    'bridge': [155, 70, 130, 80],
    'stream': [120, 0, 160, 220],
  };

  /// Get elements that unlock at the NEXT stage
  List<String> _getNextStageElements(int currentStage) {
    final nextStage = currentStage + 1;
    if (nextStage > 9) return [];
    // Elements at next stage that aren't already unlocked
    final nextStageMap = <int, List<String>>{
      1: ['pebble_path', 'small_stones'],
      2: ['bush_small'],
      3: ['zen_bamboo', 'pond_full'],
      4: ['pond_full', 'tree_cherry'],
      5: ['tree_cherry', 'lantern'],
      6: ['torii_gate', 'zen_bonsai'],
      7: ['bridge', 'stream'],
      8: ['mountain'],
      9: ['seasons'],
    };
    return (nextStageMap[nextStage] ?? [])
        .where((e) => !isUnlocked(e) && _silhouetteAssets.containsKey(e))
        .toList();
  }

  int _puzzlesUntilNextStage(int currentStage) {
    // Stage thresholds from GardenState.calculateStage
    const thresholds = [0, 3, 8, 15, 25, 40, 60, 85, 120, 170];
    if (currentStage + 1 >= thresholds.length) return 0;
    final needed = thresholds[currentStage + 1];
    final solved = gardenState.totalPuzzlesSolved;
    return (needed - solved).clamp(0, 999);
  }

  Widget _buildSilhouettePreviews(int currentStage) {
    final nextElements = _getNextStageElements(currentStage);
    if (nextElements.isEmpty) return const SizedBox.shrink();

    final puzzlesLeft = _puzzlesUntilNextStage(currentStage);

    return Stack(
      children: nextElements.map((elementId) {
        final asset = _silhouetteAssets[elementId]!;
        final layout = _silhouetteLayout[elementId]!;
        
        return Positioned(
          bottom: layout[0],
          left: layout[1],
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Solve $puzzlesLeft more puzzles to unlock!'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF2D2D2D),
                ),
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Silhouette: grayscale + low opacity
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.black,
                    BlendMode.saturation,
                  ),
                  child: Opacity(
                    opacity: 0.15,
                    child: Image.asset(
                      asset,
                      width: layout[2],
                      height: layout[3],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // Lock icon overlay
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock,
                    size: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
        ],
      ),
    );
  }
}

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

class GroundPainter extends CustomPainter {
  final int stage;

  GroundPainter({required this.stage});

  @override
  void paint(Canvas canvas, Size size) {
    // Stage 0: Dark earth with subtle texture (not black!)
    // Stage 1: Brown earth
    // Stage 2+: Green grass
    final List<Color> colors;
    if (stage >= 2) {
      colors = const [Color(0xFF6FA35E), Color(0xFF4F7F45)];
    } else if (stage >= 1) {
      colors = const [Color(0xFF9B8368), Color(0xFF7B624A)];
    } else {
      // Stage 0: Dark but visible earth
      colors = const [Color(0xFF3D4A3A), Color(0xFF2A3528)];
    }

    final earthPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), earthPaint);

    // Subtle earth texture at stage 0 (no gray ovals)
    if (stage == 0) {
      final texturePaint = Paint()
        ..color = const Color(0xFF4A5A47).withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      // Organic ground texture with small irregular patches
      for (var i = 0; i < 8; i++) {
        final x = (i * 50.0) + 20;
        final y = size.height - 80 + (i % 3) * 30;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, y), width: 30 + (i % 3) * 10, height: 8),
            const Radius.circular(4),
          ),
          texturePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GroundPainter oldDelegate) =>
      oldDelegate.stage != stage;
}

class GrassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF228B22)
      ..style = PaintingStyle.fill;

    final path = Path();
    for (var i = 0; i < 5; i++) {
      final x = size.width * (i / 5 + 0.1);
      path.moveTo(x, size.height);
      path.quadraticBezierTo(
        x - 5,
        size.height * 0.5,
        x + 3,
        0,
      );
      path.quadraticBezierTo(
        x + 8,
        size.height * 0.5,
        x + 5,
        size.height,
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Sparse grass for stage 0 - darker, fewer blades
class BaseGrassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A6B4A) // Darker, more muted green
      ..style = PaintingStyle.fill;

    final path = Path();
    // Just 3 sparse blades
    for (var i = 0; i < 3; i++) {
      final x = size.width * (i / 3 + 0.15);
      path.moveTo(x, size.height);
      path.quadraticBezierTo(
        x - 3,
        size.height * 0.5,
        x + 2,
        0,
      );
      path.quadraticBezierTo(
        x + 5,
        size.height * 0.5,
        x + 3,
        size.height,
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Beautiful organic tree with layered foliage
class TreePainter extends CustomPainter {
  final bool isCherry;
  final bool isAutumn;
  final double scale;

  TreePainter({this.isCherry = false, this.isAutumn = false, this.scale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final trunkPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.fill;

    final trunkHighlight = Paint()
      ..color = const Color(0xFF795548)
      ..style = PaintingStyle.fill;

    // Draw trunk
    final trunkPath = Path()
      ..moveTo(size.width * 0.42, size.height)
      ..lineTo(size.width * 0.38, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.35, size.height * 0.45,
        size.width * 0.4, size.height * 0.4,
      )
      ..lineTo(size.width * 0.6, size.height * 0.4)
      ..quadraticBezierTo(
        size.width * 0.65, size.height * 0.45,
        size.width * 0.62, size.height * 0.55,
      )
      ..lineTo(size.width * 0.58, size.height)
      ..close();

    canvas.drawPath(trunkPath, trunkPaint);

    // Trunk highlight
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.45, size.height * 0.5, size.width * 0.06, size.height * 0.45),
      trunkHighlight,
    );

    // Foliage colors
    final baseColor = isCherry
        ? const Color(0xFFFFB7C5)
        : isAutumn
            ? const Color(0xFFD4522A) // Autumn orange
            : const Color(0xFF2E7D32);
    final midColor = isCherry
        ? const Color(0xFFFF8FAA)
        : isAutumn
            ? const Color(0xFFE87D2A) // Autumn amber
            : const Color(0xFF43A047);
    final highlightColor = isCherry
        ? const Color(0xFFFFCDD2)
        : isAutumn
            ? const Color(0xFFFFB347) // Autumn gold
            : const Color(0xFF66BB6A);

    final basePaint = Paint()..color = baseColor..style = PaintingStyle.fill;
    final midPaint = Paint()..color = midColor..style = PaintingStyle.fill;
    final highlightPaint = Paint()..color = highlightColor..style = PaintingStyle.fill;

    // Draw layered foliage clusters
    // Back layer (larger, darker)
    _drawFoliageCluster(canvas, size.width * 0.5, size.height * 0.25, 50 * scale, basePaint);
    _drawFoliageCluster(canvas, size.width * 0.3, size.height * 0.3, 35 * scale, basePaint);
    _drawFoliageCluster(canvas, size.width * 0.7, size.height * 0.28, 38 * scale, basePaint);

    // Mid layer
    _drawFoliageCluster(canvas, size.width * 0.45, size.height * 0.2, 40 * scale, midPaint);
    _drawFoliageCluster(canvas, size.width * 0.6, size.height * 0.22, 35 * scale, midPaint);
    _drawFoliageCluster(canvas, size.width * 0.35, size.height * 0.26, 30 * scale, midPaint);

    // Front layer (smaller, lighter - highlights)
    _drawFoliageCluster(canvas, size.width * 0.5, size.height * 0.15, 28 * scale, highlightPaint);
    _drawFoliageCluster(canvas, size.width * 0.4, size.height * 0.22, 22 * scale, highlightPaint);
    _drawFoliageCluster(canvas, size.width * 0.62, size.height * 0.2, 20 * scale, highlightPaint);
  }

  void _drawFoliageCluster(Canvas canvas, double cx, double cy, double radius, Paint paint) {
    // Draw organic blob shape using overlapping circles
    canvas.drawCircle(Offset(cx, cy), radius, paint);
    canvas.drawCircle(Offset(cx - radius * 0.5, cy + radius * 0.3), radius * 0.7, paint);
    canvas.drawCircle(Offset(cx + radius * 0.5, cy + radius * 0.2), radius * 0.65, paint);
    canvas.drawCircle(Offset(cx, cy - radius * 0.4), radius * 0.6, paint);
  }

  @override
  bool shouldRepaint(covariant TreePainter oldDelegate) =>
      oldDelegate.isCherry != isCherry ||
      oldDelegate.isAutumn != isAutumn ||
      oldDelegate.scale != scale;
}

/// Simple koi fish shape
class KoiFishPainter extends CustomPainter {
  final Color color;

  KoiFishPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Fish body (oval)
    final bodyPath = Path()
      ..moveTo(size.width * 0.8, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.5,
        0,
        size.width * 0.15,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height,
        size.width * 0.8,
        size.height * 0.5,
      )
      ..close();

    canvas.drawPath(bodyPath, paint);

    // Tail
    final tailPath = Path()
      ..moveTo(size.width * 0.8, size.height * 0.5)
      ..lineTo(size.width, size.height * 0.2)
      ..lineTo(size.width, size.height * 0.8)
      ..close();

    canvas.drawPath(tailPath, paint);

    // Eye
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

/// Traditional Japanese torii gate
class ToriiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final redPaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.fill;

    final darkRedPaint = Paint()
      ..color = const Color(0xFFB71C1C)
      ..style = PaintingStyle.fill;

    // Main pillars
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.1, size.height * 0.25, size.width * 0.12, size.height * 0.75),
      redPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.78, size.height * 0.25, size.width * 0.12, size.height * 0.75),
      redPaint,
    );

    // Top beam (kasagi) - curved
    final kasagiPath = Path()
      ..moveTo(0, size.height * 0.12)
      ..quadraticBezierTo(size.width * 0.5, 0, size.width, size.height * 0.12)
      ..lineTo(size.width, size.height * 0.2)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.08, 0, size.height * 0.2)
      ..close();
    canvas.drawPath(kasagiPath, darkRedPaint);

    // Lower beam (nuki)
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.05, size.height * 0.28, size.width * 0.9, size.height * 0.08),
      redPaint,
    );

    // Small decorative piece on top
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.42, size.height * 0.04, size.width * 0.16, size.height * 0.08),
      darkRedPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small Japanese pagoda silhouette
class PagodaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final woodPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.fill;

    final roofPaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.fill;

    // Base tier
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.15, size.height * 0.7, size.width * 0.7, size.height * 0.25),
      woodPaint,
    );
    
    // Base roof
    final roof1 = Path()
      ..moveTo(0, size.height * 0.7)
      ..lineTo(size.width * 0.5, size.height * 0.58)
      ..lineTo(size.width, size.height * 0.7)
      ..close();
    canvas.drawPath(roof1, roofPaint);

    // Middle tier
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.2, size.height * 0.45, size.width * 0.6, size.height * 0.18),
      woodPaint,
    );
    
    // Middle roof
    final roof2 = Path()
      ..moveTo(size.width * 0.05, size.height * 0.45)
      ..lineTo(size.width * 0.5, size.height * 0.32)
      ..lineTo(size.width * 0.95, size.height * 0.45)
      ..close();
    canvas.drawPath(roof2, roofPaint);

    // Top tier
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.28, size.height * 0.22, size.width * 0.44, size.height * 0.13),
      woodPaint,
    );
    
    // Top roof
    final roof3 = Path()
      ..moveTo(size.width * 0.15, size.height * 0.22)
      ..lineTo(size.width * 0.5, size.height * 0.08)
      ..lineTo(size.width * 0.85, size.height * 0.22)
      ..close();
    canvas.drawPath(roof3, roofPaint);

    // Spire
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.47, 0, size.width * 0.06, size.height * 0.1),
      roofPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wooden bridge painter
class BridgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final woodPaint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.fill;

    final plankPaint = Paint()
      ..color = const Color(0xFFA0522D)
      ..style = PaintingStyle.fill;

    // Bridge arc/deck
    final deckPath = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.5, size.height * 0.3,
        size.width, size.height * 0.7,
      )
      ..lineTo(size.width, size.height * 0.85)
      ..quadraticBezierTo(
        size.width * 0.5, size.height * 0.45,
        0, size.height * 0.85,
      )
      ..close();
    canvas.drawPath(deckPath, woodPaint);

    // Planks
    for (int i = 1; i < 6; i++) {
      final x = size.width * (i / 6);
      // Calculate y position on the arc
      final t = i / 6;
      final y = size.height * (0.7 - 0.4 * math.sin(t * math.pi));
      
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, y + 5),
          width: 3,
          height: 12,
        ),
        plankPaint,
      );
    }

    // Railings
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.1, size.height * 0.4, size.width * 0.03, size.height * 0.35),
      woodPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.87, size.height * 0.4, size.width * 0.03, size.height * 0.35),
      woodPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Animated stream painter
class StreamPainter extends CustomPainter {
  final double animationValue;

  StreamPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Create gradient for water
    final waterPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF4FC3F7).withValues(alpha: 0.7),
          const Color(0xFF039BE5).withValues(alpha: 0.6),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    // Stream path - curves from left side toward pond area
    final streamPath = Path()
      ..moveTo(0, size.height * 0.3)
      ..quadraticBezierTo(
        size.width * 0.3, size.height * 0.5,
        size.width * 0.5, size.height * 0.4,
      )
      ..quadraticBezierTo(
        size.width * 0.7, size.height * 0.3,
        size.width * 0.9, size.height * 0.5,
      );

    canvas.drawPath(streamPath, waterPaint);

    // Shimmer effect
    final shimmerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3 * (0.5 + 0.5 * math.sin(animationValue * 2 * math.pi)))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Draw shimmer highlights that move along stream
    final offset = animationValue * size.width;
    for (int i = 0; i < 3; i++) {
      final startX = ((offset + i * size.width / 3) % size.width);
      if (startX < size.width * 0.1 || startX > size.width * 0.85) continue;
      
      canvas.drawCircle(
        Offset(startX, size.height * 0.4 + math.sin(startX / 50) * 10),
        3,
        shimmerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StreamPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

/// Wind chime with hanging tubes that sway in the ambient breeze
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

    // Top hanging string
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height * 0.13),
      stringPaint,
    );

    // Horizontal bar
    final barY = size.height * 0.15;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, barY),
          width: size.width * 0.9,
          height: 4,
        ),
        const Radius.circular(2),
      ),
      barPaint,
    );

    // Tubes: (xRatio, lengthRatio, tubeWidth, swayPhase)
    const tubeData = [
      (0.15, 0.40, 3.5, 0.0),
      (0.35, 0.58, 4.5, 1.3),
      (0.58, 0.66, 5.0, 2.5),
      (0.78, 0.48, 4.0, 0.7),
      (0.92, 0.35, 3.0, 1.9),
    ];

    final barBottom = barY + 2;

    for (final (xRatio, lengthRatio, tubeWidth, phase) in tubeData) {
      final swayAngle =
          math.sin(animationValue * 2 * math.pi + phase) * 0.12;
      final x = size.width * xRatio;
      final tubeHeight = size.height * lengthRatio;

      // Sway offset increases toward tube bottom (pendulum effect)
      final swayOffsetTop = math.sin(swayAngle) * tubeHeight * 0.15;
      final swayOffsetMid = math.sin(swayAngle) * tubeHeight * 0.35;

      // String from bar to tube top
      canvas.drawLine(
        Offset(x, barBottom),
        Offset(x + swayOffsetTop, barBottom + size.height * 0.06),
        stringPaint,
      );

      // Tube body
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

      // Shine highlight
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

/// Single bird painted as an M-shape silhouette (two wing arcs)
class BirdPainter extends CustomPainter {
  /// 0–1 progress through one full wing-flap cycle
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

    // Wing elevation: positive = wings up, negative = wings down
    final flapAngle = math.sin(flapProgress * 2 * math.pi);
    final wingLift = size.height * 0.45 * flapAngle;

    final cx = size.width / 2;
    final cy = size.height * 0.65;

    // Left wing arc + right wing arc meeting at the body centre dip
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

/// Dragonfly particle
class DragonflyPainter extends CustomPainter {
  final Color color;

  DragonflyPainter({this.color = const Color(0xFF64B5F6)});

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final wingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    // Body
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.5),
        width: size.width * 0.6,
        height: size.height * 0.2,
      ),
      bodyPaint,
    );

    // Wings (4 wings)
    // Top left
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.1, size.height * 0.1, size.width * 0.35, size.height * 0.3),
      wingPaint,
    );
    // Top right
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.55, size.height * 0.1, size.width * 0.35, size.height * 0.3),
      wingPaint,
    );
    // Bottom left
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.1, size.height * 0.55, size.width * 0.35, size.height * 0.3),
      wingPaint,
    );
    // Bottom right
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.55, size.height * 0.55, size.width * 0.35, size.height * 0.3),
      wingPaint,
    );
  }

  @override
  bool shouldRepaint(covariant DragonflyPainter oldDelegate) =>
      oldDelegate.color != color;
}

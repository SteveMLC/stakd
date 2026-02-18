import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/garden_state.dart';
import '../../services/zen_audio_service.dart';
import '../../services/garden_service.dart';
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
  
  // Milestone tracking
  bool _showingMilestone = false;
  int? _milestoneStage;
  String? _milestoneStageName;

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

  @override
  Widget build(BuildContext context) {
    final state = gardenState;
    
    // Check for audio updates on each build
    _checkAudioUpdates();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 0: Sky gradient
        _buildSky(state.currentStage),

        // Layer 1: Distant background
        if (isUnlocked('mountain')) _buildDistantBackground(),

        // Layer 2: Ground
        _buildGround(state.currentStage),

        // Layer 3: Water features
        if (isUnlocked('pond_empty') || isUnlocked('pond_full'))
          _buildWater(),

        // Layer 4: Flora and trees
        _buildFlora(state.currentStage),

        // Layer 5: Structures
        _buildStructures(),

        // Layer 6: Particles
        AnimatedBuilder(
          animation: _ambientController,
          builder: (context, child) => _buildParticles(),
        ),

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
    // Stage 0-5: Day sky with visible colors (not pure black)
    // Stage 6+: Night sky
    final colors = isNight
        ? [const Color(0xFF0D1321), const Color(0xFF1A1E3A), const Color(0xFF2E3D65)]
        : stage == 0
            ? [const Color(0xFF1a2a3a), const Color(0xFF2a3a4a), const Color(0xFF3a4a5a)] // Dusk for empty canvas
            : [const Color(0xFF87CEEB), const Color(0xFFB8D4E8), const Color(0xFFE6F7FF)];

    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
              stops: isNight ? const [0.0, 0.4, 1.0] : const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        
        // Stars (night only, stage 6+)
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
      bottom: 200,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 150,
        child: Stack(
          children: [
            CustomPaint(
              size: const Size(double.infinity, 150),
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
      height: 260,
      child: CustomPaint(
        painter: GroundPainter(stage: stage),
      ),
    );
  }

  Widget _buildWater() {
    final hasFull = isUnlocked('pond_full');
    final hasEmpty = isUnlocked('pond_empty');
    final hasKoi = isUnlocked('koi_fish');
    final hasLily = isUnlocked('lily_pads');

    if (!hasEmpty && !hasFull) return const SizedBox.shrink();

    return Positioned(
      bottom: 90,
      right: 60,
      child: SizedBox(
        width: 140,
        height: 85,
        child: PondFillAnimation(
          isFull: hasFull,
          emptyPond: Container(
            width: 130,
            height: 75,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(80),
              color: const Color(0xFF8B7355).withValues(alpha: 0.25),
              border: Border.all(
                color: const Color(0xFF6D5643).withValues(alpha: 0.4),
                width: 2,
              ),
            ),
          ),
          fullPond: Stack(
            children: [
              // Pond base with animated shimmer
              AnimatedBuilder(
                animation: _ambientController,
                builder: (context, child) {
                  final shimmer = 0.7 + math.sin(_ambientController.value * 2 * math.pi) * 0.1;
                  return Container(
                    width: 130,
                    height: 75,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(80),
                      gradient: RadialGradient(
                        center: Alignment.center,
                        colors: [
                          Color.lerp(
                            const Color(0xFF4FC3F7),
                            const Color(0xFF81D4FA),
                            shimmer - 0.7,
                          )!.withValues(alpha: 0.8),
                          const Color(0xFF039BE5).withValues(alpha: 0.6),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4FC3F7).withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  );
                },
              ),
            
            // Lily pads
            if (hasLily)
              GardenElement(
                elementId: 'lily_pads',
                revealType: GardenRevealType.bloomOut,
                child: Stack(
                  children: [
                    Positioned(
                      top: 15,
                      left: 20,
                      child: _lilyPad(size: 18),
                    ),
                    Positioned(
                      top: 35,
                      left: 45,
                      child: _lilyPad(size: 22, hasFlower: true),
                    ),
                    Positioned(
                      top: 20,
                      right: 30,
                      child: _lilyPad(size: 16),
                    ),
                  ],
                ),
              ),
            
            // Koi fish
            if (hasKoi)
              GardenElement(
                elementId: 'koi_fish',
                revealType: GardenRevealType.rippleIn,
                showParticles: false,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _lilyPad({required double size, bool hasFlower = false}) {
    return SizedBox(
      width: size + (hasFlower ? 8 : 0),
      height: size + (hasFlower ? 8 : 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size * 0.7,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(size),
            ),
          ),
          if (hasFlower)
            Positioned(
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFB7C5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

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

  Widget _buildFlora(int stage) {
    final elements = <Widget>[];

    // Stage 0: Baseline grass - sparse but visible, so garden isn't empty
    if (stage >= 0) {
      elements.add(
        GardenElement(
          elementId: 'grass_base',
          revealType: GardenRevealType.growUp,
          child: _baseGrass(left: 20, size: 28, opacity: 0.7),
        ),
      );
      elements.add(
        GardenElement(
          elementId: 'grass_base_2',
          revealType: GardenRevealType.growUp,
          child: _baseGrass(right: 30, size: 24, opacity: 0.6),
        ),
      );
      elements.add(
        GardenElement(
          elementId: 'grass_base_3',
          revealType: GardenRevealType.growUp,
          child: _baseGrass(left: 160, size: 26, opacity: 0.5),
        ),
      );
    }

    // Stage 1: First grass patches (more vibrant)
    if (stage >= 1) {
      elements.add(
        GardenElement(
          elementId: 'grass_1',
          revealType: GardenRevealType.growUp,
          child: _grass(left: 30, size: 40, swayPhase: 0.1),
        ),
      );
      elements.add(
        GardenElement(
          elementId: 'grass_1_b',
          revealType: GardenRevealType.growUp,
          child: _grass(right: 50, size: 36, swayPhase: 0.35),
        ),
      );
    }
    
    // Stage 2: More grass and flowers
    if (stage >= 2) {
      elements.add(
        GardenElement(
          elementId: 'grass_2',
          revealType: GardenRevealType.growUp,
          child: _grass(left: 100, size: 50, swayPhase: 0.2),
        ),
      );
      elements.add(
        GardenElement(
          elementId: 'grass_2_b',
          revealType: GardenRevealType.growUp,
          child: _grass(right: 120, size: 46, swayPhase: 0.6),
        ),
      );
      elements.add(_flower(left: 80, color: Colors.white, elementId: 'flowers_white'));
      elements.add(_flower(right: 90, color: Colors.yellow, elementId: 'flowers_yellow'));
      elements.add(
        GardenElement(
          elementId: 'bush_small',
          revealType: GardenRevealType.bloomOut,
          child: _bush(left: 200, size: 30),
        ),
      );
    }
    
    // Stage 3: Trees and more flowers
    if (stage >= 3) {
      elements.add(
        GardenElement(
          elementId: 'grass_3',
          revealType: GardenRevealType.growUp,
          child: _grass(left: 230, size: 44, swayPhase: 0.45),
        ),
      );
      elements.add(
        GardenElement(
          elementId: 'sapling',
          revealType: GardenRevealType.growUp,
          child: _tree(left: 50, stage: stage),
        ),
      );
      elements.add(_flower(left: 160, color: const Color(0xFFB39DDB), elementId: 'flowers_purple'));
    }
    
    // Stage 5: Cherry blossom tree
    if (stage >= 5) {
      elements.add(
        GardenElement(
          elementId: 'tree_cherry',
          revealType: GardenRevealType.growUp,
          child: _tree(right: 80, stage: stage, isCherry: true),
        ),
      );
    }

    // Stage 6: Autumn tree
    if (stage >= 6) {
      elements.add(
        GardenElement(
          elementId: 'tree_autumn',
          revealType: GardenRevealType.growUp,
          child: _tree(left: 140, stage: stage, isAutumn: true),
        ),
      );
    }

    return Stack(children: elements);
  }

  Widget _grass({double? left, double? right, required double size, required double swayPhase}) {
    return Positioned(
      bottom: 70,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: _ambientController,
        builder: (context, child) {
          final sway = math.sin((_ambientController.value * 2 * math.pi) + swayPhase) * 3;
          return Transform.rotate(
            angle: sway * 0.02,
            alignment: Alignment.bottomCenter,
            child: child,
          );
        },
        child: CustomPaint(
          size: Size(size, size * 1.5),
          painter: GrassPainter(),
        ),
      ),
    );
  }

  /// Sparse baseline grass for stage 0 - visible but subtle
  Widget _baseGrass({double? left, double? right, required double size, double opacity = 0.6}) {
    return Positioned(
      bottom: 65,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: _ambientController,
        builder: (context, child) {
          final sway = math.sin(_ambientController.value * 2 * math.pi) * 2;
          return Transform.rotate(
            angle: sway * 0.015,
            alignment: Alignment.bottomCenter,
            child: child,
          );
        },
        child: Opacity(
          opacity: opacity,
          child: CustomPaint(
            size: Size(size, size * 1.2),
            painter: BaseGrassPainter(),
          ),
        ),
      ),
    );
  }
  
  Widget _bush({double? left, double? right, required double size}) {
    return Positioned(
      bottom: 75,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: _ambientController,
        builder: (context, child) {
          final sway = math.sin((_ambientController.value * 2 * math.pi) * 0.5) * 1;
          return Transform.rotate(
            angle: sway * 0.01,
            alignment: Alignment.bottomCenter,
            child: child,
          );
        },
        child: Container(
          width: size,
          height: size * 0.8,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(size / 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _flower({double? left, double? right, required Color color, String? elementId}) {
    final flowerWidget = Positioned(
      bottom: 80,
      left: left,
      right: right,
      child: SizedBox(
        width: 20,
        height: 32,
        child: Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 2, height: 18, color: Colors.green[700]),
          ],
        ),
      ),
    );

    if (elementId != null) {
      return GardenElement(
        elementId: elementId,
        revealType: GardenRevealType.bloomOut,
        child: flowerWidget,
      );
    }
    return flowerWidget;
  }

  Widget _tree({double? left, double? right, required int stage, bool isCherry = false, bool isAutumn = false}) {
    final height = 80.0 + (stage - 3) * 28;
    final scale = height / 140;

    return Positioned(
      bottom: 100,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: _ambientController,
        builder: (context, child) {
          final sway = math.sin(_ambientController.value * 2 * math.pi) * 0.015;
          return Transform.rotate(
            angle: sway,
            alignment: Alignment.bottomCenter,
            child: child,
          );
        },
        child: SizedBox(
          width: 120 * scale,
          height: 160 * scale,
          child: CustomPaint(
            painter: TreePainter(
              isCherry: isCherry,
              isAutumn: isAutumn,
              scale: scale,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStructures() {
    final elements = <Widget>[];

    if (isUnlocked('bench')) {
      elements.add(
        GardenElement(
          elementId: 'bench',
          revealType: GardenRevealType.fadeScale,
          child: Positioned(
            bottom: 90,
            left: 150,
            child: _simpleBench(),
          ),
        ),
      );
    }

    if (isUnlocked('lantern')) {
      elements.add(
        GardenElement(
          elementId: 'lantern',
          revealType: GardenRevealType.growUp,
          child: Positioned(
            bottom: 90,
            right: 40,
            child: _simpleLantern(),
          ),
        ),
      );
    }

    if (isUnlocked('torii_gate')) {
      elements.add(
        GardenElement(
          elementId: 'torii_gate',
          revealType: GardenRevealType.growUp,
          revealDuration: const Duration(milliseconds: 2000),
          child: Positioned(
            bottom: 95,
            left: 220,
            child: SizedBox(
              width: 80,
              height: 100,
              child: CustomPaint(
                painter: ToriiPainter(),
              ),
            ),
          ),
        ),
      );
    }

    if (isUnlocked('pagoda')) {
      elements.add(
        GardenElement(
          elementId: 'pagoda',
          revealType: GardenRevealType.growUp,
          revealDuration: const Duration(milliseconds: 2500),
          child: Positioned(
            bottom: 130,
            left: 20,
            child: SizedBox(
              width: 55,
              height: 85,
              child: CustomPaint(
                painter: PagodaPainter(),
              ),
            ),
          ),
        ),
      );
    }

    if (isUnlocked('stream')) {
      elements.add(
        GardenElement(
          elementId: 'stream',
          revealType: GardenRevealType.rippleIn,
          child: Positioned(
            bottom: 70,
            left: 0,
            child: SizedBox(
              width: 200,
              height: 60,
              child: AnimatedBuilder(
                animation: _ambientController,
                builder: (context, _) => CustomPaint(
                  painter: StreamPainter(animationValue: _ambientController.value),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (isUnlocked('bridge')) {
      elements.add(
        GardenElement(
          elementId: 'bridge',
          revealType: GardenRevealType.fadeScale,
          child: Positioned(
            bottom: 88,
            left: 90,
            child: SizedBox(
              width: 45,
              height: 32,
              child: CustomPaint(
                painter: BridgePainter(),
              ),
            ),
          ),
        ),
      );
    }

    if (isUnlocked('wind_chime')) {
      elements.add(
        GardenElement(
          elementId: 'wind_chime',
          revealType: GardenRevealType.growUp,
          child: Positioned(
            bottom: 155,
            right: 110,
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

    return Stack(children: elements);
  }

  Widget _simpleBench() {
    return SizedBox(
      width: 60,
      height: 35,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 5,
            right: 5,
            child: Container(height: 8, color: const Color(0xFF8B4513)),
          ),
          Positioned(
            top: 8,
            left: 10,
            child: Container(width: 6, height: 20, color: const Color(0xFF654321)),
          ),
          Positioned(
            top: 8,
            right: 10,
            child: Container(width: 6, height: 20, color: const Color(0xFF654321)),
          ),
        ],
      ),
    );
  }

  Widget _simpleLantern() {
    return SizedBox(
      width: 25,
      height: 50,
      child: Column(
        children: [
          Container(
            width: 20,
            height: 25,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFACD),
              borderRadius: BorderRadius.circular(3),
              boxShadow: isUnlocked('fireflies')
                  ? [BoxShadow(color: Colors.yellow.withValues(alpha: 0.5), blurRadius: 10)]
                  : null,
            ),
          ),
          Container(width: 8, height: 25, color: const Color(0xFF696969)),
        ],
      ),
    );
  }

  Widget _buildParticles() {
    final particles = <Widget>[];

    if (isUnlocked('butterfly')) {
      particles.add(
        GardenElement(
          elementId: 'butterfly',
          revealType: GardenRevealType.fadeScale,
          showParticles: false,
          child: _flutteringBug(top: 150, left: 100),
        ),
      );
    }

    if (isUnlocked('petals')) {
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

    if (isUnlocked('fireflies')) {
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
    if (isUnlocked('birds')) {
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
    if (isUnlocked('dragonflies')) {
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

  Widget _flutteringBug({required double top, required double left}) {
    return Positioned(
      top: top + math.sin(_ambientController.value * 2 * math.pi) * 10,
      left: left + math.cos(_ambientController.value * 2 * math.pi) * 15,
      child: const Icon(
        Icons.flutter_dash,
        size: 18,
        color: Color(0xFFB388FF),
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

    // Add subtle texture at stage 0 so it's not flat
    if (stage == 0) {
      final texturePaint = Paint()..color = const Color(0xFF4A5A47).withValues(alpha: 0.3);
      for (var i = 0; i < 12; i++) {
        final x = (i * 35.0) + 10;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, size.height - 60 + (i % 3) * 20),
            width: 25 + (i % 4) * 8,
            height: 12 + (i % 3) * 5,
          ),
          texturePaint,
        );
      }
    }

    // Pebbles/stones at stage 1+
    if (stage >= 1) {
      final stonePaint = Paint()..color = const Color(0xFF9CA3AF);
      for (var i = 0; i < 5; i++) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(60 + i * 70.0, size.height - 40),
            width: 40,
            height: 25,
          ),
          stonePaint,
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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/garden_state.dart';
import 'base_theme_scene.dart';

class ZenGardenScene extends BaseThemeScene {
  const ZenGardenScene({
    super.key,
    super.showStats = false,
    super.interactive = false,
  });

  @override
  State<ZenGardenScene> createState() => _ZenGardenSceneState();
}

class _ZenGardenSceneState extends BaseThemeSceneState<ZenGardenScene>
    with TickerProviderStateMixin {
  late AnimationController _ambientController;
  late List<Offset> _fireflySeeds;
  late List<Offset> _petalSeeds;

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
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = gardenState;

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
      ],
    );
  }

  Widget _buildSky(int stage) {
    final colors = stage >= 6
        ? [const Color(0xFF1A1E3A), const Color(0xFF2E3D65)]
        : [const Color(0xFF87CEEB), const Color(0xFFE6F7FF)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
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
            color: Colors.white.withOpacity(0.75),
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

    return Positioned(
      bottom: 90,
      right: 60,
      child: Container(
        width: 130,
        height: 75,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(80),
          color: hasFull
              ? const Color(0xFF5BA3C0).withOpacity(0.7)
              : const Color(0xFF8B7355).withOpacity(0.25),
        ),
      ),
    );
  }

  Widget _buildFlora(int stage) {
    final elements = <Widget>[];

    if (stage >= 1) {
      elements.add(_grass(left: 30, size: 40, swayPhase: 0.1));
      elements.add(_grass(right: 50, size: 36, swayPhase: 0.35));
    }
    if (stage >= 2) {
      elements.add(_grass(left: 100, size: 50, swayPhase: 0.2));
      elements.add(_grass(right: 120, size: 46, swayPhase: 0.6));
      elements.add(_flower(left: 80, color: Colors.white));
      elements.add(_flower(right: 90, color: Colors.yellow));
    }
    if (stage >= 3) {
      elements.add(_tree(left: 50, stage: stage));
      elements.add(_flower(left: 160, color: const Color(0xFFB39DDB)));
    }
    if (stage >= 5) {
      elements.add(_tree(right: 80, stage: stage, isCherry: true));
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

  Widget _flower({double? left, double? right, required Color color}) {
    return Positioned(
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
  }

  Widget _tree({double? left, double? right, required int stage, bool isCherry = false}) {
    final height = 80.0 + (stage - 3) * 28;
    final color = isCherry ? const Color(0xFFFFB7C5) : const Color(0xFF228B22);

    return Positioned(
      bottom: 110,
      left: left,
      right: right,
      child: Column(
        children: [
          Container(
            width: height * 0.8,
            height: height * 0.6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(height * 0.4),
            ),
          ),
          Container(
            width: 14,
            height: height * 0.4,
            color: const Color(0xFF8B4513),
          ),
        ],
      ),
    );
  }

  Widget _buildStructures() {
    final elements = <Widget>[];

    if (isUnlocked('bench')) {
      elements.add(
        Positioned(
          bottom: 90,
          left: 150,
          child: _simpleBench(),
        ),
      );
    }

    if (isUnlocked('lantern')) {
      elements.add(
        Positioned(
          bottom: 90,
          right: 40,
          child: _simpleLantern(),
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
                  ? [BoxShadow(color: Colors.yellow.withOpacity(0.5), blurRadius: 10)]
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
      particles.add(_flutteringBug(top: 150, left: 100));
    }

    if (isUnlocked('petals')) {
      for (var i = 0; i < _petalSeeds.length; i++) {
        final seed = _petalSeeds[i];
        final offset = _ambientController.value * 200 + i * 60;
        particles.add(
          Positioned(
            top: (offset % 420),
            left: 40 + seed.dx * 260 + math.sin(offset / 50) * 20,
            child: Opacity(
              opacity: 0.7,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFB7C5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }
    }

    if (isUnlocked('fireflies')) {
      for (var i = 0; i < _fireflySeeds.length; i++) {
        final seed = _fireflySeeds[i];
        final x = 40 + seed.dx * 280;
        final y = 120 + math.sin(_ambientController.value * 2 * math.pi + i) * 30;
        final opacity = 0.3 + math.sin(_ambientController.value * 4 * math.pi + i) * 0.5;
        particles.add(
          Positioned(
            top: y.toDouble(),
            left: x.toDouble(),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.yellow.withOpacity(opacity.clamp(0.0, 1.0)),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.yellow.withOpacity(opacity.clamp(0.0, 0.5)),
                    blurRadius: 8,
                  ),
                ],
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
        color: Colors.black.withOpacity(0.4),
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
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
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
      ..color = const Color(0xFF4A5568).withOpacity(0.5)
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
    final earthPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: stage >= 2
            ? const [Color(0xFF6FA35E), Color(0xFF4F7F45)]
            : const [Color(0xFF9B8368), Color(0xFF7B624A)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), earthPaint);

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

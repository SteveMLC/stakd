import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Types of reveal animations for scene elements.
enum SceneRevealType {
  growUp,
  fadeIn,
  fadeScale,
  rippleIn,
  bloomOut,
}

/// Abstract base for reward/progression visualization scenes.
/// Provides common element positioning, ambient animation, and particle systems.
/// Extend this for game-specific reward scenes (e.g., zen garden, warehouse, etc.).
abstract class RewardSceneBase extends StatefulWidget {
  final bool showStats;
  final bool interactive;

  const RewardSceneBase({
    super.key,
    this.showStats = false,
    this.interactive = false,
  });
}

/// Base state providing ambient animation controller and particle seed generation.
abstract class RewardSceneBaseState<T extends RewardSceneBase> extends State<T>
    with TickerProviderStateMixin {
  late AnimationController ambientController;

  @override
  void initState() {
    super.initState();
    ambientController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    ambientController.dispose();
    super.dispose();
  }

  /// Generate deterministic seed-based positions for particles.
  List<Offset> generateParticleSeeds(int count, {int seed = 42}) {
    final rng = math.Random(seed);
    return List.generate(count, (_) => Offset(rng.nextDouble(), rng.nextDouble()));
  }

  /// Calculate floating particle position with gentle sine/cosine movement.
  Offset calculateFloatingPosition({
    required Offset base,
    required double progress,
    required int index,
    double xAmplitude = 20,
    double yAmplitude = 15,
    double speed = 1.0,
    double phase = 0,
  }) {
    final animPhase = progress * 2 * math.pi * speed + phase;
    final xOffset = math.sin(animPhase) * xAmplitude;
    final yOffset = math.cos(animPhase * 0.7) * yAmplitude;
    return Offset(base.dx + xOffset, base.dy + yOffset);
  }

  /// Build a pulsing glow effect for firefly-like particles.
  Widget buildGlowParticle({
    required double progress,
    required int index,
    required Color baseColor,
    Color? highlightColor,
    double baseOpacity = 0.4,
    double size = 5,
  }) {
    final time = progress * 2 * math.pi;
    final pulse = (math.sin(time * 2 + index * 1.3) + 1) / 2;
    final opacity = baseOpacity + pulse * 0.6;
    final glowRadius = 6 + pulse * 4;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color.lerp(
          baseColor.withValues(alpha: opacity),
          (highlightColor ?? baseColor).withValues(alpha: opacity),
          pulse,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: opacity * 0.6),
            blurRadius: glowRadius,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

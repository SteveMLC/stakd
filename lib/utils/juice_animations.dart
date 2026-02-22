import 'dart:math';
import 'package:flutter/material.dart';

/// Reusable animation helpers for juice and polish
/// 
/// "Juice" refers to visual and haptic feedback that makes the game feel
/// responsive and satisfying. This file provides common animation patterns.
class JuiceAnimations {
  /// Squash and stretch animation for layer pickup
  /// 
  /// Sequence: 1.0 → 0.95 (squash) → 1.05 (stretch) → 1.0 (settle)
  /// Perfect for when a layer is selected/grabbed
  static Animation<double> squashStretchAnimation(
    AnimationController controller, {
    double squashScale = 0.95,
    double stretchScale = 1.05,
  }) {
    return TweenSequence<double>([
      // Initial squash (15%)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: squashScale)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      // Stretch overshoot (25%)
      TweenSequenceItem(
        tween: Tween<double>(begin: squashScale, end: stretchScale)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      // Settle back to normal (60%)
      TweenSequenceItem(
        tween: Tween<double>(begin: stretchScale, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(controller);
  }

  /// Bounce animation for layer landing
  /// 
  /// Creates a satisfying bounce when a layer lands on a stack
  static Animation<double> bounceAnimation(
    AnimationController controller, {
    double bounceHeight = 8.0,
  }) {
    return TweenSequence<double>([
      // Rise
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -bounceHeight),
        weight: 30,
      ),
      // Fall and bounce
      TweenSequenceItem(
        tween: Tween<double>(begin: -bounceHeight, end: 0.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 70,
      ),
    ]).animate(controller);
  }

  /// Glow pulse animation for stacks nearing completion
  /// 
  /// Subtle pulsing effect to draw attention to almost-complete stacks
  static Animation<double> glowPulseAnimation(
    AnimationController controller, {
    double minAlpha = 0.3,
    double maxAlpha = 0.7,
  }) {
    return Tween<double>(begin: minAlpha, end: maxAlpha).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
  }

  /// Scale pop animation for UI feedback
  /// 
  /// Quick scale-up and back for buttons and interactive elements
  static Animation<double> popAnimation(
    AnimationController controller, {
    double popScale = 1.15,
  }) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: popScale)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: popScale, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(controller);
  }

  /// Quadratic bezier curve for arc trajectories
  /// 
  /// Used for smooth arc movement when layers travel between stacks
  static Offset quadraticBezier(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
    );
  }

  /// Calculate arc control point for smooth trajectory
  /// 
  /// Returns a point above the midpoint for a natural arc
  static Offset calculateArcControlPoint(
    Offset start,
    Offset end, {
    double arcHeightFactor = 0.3,
  }) {
    final midX = (start.dx + end.dx) / 2;
    final minY = start.dy < end.dy ? start.dy : end.dy;
    final distance = (end - start).distance;
    final arcHeight = (distance * arcHeightFactor).clamp(40.0, 80.0);
    
    return Offset(midX, minY - arcHeight);
  }

  /// Squash/stretch for layer pickup and drop
  /// 
  /// Horizontal and vertical scale animations that create squash/stretch effect
  /// - Pickup: squash wide (scaleX up) and short (scaleY down)
  /// - Drop: stretch narrow (scaleX down) and tall (scaleY up)
  static ({
    Animation<double> scaleX,
    Animation<double> scaleY,
  }) squashStretchPickupDrop(AnimationController controller) {
    final scaleX = TweenSequence<double>([
      // Pickup: squash wide (1.0 → 1.08)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      // Travel: back to normal (1.08 → 1.0)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 50,
      ),
      // Drop: stretch narrow (1.0 → 0.92)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.92)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      // Bounce back: elasticOut (0.92 → 1.0)
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.92, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 20,
      ),
    ]).animate(controller);

    final scaleY = TweenSequence<double>([
      // Pickup: squash short (1.0 → 0.92)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.92)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      // Travel: back to normal (0.92 → 1.0)
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.92, end: 1.0)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 50,
      ),
      // Drop: stretch tall (1.0 → 1.08)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      // Bounce back: elasticOut (1.08 → 1.0)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 20,
      ),
    ]).animate(controller);

    return (scaleX: scaleX, scaleY: scaleY);
  }

  /// Shake animation for invalid moves or errors
  /// 
  /// Horizontal shake to indicate "no" or invalid action
  static Animation<double> shakeAnimation(AnimationController controller) {
    return TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
  }

  /// Particle burst data for confetti-style celebrations
  /// 
  /// Creates colorful particle effects for stack completions
  static List<ParticleData> generateParticleBurst({
    required Offset center,
    required Color color,
    int particleCount = 18,
    double minSpeed = 50,
    double maxSpeed = 150,
    double spread = 360,
  }) {
    final particles = <ParticleData>[];
    
    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * spread * (pi / 180);
      final speed = minSpeed + (maxSpeed - minSpeed) * (i / particleCount);
      
      particles.add(ParticleData(
        position: center,
        velocity: Offset(
          speed * cos(angle),
          speed * sin(angle),
        ),
        color: color,
        size: 4.0 + (i % 3) * 2.0,
        lifetime: Duration(milliseconds: 400 + (i % 200)),
      ));
    }
    
    return particles;
  }
}

/// Data class for particle effects
class ParticleData {
  final Offset position;
  final Offset velocity;
  final Color color;
  final double size;
  final Duration lifetime;

  const ParticleData({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.lifetime,
  });
}

/// Reusable widget for lift and drop effects
class LiftAndDropWrapper extends StatefulWidget {
  final Widget child;
  final bool isLifted;
  final VoidCallback? onLiftComplete;

  const LiftAndDropWrapper({
    super.key,
    required this.child,
    required this.isLifted,
    this.onLiftComplete,
  });

  @override
  State<LiftAndDropWrapper> createState() => _LiftAndDropWrapperState();
}

class _LiftAndDropWrapperState extends State<LiftAndDropWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _liftAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _liftAnimation = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(LiftAndDropWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLifted && !oldWidget.isLifted) {
      _controller.forward().then((_) => widget.onLiftComplete?.call());
    } else if (!widget.isLifted && oldWidget.isLifted) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _liftAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}

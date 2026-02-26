import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/garden_state.dart';
import '../../services/zen_audio_service.dart';

/// Celebration overlay when reaching a new garden stage
class GrowthMilestone extends StatefulWidget {
  final int stage;
  final String stageName;
  final VoidCallback onComplete;

  const GrowthMilestone({
    super.key,
    required this.stage,
    required this.stageName,
    required this.onComplete,
  });

  @override
  State<GrowthMilestone> createState() => _GrowthMilestoneState();
}

class _GrowthMilestoneState extends State<GrowthMilestone>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _particleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  
  final List<_CelebrationParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 4600),
      vsync: this,
    );
    
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 800),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 3200),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 600),
    ]).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.95, end: 1.0).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 800,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 3800),
    ]).animate(_controller);

    _glowAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
    );

    _spawnParticles();
    _playAnimation();
  }

  void _spawnParticles() {
    final rng = math.Random();
    for (int i = 0; i < 25; i++) {
      _particles.add(_CelebrationParticle(
        startX: rng.nextDouble(),
        startY: 0.5 + rng.nextDouble() * 0.1,
        angle: rng.nextDouble() * 2 * math.pi,
        speed: 80 + rng.nextDouble() * 120,
        size: 4 + rng.nextDouble() * 8,
        color: [
          const Color(0xFFFFD700),
          const Color(0xFFFFF9C4),
          const Color(0xFFFFFFFF),
          const Color(0xFF81C784),
          const Color(0xFF64B5F6),
        ][rng.nextInt(5)],
        lifespan: 0.6 + rng.nextDouble() * 0.4,
      ));
    }
  }

  Future<void> _playAnimation() async {
    // Play sound
    ZenAudioService().playStageAdvance();
    
    // Start animations
    _particleController.forward(); // particles run simultaneously
    
    // Wait for main animation to complete (4.6s)
    await _controller.forward();
    
    // Callback
    widget.onComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stageIcon = _getStageIcon(widget.stage);
    final milestoneTitle = GardenState.getMilestoneTitle(widget.stage);
    final milestoneLine = GardenState.getMilestoneLine(widget.stage);

    return GestureDetector(
      onTap: () {
        _controller.stop();
        widget.onComplete();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _particleController]),
        builder: (context, _) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              color: Colors.black.withValues(alpha: 0.7 * _fadeAnimation.value),
              child: Stack(
                children: [
                  // Particles
                  ..._buildParticles(),
                  
                  // Center card
                  Center(
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 280,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 28,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white
                                  .withValues(alpha: _glowAnimation.value * 0.3),
                              blurRadius: 24 * _glowAnimation.value,
                              spreadRadius: 2 * _glowAnimation.value,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              stageIcon,
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              milestoneTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              milestoneLine,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getStageIcon(int stage) {
    const icons = [
      '🌑', // Empty Canvas
      '🌱', // First Signs
      '🌿', // Taking Root
      '🌲', // Quiet Growth
      '💧', // Still Water
      '🌸', // First Bloom
      '🏮', // Harmony
      '⛩️', // Sanctuary
      '🌙', // Transcendence
      '✨', // Infinite
    ];
    return icons[stage.clamp(0, 9)];
  }

  List<Widget> _buildParticles() {
    final size = MediaQuery.of(context).size;
    final progress = _particleController.value;
    
    return _particles.where((p) {
      return progress <= p.lifespan;
    }).map((p) {
      final lifeProgress = (progress / p.lifespan).clamp(0.0, 1.0);
      
      final distance = p.speed * lifeProgress;
      final x = size.width * p.startX + math.cos(p.angle) * distance;
      final y = size.height * p.startY + math.sin(p.angle) * distance - 50;
      
      final opacity = (1 - lifeProgress).clamp(0.0, 1.0);
      
      return Positioned(
        left: x - p.size / 2,
        top: y - p.size / 2,
        child: Container(
          width: p.size,
          height: p.size,
          decoration: BoxDecoration(
            color: p.color.withValues(alpha: opacity),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: p.color.withValues(alpha: opacity * 0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class _CelebrationParticle {
  final double startX;
  final double startY;
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double lifespan;

  _CelebrationParticle({
    required this.startX,
    required this.startY,
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.lifespan,
  });
}

import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Animated chain reaction text popup
/// Shows escalating feedback based on chain level
class ChainTextPopup extends StatefulWidget {
  final int chainLevel;
  final VoidCallback? onComplete;

  const ChainTextPopup({
    super.key,
    required this.chainLevel,
    this.onComplete,
  });

  @override
  State<ChainTextPopup> createState() => _ChainTextPopupState();
}

class _ChainTextPopupState extends State<ChainTextPopup>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // Duration scales with chain level for more dramatic effect
    final baseDuration = 800 + (widget.chainLevel * 100).clamp(0, 400);
    
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: baseDuration),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // Scale: pop in quickly with overshoot
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.4)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.4, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.8)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    // Opacity: fade in, stay, fade out
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_controller);

    // Float upward
    _floatAnimation = Tween<double>(begin: 0, end: -60).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Slight rotation for dynamic feel (more for higher chains)
    final rotationAmount = (widget.chainLevel - 1) * 0.02;
    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: rotationAmount),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: rotationAmount, end: -rotationAmount),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -rotationAmount, end: 0),
        weight: 25,
      ),
    ]).animate(_controller);

    // Glow pulse for high chains
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.chainLevel >= 3) {
      _glowController.repeat(reverse: true);
    }

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _glowController.dispose();
    super.dispose();
  }

  String _getChainText() {
    switch (widget.chainLevel) {
      case 2:
        return '2x CHAIN!';
      case 3:
        return '3x CHAIN!!';
      case 4:
        return 'MEGA CHAIN!!!';
      default:
        if (widget.chainLevel >= 5) {
          return 'INSANE ${widget.chainLevel}x!!!';
        }
        return '${widget.chainLevel}x';
    }
  }

  List<Color> _getGradientColors() {
    switch (widget.chainLevel) {
      case 2:
        return [
          const Color(0xFFFFD700), // Gold
          const Color(0xFFFFA500), // Orange
        ];
      case 3:
        return [
          const Color(0xFFFF8C00), // Dark Orange
          const Color(0xFFFF4500), // Red-Orange
        ];
      case 4:
        return [
          const Color(0xFFFF4500), // Red-Orange
          const Color(0xFFFF0000), // Red
        ];
      default:
        if (widget.chainLevel >= 5) {
          // Rainbow gradient for 5+
          return [
            const Color(0xFFFF0000),
            const Color(0xFFFF7F00),
            const Color(0xFFFFFF00),
            const Color(0xFF00FF00),
            const Color(0xFF0000FF),
            const Color(0xFF9400D3),
          ];
        }
        return [GameColors.accent, GameColors.accent];
    }
  }

  Color _getGlowColor() {
    switch (widget.chainLevel) {
      case 2:
        return const Color(0xFFFFD700);
      case 3:
        return const Color(0xFFFF8C00);
      case 4:
        return const Color(0xFFFF4500);
      default:
        if (widget.chainLevel >= 5) {
          return Colors.white;
        }
        return GameColors.accent;
    }
  }

  double _getFontSize() {
    if (widget.chainLevel >= 5) return 42;
    if (widget.chainLevel >= 4) return 40;
    if (widget.chainLevel >= 3) return 36;
    return 32;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _glowController]),
      builder: (context, child) {
        final gradientColors = _getGradientColors();
        final glowIntensity = widget.chainLevel >= 3 
            ? _glowAnimation.value 
            : 0.7;
        
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getGlowColor().withValues(alpha: glowIntensity),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getGlowColor().withValues(
                          alpha: 0.3 + (glowIntensity * 0.4),
                        ),
                        blurRadius: 20 + (widget.chainLevel * 4),
                        spreadRadius: 4 + (widget.chainLevel * 2),
                      ),
                      // Inner glow for high chains
                      if (widget.chainLevel >= 3)
                        BoxShadow(
                          color: _getGlowColor().withValues(
                            alpha: 0.2 * glowIntensity,
                          ),
                          blurRadius: 10,
                          spreadRadius: -2,
                        ),
                    ],
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds);
                    },
                    child: Text(
                      _getChainText(),
                      style: TextStyle(
                        fontSize: _getFontSize(),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Overlay widget that manages chain popup display
class ChainTextPopupOverlay extends StatelessWidget {
  final int chainLevel;
  final VoidCallback? onComplete;

  const ChainTextPopupOverlay({
    super.key,
    required this.chainLevel,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: ChainTextPopup(
            chainLevel: chainLevel,
            onComplete: onComplete,
          ),
        ),
      ),
    );
  }
}

/// Rainbow particle burst for mega chains (4+)
class ChainParticleBurst extends StatefulWidget {
  final Offset center;
  final int chainLevel;
  final VoidCallback? onComplete;

  const ChainParticleBurst({
    super.key,
    required this.center,
    required this.chainLevel,
    this.onComplete,
  });

  @override
  State<ChainParticleBurst> createState() => _ChainParticleBurstState();
}

class _ChainParticleBurstState extends State<ChainParticleBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ChainParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    final duration = 600 + (widget.chainLevel * 100).clamp(0, 400);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: duration),
    );

    _initializeParticles();

    _controller.addListener(() => setState(() {}));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    _controller.forward();
  }

  void _initializeParticles() {
    // More particles for higher chains
    final particleCount = 20 + (widget.chainLevel * 8);
    
    // Rainbow colors for high chains, themed colors for lower
    final colors = widget.chainLevel >= 4
        ? [
            const Color(0xFFFF0000),
            const Color(0xFFFF7F00),
            const Color(0xFFFFFF00),
            const Color(0xFF00FF00),
            const Color(0xFF00BFFF),
            const Color(0xFF9400D3),
          ]
        : [
            const Color(0xFFFFD700),
            const Color(0xFFFFA500),
            const Color(0xFFFF8C00),
          ];

    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * pi + _random.nextDouble() * 0.3;
      final speed = 2.0 + _random.nextDouble() * (3.0 + widget.chainLevel);
      
      _particles.add(_ChainParticle(
        position: widget.center,
        velocity: Offset(cos(angle) * speed, sin(angle) * speed),
        color: colors[_random.nextInt(colors.length)],
        size: 3.0 + _random.nextDouble() * 4.0,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.2,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _controller.value;
    
    // Update particles
    for (final particle in _particles) {
      particle.update(progress);
    }

    return CustomPaint(
      painter: _ChainParticlePainter(
        particles: _particles,
        progress: progress,
      ),
      size: Size.infinite,
    );
  }
}

class _ChainParticle {
  Offset position;
  final Offset velocity;
  final Color color;
  final double size;
  final double rotationSpeed;
  double rotation = 0;

  _ChainParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.rotationSpeed,
  });

  void update(double progress) {
    // Apply velocity with gravity
    position = position + velocity;
    position = Offset(position.dx, position.dy + progress * 2);
    rotation += rotationSpeed;
  }
}

class _ChainParticlePainter extends CustomPainter {
  final List<_ChainParticle> particles;
  final double progress;

  _ChainParticlePainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final scale = 1.0 - (progress * 0.5);
      
      final paint = Paint()
        ..color = particle.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(particle.position.dx, particle.position.dy);
      canvas.rotate(particle.rotation);
      
      // Draw star-shaped particle for high chains
      final path = Path();
      final outerRadius = particle.size * scale;
      final innerRadius = outerRadius * 0.4;
      
      for (int i = 0; i < 5; i++) {
        final outerAngle = (i * 72 - 90) * pi / 180;
        final innerAngle = ((i * 72) + 36 - 90) * pi / 180;
        
        if (i == 0) {
          path.moveTo(
            cos(outerAngle) * outerRadius,
            sin(outerAngle) * outerRadius,
          );
        } else {
          path.lineTo(
            cos(outerAngle) * outerRadius,
            sin(outerAngle) * outerRadius,
          );
        }
        path.lineTo(
          cos(innerAngle) * innerRadius,
          sin(innerAngle) * innerRadius,
        );
      }
      path.close();
      
      // Glow
      final glowPaint = Paint()
        ..color = particle.color.withValues(alpha: opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(path, glowPaint);
      
      // Solid
      canvas.drawPath(path, paint);
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ChainParticlePainter oldDelegate) => true;
}

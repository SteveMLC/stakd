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

  /// Warehouse-vocab chain labels — replaces generic "MEGA CHAIN!!!"
  /// progression with manifest/dispatch language that escalates as a
  /// dock-floor alarm would. "CASCADE" reads like a chain of shipments
  /// firing in sequence; "BACKLOG BLITZ" + "RUSH HOUR" signal the
  /// warehouse is operating at peak load.
  String _getChainText() {
    switch (widget.chainLevel) {
      case 2:
        return 'CASCADE x2';
      case 3:
        return 'RAPID FIRE x3';
      case 4:
        return 'BACKLOG BLITZ x4';
      default:
        if (widget.chainLevel >= 5) {
          return 'RUSH HOUR x${widget.chainLevel}';
        }
        return 'CASCADE x${widget.chainLevel}';
    }
  }

  /// Warehouse palette escalation — anchors every chain level to the
  /// safety-yellow accent + steel + amber dispatch alert vocabulary
  /// rather than the prior gold→orange→red→rainbow trajectory. Higher
  /// chains read as "dock-floor emergency alert" intensity rather than
  /// generic "rainbow celebration."
  List<Color> _getGradientColors() {
    switch (widget.chainLevel) {
      case 2:
        return [
          GameColors.accent,             // safety yellow
          const Color(0xFFFFA000),       // amber
        ];
      case 3:
        return [
          GameColors.accent,
          const Color(0xFFFF6F00),       // deeper amber
        ];
      case 4:
        return [
          const Color(0xFFFF6F00),
          const Color(0xFFE53935),       // dispatch alert red
        ];
      default:
        if (widget.chainLevel >= 5) {
          // Full alert: safety yellow → red → yellow strobe band
          return [
            GameColors.accent,
            const Color(0xFFE53935),
            GameColors.accent,
            const Color(0xFFE53935),
          ];
        }
        return [GameColors.accent, GameColors.accent];
    }
  }

  Color _getGlowColor() {
    switch (widget.chainLevel) {
      case 2:
        return GameColors.accent;
      case 3:
        return const Color(0xFFFF8C00);
      case 4:
        return const Color(0xFFE53935);
      default:
        if (widget.chainLevel >= 5) {
          // Alternates accent ↔ red on the strobe pulse via
          // _glowController.value (which is already pulsing for L3+).
          return GameColors.accent;
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
                    // Brushed-steel 3-stop gradient anchors the popup
                    // to the warehouse panel vocabulary (same gradient
                    // used in HUD, settings rows, leaderboard rows).
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF3A4250),
                        Color(0xFF1A1F26),
                        Color(0xFF14181E),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _getGlowColor().withValues(alpha: glowIntensity),
                      width: widget.chainLevel >= 4 ? 2.5 : 2.0,
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
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Tiny corner rivets — sells "stamped metal plate"
                      // vocabulary. Two on the top corners only so the
                      // popup reads as a wall-mounted dispatch notice.
                      Positioned(
                        top: -1,
                        left: -1,
                        child: _ChainRivet(color: _getGlowColor()),
                      ),
                      Positioned(
                        top: -1,
                        right: -1,
                        child: _ChainRivet(color: _getGlowColor()),
                      ),
                      // Foreground text — Courier monospace stencil,
                      // gradient-masked via ShaderMask for the accent
                      // → amber → red escalation.
                      ShaderMask(
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
                            letterSpacing: 2.4,
                            fontFamily: 'Courier',
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 5,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

/// Tiny corner rivet — a small darker circle with a highlight pip,
/// sells the "metal plate" vocabulary on the chain popup corners.
class _ChainRivet extends StatelessWidget {
  final Color color;
  const _ChainRivet({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF6A7280), Color(0xFF14181E)],
          center: Alignment(-0.4, -0.5),
          radius: 1.2,
        ),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 0.5),
      ),
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

    // Warehouse palette progression — replaces the prior generic
    // rainbow/gold/orange/red sparkles. Low chains spark off in
    // accent yellow + brushed steel (dock confetti); high chains add
    // a dispatch-alert red into the mix so the burst reads as a
    // warehouse-floor emergency strobe rather than a celebration arc.
    final colors = widget.chainLevel >= 4
        ? const [
            GameColors.accent,             // safety yellow
            Color(0xFFFF6F00),             // deep amber
            Color(0xFFE53935),             // dispatch alert red
            Color(0xFFB0BEC5),             // brushed steel highlight
          ]
        : const [
            GameColors.accent,
            Color(0xFFFFA000),
            Color(0xFF8B95A1),             // dock concrete grey
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

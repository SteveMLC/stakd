import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/garden_service.dart';
import '../../services/zen_audio_service.dart';

/// Animation types for garden element reveals
enum GardenRevealType {
  fadeScale,      // Simple fade + scale up
  growUp,         // Grows from ground upward
  bloomOut,       // Blooms outward from center
  rippleIn,       // Ripples in like water
}

/// A garden element that animates when revealed for the first time
class GardenElement extends StatefulWidget {
  final String elementId;
  final Widget child;
  final Duration revealDuration;
  final Curve revealCurve;
  final GardenRevealType revealType;
  final bool showParticles;

  const GardenElement({
    super.key,
    required this.elementId,
    required this.child,
    this.revealDuration = const Duration(milliseconds: 1500),
    this.revealCurve = Curves.easeOutBack,
    this.revealType = GardenRevealType.fadeScale,
    this.showParticles = true,
  });

  @override
  State<GardenElement> createState() => _GardenElementState();
}

class _GardenElementState extends State<GardenElement>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _glowAnimation;
  
  bool _hasBeenRevealed = false;
  bool _isUnlocked = false;
  bool _showingParticles = false;
  bool _showingGlow = false;
  List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: widget.revealDuration,
      vsync: this,
    );

    _setupAnimations();
    _checkRevealState();
  }

  void _setupAnimations() {
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 1.0, curve: widget.revealCurve),
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // Glow animation - pulses then fades
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 0.9), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 0.0), weight: 50),
    ]).animate(_controller);
  }

  Future<void> _checkRevealState() async {
    _isUnlocked = GardenService.isUnlocked(widget.elementId);
    
    if (!_isUnlocked) {
      // Not unlocked yet, stay hidden
      return;
    }

    // Check if we've revealed this before
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // Guard after async gap
    
    final key = 'garden_revealed_${widget.elementId}';
    _hasBeenRevealed = prefs.getBool(key) ?? false;

    if (_hasBeenRevealed) {
      // Already revealed, show immediately
      if (mounted) _controller.value = 1.0;
    } else {
      // First time reveal - animate!
      if (mounted) _triggerReveal();
      await prefs.setBool(key, true);
      if (!mounted) return; // Guard after second async gap
    }

    if (mounted) setState(() {});
  }

  void _triggerReveal() {
    // Play sound
    ZenAudioService().playBloom();
    
    // Start particles
    if (widget.showParticles) {
      _spawnParticles();
    }
    
    // Enable glow effect
    _showingGlow = true;
    
    // Play animation
    _controller.forward().then((_) {
      if (mounted) {
        setState(() => _showingGlow = false);
      }
    });
  }

  void _spawnParticles() {
    final rng = math.Random();
    _particles = List.generate(8, (i) {
      return _Particle(
        angle: (i / 8) * 2 * math.pi + rng.nextDouble() * 0.5,
        speed: 40 + rng.nextDouble() * 30,
        size: 4 + rng.nextDouble() * 4,
        color: [
          const Color(0xFFFFD700), // Gold
          const Color(0xFFFFFFFF), // White
          const Color(0xFFFFF9C4), // Light yellow
        ][rng.nextInt(3)],
      );
    });
    _showingParticles = true;
    
    // Remove particles after animation
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _showingParticles = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        Widget result;

        switch (widget.revealType) {
          case GardenRevealType.fadeScale:
            result = Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
            break;

          case GardenRevealType.growUp:
            result = Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              ),
            );
            break;

          case GardenRevealType.bloomOut:
            result = Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
            break;

          case GardenRevealType.rippleIn:
            final wobble = math.sin(_controller.value * math.pi * 3) * 
                          (1 - _controller.value) * 0.1;
            result = Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value + wobble,
                child: child,
              ),
            );
            break;
        }

        // Add glow effect for newly revealed elements
        if (_showingGlow) {
          result = Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: _glowAnimation.value * 0.6),
                  blurRadius: 20 * _glowAnimation.value,
                  spreadRadius: 8 * _glowAnimation.value,
                ),
                BoxShadow(
                  color: const Color(0xFFFFFFFF).withValues(alpha: _glowAnimation.value * 0.3),
                  blurRadius: 10 * _glowAnimation.value,
                  spreadRadius: 2 * _glowAnimation.value,
                ),
              ],
            ),
            child: result,
          );
        }

        // Add particles overlay
        if (_showingParticles) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              result,
              ..._buildParticles(),
            ],
          );
        }

        return result;
      },
      child: widget.child,
    );
  }

  List<Widget> _buildParticles() {
    final progress = _controller.value;
    
    return _particles.map((p) {
      final distance = p.speed * progress;
      final x = math.cos(p.angle) * distance;
      final y = math.sin(p.angle) * distance - 20; // Bias upward
      final opacity = (1 - progress).clamp(0.0, 1.0);
      
      return Positioned(
        left: x - p.size / 2,
        top: y - p.size / 2,
        child: Container(
          width: p.size,
          height: p.size,
          decoration: BoxDecoration(
            color: p.color.withOpacity(opacity),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: p.color.withOpacity(opacity * 0.5),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;

  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });
}

/// A reveal animation specifically for trees that grow from sapling to full
class GrowingTree extends StatefulWidget {
  final Widget saplingChild;
  final Widget youngChild;
  final Widget fullChild;
  final int currentStage; // 3 = sapling, 4 = young, 5+ = full

  const GrowingTree({
    super.key,
    required this.saplingChild,
    required this.youngChild,
    required this.fullChild,
    required this.currentStage,
  });

  @override
  State<GrowingTree> createState() => _GrowingTreeState();
}

class _GrowingTreeState extends State<GrowingTree> {
  @override
  Widget build(BuildContext context) {
    final targetChild = widget.currentStage <= 3
        ? widget.saplingChild
        : widget.currentStage == 4
            ? widget.youngChild
            : widget.fullChild;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1500),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(widget.currentStage),
        child: targetChild,
      ),
    );
  }
}

/// Animated water fill for pond
class PondFillAnimation extends StatefulWidget {
  final bool isFull;
  final Widget emptyPond;
  final Widget fullPond;

  const PondFillAnimation({
    super.key,
    required this.isFull,
    required this.emptyPond,
    required this.fullPond,
  });

  @override
  State<PondFillAnimation> createState() => _PondFillAnimationState();
}

class _PondFillAnimationState extends State<PondFillAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _wasFull = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    
    if (widget.isFull) {
      _controller.value = 1.0;
      _wasFull = true;
    }
  }

  @override
  void didUpdateWidget(PondFillAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isFull && !_wasFull) {
      // Just unlocked - animate!
      ZenAudioService().playWaterDrop();
      _controller.forward();
      _wasFull = true;
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
        if (_controller.value < 0.1) {
          return widget.emptyPond;
        }
        
        return Stack(
          children: [
            // Show full pond with opacity based on fill level
            Opacity(
              opacity: _controller.value,
              child: widget.fullPond,
            ),
            // Ripple effect during fill
            if (_controller.value > 0 && _controller.value < 1)
              Positioned.fill(
                child: CustomPaint(
                  painter: _RipplePainter(progress: _controller.value),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;

  _RipplePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    
    for (int i = 0; i < 3; i++) {
      final rippleProgress = ((progress * 3) - i).clamp(0.0, 1.0);
      if (rippleProgress <= 0 || rippleProgress >= 1) continue;
      
      final radius = maxRadius * rippleProgress;
      final opacity = (1 - rippleProgress) * 0.3;
      
      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

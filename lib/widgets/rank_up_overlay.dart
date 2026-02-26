import 'package:flutter/material.dart';
import 'dart:math' as math;

class RankUpOverlay extends StatefulWidget {
  final int newRank;
  final String newTitle;
  final String tierEmoji;
  final String tier;
  final VoidCallback onDismiss;

  const RankUpOverlay({
    super.key,
    required this.newRank,
    required this.newTitle,
    required this.tierEmoji,
    required this.tier,
    required this.onDismiss,
  });

  @override
  State<RankUpOverlay> createState() => _RankUpOverlayState();
}

class _RankUpOverlayState extends State<RankUpOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _tierColor {
    if (widget.newRank <= 5) return const Color(0xFF4CAF50);
    if (widget.newRank <= 10) return const Color(0xFF2FB9B3);
    if (widget.newRank <= 15) return const Color(0xFFE91E63);
    if (widget.newRank <= 20) return const Color(0xFFFF8F00);
    return const Color(0xFF7C4DFF);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: Material(
        color: Colors.black54,
        child: Stack(
          children: [
            // Confetti particles
            ...List.generate(30, (index) {
              return _ConfettiParticle(
                animation: _controller,
                index: index,
              );
            }),
            // Central card
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // "RANK UP!" title
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ).createShader(bounds),
                          child: const Text(
                            'RANK UP!',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  color: Color(0xFFFFD700),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Rank badge
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _tierColor,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _tierColor.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.tierEmoji,
                                style: const TextStyle(fontSize: 48),
                              ),
                              Text(
                                '${widget.newRank}',
                                style: TextStyle(
                                  color: _tierColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Title
                        Text(
                          widget.newTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Tier
                        Text(
                          '${widget.tier} ${widget.tierEmoji}',
                          style: TextStyle(
                            color: _tierColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Continue button
                        ElevatedButton(
                          onPressed: widget.onDismiss,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700),
                            foregroundColor: const Color(0xFF0F1622),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiParticle extends StatelessWidget {
  final Animation<double> animation;
  final int index;

  const _ConfettiParticle({
    required this.animation,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final random = math.Random(index);
    final startX = random.nextDouble();
    final endY = random.nextDouble() * 0.6 + 0.4;
    final rotation = random.nextDouble() * 2 * math.pi;
    final color = [
      Colors.red,
      Colors.blue,
      Colors.yellow,
      Colors.green,
      Colors.purple,
      Colors.orange,
    ][random.nextInt(6)];

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final screenSize = MediaQuery.of(context).size;
        return Positioned(
          left: screenSize.width * startX,
          top: screenSize.height * (1 - animation.value * endY),
          child: Transform.rotate(
            angle: rotation * animation.value,
            child: Opacity(
              opacity: 1 - animation.value * 0.5,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

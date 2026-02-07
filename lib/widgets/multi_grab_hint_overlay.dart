import 'package:flutter/material.dart';
import '../utils/constants.dart';

class MultiGrabHintOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const MultiGrabHintOverlay({super.key, required this.onDismiss});

  @override
  State<MultiGrabHintOverlay> createState() => _MultiGrabHintOverlayState();
}

class _MultiGrabHintOverlayState extends State<MultiGrabHintOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: widget.onDismiss,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black.withValues(alpha: 0.7),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: GameColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: GameColors.accent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      final ringSize = 72 + (16 * _pulse.value);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: ringSize,
                            height: ringSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: GameColors.accent.withValues(
                                  alpha: 0.2 + 0.6 * (1 - _pulse.value),
                                ),
                                width: 3,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.touch_app,
                            size: 46,
                            color: GameColors.accent,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pro tip',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: GameColors.accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Long press to grab multiple\nmatching layers at once.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: GameColors.text,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Faster solving, fewer moves',
                    style: TextStyle(
                      fontSize: 13,
                      color: GameColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: widget.onDismiss,
                    child: const Text('Got it'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

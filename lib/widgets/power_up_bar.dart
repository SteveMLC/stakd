import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/power_up_service.dart';
import '../utils/constants.dart';

/// Horizontal bar displaying power-up buttons
class PowerUpBar extends StatelessWidget {
  final VoidCallback? onColorBomb;
  final VoidCallback? onShuffle;
  final VoidCallback? onMagnet;
  final VoidCallback? onHint;
  final bool isSelectionMode;
  final PowerUpType? activeSelection;

  const PowerUpBar({
    super.key,
    this.onColorBomb,
    this.onShuffle,
    this.onMagnet,
    this.onHint,
    this.isSelectionMode = false,
    this.activeSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PowerUpService>(
      builder: (context, powerUpService, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PowerUpButton(
                type: PowerUpType.colorBomb,
                count: powerUpService.getCount(PowerUpType.colorBomb),
                onTap: onColorBomb,
                isActive: activeSelection == PowerUpType.colorBomb,
                isSelectionMode: isSelectionMode,
              ),
              _PowerUpButton(
                type: PowerUpType.shuffle,
                count: powerUpService.getCount(PowerUpType.shuffle),
                onTap: onShuffle,
                isActive: activeSelection == PowerUpType.shuffle,
                isSelectionMode: isSelectionMode,
              ),
              _PowerUpButton(
                type: PowerUpType.magnet,
                count: powerUpService.getCount(PowerUpType.magnet),
                onTap: onMagnet,
                isActive: activeSelection == PowerUpType.magnet,
                isSelectionMode: isSelectionMode,
              ),
              _PowerUpButton(
                type: PowerUpType.hint,
                count: powerUpService.getCount(PowerUpType.hint),
                onTap: onHint,
                isActive: activeSelection == PowerUpType.hint,
                isSelectionMode: isSelectionMode,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Individual power-up button with icon, count, and animation
class _PowerUpButton extends StatefulWidget {
  final PowerUpType type;
  final int count;
  final VoidCallback? onTap;
  final bool isActive;
  final bool isSelectionMode;

  const _PowerUpButton({
    required this.type,
    required this.count,
    this.onTap,
    this.isActive = false,
    this.isSelectionMode = false,
  });

  @override
  State<_PowerUpButton> createState() => _PowerUpButtonState();
}

class _PowerUpButtonState extends State<_PowerUpButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_PowerUpButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.count <= 0;
    final isClickable = !isDisabled && !widget.isSelectionMode;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isActive ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: isClickable ? widget.onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isDisabled
                    ? GameColors.surface.withValues(alpha: 0.5)
                    : widget.isActive
                        ? GameColors.accent.withValues(alpha: 0.3)
                        : GameColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isActive
                      ? GameColors.accent
                      : isDisabled
                          ? Colors.transparent
                          : GameColors.textMuted.withValues(alpha: 0.3),
                  width: widget.isActive ? 2 : 1,
                ),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: GameColors.accent.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Icon
                  Center(
                    child: Text(
                      widget.type.icon,
                      style: TextStyle(
                        fontSize: 28,
                        color: isDisabled
                            ? Colors.white.withValues(alpha: 0.3)
                            : null,
                      ),
                    ),
                  ),

                  // Count badge
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDisabled
                            ? GameColors.textMuted
                            : GameColors.accent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${widget.count}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Selection mode overlay for Color Bomb
class ColorBombSelectionOverlay extends StatelessWidget {
  final VoidCallback onCancel;
  final String message;

  const ColorBombSelectionOverlay({
    super.key,
    required this.onCancel,
    this.message = 'Tap a block to select its color',
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: GameColors.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: GameColors.accent.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: GameColors.accent.withValues(alpha: 0.3),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💣', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Text(
                message,
                style: const TextStyle(
                  color: GameColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.red,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selection mode overlay for Magnet
class MagnetSelectionOverlay extends StatelessWidget {
  final VoidCallback onCancel;
  final String message;

  const MagnetSelectionOverlay({
    super.key,
    required this.onCancel,
    this.message = 'Tap a highlighted stack to complete it',
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: GameColors.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: GameColors.zen.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: GameColors.zen.withValues(alpha: 0.3),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🧲', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Text(
                message,
                style: const TextStyle(
                  color: GameColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.red,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

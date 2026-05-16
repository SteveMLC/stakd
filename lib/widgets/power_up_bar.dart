import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/power_up_service.dart';
import '../services/ad_service.dart';
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
    final isClickable = !widget.isSelectionMode;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isActive ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: isClickable
                ? () {
                    if (isDisabled) {
                      _showGetPowerUpDialog(context);
                    } else {
                      widget.onTap?.call();
                    }
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              height: 96,
              decoration: BoxDecoration(
                // 2026-05-15 (Lovart loading-dock reference): power-up
                // pill is now a neon-ring circle rather than a
                // brushed-steel rounded square. Per-type ring colour
                // (cyan/magenta/red/amber) gives each power-up its own
                // visual signature; player learns "the cyan one is
                // re-route" much faster than scanning 4 grey buttons.
                shape: BoxShape.rectangle,
                color: const Color(0xFF0B0E16),
                gradient: isDisabled
                    ? null
                    : RadialGradient(
                        center: Alignment.center,
                        radius: 0.85,
                        colors: [
                          Color(widget.type.neonHex).withValues(
                            alpha: widget.isActive ? 0.45 : 0.18,
                          ),
                          const Color(0xFF0B0E16),
                        ],
                        stops: const [0.0, 1.0],
                      ),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: isDisabled
                      ? const Color(0xFF2A3140)
                      : Color(widget.type.neonHex).withValues(
                          alpha: widget.isActive ? 0.95 : 0.75,
                        ),
                  width: widget.isActive ? 2.5 : 1.8,
                ),
                boxShadow: isDisabled
                    ? null
                    : widget.isActive
                        ? [
                            BoxShadow(
                              color: Color(widget.type.neonHex).withValues(
                                alpha: 0.65,
                              ),
                              blurRadius: 18,
                              spreadRadius: 3,
                            ),
                          ]
                        : [
                            // Soft outer neon halo so each power-up
                            // pill carries its own glow off the dark
                            // background, matching the reference's
                            // arcade-cabinet aesthetic.
                            BoxShadow(
                              color: Color(widget.type.neonHex).withValues(
                                alpha: 0.32,
                              ),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Icon + text label column — addresses Steve audit:
                  // "Player can't tell color bomb from forklift from
                  // shuffle from hint. Just icon + count badge."
                  // Compact 9pt amber caps label nests under the icon
                  // so the button is self-labelling without tooltip.
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Opacity(
                            opacity: isDisabled ? 0.32 : 1.0,
                            child: Image.asset(
                              widget.type.iconAsset,
                              width: 48,
                              height: 48,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.type.shortLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              height: 1.0,
                              color: isDisabled
                                  ? GameColors.textMuted
                                  : Color(widget.type.neonHex).withValues(
                                      alpha: 0.95,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Count chip — subtle uses-remaining pill, NOT a
                  // red alert badge. Was a screaming red gradient w/
                  // white border + drop shadow at top-right that
                  // read as a notification dot ("ERROR ERROR ERROR"
                  // per Winnie's audit). Now a small dark amber pill
                  // tucked at the bottom-right so the eye lands on
                  // the icon first, count is supplementary info.
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isDisabled
                            ? Colors.black.withValues(alpha: 0.55)
                            : Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDisabled
                              ? GameColors.textMuted.withValues(alpha: 0.35)
                              : GameColors.accent.withValues(alpha: 0.55),
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.count}',
                          style: TextStyle(
                            color: isDisabled
                                ? GameColors.textMuted
                                : GameColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
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

  void _showGetPowerUpDialog(BuildContext context) {
    final name = widget.type.name;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GameColors.surface,
        title: Text('Get ${widget.type.icon} $name',
            style: const TextStyle(color: GameColors.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Watch ad option
            ListTile(
              leading: const Icon(Icons.ondemand_video, color: GameColors.accent),
              title: const Text('Watch ad for free',
                  style: TextStyle(color: GameColors.text)),
              onTap: () async {
                Navigator.pop(ctx);
                final rewarded = await AdService().showRewardedAd();
                if (rewarded) {
                  await PowerUpService().addPowerUp(widget.type, 1);
                }
              },
            ),
            const Divider(color: GameColors.textMuted),
            // Buy with coins option
            ListTile(
              leading: const Icon(Icons.monetization_on,
                  color: Color(0xFFFFD700)),
              title: const Text('Buy for 50 coins',
                  style: TextStyle(color: GameColors.text)),
              onTap: () async {
                Navigator.pop(ctx);
                final success =
                    await PowerUpService().buyPowerUp(widget.type);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Not enough coins!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: GameColors.textMuted)),
          ),
        ],
      ),
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
              color: GameColors.tealAccent.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: GameColors.tealAccent.withValues(alpha: 0.3),
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

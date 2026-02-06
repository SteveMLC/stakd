import 'package:flutter/material.dart';
import '../services/tutorial_service.dart';
import '../utils/constants.dart';

/// Tutorial overlay with spotlight effect and tooltips
class TutorialOverlay extends StatefulWidget {
  final TutorialService tutorialService;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const TutorialOverlay({
    super.key,
    required this.tutorialService,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    // Listen for tutorial completion
    widget.tutorialService.addListener(_onTutorialChange);
  }

  void _onTutorialChange() {
    if (!widget.tutorialService.isActive) {
      _fadeController.reverse().then((_) {
        widget.onComplete();
      });
    }
  }

  @override
  void dispose() {
    widget.tutorialService.removeListener(_onTutorialChange);
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.tutorialService,
      builder: (context, child) {
        final stepData = widget.tutorialService.currentStepData;
        final targetKey = widget.tutorialService.targetKey;

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            children: [
              // Dark overlay with spotlight cutout
              _buildSpotlightOverlay(targetKey),
              
              // Tooltip
              if (targetKey != null)
                _buildTooltip(stepData, targetKey)
              else
                _buildCenterMessage(stepData),
              
              // Skip button in top right
              Positioned(
                top: 60,
                right: 16,
                child: _buildSkipButton(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpotlightOverlay(GlobalKey? targetKey) {
    return CustomPaint(
      painter: _SpotlightPainter(
        targetKey: targetKey,
        animation: _fadeAnimation,
      ),
      child: Container(),
    );
  }

  Widget _buildTooltip(TutorialStepData stepData, GlobalKey targetKey) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) {
          return _buildCenterMessage(stepData);
        }

        final targetPosition = renderBox.localToGlobal(Offset.zero);
        final targetSize = renderBox.size;
        
        // Position tooltip above or below target
        final isBottomHalf = targetPosition.dy > constraints.maxHeight / 2;
        final tooltipY = isBottomHalf
            ? targetPosition.dy - 120 // Above
            : targetPosition.dy + targetSize.height + 20; // Below

        return Positioned(
          left: 0,
          right: 0,
          top: tooltipY,
          child: _buildTooltipContent(stepData, isBottomHalf),
        );
      },
    );
  }

  Widget _buildTooltipContent(TutorialStepData stepData, bool arrowDown) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!arrowDown) _buildArrow(true),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: GameColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: GameColors.accent.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (stepData.icon != null) ...[
                Icon(
                  stepData.icon,
                  color: GameColors.accent,
                  size: 28,
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Text(
                  stepData.message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: GameColors.text,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        if (arrowDown) _buildArrow(false),
      ],
    );
  }

  Widget _buildArrow(bool pointingDown) {
    return CustomPaint(
      size: const Size(20, 10),
      painter: _ArrowPainter(
        color: GameColors.surface,
        borderColor: GameColors.accent.withValues(alpha: 0.5),
        pointingDown: pointingDown,
      ),
    );
  }

  Widget _buildCenterMessage(TutorialStepData stepData) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: GameColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: GameColors.accent.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (stepData.icon != null) ...[
              Icon(
                stepData.icon,
                color: GameColors.accent,
                size: 48,
              ),
              const SizedBox(height: 16),
            ],
            Text(
              stepData.message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: GameColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            if (stepData.step == TutorialStep.complete) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: widget.onComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Let\'s Play!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return TextButton(
      onPressed: widget.onSkip,
      style: TextButton.styleFrom(
        backgroundColor: GameColors.surface.withValues(alpha: 0.8),
        foregroundColor: GameColors.textMuted,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Skip Tutorial',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(width: 4),
          Icon(Icons.close, size: 16),
        ],
      ),
    );
  }
}

/// Custom painter for spotlight overlay
class _SpotlightPainter extends CustomPainter {
  final GlobalKey? targetKey;
  final Animation<double> animation;

  _SpotlightPainter({
    required this.targetKey,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.85 * animation.value);

    if (targetKey == null || targetKey!.currentContext == null) {
      // Just draw dark overlay
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    final renderBox = targetKey!.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    final targetPosition = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;

    // Create spotlight cutout with rounded corners
    final spotlightRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        targetPosition.dx - 8,
        targetPosition.dy - 8,
        targetSize.width + 16,
        targetSize.height + 16,
      ),
      const Radius.circular(12),
    );

    // Draw overlay with cutout
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(spotlightRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw spotlight glow
    final glowPaint = Paint()
      ..color = GameColors.accent.withValues(alpha: 0.3 * animation.value)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawRRect(spotlightRect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetKey != targetKey;
  }
}

/// Custom painter for tooltip arrow
class _ArrowPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final bool pointingDown;

  _ArrowPainter({
    required this.color,
    required this.borderColor,
    required this.pointingDown,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    
    if (pointingDown) {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    }
    
    path.close();

    // Fill
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

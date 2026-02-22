import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../services/achievement_service.dart';
import 'achievement_toast_card.dart';

/// Mixin that listens to AchievementService and shows toast overlays
/// when achievements are unlocked.
mixin AchievementToastMixin<T extends StatefulWidget> on State<T> {
  final AchievementService _achievementService = AchievementService();

  @override
  void initState() {
    super.initState();
    _achievementService.addListener(_onAchievementChange);
  }

  @override
  void dispose() {
    _achievementService.removeListener(_onAchievementChange);
    super.dispose();
  }

  void _onAchievementChange() {
    if (!mounted) return;
    final pending = _achievementService.pendingToasts;
    if (pending.isEmpty) return;

    // Show each pending toast
    for (final achievement in List<Achievement>.from(pending)) {
      _showAchievementToast(achievement);
      _achievementService.dismissToast(achievement);
    }
  }

  void _showAchievementToast(Achievement achievement) {
    if (!mounted) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AchievementToastAnimation(
        achievement: achievement,
        onDismiss: () => entry.remove(),
      ),
    );

    Overlay.of(context).insert(entry);
  }
}

class _AchievementToastAnimation extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onDismiss;

  const _AchievementToastAnimation({
    required this.achievement,
    required this.onDismiss,
  });

  @override
  State<_AchievementToastAnimation> createState() =>
      _AchievementToastAnimationState();
}

class _AchievementToastAnimationState
    extends State<_AchievementToastAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // Auto-dismiss after 3.5 seconds
    Future.delayed(const Duration(milliseconds: 3500), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: AchievementToastCard(
              achievement: widget.achievement,
              onTap: _dismiss,
            ),
          ),
        ),
      ),
    );
  }
}

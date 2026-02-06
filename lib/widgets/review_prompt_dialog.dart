import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import '../services/review_service.dart';

/// Review prompt dialog shown when trigger conditions are met
class ReviewPromptDialog extends StatefulWidget {
  const ReviewPromptDialog({super.key});

  @override
  State<ReviewPromptDialog> createState() => _ReviewPromptDialogState();

  /// Show the review prompt dialog
  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (context) => const ReviewPromptDialog(),
    );
  }
}

class _ReviewPromptDialogState extends State<ReviewPromptDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  static const String _storeUrl =
      'https://play.google.com/store/apps/details?id=com.go7studio.stakd';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleYes() async {
    final reviewService = ReviewService();
    await reviewService.markReviewed();

    // Try to open Play Store
    final uri = Uri.parse(_storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleNo() async {
    final reviewService = ReviewService();
    await reviewService.markReviewPromptShown(); // Start cooldown

    if (mounted) {
      Navigator.of(context).pop();

      // Show brief thank you message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks for the feedback!'),
          duration: Duration(seconds: 2),
          backgroundColor: GameColors.surface,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: GameColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: GameColors.accent.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: GameColors.accent.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emoji
                const Text('😊', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),

                // Title
                const Text(
                  'Enjoying Stakd?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: GameColors.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                const Text(
                  'Your feedback helps us improve!',
                  style: TextStyle(fontSize: 14, color: GameColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Yes button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleYes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameColors.accent,
                      foregroundColor: GameColors.text,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Yes! ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text('💚', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // No button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _handleNo,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GameColors.textMuted,
                      side: BorderSide(
                        color: GameColors.textMuted.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Not really ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text('😕', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class ScoreBreakdown extends StatefulWidget {
  final int totalScore;
  final int xpEarned;
  final int coinsEarned;
  final double difficultyMultiplier;
  final double starMultiplier;
  final double moveEfficiency;
  final double timeEfficiency;
  final double bonusMultiplier;
  final int flatBonus;
  final int baseScore;

  const ScoreBreakdown({
    super.key,
    required this.totalScore,
    required this.xpEarned,
    required this.coinsEarned,
    required this.difficultyMultiplier,
    required this.starMultiplier,
    required this.moveEfficiency,
    required this.timeEfficiency,
    required this.bonusMultiplier,
    required this.flatBonus,
    required this.baseScore,
  });

  @override
  State<ScoreBreakdown> createState() => _ScoreBreakdownState();
}

class _ScoreBreakdownState extends State<ScoreBreakdown>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _lineAnimations;
  late Animation<int> _scoreCountAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Create staggered animations for each line
    final lineCount = _getLineCount();
    _lineAnimations = List.generate(lineCount, (index) {
      final begin = index * 0.1;
      final end = begin + 0.2;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            begin.clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      );
    });

    // Score count-up animation
    _scoreCountAnimation = IntTween(begin: 0, end: widget.totalScore).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _getLineCount() {
    int count = 1; // Base score
    if (widget.difficultyMultiplier != 1.0) count++;
    if (widget.starMultiplier != 1.0) count++;
    if (widget.moveEfficiency != 1.0) count++;
    if (widget.timeEfficiency != 1.0) count++;
    if (widget.bonusMultiplier != 0.0) count++;
    if (widget.flatBonus != 0) count++;
    return count + 1; // +1 for total line
  }

  @override
  Widget build(BuildContext context) {
    int lineIndex = 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2FB9B3).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Base score
          _buildLine(
            'Base Score',
            widget.baseScore.toString(),
            _lineAnimations[lineIndex++],
            const Color(0xFFFFD700),
          ),
          // Difficulty
          if (widget.difficultyMultiplier != 1.0)
            _buildLine(
              'Difficulty',
              '×${widget.difficultyMultiplier.toStringAsFixed(1)}',
              _lineAnimations[lineIndex++],
              const Color(0xFFFFD700),
            ),
          // Stars
          if (widget.starMultiplier != 1.0)
            _buildLine(
              'Stars',
              '×${widget.starMultiplier.toStringAsFixed(1)}',
              _lineAnimations[lineIndex++],
              const Color(0xFFFFD700),
            ),
          // Move efficiency
          if (widget.moveEfficiency != 1.0)
            _buildLine(
              'Move Efficiency',
              '×${widget.moveEfficiency.toStringAsFixed(1)}',
              _lineAnimations[lineIndex++],
              const Color(0xFFFFD700),
            ),
          // Time efficiency
          if (widget.timeEfficiency != 1.0)
            _buildLine(
              'Time',
              '×${widget.timeEfficiency.toStringAsFixed(1)}',
              _lineAnimations[lineIndex++],
              const Color(0xFFFFD700),
            ),
          // Bonus multiplier
          if (widget.bonusMultiplier != 0.0)
            _buildLine(
              'Perfect Run',
              '+${(widget.bonusMultiplier * 100).toInt()}%',
              _lineAnimations[lineIndex++],
              const Color(0xFFFFD700),
            ),
          // Flat bonus
          if (widget.flatBonus != 0)
            _buildLine(
              'Bonus',
              '+${widget.flatBonus}',
              _lineAnimations[lineIndex++],
              const Color(0xFFFFD700),
            ),
          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              height: 1,
              color: Colors.white24,
            ),
          ),
          // Total score with count-up
          AnimatedBuilder(
            animation: _scoreCountAnimation,
            builder: (context, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL SCORE:',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ).createShader(bounds),
                      child: Text(
                        _scoreCountAnimation.value.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Rewards
          FadeTransition(
            opacity: _lineAnimations[lineIndex - 1],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildReward('💎', widget.coinsEarned, const Color(0xFF64B5F6)),
                const SizedBox(width: 24),
                _buildReward('⭐', widget.xpEarned, const Color(0xFF4CAF50)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLine(
    String label,
    String value,
    Animation<double> animation,
    Color color,
  ) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(animation),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReward(String emoji, int amount, Color color) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 4),
        Text(
          '+$amount',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

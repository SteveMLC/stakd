import 'package:flutter/material.dart';

class XPProgressBar extends StatefulWidget {
  final int currentXP;
  final int xpForCurrentRank;
  final int xpForNextRank;
  final int rank;
  final String rankTitle;
  final String nextRankTitle;

  const XPProgressBar({
    super.key,
    required this.currentXP,
    required this.xpForCurrentRank,
    required this.xpForNextRank,
    required this.rank,
    required this.rankTitle,
    required this.nextRankTitle,
  });

  @override
  State<XPProgressBar> createState() => _XPProgressBarState();
}

class _XPProgressBarState extends State<XPProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: _progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(XPProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentXP != widget.currentXP) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: _progress,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _progress {
    final xpInCurrentRank = widget.currentXP - widget.xpForCurrentRank;
    final xpNeeded = widget.xpForNextRank - widget.xpForCurrentRank;
    return (xpInCurrentRank / xpNeeded).clamp(0.0, 1.0);
  }

  Color get _tierColor {
    if (widget.rank <= 5) return const Color(0xFF4CAF50); // Seedling
    if (widget.rank <= 10) return const Color(0xFF2FB9B3); // Sprout
    if (widget.rank <= 15) return const Color(0xFFE91E63); // Blossom
    if (widget.rank <= 20) return const Color(0xFFFF8F00); // Ancient
    return const Color(0xFF7C4DFF); // Transcendent
  }

  @override
  Widget build(BuildContext context) {
    final xpInCurrentRank = widget.currentXP - widget.xpForCurrentRank;
    final xpNeeded = widget.xpForNextRank - widget.xpForCurrentRank;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress bar
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: _animation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _tierColor,
                              _tierColor.withValues(alpha: 0.7),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _tierColor.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        // XP text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.rankTitle,
              style: TextStyle(
                color: _tierColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$xpInCurrentRank / $xpNeeded XP',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Text(
          'Next: ${widget.nextRankTitle}',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

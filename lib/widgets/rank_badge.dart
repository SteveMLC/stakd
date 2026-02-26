import 'package:flutter/material.dart';

class RankBadge extends StatelessWidget {
  final int rank;
  final String tierEmoji;
  final String title;
  final double size;
  final bool showTitle;

  const RankBadge({
    super.key,
    required this.rank,
    required this.tierEmoji,
    required this.title,
    this.size = 40,
    this.showTitle = false,
  });

  Color get _tierColor {
    // Determine tier based on rank (1-5 per tier)
    if (rank <= 5) return const Color(0xFF4CAF50); // Seedling: green
    if (rank <= 10) return const Color(0xFF2FB9B3); // Sprout: teal
    if (rank <= 15) return const Color(0xFFE91E63); // Blossom: pink
    if (rank <= 20) return const Color(0xFFFF8F00); // Ancient: amber
    return const Color(0xFF7C4DFF); // Transcendent: purple
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _tierColor,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: _tierColor.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tierEmoji,
                style: TextStyle(fontSize: size * 0.4),
              ),
              Text(
                '$rank',
                style: TextStyle(
                  color: _tierColor,
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (showTitle) ...[
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

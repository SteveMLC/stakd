import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/garden_service.dart';
import '../services/audio_service.dart';

class ZenSessionSummary extends StatefulWidget {
  final int puzzlesSolved;
  final Duration sessionDuration;
  final int bestMoves;
  final String difficulty;
  final int totalStars;
  final int bestStreak;
  final VoidCallback onContinue;

  const ZenSessionSummary({
    super.key,
    required this.puzzlesSolved,
    required this.sessionDuration,
    required this.bestMoves,
    required this.difficulty,
    required this.totalStars,
    required this.bestStreak,
    required this.onContinue,
  });

  @override
  State<ZenSessionSummary> createState() => _ZenSessionSummaryState();
}

class _ZenSessionSummaryState extends State<ZenSessionSummary>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final gardenState = GardenService.state;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          color: GameColors.backgroundDark.withValues(alpha: 0.9 * _fadeAnimation.value),
          child: Center(
            child: Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: GameColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: GameColors.zen.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: GameColors.zen.withValues(alpha: 0.2),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        'Session Complete!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: GameColors.text,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Stats grid
                      _buildStatsGrid(),
                      
                      const SizedBox(height: 20),
                      
                      // Garden progress
                      _buildGardenProgress(gardenState),
                      
                      const SizedBox(height: 24),
                      
                      // Continue button
                      ElevatedButton(
                        onPressed: () {
                          AudioService().playTap();
                          widget.onContinue();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GameColors.zen,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: GameColors.backgroundDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GameColors.backgroundDark.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.spa_outlined,
                  value: widget.puzzlesSolved.toString(),
                  label: 'puzzles solved',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatItem(
                  icon: Icons.timer,
                  value: _formatDuration(widget.sessionDuration),
                  label: 'session time',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.emoji_events,
                  value: widget.bestMoves == 999999 ? '--' : '${widget.bestMoves}',
                  label: 'best (${widget.difficulty})',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatItem(
                  icon: Icons.local_fire_department,
                  value: '${widget.bestStreak}',
                  label: 'best streak',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGardenProgress(dynamic gardenState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GameColors.zen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: GameColors.zen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Text(gardenState.stageIcon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Garden: ${gardenState.stageName}',
                  style: TextStyle(
                    color: GameColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${gardenState.totalPuzzlesSolved} total puzzles',
                  style: TextStyle(
                    color: GameColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.trending_up,
            color: GameColors.zen,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: GameColors.zen.withValues(alpha: 0.8),
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: GameColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: GameColors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
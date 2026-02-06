import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/game_state.dart';
import '../services/audio_service.dart';
import '../services/level_generator.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/game_board.dart';
import '../widgets/game_button.dart';
import '../widgets/particles/confetti_overlay.dart';

/// Daily Challenge gameplay screen
class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  final LevelGenerator _levelGenerator = LevelGenerator();
  late DateTime _challengeDateUtc;
  late String _dateKey;
  bool _isCompletedToday = false;
  int _currentStreak = 0;
  bool _milestoneReached = false;
  bool _completionScheduled = false;

  @override
  void initState() {
    super.initState();
    _challengeDateUtc = DateTime.now().toUtc();
    _dateKey = _formatDateKey(_challengeDateUtc);
    _loadStatus();
    _loadLevel();
  }

  void _loadStatus() {
    final storage = StorageService();
    _isCompletedToday = storage.isDailyChallengeCompleted(_dateKey);
    _currentStreak = storage.getDailyChallengeStreak();
  }

  void _loadLevel() {
    final stacks = _levelGenerator.generateDailyChallenge(
      date: _challengeDateUtc,
    );
    context.read<GameState>().initGame(stacks, 0);
  }

  Future<void> _onDailyComplete() async {
    if (_isCompletedToday) return;

    final storage = StorageService();
    final previousStreak = storage.getDailyChallengeStreak();

    await storage.addMoves(context.read<GameState>().moveCount);
    final newStreak = await storage.markDailyChallengeCompleted(_dateKey);
    final milestone =
        _isStreakMilestone(newStreak) && newStreak > previousStreak;

    if (!mounted) return;
    setState(() {
      _isCompletedToday = true;
      _currentStreak = newStreak;
      _milestoneReached = milestone;
    });
  }

  void _restartChallenge() {
    _loadLevel();
  }

  void _onUndo() {
    final gameState = context.read<GameState>();
    if (gameState.canUndo) {
      AudioService().playTap();
      gameState.undo();
    }
  }

  void _onUndoWithAd() {
    // Daily challenge does not grant extra undos via ads yet.
  }

  void _shareResult(int moves) {
    final dateLabel = _formatDisplayDate(_challengeDateUtc);
    final text =
        'I completed the Stakd Daily Challenge for $dateLabel (UTC) in $moves moves! \u{1F525}';
    Share.share(text, subject: 'Stakd Daily Challenge');
  }

  void _goHome() {
    Navigator.of(context).pop({
      'completed': _isCompletedToday,
      'milestone': _milestoneReached,
      'streak': _currentStreak,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B1E3C), Color(0xFF2B1B47), Color(0xFF401B3A)],
          ),
        ),
        child: SafeArea(
          child: Consumer<GameState>(
            builder: (context, gameState, child) {
              if (gameState.isComplete && !_completionScheduled) {
                _completionScheduled = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _onDailyComplete();
                });
              }

              return Stack(
                children: [
                  Column(
                    children: [
                      _buildTopBar(gameState),
                      _buildDailyHeader(),
                      Expanded(
                        child: GameBoard(
                          gameState: gameState,
                          onTap: () => AudioService().playTap(),
                          onMove: () => AudioService().playSlide(),
                          onClear: () => AudioService().playClear(),
                        ),
                      ),
                      _buildBottomControls(gameState),
                      _buildLeaderboardPlaceholder(),
                    ],
                  ),
                  if (gameState.isComplete)
                    _buildCompletionOverlay(gameState.moveCount),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(GameState gameState) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GameIconButton(icon: Icons.arrow_back, onPressed: _goHome),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: GameColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.touch_app, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${gameState.moveCount}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyHeader() {
    final dateLabel = _formatDisplayDate(_challengeDateUtc);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              GameColors.accent.withValues(alpha: 0.9),
              GameColors.palette[1].withValues(alpha: 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: GameColors.accent.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.today, color: GameColors.text),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Challenge',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: GameColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dateLabel • UTC',
                    style: const TextStyle(
                      fontSize: 12,
                      color: GameColors.text,
                    ),
                  ),
                ],
              ),
            ),
            if (_isCompletedToday)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Completed!',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: GameColors.text,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(GameState gameState) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GameIconButton(icon: Icons.refresh, onPressed: _restartChallenge),
          const SizedBox(width: 16),
          GameIconButton(
            icon: Icons.undo,
            badge: gameState.undosRemaining > 0
                ? '${gameState.undosRemaining}'
                : null,
            isDisabled: !gameState.canUndo,
            onPressed: gameState.canUndo ? _onUndo : _onUndoWithAd,
          ),
          const SizedBox(width: 16),
          GameIconButton(
            icon: Icons.lightbulb_outline,
            onPressed: () {
              final hint = gameState.getHint();
              if (hint != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Move from stack ${hint.$1 + 1} to ${hint.$2 + 1}',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardPlaceholder() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: GameColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GameColors.accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.leaderboard, color: GameColors.textMuted),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Leaderboard coming soon',
                style: TextStyle(
                  color: GameColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: GameColors.empty,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Soon',
                style: TextStyle(color: GameColors.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionOverlay(int moves) {
    return Stack(
      children: [
        const Positioned.fill(
          child: ConfettiOverlay(
            duration: Duration(seconds: 3),
            colors: GameColors.palette,
            confettiCount: 50,
          ),
        ),
        Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.emoji_events,
                  size: 72,
                  color: GameColors.accent,
                ),
                const SizedBox(height: 20),
                Text(
                  'Daily Complete!',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: GameColors.text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: GameColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app, color: GameColors.accent),
                      const SizedBox(width: 8),
                      Text(
                        '$moves moves',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => _shareResult(moves),
                  icon: const Icon(Icons.share),
                  label: const Text('Share Result'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _goHome,
                  icon: const Icon(Icons.home),
                  label: const Text('Home'),
                  style: TextButton.styleFrom(
                    foregroundColor: GameColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  String _formatDisplayDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthLabel = months[date.month - 1];
    return '$monthLabel ${date.day}, ${date.year}';
  }

  bool _isStreakMilestone(int streak) {
    const milestones = [3, 5, 7, 10, 14, 21, 30];
    return milestones.contains(streak);
  }
}

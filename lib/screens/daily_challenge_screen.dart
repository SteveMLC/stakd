import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_challenge.dart';
import '../models/game_state.dart';
import '../models/stack_model.dart';
import '../services/daily_challenge_service.dart';
import '../services/leaderboard_service.dart';
import '../utils/constants.dart';
import '../widgets/game_board.dart';
import '../widgets/name_entry_dialog.dart';

// Top-level function for isolate-based puzzle generation
List<GameStack> _generateStacksInIsolate(Map<String, dynamic> params) {
  final challenge = DailyChallenge(
    date: DateTime.parse(params['date']),
    seed: params['seed'],
    difficulty: params['difficulty'],
  );
  return challenge.generateStacks();
}

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  final DailyChallengeService _service = DailyChallengeService();
  final GameState _gameState = GameState();
  DailyChallenge? _challenge;
  int _streak = 0;
  Map<DateTime, DailyChallengeResult> _history = {};

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _timerRunning = false;
  bool _showCalendar = false;
  bool _completionHandled = false;

  @override
  void initState() {
    super.initState();
    _gameState.addListener(_handleGameStateChange);
    _loadChallenge();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gameState.removeListener(_handleGameStateChange);
    super.dispose();
  }

  Future<void> _loadChallenge() async {
    final challenge = await _service.getTodaysChallenge();
    final streak = await _service.getStreak();
    final history = await _service.getHistory();

    // Generate puzzle in isolate to avoid blocking UI
    final params = {
      'date': challenge.date.toIso8601String(),
      'seed': challenge.seed,
      'difficulty': challenge.difficulty,
    };
    final stacks = await compute(_generateStacksInIsolate, params);
    _gameState.initGame(stacks, challenge.getDayNumber());

    if (!mounted) return;

    setState(() {
      _challenge = challenge;
      _streak = streak;
      _history = history;
      _elapsed = challenge.bestTime ?? Duration.zero;
      _timerRunning = false;
      _completionHandled = challenge.completed;
    });
  }

  void _handleGameStateChange() {
    if (_challenge == null) return;
    if (_gameState.isComplete && !_completionHandled) {
      _completionHandled = true;
      _onChallengeCompleted();
    }
  }

  void _startTimerIfNeeded() {
    if (_timerRunning || (_challenge?.completed ?? false)) return;
    _timerRunning = true;
    _elapsed = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _elapsed += const Duration(milliseconds: 100);
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timerRunning = false;
  }

  Future<void> _onChallengeCompleted() async {
    _stopTimer();

    final elapsed = _elapsed;
    final moves = _gameState.moveCount;

    await _service.markCompleted(elapsed, moves);
    
    // Submit to leaderboard
    await _submitToLeaderboard(elapsed.inSeconds);
    
    await _loadChallenge();

    if (!mounted) return;
    _showCompletionDialog(elapsed, moves);
  }

  Future<void> _submitToLeaderboard(int seconds) async {
    final leaderboardService = LeaderboardService();
    
    // Check if player has set a custom name
    final hasName = await leaderboardService.hasCustomName();
    
    if (!hasName && mounted) {
      // Prompt for name on first leaderboard submission
      final name = await showNameEntryDialog(
        context,
        currentName: leaderboardService.playerName,
        isFirstTime: true,
      );
      
      if (name != null && name.isNotEmpty) {
        await leaderboardService.setPlayerName(name);
      }
    }
    
    // Submit the time
    await leaderboardService.submitDailyTime(seconds);
  }

  void _showCompletionDialog(Duration elapsed, int moves) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Challenge Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDuration(elapsed),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '$moves moves',
              style: const TextStyle(fontSize: 16, color: GameColors.textMuted),
            ),
            const SizedBox(height: 12),
            Text(
              '🔥 $_streak day streak',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              _shareResult();
              Navigator.pop(context);
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareResult() async {
    final challenge = _challenge;
    if (challenge == null) return;
    final bestTime = challenge.bestTime ?? _elapsed;
    final bestMoves = challenge.bestMoves ?? _gameState.moveCount;
    await _service.shareResult(
      challenge: challenge,
      time: bestTime,
      moves: bestMoves,
      streak: _streak,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Result copied to clipboard')),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _challenge;
    if (challenge == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dateFormat = DateFormat('EEEE, MMMM d');
    final isCompleted = challenge.completed;
    final timeDisplay = isCompleted
        ? _formatDuration(challenge.bestTime ?? Duration.zero)
        : _formatDuration(_elapsed);
    final movesDisplay = isCompleted
        ? (challenge.bestMoves ?? 0).toString()
        : _gameState.moveCount.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Challenge'),
        actions: [
          IconButton(
            icon: Icon(_showCalendar ? Icons.grid_4x4 : Icons.calendar_month),
            onPressed: () {
              setState(() {
                _showCalendar = !_showCalendar;
              });
            },
          ),
        ],
      ),
      body: _showCalendar
          ? _buildCalendarView()
          : _buildGameView(dateFormat, isCompleted, timeDisplay, movesDisplay),
    );
  }

  Widget _buildGameView(
    DateFormat dateFormat,
    bool isCompleted,
    String timeDisplay,
    String movesDisplay,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GameColors.surface.withValues(alpha: 0.6),
            border: const Border(
              bottom: BorderSide(color: GameColors.backgroundMid),
            ),
          ),
          child: Column(
            children: [
              Text(
                dateFormat.format(_challenge!.date.toLocal()),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Daily Challenge #${_challenge!.getDayNumber()}',
                style: const TextStyle(
                  fontSize: 14,
                  color: GameColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('⏱️', timeDisplay, 'Time'),
                  _buildStatCard('🧩', movesDisplay, 'Moves'),
                  _buildStatCard('🔥', '$_streak', 'Streak'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: IgnorePointer(
                ignoring: isCompleted,
                child: GameBoard(
                  gameState: _gameState,
                  onTap: _startTimerIfNeeded,
                  onMove: _startTimerIfNeeded,
                  onClear: () {},
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (isCompleted)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareResult,
                    icon: const Icon(Icons.share),
                    label: const Text('Share Result'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _stopTimer();
                      setState(() => _elapsed = Duration.zero);
                    },
                    child: const Text('Reset Timer'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: GameColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildCalendarView() {
    final now = DateTime.now().toUtc();
    const daysToShow = 30;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Past 30 Days',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: daysToShow,
          itemBuilder: (context, index) {
            final date = DateTime.utc(now.year, now.month, now.day)
                .subtract(Duration(days: daysToShow - 1 - index));
            final result = _history[date];
            final isCompleted = result != null;

            return Container(
              decoration: BoxDecoration(
                color: isCompleted
                    ? GameColors.successGlow
                    : GameColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? GameColors.text : GameColors.textMuted,
                    ),
                  ),
                  if (isCompleted) ...[
                    Text(
                      _formatDuration(result.time),
                      style: TextStyle(fontSize: 9, color: GameColors.text.withValues(alpha: 0.7)),
                    ),
                    Text(
                      '${result.moves}m',
                      style: TextStyle(fontSize: 8, color: GameColors.text.withValues(alpha: 0.7)),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

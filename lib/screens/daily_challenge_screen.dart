import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/daily_challenge.dart';
import '../models/game_state.dart';
import '../models/stack_model.dart';
import '../models/layer_model.dart';
import '../services/daily_challenge_service.dart';
import '../widgets/game_board.dart';
import '../widgets/game_button.dart';
import '../utils/constants.dart';
import 'dart:async';

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  final DailyChallengeService _service = DailyChallengeService();
  DailyChallenge? _challenge;
  int _streak = 0;
  Map<DateTime, Duration?> _history = {};
  
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isPlaying = false;
  bool _showCalendar = false;
  
  GameState? _gameState;

  @override
  void initState() {
    super.initState();
    _loadChallenge();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gameState?.dispose();
    super.dispose();
  }

  Future<void> _loadChallenge() async {
    final challenge = await _service.getTodaysChallenge();
    final streak = await _service.getStreak();
    final history = await _service.getHistory();
    
    // Generate puzzle grid and convert to stacks
    final puzzleGrid = challenge.generatePuzzle();
    final stacks = _gridToStacks(puzzleGrid);
    
    final gameState = GameState();
    gameState.initGame(stacks, challenge.getDayNumber());
    
    setState(() {
      _challenge = challenge;
      _streak = streak;
      _history = history;
      _gameState = gameState;
    });
    
    // Listen to game state for completion
    gameState.addListener(_onGameStateChanged);
  }

  void _onGameStateChanged() {
    if (_gameState?.isComplete ?? false) {
      if (!(_challenge?.completed ?? false)) {
        _onChallengeCompleted();
      }
    }
  }

  List<GameStack> _gridToStacks(List<List<int>> grid) {
    final stacks = <GameStack>[];
    final maxDepth = grid.length;
    
    // Convert each column of the grid to a stack
    for (var col = 0; col < grid[0].length; col++) {
      final layers = <Layer>[];
      for (var row = grid.length - 1; row >= 0; row--) {
        final colorIndex = grid[row][col] - 1; // Grid uses 1-6, Layer uses 0-5
        layers.add(Layer(colorIndex: colorIndex));
      }
      stacks.add(GameStack(layers: layers, maxDepth: maxDepth));
    }
    
    // Add 2 empty stacks for moves
    stacks.add(GameStack(layers: [], maxDepth: maxDepth));
    stacks.add(GameStack(layers: [], maxDepth: maxDepth));
    
    return stacks;
  }

  void _startTimer() {
    if (_challenge?.completed ?? false) return;
    
    if (!_isPlaying) {
      setState(() {
        _isPlaying = true;
      });
      
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (mounted) {
          setState(() {
            _elapsed += const Duration(milliseconds: 100);
          });
        }
      });
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _onChallengeCompleted() async {
    _stopTimer();
    
    await _service.markCompleted(_elapsed);
    await _loadChallenge(); // Reload to get updated streak
    
    if (mounted) {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: GameColors.surface,
        title: const Text(
          '🎉 Challenge Complete!',
          style: TextStyle(color: GameColors.text),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDuration(_elapsed),
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: GameColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '🔥 $_streak day streak!',
              style: const TextStyle(fontSize: 20, color: GameColors.text),
            ),
            const SizedBox(height: 8),
            Text(
              '${_gameState?.moveCount ?? 0} moves',
              style: const TextStyle(fontSize: 16, color: GameColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GameColors.accent,
              foregroundColor: GameColors.text,
            ),
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

  void _shareResult() {
    final dayNum = _challenge?.getDayNumber() ?? 0;
    final timeStr = _formatDuration(_elapsed);
    final text = '''Stakd Daily #$dayNum 🟩
⏱️ $timeStr
🔥 $_streak day streak
go7studio.com/stakd''';
    
    Clipboard.setData(ClipboardData(text: text));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Result copied to clipboard!'),
          backgroundColor: GameColors.accent,
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_challenge == null || _gameState == null) {
      return const Scaffold(
        backgroundColor: GameColors.background,
        body: Center(child: CircularProgressIndicator(color: GameColors.accent)),
      );
    }

    final dateFormat = DateFormat('EEEE, MMMM d');
    final isCompleted = _challenge!.completed;

    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: GameColors.surface,
        title: const Text('Daily Challenge', style: TextStyle(color: GameColors.text)),
        iconTheme: const IconThemeData(color: GameColors.text),
        actions: [
          IconButton(
            icon: Icon(
              _showCalendar ? Icons.grid_4x4 : Icons.calendar_month,
              color: GameColors.text,
            ),
            onPressed: () {
              setState(() {
                _showCalendar = !_showCalendar;
              });
            },
          ),
        ],
      ),
      body: _showCalendar ? _buildCalendarView() : _buildGameView(dateFormat, isCompleted),
    );
  }

  Widget _buildGameView(DateFormat dateFormat, bool isCompleted) {
    return Column(
      children: [
        // Header: Date, Timer, Streak
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GameColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                dateFormat.format(_challenge!.date),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: GameColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Daily Challenge #${_challenge!.getDayNumber()}',
                style: const TextStyle(fontSize: 14, color: GameColors.textMuted),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('⏱️', _formatDuration(_elapsed), 'Time'),
                  _buildStatCard('🔥', '$_streak', 'Streak'),
                  if (isCompleted)
                    _buildStatCard('✓', _formatDuration(_challenge!.bestTime!), 'Best'),
                  if (!isCompleted)
                    _buildStatCard('📦', '${_gameState!.moveCount}', 'Moves'),
                ],
              ),
            ],
          ),
        ),
        
        // Game Board
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GameBoard(
                gameState: _gameState!,
                onTap: _startTimer,
                onMove: () {},
                onClear: () {},
              ),
            ),
          ),
        ),
        
        // Bottom Actions
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (isCompleted) ...[
                Expanded(
                  child: GameButton(
                    text: 'Share Result',
                    icon: Icons.share,
                    isPrimary: true,
                    onPressed: _shareResult,
                  ),
                ),
              ] else ...[
                if (_gameState!.canUndo)
                  Expanded(
                    child: GameButton(
                      text: 'Undo',
                      icon: Icons.undo,
                      isPrimary: false,
                      onPressed: () {
                        _gameState!.undo();
                      },
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
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: GameColors.text,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: GameColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildCalendarView() {
    final now = DateTime.now();
    final daysToShow = 30;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Past 30 Days',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: GameColors.text,
          ),
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
            final date = DateTime(now.year, now.month, now.day)
                .subtract(Duration(days: daysToShow - 1 - index));
            final time = _history[date];
            final isCompleted = time != null;
            
            return Container(
              decoration: BoxDecoration(
                color: isCompleted ? GameColors.palette[2] : GameColors.empty,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCompleted
                      ? GameColors.palette[2]
                      : GameColors.empty.withValues(alpha: 0.3),
                  width: 2,
                ),
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
                  if (isCompleted)
                    Text(
                      _formatDuration(time),
                      style: TextStyle(
                        fontSize: 8,
                        color: GameColors.text.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

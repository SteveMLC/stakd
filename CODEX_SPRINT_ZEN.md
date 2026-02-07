# STAKD Zen Mode Focus Sprint

## 🎯 Mission
Make Zen Mode the PRIMARY experience. The current version is functional but too easy - players solve puzzles in 4-7 moves without thinking. We need flow state, not boredom.

## 📁 Project Location
`/Users/venomspike/.openclaw/workspace/projects/stakd/`

## 🔑 Key Files
- `lib/screens/home_screen.dart` - Main menu layout
- `lib/screens/game_screen.dart` - Level mode gameplay
- `lib/screens/zen_screen.dart` - Zen mode (CREATE if missing)
- `lib/services/level_generator.dart` - Puzzle generation
- `lib/utils/constants.dart` - Game config params
- `lib/widgets/celebration_overlay.dart` - Win effects
- `lib/widgets/game_board.dart` - Stack rendering

---

## Phase 1: Zen Mode Difficulty Fix (CRITICAL)

### 1.1 Update LevelParams in constants.dart

Current difficulty is trivial. Update the Zen presets:

```dart
// In constants.dart or level_generator.dart

class ZenParams {
  static LevelParams easy = LevelParams(
    colors: 4,
    depth: 4,
    emptySlots: 2,
    shuffleMoves: 25,
    minDifficultyScore: 4,
  );
  
  static LevelParams medium = LevelParams(
    colors: 5,      // Was 4
    depth: 5,       // Was 4
    emptySlots: 1,  // Was 2 - forces more planning
    shuffleMoves: 40,
    minDifficultyScore: 8,
  );
  
  static LevelParams hard = LevelParams(
    colors: 6,
    depth: 5,
    emptySlots: 1,
    shuffleMoves: 60,
    minDifficultyScore: 12,
  );
}
```

### 1.2 Update LevelGenerator for Zen

In `level_generator.dart`, add method:

```dart
/// Generate an endless Zen puzzle with difficulty preset
List<GameStack> generateZenPuzzle(String difficulty) {
  final params = switch (difficulty) {
    'easy' => ZenParams.easy,
    'medium' => ZenParams.medium,
    'hard' => ZenParams.hard,
    _ => ZenParams.medium,
  };
  
  return _generateWithParams(params);
}

List<GameStack> _generateWithParams(LevelParams params) {
  // Similar to generateSolvableLevel but uses params directly
  List<GameStack>? bestLevel;
  int bestScore = -1;

  for (int attempt = 0; attempt < 15; attempt++) {
    final random = Random(DateTime.now().millisecondsSinceEpoch + attempt);
    var level = _createSolvedState(params, random);
    level = _shuffleLevel(level, params.shuffleMoves, random);

    if (!isSolvable(level, maxStates: 5000)) continue;

    final score = difficultyScore(level);
    if (score >= params.minDifficultyScore) {
      return level;
    }

    if (score > bestScore) {
      bestScore = score;
      bestLevel = level;
    }
  }

  return bestLevel ?? _createSolvedState(params, Random());
}
```

---

## Phase 2: Zen Mode Screen Overhaul

### 2.1 Create/Update zen_screen.dart

The Zen screen needs:
- **Endless mode**: Auto-generate new puzzle when solved
- **Optional UI**: Toggle timer/moves on/off (Settings gear in corner)
- **Cleaner layout**: No bottom controls (pure zen)

```dart
class ZenScreen extends StatefulWidget {
  final String difficulty; // 'easy' | 'medium' | 'hard'
  
  const ZenScreen({super.key, required this.difficulty});
  
  @override
  State<ZenScreen> createState() => _ZenScreenState();
}

class _ZenScreenState extends State<ZenScreen> {
  final LevelGenerator _generator = LevelGenerator();
  int _puzzlesSolved = 0;
  int _totalMoves = 0;
  bool _showStats = false; // Toggle via settings
  Stopwatch _sessionTimer = Stopwatch();
  
  @override
  void initState() {
    super.initState();
    _sessionTimer.start();
    _loadNewPuzzle();
  }
  
  void _loadNewPuzzle() {
    final stacks = _generator.generateZenPuzzle(widget.difficulty);
    context.read<GameState>().initZenGame(stacks);
  }
  
  void _onPuzzleSolved() {
    _puzzlesSolved++;
    _totalMoves += context.read<GameState>().moveCount;
    
    // Brief celebration, then auto-load next
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _loadNewPuzzle();
    });
  }
  
  // ... rest of build method
}
```

### 2.2 Add GameState.initZenGame()

In `game_state.dart`:

```dart
void initZenGame(List<GameStack> stacks) {
  _stacks = stacks;
  _level = 0; // No level in zen
  _moveCount = 0;
  _par = null; // No par in zen
  _isZenMode = true;
  notifyListeners();
}

bool get isZenMode => _isZenMode;
bool _isZenMode = false;
```

---

## Phase 3: Home Screen Restructure

### 3.1 Update home_screen.dart

New button order (Zen Mode PRIMARY):

```dart
// Button order in _buildButtons()
return Column(
  children: [
    // PRIMARY ACTION - ZEN MODE
    _buildPrimaryButton(
      icon: Icons.spa,
      label: 'Zen Mode',
      color: GameColors.zen, // New zen color
      onPressed: () => _showZenDifficultyPicker(),
    ),
    
    const SizedBox(height: 16),
    
    // Secondary row
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSecondaryButton(
          icon: Icons.calendar_today,
          label: 'Daily',
          badge: _hasStreak ? '🔥$_streakCount' : null,
          onPressed: () => _goToDailyChallenge(),
        ),
        const SizedBox(width: 16),
        _buildSecondaryButton(
          icon: Icons.grid_view,
          label: 'Levels',
          badge: 'Lv $_currentLevel',
          onPressed: () => _goToLevelSelect(),
        ),
      ],
    ),
    
    const SizedBox(height: 24),
    
    // Settings
    _buildSmallButton(icon: Icons.settings, onPressed: _goToSettings),
  ],
);
```

### 3.2 Zen Difficulty Picker (Bottom Sheet)

```dart
void _showZenDifficultyPicker() {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GameColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Choose Your Vibe', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          _buildDifficultyOption(
            title: 'Easy',
            subtitle: '4 colors • Relaxed',
            icon: Icons.wb_sunny,
            onTap: () => _startZen('easy'),
          ),
          _buildDifficultyOption(
            title: 'Medium',
            subtitle: '5 colors • Focused',
            icon: Icons.cloud,
            onTap: () => _startZen('medium'),
          ),
          _buildDifficultyOption(
            title: 'Hard',
            subtitle: '6 colors • Challenge',
            icon: Icons.bolt,
            onTap: () => _startZen('hard'),
          ),
        ],
      ),
    ),
  );
}
```

---

## Phase 4: Visual Polish

### 4.1 Stack Clear Celebration

In `game_board.dart` or create `stack_clear_effect.dart`:

```dart
class StackClearEffect extends StatefulWidget {
  final Offset position;
  final Color color;
  
  // Simple particle burst when stack completes
}
```

### 4.2 Subtle Background Animation

In zen mode, add gentle particle drift:

```dart
class ZenBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient base
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D1117), Color(0xFF161B22)],
            ),
          ),
        ),
        // Floating particles (optional, subtle)
        const ParticleField(count: 20, speed: 0.3),
      ],
    );
  }
}
```

### 4.3 Combo Indicator (Optional)

If player clears multiple stacks quickly, show combo:

```dart
// In game state, track rapid clears
void onStackCleared() {
  _recentClears.add(DateTime.now());
  _recentClears.removeWhere((t) => 
    DateTime.now().difference(t) > const Duration(seconds: 3)
  );
  
  if (_recentClears.length >= 2) {
    _currentCombo = _recentClears.length;
    notifyListeners();
  }
}
```

---

## Phase 5: Settings for Zen Mode

### 5.1 Zen Settings

Add to `settings_screen.dart` or create zen settings:

```dart
// Zen mode preferences
class ZenSettings {
  bool showTimer = false;  // Default OFF for true zen
  bool showMoves = false;  // Default OFF
  bool autoNext = true;    // Auto-advance to next puzzle
  bool haptics = true;
  bool sounds = true;
}
```

---

## Testing Checklist

After implementation:
- [ ] Easy Zen: Should take ~30-60 seconds per puzzle
- [ ] Medium Zen: Should take ~1-2 minutes per puzzle  
- [ ] Hard Zen: Should take ~2-4 minutes per puzzle
- [ ] Puzzles should require actual THINKING, not just muscle memory
- [ ] New puzzle auto-loads after solve (no tap required)
- [ ] Timer/moves hidden by default in Zen
- [ ] Home screen shows Zen as primary action
- [ ] Particle burst on stack clear
- [ ] Smooth transitions between puzzles

---

## Git Protocol

1. `git pull origin main` before starting
2. Make changes
3. Test in emulator if possible (or confirm build compiles)
4. `git add -A && git commit -m "feat: Zen mode overhaul - difficulty + UI + endless"`
5. `git push origin main`

---

## When Complete

Run:
```bash
openclaw gateway wake --text "Done: Stakd Zen Mode overhaul complete - harder difficulty, endless mode, UI restructure" --mode now
```

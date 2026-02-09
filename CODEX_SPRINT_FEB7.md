# Stakd Polish Sprint - February 7, 2026
## CODEX EXECUTION FILE

**Goal:** Implement key polish features identified from gameplay video analysis.

**Repository:** `/Users/venomspike/.openclaw/workspace/projects/stakd`  
**GitHub:** https://github.com/SteveMLC/stakd

---

## PRE-WORK

```bash
cd /Users/venomspike/.openclaw/workspace/projects/stakd
git pull origin main
flutter pub get
```

---

## SPRINT TASKS (Execute in order)

### TASK 1: Add Undo Functionality (Priority: HIGH)

**Files to modify:**
- `lib/models/game_state.dart` - Add move history tracking
- `lib/screens/game_screen.dart` - Add undo button to UI

**Implementation:**

1. In `game_state.dart`:
```dart
// Add to GameState class:
final List<MoveRecord> _moveHistory = [];
static const int maxHistorySize = 10;

// Add MoveRecord class (can be at top of file):
class MoveRecord {
  final int fromStack;
  final int toStack;
  final int layerCount;
  final List<Layer> layers;
  
  MoveRecord({
    required this.fromStack,
    required this.toStack,
    required this.layerCount,
    required this.layers,
  });
}

// In the move execution method, before making the move:
void _recordMove(int from, int to, List<Layer> layers) {
  _moveHistory.add(MoveRecord(
    fromStack: from,
    toStack: to,
    layerCount: layers.length,
    layers: List.from(layers),
  ));
  if (_moveHistory.length > maxHistorySize) {
    _moveHistory.removeAt(0);
  }
}

// Add undo method:
bool get canUndo => _moveHistory.isNotEmpty;

void undo() {
  if (_moveHistory.isEmpty) return;
  final move = _moveHistory.removeLast();
  
  // Remove layers from destination
  final destStack = stacks[move.toStack];
  for (int i = 0; i < move.layerCount; i++) {
    destStack.pop();
  }
  
  // Add layers back to source
  final sourceStack = stacks[move.fromStack];
  for (final layer in move.layers) {
    sourceStack.push(layer);
  }
  
  // Update move count (optional: decrement or keep as-is)
  notifyListeners();
}
```

2. In `game_screen.dart`, add undo button to HUD area:
```dart
// In the bottom HUD row, add:
IconButton(
  onPressed: gameState.canUndo ? () {
    haptics.lightTap();
    gameState.undo();
  } : null,
  icon: Icon(
    Icons.undo_rounded,
    color: gameState.canUndo 
        ? GameColors.text 
        : GameColors.textMuted.withValues(alpha: 0.3),
  ),
  tooltip: 'Undo last move',
),
```

---

### TASK 2: Add Completion Celebration Overlay (Priority: HIGH)

**Create new file:** `lib/widgets/completion_overlay.dart`

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/haptic_service.dart';

class CompletionOverlay extends StatefulWidget {
  final int moves;
  final Duration time;
  final VoidCallback onNextPuzzle;
  final VoidCallback onHome;

  const CompletionOverlay({
    super.key,
    required this.moves,
    required this.time,
    required this.onNextPuzzle,
    required this.onHome,
  });

  @override
  State<CompletionOverlay> createState() => _CompletionOverlayState();
}

class _CompletionOverlayState extends State<CompletionOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  final List<_ConfettiParticle> _confetti = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Generate confetti
    _generateConfetti();

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      _scaleController.forward();
      _confettiController.forward();
      haptics.levelWin();
    });
  }

  void _generateConfetti() {
    for (int i = 0; i < 50; i++) {
      _confetti.add(_ConfettiParticle(
        x: _random.nextDouble(),
        delay: _random.nextDouble() * 0.3,
        speed: 0.3 + _random.nextDouble() * 0.5,
        rotation: _random.nextDouble() * 2 * pi,
        color: GameColors.palette[_random.nextInt(GameColors.palette.length)],
        size: 8 + _random.nextDouble() * 8,
      ));
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return minutes > 0 ? '$minutes:${seconds.toString().padLeft(2, '0')}' : '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha: 0.7 * _fadeAnimation.value),
          child: Stack(
            children: [
              // Confetti
              AnimatedBuilder(
                animation: _confettiController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ConfettiPainter(
                      particles: _confetti,
                      progress: _confettiController.value,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
              // Content
              Center(
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: GameColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: GameColors.accent.withValues(alpha: 0.3),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.celebration,
                              color: GameColors.accent,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'PUZZLE COMPLETE!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: GameColors.text,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _StatChip(
                                  icon: Icons.touch_app,
                                  label: '${widget.moves}',
                                  subtitle: 'moves',
                                ),
                                const SizedBox(width: 24),
                                _StatChip(
                                  icon: Icons.timer,
                                  label: _formatTime(widget.time),
                                  subtitle: 'time',
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: widget.onHome,
                                  child: const Text('Home'),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: widget.onNextPuzzle,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: GameColors.accent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                  ),
                                  child: const Text(
                                    'Next Puzzle',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: GameColors.textMuted, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: GameColors.text,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: GameColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _ConfettiParticle {
  final double x;
  final double delay;
  final double speed;
  final double rotation;
  final Color color;
  final double size;

  _ConfettiParticle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.rotation,
    required this.color,
    required this.size,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final effectiveProgress = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (effectiveProgress <= 0) continue;

      final x = p.x * size.width;
      final y = effectiveProgress * size.height * p.speed;
      final opacity = 1.0 - effectiveProgress;
      final rotation = p.rotation + effectiveProgress * 4;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
```

**In `game_screen.dart`:**
- Import the new overlay
- Show overlay when `gameState.isComplete` becomes true
- Pass appropriate callbacks for next puzzle and home navigation

---

### TASK 3: Improve Empty Slot Visibility (Priority: MEDIUM)

**File:** `lib/widgets/stack_widget.dart` (specifically the `_StackWidget` class in `game_board.dart`)

In the empty state, instead of just showing nothing, add a subtle visual indicator:

```dart
// In the _buildLayers() method of _StackWidget, update the empty case:
if (layers.isEmpty) {
  return Center(
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: GameColors.textMuted.withValues(alpha: 0.15),
          width: 2,
        ),
      ),
      child: Icon(
        Icons.add,
        color: GameColors.textMuted.withValues(alpha: 0.2),
        size: 24,
      ),
    ),
  );
}
```

---

### TASK 4: Add Progress Indicator (Priority: MEDIUM)

**File:** `lib/screens/game_screen.dart`

Add a simple progress indicator showing completed stacks:

```dart
// In the HUD area, add:
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      '${gameState.completedStackCount}/${gameState.totalStacks}',
      style: TextStyle(
        fontSize: 14,
        color: GameColors.textMuted,
      ),
    ),
    const SizedBox(width: 4),
    Icon(
      Icons.check_circle,
      size: 16,
      color: GameColors.palette[2].withValues(alpha: 0.7),
    ),
  ],
),
```

**In `lib/models/game_state.dart`, add getters:**
```dart
int get completedStackCount => stacks.where((s) => s.isComplete).length;
int get totalStacks => stacks.length;
```

---

### TASK 5: Add Loading Animation (Priority: LOW)

**File:** `lib/screens/game_screen.dart` or wherever "Generating puzzle..." is shown

Replace plain text with animated version:

```dart
class _LoadingText extends StatefulWidget {
  const _LoadingText();

  @override
  State<_LoadingText> createState() => _LoadingTextState();
}

class _LoadingTextState extends State<_LoadingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _dotCount = (_dotCount + 1) % 4;
          });
          _controller.forward(from: 0);
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Generating puzzle${'.' * _dotCount}',
      style: const TextStyle(
        color: GameColors.textMuted,
        fontSize: 16,
      ),
    );
  }
}
```

---

## POST-WORK

```bash
# Verify no issues
flutter analyze

# Quick build test
flutter build apk --debug

# Commit and push
git add -A
git commit -m "Polish sprint: Undo, completion celebration, progress indicator, UI improvements"
git push origin main

# Signal completion
echo "CODEX_DONE: Stakd polish sprint complete - undo, celebration overlay, progress indicator added"
```

---

## NOTES FOR CODEX

1. **Start with Task 1 (Undo)** - Most critical for user experience
2. **Task 2 (Completion)** - Essential for satisfaction
3. **If time permits**, do Tasks 3-5
4. **Always run `flutter analyze`** before committing
5. **The "VERFLOWED BY" bug** is NOT in the current codebase - likely a screen recorder watermark

## INVESTIGATION TASK (if time permits)

Search for any code that might produce "VERFLOWED BY" or similar text:
```bash
grep -rni "VERFLOWED\|OVERFLOW\|hazard\|stripe" . --include="*.dart"
```

If found, report location. If not found, confirm it's likely a screen recorder watermark.

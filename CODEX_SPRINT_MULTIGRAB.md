# STAKD Multi-Grab Tutorial & Polish

## 🎯 Mission
Multi-grab (long-press to grab multiple matching layers) is our UNIQUE mechanic that differentiates us. But users don't know it exists! Fix discoverability and polish the experience.

## The Problem
- Users tap-tap-tap one layer at a time
- Multi-grab is discovered by accident (if at all)
- No tutorial or hint about this mechanic
- Tip text is buried and unclear

## The Solution
1. First-time hint when multi-grab is possible
2. Better visual indicator for "long-press available"
3. Tutorial overlay for new users
4. Polish the multi-grab animation

---

## Phase 1: Multi-Grab Discovery Hint

### 1.1 First-Time Hint Overlay

When a stack has 2+ matching top layers AND user hasn't used multi-grab before:

```dart
// In game_board.dart or game_screen.dart

class MultiGrabHint extends StatelessWidget {
  final VoidCallback onDismiss;
  
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onDismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.7),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: GameColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: GameColors.accent, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated hand icon
                  _buildAnimatedLongPressIcon(),
                  const SizedBox(height: 16),
                  const Text(
                    '💡 Pro Tip!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: GameColors.accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'LONG PRESS to grab multiple\nmatching layers at once!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: GameColors.text,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Faster solving • Fewer moves',
                    style: TextStyle(
                      fontSize: 14,
                      color: GameColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: onDismiss,
                    child: const Text('Got it!'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAnimatedLongPressIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing ring
            Container(
              width: 80 + (value * 20),
              height: 80 + (value * 20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: GameColors.accent.withValues(alpha: 1 - value),
                  width: 3,
                ),
              ),
            ),
            // Hand icon
            const Icon(
              Icons.touch_app,
              size: 48,
              color: GameColors.accent,
            ),
          ],
        );
      },
    );
  }
}
```

### 1.2 Track Multi-Grab Discovery

```dart
// In storage_service.dart

class StorageService {
  // ... existing methods
  
  bool hasSeenMultiGrabHint() {
    return _prefs.getBool('multi_grab_hint_seen') ?? false;
  }
  
  Future<void> setMultiGrabHintSeen() async {
    await _prefs.setBool('multi_grab_hint_seen', true);
  }
  
  bool hasUsedMultiGrab() {
    return _prefs.getBool('multi_grab_used') ?? false;
  }
  
  Future<void> setMultiGrabUsed() async {
    await _prefs.setBool('multi_grab_used', true);
  }
}
```

### 1.3 Show Hint When Appropriate

In `game_screen.dart` or `game_board.dart`:

```dart
// Check if we should show multi-grab hint
void _checkMultiGrabHint(GameState gameState) {
  final storage = StorageService();
  
  // Don't show if already seen
  if (storage.hasSeenMultiGrabHint()) return;
  
  // Check if any stack has 2+ matching top layers
  for (final stack in gameState.stacks) {
    if (stack.topGroupSize >= 2) {
      setState(() => _showMultiGrabHint = true);
      storage.setMultiGrabHintSeen();
      break;
    }
  }
}
```

---

## Phase 2: Visual Indicator for Multi-Grab Available

### 2.1 Subtle Glow on Multi-Grabbable Stacks

When a stack has 2+ matching top layers, add subtle pulsing indicator:

```dart
// In _StackWidget

bool get _hasMultiGrabOpportunity {
  return widget.stack.topGroupSize >= 2;
}

Widget build(BuildContext context) {
  // Add indicator badge
  return Stack(
    children: [
      _buildStackContainer(),
      
      // Multi-grab indicator
      if (_hasMultiGrabOpportunity && !widget.isSelected)
        Positioned(
          top: 4,
          right: 4,
          child: _MultiGrabIndicator(count: widget.stack.topGroupSize),
        ),
    ],
  );
}

class _MultiGrabIndicator extends StatefulWidget {
  final int count;
  const _MultiGrabIndicator({required this.count});
  
  @override
  State<_MultiGrabIndicator> createState() => _MultiGrabIndicatorState();
}

class _MultiGrabIndicatorState extends State<_MultiGrabIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1 + _controller.value * 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3 + _controller.value * 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.layers,
                size: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 2),
              Text(
                '×${widget.count}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

---

## Phase 3: Improved Multi-Grab Activation Feedback

### 3.1 Better Visual Feedback on Long Press

```dart
// In _StackWidgetState

void _onLongPressStart(LongPressStartDetails details) {
  if (widget.stack.isEmpty) return;
  
  // Start visual feedback immediately
  setState(() => _isLongPressing = true);
  haptics.mediumImpact();
}

void _onLongPress() {
  if (widget.stack.isEmpty) return;
  
  final topGroup = widget.stack.getTopGroup();
  if (topGroup.length > 1) {
    // Multi-grab SUCCESS!
    haptics.successPattern();
    widget.onMultiGrab();
    
    // Track first use
    if (!StorageService().hasUsedMultiGrab()) {
      StorageService().setMultiGrabUsed();
    }
  } else {
    // Just one layer, fallback to normal tap
    widget.onTap();
  }
  
  setState(() => _isLongPressing = false);
}

// In build method, add long-press visual
if (_isLongPressing) 
  // Show expanding ring animation around stack
  _buildLongPressRing(),
```

### 3.2 Ring Animation During Long Press

```dart
class _LongPressRing extends StatefulWidget {
  final double size;
  final Color color;
  
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.2),
      duration: const Duration(milliseconds: 400),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 1.2 - scale),
                width: 4,
              ),
            ),
          ),
        );
      },
    );
  }
}
```

---

## Phase 4: Update Existing Tips/Tutorial

### 4.1 Improve Tutorial Text

In `tutorial_service.dart` or wherever tips are defined:

```dart
// Update the multi-grab tip text
const multiGrabTip = Tip(
  title: 'Multi-Grab Power Move',
  body: 'See multiple matching colors on top?\n'
        'LONG PRESS to grab them all at once!\n\n'
        '⚡ Faster solving\n'
        '📉 Fewer moves',
  icon: Icons.touch_app,
);
```

### 4.2 Contextual Tooltip During Play

When user has 3+ matching layers and hasn't used multi-grab recently:

```dart
// Small floating tooltip near the stack
class ContextualTooltip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: GameColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.touch_app, size: 16, color: GameColors.accent),
          const SizedBox(width: 6),
          const Text(
            'Hold to grab all',
            style: TextStyle(fontSize: 12, color: GameColors.text),
          ),
        ],
      ),
    );
  }
}
```

---

## Phase 5: Settings Toggle

Allow users to disable multi-grab hints:

```dart
// In settings_screen.dart

SwitchListTile(
  title: const Text('Multi-Grab Hints'),
  subtitle: const Text('Show tip when multiple layers can be grabbed'),
  value: _showMultiGrabHints,
  onChanged: (value) {
    setState(() => _showMultiGrabHints = value);
    StorageService().setShowMultiGrabHints(value);
  },
),
```

---

## Testing Checklist

- [ ] First-time hint appears when 2+ matching layers exist
- [ ] Hint only shows once
- [ ] Subtle indicator badge shows on multi-grabbable stacks
- [ ] Long press shows visual feedback (ring animation)
- [ ] Multi-grab animation is smooth
- [ ] Settings toggle works
- [ ] Tutorial text is clear and helpful

---

## Git

```bash
git add -A && git commit -m "feat: multi-grab tutorial and polish - better discoverability" && git push origin main
```

## When Complete

```bash
openclaw gateway wake --text "Done: Stakd multi-grab tutorial complete - hints, indicators, better feedback" --mode now
```

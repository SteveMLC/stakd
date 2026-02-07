# STAKD Visual Polish Sprint

## 🎯 Mission
Make Stakd BEAUTIFUL. Current UI is functional but generic. We need premium visual polish that differentiates us.

## 📁 Project Location
`/Users/venomspike/.openclaw/workspace/projects/stakd/`

## Key Files
- `lib/utils/constants.dart` - Colors, sizes, gradients
- `lib/widgets/layer_widget.dart` - Layer visuals
- `lib/widgets/stack_widget.dart` - Stack visuals
- `lib/widgets/game_board.dart` - Overall board
- `lib/screens/home_screen.dart` - Home visuals
- `lib/widgets/game_button.dart` - Button styling

---

## Phase 1: Enhanced Color Palette

### 1.1 Update GameColors in constants.dart

Add gradient support and richer colors:

```dart
class GameColors {
  // Primary palette - richer, more saturated
  static const List<Color> palette = [
    Color(0xFFFF4757), // Coral Red (was 0xFFE53935)
    Color(0xFF3742FA), // Electric Blue (was 0xFF1E88E5)
    Color(0xFF2ED573), // Emerald Green (was 0xFF43A047)
    Color(0xFFFFD93D), // Golden Yellow (was 0xFFFFB300)
    Color(0xFFA55EEA), // Royal Purple (was 0xFF8E24AA)
    Color(0xFF17A2B8), // Teal Cyan (was 0xFF00ACC1)
    Color(0xFFFF6B81), // Soft Pink
    Color(0xFF1E90FF), // Dodger Blue
  ];

  // Gradients for layers (top to bottom)
  static List<List<Color>> layerGradients = [
    [Color(0xFFFF4757), Color(0xFFE74C3C)], // Red gradient
    [Color(0xFF3742FA), Color(0xFF2C3E50)], // Blue gradient
    [Color(0xFF2ED573), Color(0xFF27AE60)], // Green gradient
    [Color(0xFFFFD93D), Color(0xFFF39C12)], // Yellow gradient
    [Color(0xFFA55EEA), Color(0xFF9B59B6)], // Purple gradient
    [Color(0xFF17A2B8), Color(0xFF1ABC9C)], // Cyan gradient
    [Color(0xFFFF6B81), Color(0xFFE91E63)], // Pink gradient
    [Color(0xFF1E90FF), Color(0xFF2980B9)], // Blue 2 gradient
  ];

  // Background enhancement
  static const Color backgroundDark = Color(0xFF0D1117);
  static const Color backgroundMid = Color(0xFF161B22);
  static const Color backgroundLight = Color(0xFF21262D);
  
  // Accent glow colors
  static const Color successGlow = Color(0xFF2ED573);
  static const Color warningGlow = Color(0xFFFFD93D);
  static const Color errorGlow = Color(0xFFFF4757);
  
  // Get gradient for color index
  static List<Color> getGradient(int index) {
    return layerGradients[index % layerGradients.length];
  }
}
```

---

## Phase 2: Layer Visual Enhancement

### 2.1 Add Gradient + Shine Effect to Layers

In `_buildLayers()` method (game_board.dart or stack_widget):

```dart
Widget _buildLayer(Layer layer, int index, int totalLayers) {
  final colors = GameColors.getGradient(layer.colorIndex);
  final isTopLayer = index == totalLayers - 1;
  
  return Container(
    width: double.infinity,
    height: GameSizes.layerHeight,
    margin: const EdgeInsets.only(bottom: 2),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ),
      borderRadius: BorderRadius.circular(6),
      boxShadow: [
        // Inner depth shadow
        BoxShadow(
          color: colors[1].withValues(alpha: 0.5),
          offset: const Offset(0, 2),
          blurRadius: 4,
        ),
      ],
    ),
    child: Stack(
      children: [
        // Highlight/shine stripe at top
        Positioned(
          top: 2,
          left: 4,
          right: 4,
          height: 4,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Subtle bottom shadow line
        Positioned(
          bottom: 1,
          left: 2,
          right: 2,
          height: 2,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ],
    ),
  );
}
```

---

## Phase 3: Stack Container Enhancement

### 3.1 Better Stack Styling

```dart
// In _StackWidget build method
return Container(
  width: GameSizes.stackWidth,
  height: GameSizes.stackHeight,
  decoration: BoxDecoration(
    // Subtle gradient background for empty stack
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        GameColors.empty.withValues(alpha: 0.8),
        GameColors.empty,
      ],
    ),
    borderRadius: BorderRadius.circular(GameSizes.stackBorderRadius),
    border: Border.all(
      color: _getBorderColor(),
      width: _getBorderWidth(),
    ),
    // Inner shadow for depth
    boxShadow: [
      // Outer glow when selected
      if (isSelected || isMultiGrabActive)
        BoxShadow(
          color: _getGlowColor().withValues(alpha: 0.5),
          blurRadius: 16,
          spreadRadius: 2,
        ),
      // Base shadow
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        offset: const Offset(0, 4),
        blurRadius: 8,
      ),
    ],
  ),
  // ... rest
);
```

---

## Phase 4: Home Screen Visual Upgrade

### 4.1 Animated Background

Add subtle particle/star animation to home screen:

```dart
// In home_screen.dart, wrap body with animated background

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  
  const AnimatedBackground({super.key, required this.child});
  
  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Star> _stars = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    
    // Generate subtle background stars
    final random = Random();
    for (int i = 0; i < 30; i++) {
      _stars.add(_Star(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 2 + 1,
        speed: random.nextDouble() * 0.02 + 0.01,
        opacity: random.nextDouble() * 0.3 + 0.1,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                GameColors.backgroundDark,
                GameColors.backgroundMid,
                GameColors.backgroundLight,
              ],
            ),
          ),
        ),
        // Floating particles
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _StarFieldPainter(_stars, _controller.value),
              size: Size.infinite,
            );
          },
        ),
        // Content
        widget.child,
      ],
    );
  }
}
```

### 4.2 Better Button Styling

In `game_button.dart`:

```dart
// Enhanced button with gradient and glow

return AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  decoration: BoxDecoration(
    gradient: isPrimary 
        ? LinearGradient(
            colors: [
              GameColors.accent,
              GameColors.accent.withValues(alpha: 0.8),
            ],
          )
        : null,
    color: isPrimary ? null : GameColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: isPrimary 
          ? GameColors.accent.withValues(alpha: 0.5)
          : GameColors.textMuted.withValues(alpha: 0.3),
      width: isPrimary ? 2 : 1,
    ),
    boxShadow: [
      if (isPrimary)
        BoxShadow(
          color: GameColors.accent.withValues(alpha: 0.4),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: // button content
);
```

---

## Phase 5: Selection & Interaction Polish

### 5.1 Better Selection Animation

When stack is tapped, add:
- Scale up slightly (1.02x)
- Color-matched border glow
- Lift shadow increases

### 5.2 Move Animation Enhancement

The layer arc animation exists but add:
- Motion blur effect (optional)
- Trail particles for multi-grab

---

## Testing

- [ ] Colors are richer and more vibrant
- [ ] Layers have gradient + shine effect
- [ ] Stacks have depth shadows
- [ ] Home screen has subtle animated background
- [ ] Buttons have gradient and glow
- [ ] Selection feels premium
- [ ] Everything maintains 60fps

## Git

```bash
git add -A && git commit -m "feat: visual polish - gradients, shadows, animations" && git push origin main
```

## When Complete

```bash
openclaw gateway wake --text "Done: Stakd visual polish complete - gradients, shadows, premium feel" --mode now
```

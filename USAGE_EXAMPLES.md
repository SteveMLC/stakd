# Stakd Difficulty Features - Code Examples

## Creating Special Blocks

### Multi-Color Block
```dart
// Create a block with Red and Blue colors
final multiColorBlock = Layer.multiColor(
  colors: [0, 1], // Color indices for Red and Blue
);

// Create a block with three colors
final triColorBlock = Layer.multiColor(
  colors: [0, 2, 4], // Red, Green, Purple
);
```

### Locked Block
```dart
// Create a block locked for 3 moves
final lockedBlock = Layer.locked(
  colorIndex: 2, // Green
  lockedFor: 3,
);
```

### Regular Block (unchanged)
```dart
final normalBlock = Layer(colorIndex: 0); // Red
```

## Checking Block Properties

```dart
// Check if a block is multi-color
if (layer.isMultiColor) {
  print("This block has ${layer.colors!.length} colors");
}

// Check if a block is locked
if (layer.isLocked) {
  print("This block is locked for ${layer.lockedUntil} more moves");
}

// Check if a layer contains a specific color
if (layer.hasColor(0)) { // Check for Red
  print("This layer contains Red");
}

// Check if two layers can match
if (layer1.canMatchWith(layer2)) {
  print("These layers can be stacked together");
}
```

## Using the Unstacking Mechanic

```dart
// In your GameState instance:

// 1. Unstack 2 layers from stack index 3
bool success = gameState.unstackFrom(3, 2);
if (success) {
  print("Unstacked ${gameState.unstakedLayers.length} layers");
}

// 2. Check if we have unstacked layers
if (gameState.hasUnstakedLayers) {
  print("Currently holding ${gameState.unstakedLayers.length} layers");
}

// 3. Restack to a different stack (index 5)
bool restacked = gameState.restackTo(5);
if (restacked) {
  print("Successfully restacked layers");
}

// 4. Cancel unstacking (return to original stack)
gameState.cancelUnstack();
```

## Level Generation with New Features

The level generator automatically creates special blocks based on the level number:

```dart
final generator = LevelGenerator();

// Generate level 15 (will have some multi-color blocks)
final stacks15 = generator.generateLevel(15);

// Generate level 40 (will have multi-color and locked blocks)
final stacks40 = generator.generateLevel(40);

// Generate level 100 (high difficulty with many special blocks)
final stacks100 = generator.generateLevel(100);
```

## Custom Level Parameters

You can create levels with custom difficulty:

```dart
final params = LevelParams(
  colors: 6,
  depth: 5,
  stacks: 8,
  emptySlots: 2,
  shuffleMoves: 60,
  multiColorProbability: 0.3,  // 30% multi-color blocks
  lockedBlockProbability: 0.15, // 15% locked blocks
  maxLockedMoves: 4,            // Locked for up to 4 moves
);

final generator = LevelGenerator();
final customStacks = generator.generatePuzzleWithParams(params);
```

## UI Integration Suggestions

### Rendering Multi-Color Blocks

```dart
// In your layer widget:
Widget buildLayer(Layer layer) {
  if (layer.isMultiColor) {
    return MultiColorLayerWidget(
      colors: layer.allColors, // List<Color>
      // Render as gradient or split
    );
  }
  
  return StandardLayerWidget(
    color: layer.color,
  );
}
```

### Rendering Locked Blocks

```dart
Widget buildLayer(Layer layer) {
  return Stack(
    children: [
      StandardLayerWidget(color: layer.color),
      if (layer.isLocked)
        Positioned(
          right: 4,
          top: 4,
          child: LockIcon(movesRemaining: layer.lockedUntil),
        ),
    ],
  );
}
```

### Unstack Button

```dart
// When a stack is selected:
if (gameState.selectedStackIndex != -1 && !gameState.hasUnstakedLayers) {
  ElevatedButton(
    onPressed: () {
      // Show dialog to choose number of layers
      showUnstackDialog(context, gameState.selectedStackIndex);
    },
    child: Text('Unstack'),
  );
}

// When holding unstacked layers:
if (gameState.hasUnstakedLayers) {
  Row(
    children: [
      Text('Holding ${gameState.unstakedLayers.length} layers'),
      ElevatedButton(
        onPressed: () => gameState.cancelUnstack(),
        child: Text('Cancel'),
      ),
    ],
  );
}
```

## Testing New Features

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Multi-color block matches multiple colors', () {
    final multiColor = Layer.multiColor(colors: [0, 1, 2]);
    
    expect(multiColor.hasColor(0), true);
    expect(multiColor.hasColor(1), true);
    expect(multiColor.hasColor(2), true);
    expect(multiColor.hasColor(3), false);
  });
  
  test('Locked block cannot be moved', () {
    final locked = Layer.locked(colorIndex: 0, lockedFor: 3);
    final stack = GameStack(layers: [], maxDepth: 5);
    
    expect(locked.isLocked, true);
    expect(stack.canAccept(locked), false); // Can't add locked blocks
  });
  
  test('Lock counter decrements', () {
    final locked = Layer.locked(colorIndex: 0, lockedFor: 3);
    final decremented = locked.decrementLock();
    
    expect(decremented.lockedUntil, 2);
  });
  
  test('Unstacking works correctly', () {
    final gameState = GameState();
    final stacks = [
      GameStack(
        layers: [
          Layer(colorIndex: 0),
          Layer(colorIndex: 0),
          Layer(colorIndex: 1),
        ],
        maxDepth: 5,
      ),
    ];
    
    gameState.initGame(stacks, 1);
    
    // Unstack top 2 layers
    expect(gameState.unstackFrom(0, 2), true);
    expect(gameState.hasUnstakedLayers, true);
    expect(gameState.unstakedLayers.length, 2);
    expect(gameState.stacks[0].layers.length, 1); // One left
  });
}
```

## Migration Guide

If you have existing level generation or custom puzzles:

### Before:
```dart
final layer = Layer(colorIndex: 2);
```

### After (still works):
```dart
final layer = Layer(colorIndex: 2); // Still creates a normal block
```

### New capabilities:
```dart
// Multi-color
final multiLayer = Layer.multiColor(colors: [0, 1]);

// Locked
final lockedLayer = Layer.locked(colorIndex: 2, lockedFor: 3);
```

**Backward compatibility:** All existing code continues to work. The new features are opt-in through new constructors and properties.

---

**Note:** UI integration is pending. The core game logic is complete and tested. Add visual elements and gestures to make these features accessible to players.

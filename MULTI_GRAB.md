# Multi-Grab Mechanic

**THE differentiator** - no other sort game has this!

## How It Works

### Activation
- **Tap and hold** (300ms) on any stack with 2+ consecutive same-color layers on top
- Haptic feedback confirms activation
- Visual indicator shows which layers will be grabbed (white glow + pulse)

### Grab Zone
- Automatically detects ALL consecutive same-color layers from top
- Visual indicators:
  - White border pulse on grabbed layers
  - Enhanced stack glow in the layer color
  - Lifted animation effect on the stack
  - Layers float upward slightly while held

### Valid Drops
- **Empty stack**: Always valid
- **Stack with matching top color**: Valid if enough space for ALL grabbed layers
- Invalid drops: Fallback to selecting the tapped stack

### Counting
- Multi-grab moves count as **1 move** (huge strategic advantage!)
- Undo properly reverses all layers in the grab

## Technical Details

### Files Modified
- `lib/utils/constants.dart` - Added timing constants
- `lib/models/stack_model.dart` - Added multi-grab helpers
- `lib/models/game_state.dart` - Multi-grab state + move logic
- `lib/widgets/game_board.dart` - Long press detection + animations

### Animation
- Higher arc trajectory for multi-layer moves
- Longer animation duration (320ms vs 280ms)
- Stronger haptic feedback on land
- Group shadow/glow effects

## Strategy Tips

Players who master multi-grab can:
1. Complete stacks in fewer moves
2. Clear multiple layers at once
3. Set up more complex chain reactions
4. Beat par scores more easily

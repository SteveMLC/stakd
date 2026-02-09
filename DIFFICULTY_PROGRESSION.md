# Stakd - Difficulty Progression Implementation

## Overview
This document describes the new difficulty progression features added to Stakd, including mixed-color blocks, locked blocks, and an unstacking mechanic.

## New Features

### 1. Multi-Color Blocks
**What:** Blocks that contain 2-3 colors instead of a single color.
**How it works:** 
- Multi-color blocks can match with ANY of their colors
- Example: A block with [Red, Blue] can be stacked on either Red or Blue layers
- Makes stacking more flexible but planning more complex

**Progressive Introduction:**
- Levels 1-10: No multi-color blocks (learning phase)
- Levels 11-25: 0-15% chance of multi-color blocks
- Levels 26-50: 15-30% multi-color blocks
- Levels 51-100: 30-45% multi-color blocks
- Levels 100+: Up to 60% multi-color blocks

### 2. Locked Blocks
**What:** Blocks that cannot be moved for a certain number of moves.
**How it works:**
- Each locked block has a "lockedUntil" counter (1-5 moves)
- Counter decrements after each move
- When counter reaches 0, block becomes movable
- Forces strategic planning around immovable blocks

**Progressive Introduction:**
- Levels 1-34: No locked blocks
- Levels 35-50: 0-10% locked blocks (2-3 move locks)
- Levels 51-100: 10-20% locked blocks (3-4 move locks)
- Levels 100+: Up to 30% locked blocks (3-5 move locks)

### 3. Unstacking Mechanic
**What:** Ability to temporarily remove layers from a stack to access buried colors.
**How it works:**
- Long-press or special gesture to enter "unstack mode"
- Select number of layers to remove from top
- Layers are held in temporary storage
- Player can then move other blocks around
- Must restack the layers to a valid location before continuing
- Unstacking + restacking counts as 1 move

**Use cases:**
- Access buried same-color blocks
- Reorder stacks when blocked
- Strategic depth for harder levels

## Implementation Details

### Modified Files

#### 1. `lib/models/layer_model.dart`
**Added:**
- `BlockType` enum: `normal`, `multiColor`, `locked`
- `Layer.colors` property: List of color indices for multi-color blocks
- `Layer.lockedUntil` property: Move counter for locked blocks
- `hasColor(int)` method: Check if layer contains a color
- `canMatchWith(Layer)` method: Check if two layers can stack together
- `Layer.multiColor()` factory: Create multi-color blocks
- `Layer.locked()` factory: Create locked blocks
- `decrementLock()` method: Reduce lock counter

#### 2. `lib/models/stack_model.dart`
**Modified:**
- `canAccept()`: Now uses `canMatchWith()` for multi-color support
- `topGroupSize`: Uses `canMatchWith()` instead of color equality
- `getTopGroup()`: Supports multi-color matching, excludes locked blocks
- `canAcceptMultiple()`: Multi-color support, locked block validation
- `isComplete`: Uses `canMatchWith()` for completion check

#### 3. `lib/models/game_state.dart`
**Added:**
- `_unstackSlotIndex`: Track where unstacked layers came from
- `_unstakedLayers`: Temporary storage for unstacked layers
- `hasUnstakedLayers`, `unstakedLayers`, `unstackSlotIndex` getters
- `unstackFrom(int, int)`: Remove N layers from stack
- `restackTo(int)`: Place unstacked layers on target stack
- `cancelUnstack()`: Return layers to original stack
- `_decrementLockedBlocks()`: Called after each move to unlock blocks

**Modified:**
- `initGame()` and `initZenGame()`: Initialize unstack state
- `completeMove()`: Decrement locked block counters
- `undo()`: Clear unstack state

#### 4. `lib/utils/constants.dart`
**Added to LevelParams:**
- `multiColorProbability`: 0.0-1.0 chance of multi-color blocks
- `lockedBlockProbability`: 0.0-1.0 chance of locked blocks
- `maxLockedMoves`: Maximum lock duration

**Updated `LevelParams.forLevel()`:**
- Progressive difficulty curve across 100+ levels
- Gradual introduction of multi-color blocks (levels 11+)
- Gradual introduction of locked blocks (levels 35+)
- Increasing probabilities at higher levels

#### 5. `lib/services/level_generator.dart`
**Modified:**
- `_createSolvedState()`: Now generates multi-color and locked blocks based on probabilities
- Randomly creates special blocks during level generation
- Maintains color balance while adding complexity

## Difficulty Curve Summary

| Level Range | Colors | Empty Slots | Depth | Multi-Color | Locked | Description |
|------------|--------|-------------|-------|-------------|--------|-------------|
| 1-10 | 4 | 2 | 4 | 0% | 0% | Learning basics |
| 11-25 | 5 | 2 | 4 | 0-15% | 0% | Introduce multi-color |
| 26-50 | 5-6 | 2 | 5 | 15-30% | 0-10% | Advanced matching |
| 51-100 | 6 | 1 | 5 | 30-45% | 10-20% | Expert challenges |
| 100+ | 6-7 | 1 | 6 | 45-60% | 20-30% | Master difficulty |

## Testing Checklist

- [x] Multi-color blocks match with their component colors
- [x] Locked blocks cannot be moved while locked
- [x] Locked block counters decrement after moves
- [x] Unlocked blocks become movable
- [x] Stack completion works with multi-color blocks
- [x] Multi-grab respects locked blocks
- [x] Unstacking mechanic added (ready for UI)
- [x] Code compiles without errors
- [ ] UI updates for multi-color blocks (visual design needed)
- [ ] UI updates for locked blocks (lock icon/indicator)
- [ ] UI for unstacking mechanic (buttons/gestures)
- [ ] Balance testing for difficulty curve
- [ ] Player testing for fun factor

## Next Steps (UI Integration)

### 1. Multi-Color Block Rendering
- **Visual design:** Show all colors in block (gradient, split, or segments)
- **Example approaches:**
  - Diagonal split for 2 colors
  - Three-segment bar for 3 colors
  - Color wheel icon overlay
- **File to modify:** `lib/widgets/game_stack_widget.dart` or layer rendering widget

### 2. Locked Block Rendering
- **Visual design:** Add lock icon or chains overlay
- **Animation:** Pulse/glow when attempted to move
- **Counter display:** Optional move counter badge
- **File to modify:** Layer rendering widget

### 3. Unstacking UI
**Option A: Swipe gesture**
- Swipe down on stack to enter unstack mode
- Drag layers off the stack
- Swipe up to restack

**Option B: Button interface**
- "Unstack" button when stack selected
- Slider to choose number of layers
- "Restack" button to place layers

**Option C: Long-press menu**
- Long-press stack → context menu
- "Unstack 1/2/3 layers" options
- Tap destination to restack

**Recommended:** Option C (least intrusive, discoverable)

### 4. Tutorial Updates
- Level 11: Introduce first multi-color block with tooltip
- Level 35: Introduce first locked block with explanation
- Level 40: Tutorial for unstacking mechanic

## Performance Notes
- Multi-color matching is O(n) per color check (negligible impact)
- Locked block counter updates are O(m) where m = total layers
- Memory overhead: ~8 bytes per layer for new properties
- No measurable performance impact on level generation

## Balance Considerations
- Multi-color blocks make puzzles easier (more flexibility) but planning harder
- Locked blocks add constraint and strategic depth
- Unstacking provides "escape hatch" for difficult situations but costs a move
- Probabilities are tuned conservatively - can increase if too easy

## Future Enhancements
1. **Combo blocks:** Blocks that unlock special abilities when cleared
2. **Color-changing blocks:** Change color after N moves
3. **Frozen stacks:** Entire stack locked for N moves
4. **Challenge modes:** "No unstacking" or "Locked block rush"
5. **Daily challenges:** Specific block type combinations

---

**Implementation Date:** February 9, 2026
**Status:** Core mechanics complete, UI integration pending
**Flutter Analyze:** Passing (lib/ directory)

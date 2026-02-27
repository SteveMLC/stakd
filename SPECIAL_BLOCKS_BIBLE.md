# SortBloom — Special Blocks Bible

> Unique block mechanics that create interesting solve constraints.
> Each block type changes HOW you think about moves, not just WHAT moves you make.

---

## 🎯 Design Principles

1. **Each block creates a unique constraint** — not just "harder" but "think differently"
2. **Visually distinct at a glance** — player must immediately know what a block does
3. **Composable** — blocks can combine (a heavy frozen block, a magnetic anchor, etc.)
4. **Introduce one at a time** — new block type per difficulty tier, never 3+ new types at once
5. **Always solvable** — generator must verify the puzzle is solvable WITH the constraints

---

## ✅ EXISTING BLOCKS

### 🧊 Frozen Block
- **Mechanic:** Cannot be moved until an adjacent block is moved first (thaws after N moves nearby)
- **Visual:** Ice crystal overlay, cracks appear as it thaws
- **Introduced:** Medium (puzzle 4+)

### 🔒 Locked Block
- **Mechanic:** Cannot be moved for N turns. Counter decrements each move.
- **Visual:** Padlock icon with number countdown
- **Introduced:** Medium (puzzle 3+)

---

## 🆕 STEVE'S BLOCK CONCEPTS

### ⬇️ Heavy Block (Gravity Block)
- **Mechanic:** Can only move DOWN — to a tube that is lower on screen or has fewer blocks (shorter stack). Cannot be lifted to a taller stack.
- **Rule:** Target stack height must be ≤ source stack height - 1
- **Strategy impact:** Forces you to plan vertical space. Can't just dump heavies on tall stacks. You need to CREATE short stacks first.
- **Visual:** Dark stone/iron texture with a downward arrow (⬇️). Slight drop shadow. Feels "weighty."
- **Combo potential:** Heavy + Frozen = nightmare. Must thaw it AND have a shorter stack ready.
- **Introduced:** Hard (puzzle 3+)

### 🎈 Float Block (Helium Block)
- **Mechanic:** Can only move UP — to a tube with MORE blocks (taller stack) or to an empty tube's top position. Cannot sink to a shorter stack.
- **Rule:** Target stack height must be ≥ source stack height
- **Strategy impact:** Opposite of Heavy. Floaters want to go high. Forces you to build UP before you can place them.
- **Visual:** Light/translucent with small bubbles and upward arrow (⬆️). Soft glow. Feels "airy."
- **Combo potential:** Float + Heavy in same puzzle = extreme constraint management
- **Introduced:** Hard (puzzle 6+)

### ↔️ Horizontal Block (Slide Block)
- **Mechanic:** Can only move to an ADJACENT tube (left or right neighbor). Cannot jump across multiple tubes.
- **Rule:** Target tube index must be source tube index ± 1
- **Strategy impact:** Forces sequential thinking. You may need to "pass" a block through intermediate tubes to get it where it needs to go. Essentially a sliding puzzle within the sorting puzzle.
- **Visual:** Side-pointing arrows (↔️) on both sides. Slightly wider than normal blocks. Feels "slidey."
- **Combo potential:** Horizontal + Frozen = can only slide when thawed, to adjacent tube only
- **Introduced:** Ultra (puzzle 1+)

### 👑 Crown Block (Top-Only Block)
- **Mechanic:** Can ONLY be placed as the TOP block of a stack. Cannot be placed beneath other blocks. If it's not on top, it's stuck until blocks above it are removed.
- **Rule:** Target stack must have space AND the crown block will be the topmost
- **Strategy impact:** Crowns must go LAST on each stack. Forces careful sequencing — you need to sort everything else before capping with crowns.
- **Visual:** Small crown icon (👑) with gold shimmer. Premium feel.
- **Combo potential:** Crown + Float = must go to top of a tall stack AND be the final piece
- **Introduced:** Ultra (puzzle 4+)

---

## 💡 ADDITIONAL BLOCK CONCEPTS

### 🧲 Magnet Block (Attract)
- **Mechanic:** When placed, pulls the nearest same-color block one position closer (from an adjacent tube). One-time effect on placement.
- **Strategy impact:** Creates chain reactions. Place a magnet strategically and it auto-sorts a neighbor. Rewards planning ahead.
- **Visual:** Horseshoe magnet icon with magnetic field lines. Pulses when about to attract.
- **Introduced:** Hard (puzzle 8+)

### 💣 Bomb Block (Wildcard Destructor)
- **Mechanic:** Matches ANY color. When a tube is completed with a bomb block in it, the bomb "explodes" (satisfying animation) and counts as whatever color was needed.
- **Strategy impact:** Powerful but rare. Do you use it to fix a mistake or save it for the hardest color to sort?
- **Visual:** Round bomb with lit fuse. Sparkles. Rainbow color shimmer since it's wild.
- **Introduced:** As a rare reward/powerup, not a difficulty mechanic

### 🪨 Anchor Block
- **Mechanic:** Cannot be moved AT ALL once placed. Permanently stuck in its position. Pre-placed by the puzzle generator.
- **Strategy impact:** Pure obstacle. You must sort everything around the anchors. Creates fixed constraints that define the puzzle's shape.
- **Visual:** Stone/concrete texture with chain links. No arrows — it's going nowhere.
- **Combo potential:** The ultimate constraint — plan everything around immovable objects
- **Introduced:** Ultra (puzzle 8+)

### 🔄 Swap Block
- **Mechanic:** Instead of normal move, a swap block EXCHANGES positions with the top block of the target tube. Both blocks move simultaneously.
- **Strategy impact:** Creates unique two-for-one moves. Can be extremely powerful OR create chaos depending on planning.
- **Visual:** Circular arrows icon (🔄). Spins slightly when selected.
- **Introduced:** Hard (puzzle 10+)

### ⏳ Timer Block (Decay Block)
- **Mechanic:** Must be placed within N moves or it "decays" into a random color. Counter shown on block.
- **Strategy impact:** Creates urgency. Forces you to deal with timer blocks first before methodically sorting others.
- **Visual:** Hourglass icon with sand animation. Number countdown. Turns red when 1 move left.
- **Introduced:** Ultra (puzzle 6+)

### 🪞 Mirror Block
- **Mechanic:** When moved, a copy of the move happens in the OPPOSITE direction (mirrored tube). E.g., move from tube 2→4 also moves top of tube 5→3 (mirrored positions).
- **Strategy impact:** Every move has consequences elsewhere. Forces whole-board thinking.
- **Visual:** Reflective/chrome surface with mirror icon. Shimmer effect.
- **Introduced:** Ultra (puzzle 10+) — endgame mechanic

### 🌀 Vortex Block
- **Mechanic:** When placed on a stack, it REVERSES the order of all blocks in that stack. One-time effect.
- **Strategy impact:** Extremely powerful for fixing "upside down" stacks. But can also ruin a nearly-sorted stack if misused.
- **Visual:** Spiral/vortex icon. Swirl animation on activation.
- **Introduced:** As a rare powerup/reward

---

## 📊 DIFFICULTY INTRODUCTION SCHEDULE

| Difficulty | Puzzle Range | New Block Type | Existing + New |
|------------|-------------|----------------|----------------|
| **Easy** | All | None | Normal blocks only |
| **Medium** | 3-4 | 🔒 Locked | Locked |
| **Medium** | 5-7 | 🧊 Frozen | Locked + Frozen |
| **Medium** | 8+ | — | Locked + Frozen (steady state) |
| **Hard** | 1-2 | ⬇️ Heavy | Locked + Frozen + Heavy |
| **Hard** | 3-5 | — | Same, higher density |
| **Hard** | 6-8 | 🎈 Float | Locked + Frozen + Heavy + Float |
| **Hard** | 8-10 | 🧲 Magnet | Add Magnet |
| **Hard** | 10+ | 🔄 Swap | Add Swap |
| **Ultra** | 1-3 | ↔️ Horizontal | All Hard + Horizontal |
| **Ultra** | 4-6 | 👑 Crown | Add Crown |
| **Ultra** | 6-8 | ⏳ Timer | Add Timer |
| **Ultra** | 8-10 | 🪨 Anchor | Add Anchor |
| **Ultra** | 10+ | 🪞 Mirror | The full chaos |

---

## 🎮 BLOCK COMBINATIONS (High Difficulty Scenarios)

### "The Gravity Well"
- Mix of ⬇️ Heavy + 🎈 Float blocks
- Heavies want to go down, floats want to go up
- Player must create a "gravity well" pattern: short stacks for heavies, tall stacks for floats

### "The Gauntlet"
- 🪨 Anchor blocks in fixed positions + 🔒 Locked blocks counting down
- Must route blocks around immovable anchors while racing lock timers

### "The Slide Puzzle"
- All blocks are ↔️ Horizontal
- Entire puzzle becomes a sequential sliding challenge
- Classic brain teaser within the sorting game

### "The Crown Jewels"
- 👑 Crown blocks on every color + 🧊 Frozen regular blocks
- Must thaw all blocks before sorting, then carefully cap each stack with crowns

### "Mirror Madness"
- 🪞 Mirror blocks throughout
- Every move echoes — requires thinking 2 moves at once

---

## 🎨 VISUAL DESIGN GUIDELINES

### Block Indicators
Each special block gets:
1. **Icon overlay** — small symbol in corner of block (arrow, lock, crown, etc.)
2. **Texture/effect** — subtle visual treatment on the block surface
3. **Color tint** — very subtle tint that doesn't interfere with the sort color:
   - Heavy: slight dark vignette at bottom
   - Float: slight bright glow at top
   - Horizontal: subtle gradient from left to right
   - Crown: gold sparkle at top edge
   - Anchor: stone texture overlay
   - Timer: pulsing edge glow (faster as time runs out)

### First Encounter
Every new block type gets a brief intro modal:
- Block icon + name + one-sentence rule
- "Got it!" dismiss button
- Only shows once (SharedPreferences flag)
- Example: "⬇️ **Heavy Block** — This block is too heavy to lift up! It can only move to a shorter stack."

### Sound Design
Each block type gets a unique move sound:
- Heavy: deep thud/stone drop
- Float: whoosh/air puff
- Horizontal: slide/swoosh
- Crown: royal chime
- Anchor: chain clink (when you try to move it)
- Timer: ticking (accelerates near expiry)
- Magnet: magnetic pull zap
- Bomb: kaboom on completion

---

## 🛠️ IMPLEMENTATION NOTES

### Data Model Extension
```dart
enum BlockType {
  normal,
  frozen,
  locked,
  heavy,      // can only move to shorter/lower stacks
  floating,   // can only move to taller/higher stacks
  horizontal, // can only move to adjacent tubes (±1 index)
  crown,      // can only be placed as topmost block
  anchor,     // cannot be moved at all
  swap,       // exchanges with target top block
  timer,      // must be placed within N moves
  magnet,     // pulls nearest same-color on placement
  mirror,     // mirrors move to opposite tube
  vortex,     // reverses stack order on placement
  bomb,       // wildcard — matches any color
}

class Layer {
  final int colorIndex;
  final BlockType type;
  final int? lockedUntil;  // for locked
  final bool isFrozen;     // for frozen
  final int? timerMoves;   // for timer
  // ... existing fields
}
```

### Move Validation
Each block type adds a validation rule to the move checker:
```dart
bool canMove(Layer block, int fromTube, int toTube, List<GameStack> stacks) {
  switch (block.type) {
    case BlockType.heavy:
      return stacks[toTube].length < stacks[fromTube].length;
    case BlockType.floating:
      return stacks[toTube].length >= stacks[fromTube].length || stacks[toTube].isEmpty;
    case BlockType.horizontal:
      return (toTube - fromTube).abs() == 1;
    case BlockType.crown:
      return stacks[toTube].length == stacks[toTube].maxDepth - 1;
    case BlockType.anchor:
      return false; // never movable
    // ...
  }
}
```

### Puzzle Generation
- Generator must verify solvability WITH block constraints
- Start with normal puzzle, then apply special blocks
- Run constrained solver to verify
- If unsolvable with constraints, try different block placements
- Fallback: reduce number of special blocks until solvable

---

## 📝 PRIORITY ORDER FOR IMPLEMENTATION

### Phase 1 (Next Sprint)
1. ⬇️ Heavy Block — simplest new mechanic, single directional constraint
2. 🎈 Float Block — natural pair with Heavy, same validation pattern

### Phase 2
3. ↔️ Horizontal Block — adjacency constraint, different axis
4. 👑 Crown Block — placement order constraint

### Phase 3
5. 🧲 Magnet Block — first "active effect" block
6. 🔄 Swap Block — two-block interaction

### Phase 4 (Endgame)
7. 🪨 Anchor Block — static obstacle
8. ⏳ Timer Block — time pressure
9. 🪞 Mirror Block — advanced/complex

### Phase 5 (Powerups, not difficulty)
10. 💣 Bomb Block — reward/powerup
11. 🌀 Vortex Block — reward/powerup

---

*"Each block doesn't just make it harder — it makes you think in a new way."*

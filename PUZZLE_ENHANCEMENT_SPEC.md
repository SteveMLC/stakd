# Stakd — Puzzle Enhancement Spec

## Current Game Summary

Stakd is a **color-sorting stack puzzle** (similar to Water Sort Puzzle / Ball Sort). Players move colored layers between stacks, one at a time (or multi-grab same-color groups), to sort all layers so each stack contains a single color. Current features:

- **Levels 1–∞** with progressive difficulty (4→7 colors, 4→6 depth, 2→1 empty slots)
- **Zen Mode** (easy/medium/hard/ultra presets, endless)
- **Daily Challenge** (deterministic seed, harder than normal)
- **Combo system** (consecutive clears within 3s)
- **Par scoring** (BFS-calculated minimum moves)
- **Multi-grab** (long-press to grab consecutive same-color layers)
- **Undo** (3 base, +3 via rewarded ad)
- **Zen Garden** (meta progression / reward system)

---

## Research: What Works in Successful Puzzle Games

### Color-Sorting Puzzles (Direct Competitors)
- **Water Sort Puzzle** (500M+ downloads): Pure sorting, no special mechanics. Retention comes from difficulty curve and ad-funded hints. Simple but repetitive.
- **Ball Sort Puzzle**: Same core, adds tube count variety. Some versions add "locked" tubes.
- **Key takeaway**: The genre succeeds on satisfying sorting, but players churn after ~50 levels due to mechanical monotony.

### Tetris & Variants
- **Tetris Effect**: Emotional engagement through audiovisual coupling (music reacts to play)
- **Puyo Puyo Tetris**: Chain reactions create exponential scoring — "I didn't plan that but it was amazing" moments
- **Key takeaway**: Chain reactions and audiovisual feedback are the #1 retention drivers

### Match-3 / Color Matching (Candy Crush, Bejeweled)
- **Special pieces** from combos (bombs, line clears, color bombs) — the single most copied mechanic in mobile puzzles
- **Objectives beyond "clear everything"** — reach a score, clear specific colors, break obstacles
- **Key takeaway**: Varied objectives per level prevent monotony; special pieces reward skill

### Physics Puzzlers (Cut the Rope, Angry Birds)
- **Emergent solutions** — multiple valid approaches with different scores
- **Key takeaway**: Players love feeling clever; reward creative/unexpected solutions

### Meta-Progression (Homescapes, Gardenscapes)
- **Narrative wrapper** around puzzles dramatically increases retention
- **Key takeaway**: Stakd's Zen Garden is already this — double down on it

---

## Mechanic Ideas (Ranked by Implementation Effort)

### Tier 1 — Low Effort (1-3 days each)

| # | Mechanic | Description | Why It Works |
|---|----------|-------------|--------------|
| 1 | **Star Rating** | 3-star system: ★ = complete, ★★ = at par, ★★★ = under par | Replayability without new code. Uses existing par calculation. |
| 2 | **Color Objectives** | "Clear all Red first" or "Clear Blue in ≤3 moves" | Adds constraint variety to existing levels. Just UI + validation. |
| 3 | **Move Limit Mode** | Hard cap on moves (par + N). Fail = retry. | Creates tension. Trivial to implement — just a check in `completeMove()`. |
| 4 | **Speed Run Mode** | Timer-based scoring. Same puzzles, time pressure. | New mode using existing puzzle gen. Timer + leaderboard. |

### Tier 2 — Medium Effort (3-7 days each)

| # | Mechanic | Description | Why It Works |
|---|----------|-------------|--------------|
| 5 | **Locked Layers** | Some layers have a "lock" — can't be moved until adjacent same-color layer is placed on top | Forces planning ahead. Adds `isLocked` bool to `Layer`. |
| 6 | **Wildcard Layers** | Rainbow layer that matches any color. Completes any stack. | Strategic — where to place it matters. New `colorIndex = -1` sentinel. |
| 7 | **Frozen Stacks** | A stack that's temporarily frozen (can't add/remove for N moves) | Creates routing puzzles. Timer/counter on `GameStack`. |
| 8 | **Chain Clear Bonus** | When completing a stack causes a layer to "fall" and auto-complete another | The Puyo Puyo moment. Needs cascade logic in `completeMove()`. |

### Tier 3 — High Effort (1-2 weeks each)

| # | Mechanic | Description | Why It Works |
|---|----------|-------------|--------------|
| 9 | **Bomb Layers** | Placed in stacks during gen. Explode (clear) after N moves if not defused (sorted). | Urgency + planning. Needs countdown UI, explosion animation, level gen changes. |
| 10 | **Portal Stacks** | Two stacks are "linked" — placing on one teleports to the other | Mind-bending routing. Needs visual connection, modified `canAccept` logic. |

---

## Recommended Priority Order

### Phase 1: Quick Wins (Week 1)
1. **Star Rating** — Immediate replayability, uses existing par system
2. **Move Limit Mode** — One `if` statement creates a whole new feel
3. **Color Objectives** — 2-3 objective types make levels feel unique

### Phase 2: Depth (Week 2-3)
4. **Locked Layers** — Single biggest "puzzle enhancement" with minimal code
5. **Wildcard Layers** — Feels like a reward / power-up
6. **Speed Run Mode** — Different player segment (competitive vs casual)

### Phase 3: Wow Factor (Week 3-4)
7. **Chain Clear Bonus** — Most satisfying moment possible
8. **Frozen Stacks** — Adds planning depth
9. **Bomb Layers** — Tension + urgency

### Phase 4: Experimental
10. **Portal Stacks** — Only if player engagement data supports complexity appetite

---

## Implementation Notes: Top 3 Ideas

### 1. Star Rating System

**Where to change:**
- `GameState` — add `int get starRating` computed property
- `CompletionOverlay` widget — show 1-3 stars with animation
- `StorageService` — persist best star rating per level
- `LevelSelectScreen` — show stars on level tiles

**Logic:**
```dart
int get starRating {
  if (!isComplete) return 0;
  if (par == null) return 1; // No par data = 1 star for completion
  if (moveCount <= par!) return 3; // Under or at par
  if (moveCount <= par! + 3) return 2; // Within 3 of par
  return 1; // Completed
}
```

**Storage:** Add `Map<int, int> levelStars` to StorageService (level → best stars). Show total stars as a progression metric.

**Effort:** ~1 day. Most time is on the star animation in CompletionOverlay.

---

### 2. Locked Layers

**Concept:** Some layers have a padlock icon. A locked layer cannot be picked up (moved). It unlocks when a layer of the **same color** is placed directly on top of it.

**Where to change:**
- `Layer` model — add `bool isLocked` field
- `GameStack.canPickUp()` — new method, returns false if top layer is locked
- `GameState._tryMove()` — check `canPickUp` before allowing selection
- `GameStack.withLayerAdded()` — after adding, check if the layer below was locked and same color → unlock it
- `LevelGenerator` — after shuffling, mark 1-3 random non-top layers as locked (ensuring solvability)
- `LayerWidget` — render lock icon overlay on locked layers
- `constants.dart` — add locked layer introduction at level ~15

**Key constraint:** The level generator must verify solvability AFTER placing locks. Strategy: generate normal level, add locks to buried layers, re-verify with `isSolvable()`.

**Layer model change:**
```dart
class Layer {
  final int colorIndex;
  final String id;
  final bool isLocked;
  
  Layer({required this.colorIndex, String? id, this.isLocked = false});
}
```

**Effort:** ~4 days. Lock/unlock logic is simple; the hard part is ensuring generated levels remain solvable with locks, and the lock/unlock animation.

---

### 3. Wildcard (Rainbow) Layers

**Concept:** A special layer that matches ANY color. It can be placed on any non-full stack and counts as the color of the stack it completes with.

**Where to change:**
- `Layer` model — `static const int wildcardColor = -1;` and `bool get isWildcard`
- `GameStack.canAccept()` — accept wildcards always (if not full)
- `GameStack.isComplete` — wildcards count as the majority color in the stack
- `LevelGenerator` — inject 1 wildcard per puzzle starting at level ~20, replacing a random layer
- `LayerWidget` — rainbow gradient rendering for wildcard layers
- `constants.dart` — add wildcard color constant

**canAccept change:**
```dart
bool canAccept(Layer layer) {
  if (isFull) return false;
  if (isEmpty) return true;
  if (layer.isWildcard) return true; // Wildcards go anywhere
  if (topLayer!.isWildcard) return true; // Can stack on wildcard
  return topColorIndex == layer.colorIndex;
}
```

**isComplete change:**
```dart
bool get isComplete {
  if (layers.isEmpty) return false;
  if (layers.length != maxDepth) return false;
  // Find the non-wildcard color (if any)
  final realColors = layers.where((l) => !l.isWildcard).map((l) => l.colorIndex).toSet();
  if (realColors.length > 1) return false; // Mixed non-wildcard colors
  return true; // All same color (+ wildcards)
}
```

**Effort:** ~3 days. The `canAccept` logic change cascades into multi-grab and hints. Rainbow animation is the fun part.

---

## Summary

Stakd's core sorting mechanic is solid. The biggest gap is **variety** — every level feels the same except harder. The recommended path:

1. **Star ratings** give immediate replay motivation (free)
2. **Locked layers** add a "puzzle within a puzzle" feeling
3. **Wildcards** feel rewarding and strategic
4. **Chain clears** create viral-worthy "wow" moments

These four additions would transform Stakd from "another sort puzzle" to a game with genuine depth and retention hooks, while staying true to the calm, satisfying core experience.

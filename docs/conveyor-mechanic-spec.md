# Warehouse Sort — Conveyor Mechanic (Priority-1 Overhaul Spec)

**Status:** Design / not yet implemented. Tracking via `.claude/build-state.md`.
**Owner:** Steve (vision) · Walt (implementation)
**Last touched:** 2026-05-16

---

## 1. Vision (Steve's brief, verbatim summary)

Today: a level is "5 bays full of mixed crates, sort all 5, level done." Scope
is hard-capped at what fits on screen.

Tomorrow: a level is **a continuous shift on the dock**. 4-5 bays are on
screen at any moment. The player sorts a bay → that bay ships off (warehouse
takes it, monetary popup, ding) → a fresh mixed bay slides in from the right
to take its place. The player keeps working through a queue of deliveries.
A level could be "ship 5 bays" (intro), "ship 12 bays" (mid-game), or "ship
25 bays" (procedural late-game) — far beyond what fits on screen at once.

The mechanic isolates two concerns that the old generator confused:

- **Puzzle generation** stays simple. One algorithm produces solvable mixed
  bays, deterministically.
- **Difficulty** is a layered concern. Number of deliveries, color count,
  bay depth, post-seed wrinkle additives (frozen / fragile / priority /
  locked) — all sit ON TOP of the simple generator.

The OLD seed/level system is being removed. This is a from-the-ground-up
rewrite so we never hit "level unsolvable, BFS budget blown" again.

---

## 2. Inviolable Requirements

These are non-negotiable per Steve's brief:

1. **The game must NEVER start with a pre-solved bay on screen.** No bay can
   be all-single-color-full at level start. (Sanity check baked into the
   generator — a pre-solved bay would let the player do nothing and break
   the loop.)
2. **Solved bays must ship off and be replaced.** Cleared bays don't stay
   empty as workspace forever — a new mixed delivery slides in from the
   right after a short pause.
3. **Delivery animation must be quick and feel like fresh work.** Right-edge
   slide-in ~400ms, crates "drop into" the bay with a small bounce. Player
   shouldn't wait — the next puzzle is immediately legible.
4. **Seeding is simple, deterministic, and solvable-by-construction.** No
   probabilistic difficulty score. No BFS validation pass needed.
5. **Wrinkles are post-seed additives.** Generator knows about colors and
   depth only. Frozen / fragile / priority / locked / time-bomb / oversized
   / gravity-flip / conveyor-drift / double-color all get layered ON TOP of
   the clean seed, with their own per-delivery probability.
6. **Simpler is better.** The new generator should fit in ~150 LOC, be
   trivial to reason about, and have unit tests that pass on every level
   number from 1 to 1000+ without flaking.

---

## 3. Industry-Standard Seed Algorithm — Reverse Construction

This is how Water Sort / Ball Sort / Blue Steel / Sort Puzzle Mania / every
serious sort-puzzle game generates levels. **It is mathematically guaranteed
to produce a solvable puzzle.** No BFS validation needed.

### 3.1 Forward game move (player's perspective)

> Move the top crate of bay A to bay B if bay B is empty OR bay B's top
> crate is the same color as bay A's top crate AND bay B has space.

### 3.2 Reverse move (generator's perspective)

> Move the top crate of bay A back to bay B, where bay B is non-empty and
> has space.

Because every reverse move is the literal inverse of a forward move, the
sequence of reverse moves we apply IS a sequence of forward moves we can
play back to solve the puzzle. **Solvability is a property of construction,
not validation.**

### 3.3 Algorithm

```
Input: numColors C, bayDepth D, numEmptyBays E, scrambleMoves M
Output: List<GameStack> initial state

1. Build the SOLVED state:
   - For each color c in [0..C): create one bay with D crates of color c.
   - Add E empty bays. (E >= 1 always; the player needs workspace.)
   - Total bays = C + E.

2. Pick a random RNG seed (or use a level-deterministic seed for repeatable
   daily puzzles).

3. Repeat M times:
   a. Find all valid reverse moves: pick a (source, dest) pair where
      source is non-empty AND dest has space AND (source != dest).
      Optionally constrain: dest must already contain different colors
      OR be empty (otherwise the "reverse" is reversible-by-the-player
      in one trivial move which doesn't add difficulty).
   b. Pick one uniformly at random.
   c. Apply: move top crate of source onto top of dest.

4. Sanity check: NO bay can be all-single-color-full at this point. If any
   is, run another M/10 reverse moves to mix it up. (With M sufficiently
   large vs C*D this never trips in practice, but the check is cheap.)

5. Return the resulting list of bays.
```

**Difficulty knob = M (scramble moves).** More reverse moves → more
scrambled puzzle → harder to solve. The puzzle is ALWAYS solvable in at
most M forward moves (often fewer, since the BFS-optimal solve compresses
some reverses).

### 3.4 Choosing M (difficulty scaling)

| Level band | numColors | bayDepth | numEmptyBays | scrambleMoves |
|---|---|---|---|---|
| 1-5 (intro)  | 3 | 4 | 2 | C * D * 2  = 24 |
| 6-15        | 4 | 4 | 2 | C * D * 3  = 48 |
| 16-30       | 5 | 4 | 2 | C * D * 4  = 80 |
| 31-60       | 6 | 5 | 2 | C * D * 5 = 150 |
| 61-100      | 7 | 5 | 2 | C * D * 6 = 210 |
| 100+        | 7 | 5 | 1 | C * D * 8 = 280 |

(Curve tunable; this is the starting recipe.)

### 3.5 Code shape

```dart
// lib/services/conveyor_seed.dart
class ConveyorSeed {
  static List<GameStack> generateBays({
    required int numColors,
    required int bayDepth,
    required int numEmptyBays,
    required int scrambleMoves,
    required Random rng,
  }) {
    // Step 1: Build solved state.
    final bays = <List<int>>[];
    for (int c = 0; c < numColors; c++) {
      bays.add(List<int>.filled(bayDepth, c));
    }
    for (int e = 0; e < numEmptyBays; e++) {
      bays.add(<int>[]);
    }

    // Steps 2-3: Apply M valid reverse moves.
    for (int i = 0; i < scrambleMoves; i++) {
      final validPairs = <(int, int)>[];
      for (int s = 0; s < bays.length; s++) {
        if (bays[s].isEmpty) continue;
        for (int d = 0; d < bays.length; d++) {
          if (s == d) continue;
          if (bays[d].length >= bayDepth) continue;
          validPairs.add((s, d));
        }
      }
      if (validPairs.isEmpty) break;
      final (src, dst) = validPairs[rng.nextInt(validPairs.length)];
      bays[dst].add(bays[src].removeLast());
    }

    // Step 4: Sanity check — no pre-solved bay.
    bool anySolved = bays.any((b) =>
        b.length == bayDepth && b.toSet().length == 1);
    int safetyRetries = 0;
    while (anySolved && safetyRetries < 10) {
      // Apply one more reverse move and re-check.
      // ... (extracted helper)
      safetyRetries++;
      anySolved = bays.any((b) =>
          b.length == bayDepth && b.toSet().length == 1);
    }

    // Step 5: Wrap into GameStack list with maxDepth.
    return bays
        .map((layers) => GameStack(
              layers: layers.map((c) => Layer(colorIndex: c)).toList(),
              maxDepth: bayDepth,
            ))
        .toList();
  }
}
```

That's the whole algorithm. ~50 lines. No BFS, no difficulty-score
heuristic, no retry loops to find solvable seeds, no flaky tests.

---

## 4. Delivery Queue Model

A level isn't "a board" anymore. A level is a **queue of deliveries** that
the player works through. The on-screen 4-5 bays are a sliding window over
the queue.

### 4.1 Data shape

```dart
class ConveyorLevel {
  final int levelNumber;
  /// Currently visible bays (4-5 of them) — what the player interacts with.
  List<GameStack> visibleBays;
  /// Pending deliveries that will slide in as visible bays get cleared.
  Queue<GameStack> pendingDeliveries;
  /// How many bays the player has already shipped this level.
  int baysShipped;
  /// How many bays total for this level (won when baysShipped == totalDeliveries).
  final int totalDeliveries;
}
```

### 4.2 Level config

```dart
class ConveyorLevelConfig {
  final int numVisibleBays;        // 4 or 5
  final int numColors;             // 3-7
  final int bayDepth;              // 4-5
  final int numEmptyBays;          // 1-2 (always at least 1)
  final int scrambleMovesPerBay;   // see difficulty table above
  final int totalDeliveries;       // 5 (intro) → 25 (late-game)
  final List<WrinkleAdditive> wrinkles;  // post-seed additives
}
```

### 4.3 Level number → config mapping

```dart
ConveyorLevelConfig configForLevel(int n) {
  if (n <= 5)   return ConveyorLevelConfig(numVisibleBays: 4, numColors: 3, bayDepth: 4, numEmptyBays: 2, scrambleMovesPerBay: 24, totalDeliveries: 5,  wrinkles: []);
  if (n <= 15)  return ConveyorLevelConfig(numVisibleBays: 4, numColors: 4, bayDepth: 4, numEmptyBays: 2, scrambleMovesPerBay: 48, totalDeliveries: 8,  wrinkles: [frozen]);
  if (n <= 30)  return ConveyorLevelConfig(numVisibleBays: 5, numColors: 5, bayDepth: 4, numEmptyBays: 2, scrambleMovesPerBay: 80, totalDeliveries: 12, wrinkles: [frozen, locked]);
  if (n <= 60)  return ConveyorLevelConfig(numVisibleBays: 5, numColors: 6, bayDepth: 5, numEmptyBays: 2, scrambleMovesPerBay: 150, totalDeliveries: 18, wrinkles: [frozen, locked, fragile, priority]);
  if (n <= 100) return ConveyorLevelConfig(numVisibleBays: 5, numColors: 7, bayDepth: 5, numEmptyBays: 2, scrambleMovesPerBay: 210, totalDeliveries: 22, wrinkles: [frozen, locked, fragile, priority, time-bomb]);
  return        ConveyorLevelConfig(numVisibleBays: 5, numColors: 7, bayDepth: 5, numEmptyBays: 1, scrambleMovesPerBay: 280, totalDeliveries: 25, wrinkles: [all]);
}
```

### 4.4 Lifecycle

1. **Level start:** generate `numVisibleBays + (totalDeliveries - numVisibleBays)`
   bays. Top `numVisibleBays` become `visibleBays`; the rest queue up in
   `pendingDeliveries`.
2. **Player solves a bay → it becomes all-single-color-full.**
3. **Ship-off:** the solved bay animates right + crates fade. Cash payout
   popup floats from the bay to the HUD cash counter. ~500ms.
4. **Slide-shift:** remaining visible bays animate one slot to the left.
   ~250ms.
5. **Arrival:** new bay slides in from the right into the rightmost slot
   (just below the LOADING DOCK banner). Crates "drop in" from above with
   a small bounce. ~400ms total.
6. **`baysShipped++`. Check win:** if `baysShipped == totalDeliveries`,
   fire the existing CompletionOverlay. Otherwise loop back to (2).

Total time ship→arrive: ~1.1s. Feels like a quick beat, not a wait.

### 4.5 Inviolable seed-time guarantees

Each pre-generated bay in BOTH `visibleBays` and `pendingDeliveries` must:

- Not be pre-solved (all-single-color-full).
- Not be empty unless explicitly an `emptyBay` slot.
- Be reachable to "solved" via valid game moves USING THE OTHER VISIBLE
  BAYS as workspace. (This is automatically true since reverse-construction
  is run across the whole visible+pending pool with workspace bays
  included.)

Wait — actually a subtlety: the reverse-construction algorithm needs to
guarantee that EACH delivery is independently solvable using only the
workspace bays available WHEN IT SLIDES IN. This needs more thought.

**Resolution:** generate each delivery as a self-contained mini-puzzle.
Each delivery = `1 mixed bay + numEmptyBays workspace bays`. Reverse-
construct that mini-puzzle individually. The mini-puzzle's "workspace
bays" don't actually exist on screen — they're conceptual scratch space
during generation only. The player solves the bay using the OTHER
currently-visible bays as workspace. As long as the player has enough
free bays at any moment, they can always solve.

Open question: How many empty workspace bays does the player need at any
moment? Probably `bayDepth - 1` if we're paranoid; probably 1-2 in
practice if the level config keeps `numEmptyBays` >= 2.

**Practical answer:** for `numEmptyBays >= 2` and `bayDepth <= 5`, all
deliveries are solvable using the on-screen bays as workspace. Confirm
empirically with playtests at scale.

---

## 5. Visual / VFX Design

### 5.1 Layout

Horizontal row of `numVisibleBays` bays at the playfield center. The
current 3×2 grid goes away. A horizontal carousel feels like a conveyor
belt naturally.

Above: LOADING DOCK banner (current `loading_dock_banner.dart`, unchanged
in spirit — shows the colors of the CURRENT visible bays as targets).

Below: action bar (`unified_action_bar.dart`), unchanged.

### 5.2 Ship-off animation

```
1. Bay slides right at +800px over 400ms easeInCubic.
2. Crates inside fade to 0 opacity over the same 400ms.
3. Cash popup ("+$XX") spawns at the bay's center and floats up-and-
   left toward the HUD cash counter over 600ms, scaling 1.0 → 1.4.
4. SFX: existing `playWin` from rewards channel (chord + ding).
5. Haptic: existing `successPattern`.
6. Bay slot becomes "empty placeholder" for ~250ms before the next
   bay slides in.
```

### 5.3 Slide-shift animation

When a bay ships and there's >0 remaining visible bays, the bays to
the right of the cleared slot animate left to close the gap.
`AnimatedPositioned` keyed on the bay's slot index, 250ms easeOutCubic.

### 5.4 Arrival animation

```
1. New bay container slides in from off-screen-right at -800px → 0
   over 400ms easeOutCubic. Just the empty bay frame, no crates yet.
2. Once the container settles, crates "drop in" from y=-60px to y=0
   in a stagger (each crate 50ms later than the previous) with a small
   elasticOut bounce. Total crate-drop time: ~300ms.
3. SFX: existing `playCratePickup` (clack/click vibe) on each crate
   drop, OR a single `playSlide` on the bay-container slide.
4. Haptic: light tap when the bay container settles.
```

### 5.5 LOADING DOCK banner update

When a bay ships, its target color slot in the LOADING DOCK banner gets
a ✓ briefly (already implemented) and then disappears, and the NEW
arriving bay's target color appears in its place. The banner shows
"what's currently on the belt" rather than "what the whole level is."

---

## 6. Win Condition Rewrite

**Old:** all bays on screen are single-color full → level complete.

**New:** `baysShipped == totalDeliveries` AND no bay is in-progress on
screen (i.e., the queue is empty AND the visible bays are all
shipped/empty).

Edge case: the last `numEmptyBays` worth of bays on screen are workspace
slots that never had a delivery assigned. Those don't need to ship; the
level wins when the last delivery ships.

---

## 7. Wrinkle Layering (Post-Seed Additives)

The current generator's `applySpecialBlocks` already does this for
frozen/locked/fragile/priority/time-bomb/double-color — apply AFTER the
clean seed is generated. We keep that pattern but reframe it:

- Each delivery (pre-queued or visible) gets the post-seed pass.
- Probabilities scale per delivery, not per level. A `totalDeliveries=20`
  level with `fragileProb=0.10` averages 2 fragile crates total.
- Gravity-flip is a per-level wrinkle (not per-delivery) — toggles every
  N moves whether the wrinkle is in the level config.
- Conveyor-drift (if we still want this) becomes "every N moves a random
  visible bay gets bumped right one slot in the queue, the next delivery
  arrives a bay early."
- Oversized crates: 2-slot layers; can appear on any delivery. Generator
  needs slotSpan-aware reverse-construction (slightly more complex —
  defer until base mechanic ships).

---

## 8. Implementation Phases

Each phase = one or a few cron iterations. The cron prompt is updated to
work through these in order.

| Phase | Deliverable | Files | Est. iters |
|---|---|---|---|
| **A. Spec** | This document committed | `docs/conveyor-mechanic-spec.md` | 1 (done) |
| **B. Seed rewrite** | `lib/services/conveyor_seed.dart` + unit tests; old generator stays alive in parallel | `conveyor_seed.dart`, `test/services/conveyor_seed_test.dart` | 1 |
| **C. Delivery queue** | `ConveyorLevel` state on `GameState`; ship-off triggers next-delivery pull; old win condition still active | `game_state.dart`, `level_generator.dart` (proxy to conveyor_seed for now) | 2 |
| **D. Ship/arrive VFX** | Animations land; sound + haptic + cash popup | `game_board.dart`, `widgets/conveyor_ship_anim.dart`, `widgets/conveyor_arrive_anim.dart` | 2-3 |
| **E. Layout refactor** | 3×2 grid → horizontal carousel of N visible bays; LOADING DOCK shows current bays only | `game_board.dart`, `loading_dock_banner.dart` | 1-2 |
| **F. Win condition + level config** | New `configForLevel` + new win check + new `_onLevelComplete` flow | `level_generator.dart`, `game_screen.dart`, `models/game_state.dart` | 1 |
| **G. Wrinkle re-layering** | Re-route existing wrinkles to per-delivery additives | `conveyor_seed.dart`, `level_generator.dart` | 1-2 |
| **H. Cleanup** | Remove old generator + `applySpecialBlocks` path; delete `_isSolvable` BFS + flaky tests | `level_generator.dart`, `test/level_generator_test.dart` | 1 |

**Total: ~11-14 cron iterations** at 15-min cadence = 3-4 hours of
autonomous work, assuming each iter is a single focused commit.

---

## 9. Backward Compat

The old generator (`LevelGenerator.generateLevelWithPar`) stays alive
through phases B-G. Each phase's commit is a SMALL DIFF that can be
rolled back if it breaks the existing game. Once phase H lands and the
new generator is the only path, the old one is `git rm`'d in one final
cleanup commit.

The 6 working wrinkles (frozen / locked / fragile / priority / time-bomb
/ double-color) are tested and stay working through the transition.

---

## 10. Open Questions for Steve

1. **Cash payout per shipped bay** — flat amount or scaled by level?
   Suggest: scaled by base cash × `numColors` × `bayDepth` so deeper /
   harder bays pay more.
2. **What happens if the player drags a NOT-fully-sorted bay's crates
   out and the bay becomes empty?** Today an empty bay is workspace. In
   the conveyor model, do empty bays auto-ship-and-arrive? Suggest:
   empty bays stay as workspace; only FULL-SORTED bays ship.
3. **What happens during a multi-bay chain (clear two in quick
   succession)?** Suggest: queue ship-offs sequentially with their own
   animations rather than overlap.
4. **Should the LOADING DOCK banner show the FULL LEVEL queue or just the
   visible bays?** Suggest: visible only, with a `5/20` counter for
   total progress.
5. **Should pending deliveries be visible in a "next up" peek lane to the
   right?** Could be cool but adds complexity. Suggest: NO for v1, see
   if players ask.

These can be answered post-implementation if needed. Defaults above are
in the spec.

---

## END OF SPEC

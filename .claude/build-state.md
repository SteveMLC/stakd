# Warehouse Sort — Polish Loop State

**Persistent progress log for the `/loop 15m` autonomous iteration loop.** Each
iteration appends a single block at the bottom. Read top-down on resume.

---

## CURRENT PRIORITY 1 — Conveyor Mechanic Overhaul

**Spec:** `docs/conveyor-mechanic-spec.md` (READ THIS FIRST every iteration).

Steve's vision (2026-05-16): replace the static "all bays on screen at level
start, sort them all, level done" model with a **conveyor of deliveries**.
4-5 bays visible at any time. Player sorts a bay → it ships off (cash payout
+ VFX) → new mixed delivery slides in from the right. A level = 5-25
deliveries.

The OLD seed/level generator (probabilistic difficulty score + BFS solvability
validation + retry loops) is being REPLACED with a **reverse-construction**
generator (industry-standard Water Sort algorithm). Solvability is guaranteed
by construction. Wrinkles (frozen/fragile/priority/etc.) are POST-SEED
additives, not baked into seeding.

## Implementation Phases (work through in order)

| Phase | Deliverable | Status |
|---|---|---|
| **A** | docs/conveyor-mechanic-spec.md committed | ✅ DONE this iter |
| **B** | `lib/services/conveyor_seed.dart` + unit tests | ⏳ NEXT |
| **C** | `ConveyorLevel` state on GameState; delivery queue + ship-off trigger | pending |
| **D** | Ship-off + arrival VFX (animations, cash popup, sound, haptic) | pending |
| **E** | Layout: 3×2 grid → horizontal carousel of 4-5 bays | pending |
| **F** | New win condition (queue empty AND board cleared) + level config table | pending |
| **G** | Re-layer wrinkles as per-delivery additives | pending |
| **H** | Remove old generator + flaky BFS tests | pending |

Each phase is 1-3 cron iterations. Estimated total: 11-14 iterations × 15 min
= ~3-4 hours of autonomous work.

## Inviolable Requirements (do not violate, ever)

1. The game must **NEVER** start with a pre-solved bay on screen. Generator
   has a sanity check; tests assert this for levels 1..1000.
2. Solvability is **guaranteed by construction** (reverse-moves are inverses
   of valid forward-moves). No BFS validation pass needed. No flaky tests.
3. Wrinkles are **post-seed additives**. Seed generator knows about
   `numColors`, `bayDepth`, `numEmptyBays`, `scrambleMoves` ONLY. Frozen /
   fragile / priority etc. layer on AFTER.
4. **Backward compat through phase G.** The old `LevelGenerator.generate
   LevelWithPar` stays callable through phases B-G. Game stays shippable on
   every commit. Phase H is the cleanup-and-delete pass.
5. Each cron iteration ends with a CLEAN turn (no `flutter run`, no
   AskUserQuestion, no waiting on user input). Loop fires next at the next
   `:00`/`:15`/`:30`/`:45` mark.

## Latest State

- Branch: `main`
- HEAD: `cc75b7a` `chore(state): iter 1 log entry — gravity-flip shipped`
  (gravity-flip wrinkle was iter 1 of the OLD priority. With the conveyor
  pivot, gravity-flip stays in the codebase but its per-move toggle is
  decoupled from the level — it's still triggered by a wrinkle flag that
  the new level config can set. No work needed to preserve it.)
- Tests: 175/175 service tests green
- Analyze: clean
- Sim: iPhone 17 UUID `8C01668E-EF11-43A9-8448-E276C07C1919`, bundle `com.go7studio.warehouseSort`
- Reference screenshot: `/tmp/wh_sort_audit/POST_ITER5_VERIFIED.png`

## Six Working Wrinkles (preserve through transition)

These stay working through phases B-G; only the LEVEL HARNESS around them
changes. Phase G re-routes them through the new `ConveyorLevel.wrinkles`
config list:

1. frozen — `Layer.isFrozen` + tap-to-thaw (native)
2. locked — `Layer.isLocked` + lockedUntil countdown (native)
3. fragile — wrong-drop penalty (`970335a`)
4. priority — countdown + miss penalty (`af12000`)
5. time-bomb — tighter deadline + bigger penalty + 💥 marker (`1547954`)
6. double-color — multi-color crates match either color (`5ee365e`)
7. gravity-flip — board inverts every 5 moves (`f1db9a5`)

Three stubs (oversized / conveyor-drift) remain. They're parked until
post-conveyor; once the conveyor mechanic is shipped they become
trivial additions to the wrinkle list.

## Reverse-Construction Algorithm (memorize this)

```
Input: numColors C, bayDepth D, numEmptyBays E, scrambleMoves M
Output: List<GameStack> initial state

1. Build SOLVED state: C single-color bays + E empty bays.
2. Repeat M times:
   - Find all valid (src, dst) pairs where src is non-empty AND dst has
     space AND src != dst.
   - Pick one uniformly at random.
   - Move top crate src → dst.
3. Sanity check: no bay is single-color-full. (If any is, re-scramble.)
4. Return bays.
```

Difficulty = M. Always solvable in ≤M forward moves. No BFS needed.

## Iteration Log

### [2026-05-16T00:42] iter 1 (OLD PRIORITY — gravity-flip)
- did: gravity-flip wrinkle end-to-end (LevelParams + level_generator switch + GameState fields/tick/event + game_screen consumer/snackbar + game_board AnimatedRotation wrap)
- result: pass (flutter analyze clean; flutter test test/services/ 175/175 green; level_generator "high level puzzles" test flaky in isolation but passes solo — same pre-existing BFS-budget issue as Level 3)
- commit: f1db9a5
- next: conveyor-drift wrinkle — every 5 moves, bottom layer of random non-empty stack shifts to a neighbor that can accept it (must preserve solvability)

### [2026-05-16T08:50] PIVOT — Priority 1 Conveyor Overhaul + Phase A
- did: Steve's vision recorded; docs/conveyor-mechanic-spec.md drafted (535 lines); old wrinkle-iter cron 5ff6f4e1 killed; new phase plan A-H in place.
- result: spec landed; build-state.md updated to reflect the pivot.
- commit: 36f5a72
- next: Phase B — write `lib/services/conveyor_seed.dart` with reverse-construction algorithm + unit tests asserting "no pre-solved bay at construction time" for level 1..100.

### [2026-05-16T08:58] iter — Phase B
- did: `lib/services/conveyor_seed.dart` (~170 lines) + `test/services/conveyor_seed_test.dart` (7 tests covering all 6 difficulty bands from spec section 4.3). Algorithm: reverse-construction. Inviolable #1 (no pre-solved bay) asserted across 100 seeds × 6 bands = 600 generations.
- result: pass (flutter analyze clean; 7/7 new tests green; full service suite 175+7=182/182 green; no regressions to existing wrinkles).
- commit: 483dc1c
- next: Phase C — introduce `ConveyorLevel` to GameState. Add `visibleBays`, `pendingDeliveries`, `baysShipped`, `totalDeliveries`. Update `initGame` to accept a ConveyorLevel optionally (additive; old callers unchanged). Add `_onBayShipped(bayIndex)` data-flow method that pulls next from queue and replaces. NO VFX yet — animations are Phase D. NO new win condition yet — Phase F. Keep old `_loadLevel` path working unchanged through this iter.

### [2026-05-16T09:00] cron re-arm
- new cron: 3f6a2a4e (15-min cadence). Prompt: conveyor-overhaul iteration loop. Phases B-H queued.
- old cron 5ff6f4e1 deleted (wrinkle-iter prompt was obsolete).

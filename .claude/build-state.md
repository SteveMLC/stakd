# Warehouse Sort — Polish Loop State

**Persistent progress log for the `/loop 15m` autonomous iteration loop.** Each
iteration appends a single block at the bottom. Read top-down on resume.

---

## Current Goal

Ship Warehouse Sort to a state where:

1. All 8 district wrinkles work as real gameplay (frozen + locked + fragile +
   priority + time-bomb + double-color **DONE**; remaining stubs:
   **gravity-flip**, **conveyor-drift**, **oversized**).
2. `flutter analyze` stays clean (no warnings — zen-garden ghost cleared in
   commit `efb7896`).
3. `flutter test test/services/` stays at **175/175** green.
4. In-game visual matches the Lovart reference baseline at
   `/tmp/wh_sort_audit/POST_ITER5_VERIFIED.png`: glass-tube bays, LOADING DOCK
   target panel, hydraulic steel-blue pressure gauge, unified inline action
   bar, 3-zone top HUD.

When all three stub wrinkles are live AND analyze + tests stay green, log
`STOP_REASON: all-wrinkles-shipped` and stop iterating.

## Latest State (as of bootstrap)

- Branch: `main`
- HEAD: `efb7896` `chore(cleanup): purge stale Stakd / SortBloom / Zen Garden references`
- Tests: 175/175 service tests green
- Analyze: clean
- Sim: iPhone 17 UUID `8C01668E-EF11-43A9-8448-E276C07C1919`, bundle `com.go7studio.warehouseSort`
- Reference screenshot: `/tmp/wh_sort_audit/POST_ITER5_VERIFIED.png`

## Wrinkle Implementation Templates (read before touching the stubs)

The pattern for any new wrinkle, shipped twice already (fragile = `970335a`,
priority = `af12000`, time-bomb = `1547954`, double-color = `5ee365e`):

1. **Layer field/flag** in `lib/models/layer_model.dart` if it's a crate-level
   mechanic, OR GameState field if it's a board-level mechanic. Add to
   `copyWith`, `toJson`, `fromJson`. Factory if needed.
2. **`LevelParams` field** in `lib/utils/constants.dart`.
3. **Switch entry** in `lib/services/level_generator.dart`'s `paramsForLevel`
   that bumps the probability when the wrinkle is in the district's wrinkle
   list. The district pool is already in `lib/services/district_service.dart`
   (`wrinklePool` constant).
4. **Spawn** in `applySpecialBlocks` (crate-level) or board-tick logic in
   `GameState.completeMove()` (board-level).
5. **Render** in `lib/widgets/layer_widget.dart` (crate) or
   `lib/widgets/game_board.dart` (board).
6. **Event surface** in `lib/screens/game_screen.dart`'s `_handleGameStateChange`
   if penalty-based: snackbar + haptic + sfx.
7. **Payout deduction** in `_onLevelComplete` if penalty-based.
8. **Tests** if you touched logic.

### gravity-flip (next target)

Per `PROMPT_polish.md`: add a `_gravityFlipped` bool on GameState that toggles
every 5 moves when the wrinkle is active. In `game_board.dart`, wrap the
stacks Column in `Transform(transform: Matrix4.identity()..scale(1.0, -1.0))`
when the flag is true. Snackbar + medium haptic on each flip. New
`LevelParams.gravityFlipActive: bool = false`. Wire the case in `paramsForLevel`'s
switch.

### conveyor-drift

Every 5 moves, the bottom layer of a random non-empty stack shifts to the
bottom of a neighbor. New `GameState._applyConveyorDrift()` from
`completeMove()` when wrinkle active. **CRITICAL**: must NEVER break
solvability — pick a destination whose existing layers can accept the moved
layer (top color matches or destination is empty).

### oversized

Add `slotSpan: int = 1` to Layer (default 1; oversized = 2). Update
`GameStack.isFull` / `canAccept` / `withLayerAdded` to multiply by span. Render
in `game_board.dart`'s layer builder by passing `height: GameSizes.layerHeight * 2`
for span=2. **Depth math is load-bearing** — read all `test/models/` carefully
before touching.

---

## Iteration Log

(append below)

### [2026-05-16T00:42] iter 1
- did: gravity-flip wrinkle end-to-end (LevelParams + level_generator switch + GameState fields/tick/event + game_screen consumer/snackbar + game_board AnimatedRotation wrap)
- result: pass (flutter analyze clean; flutter test test/services/ 175/175 green; level_generator "high level puzzles" test flaky in isolation but passes solo — same pre-existing BFS-budget issue as Level 3)
- commit: f1db9a5
- next: conveyor-drift wrinkle — every 5 moves, bottom layer of random non-empty stack shifts to a neighbor that can accept it (must preserve solvability)

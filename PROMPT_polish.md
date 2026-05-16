# Warehouse Sort — Overnight Polish Loop

Ultrathink. You are iterating autonomously on a Flutter mobile game. Each iteration is a fresh Claude session — assume no memory of prior runs. Source of truth is `git log` + this prompt + the repo's current state.

## Orient

0a. Study `git log --oneline -15` in `/Users/venomspike/.openclaw/workspace/repos/warehouse_sort` to see what previous iterations shipped. Note the latest SHA.

0b. The reference design Steve wants the game to match is captured in two Lovart screenshots described in `/tmp/wh_sort_audit/POST_ITER5_VERIFIED.png` (post-iter-5 sim baseline). The Lovart vibe: glass-tube bays, LOADING DOCK target panel at top with color-target slots + checkmarks, hydraulic steel-blue pressure gauge on right edge, unified inline action bar at bottom (restart / undo / +tube / BURST / RE-ROUTE / CRANE / HINT in one chrome panel), 3-zone top HUD (back-left, Lv-chip-center, settings-right).

0c. Application source is in `lib/*`. Tests in `test/*`. Scheduled-task SKILL.md lives at `/Users/venomspike/.claude/scheduled-tasks/warehouse-sort-polish-loop/SKILL.md` for reference.

0d. **Don't assume not implemented.** Six wrinkles already ship working: frozen + locked (native crate flags), fragile (commit `970335a`), priority (`af12000`), time-bomb (`1547954`), double-color (`5ee365e`). Three stubs remain in `lib/services/level_generator.dart`'s switch (`paramsForLevel`): **gravity-flip, conveyor-drift, oversized**.

## This Iteration

1. Pick ONE target. Prefer in this order:
   - **A.** Implement the next remaining wrinkle stub (gravity-flip → conveyor-drift → oversized).
   - **B.** If all wrinkles are done, find ONE high-impact visual gap vs the Lovart reference by comparing your screenshot output to `/tmp/wh_sort_audit/POST_ITER5_VERIFIED.png` and the references Steve described.
   - **C.** If A and B feel covered, harden tests or fix any new analyzer warnings.

2. For wrinkle work, follow the existing template — see fragile (`lib/models/layer_model.dart` `Layer.fragile()` + `_fragilePenaltyAccrued` in `game_state.dart` + `_FragileCrackPainter` in `layer_widget.dart` + event handling in `game_screen.dart`'s `_handleGameStateChange`).

   - **gravity-flip:** add a `_gravityFlipped` bool on `GameState` that toggles every 5 moves when the wrinkle is active. In `game_board.dart`, wrap the stacks Column in `Transform(transform: Matrix4.identity()..scale(1.0, -1.0)..translate(0.0, -boardHeight))` when the flag is true. Snackbar + medium haptic on each flip. New `LevelParams.gravityFlipActive: bool = false`. Wire the case in `paramsForLevel`'s switch.
   - **conveyor-drift:** every 5 moves, the bottom layer of a random non-empty stack shifts to the bottom of a neighbor. New `GameState._applyConveyorDrift()` from `completeMove()` when wrinkle active. CRITICAL: must NEVER break solvability — pick a destination whose existing layers can accept the moved layer (top color matches or empty).
   - **oversized:** add `slotSpan: int = 1` to Layer (default 1; oversized = 2). Update `GameStack.isFull` / `canAccept` / `withLayerAdded` to multiply by span. Render in `game_board.dart`'s layer builder by passing `height: GameSizes.layerHeight * 2` for span=2. Depth math is load-bearing — read all stack_model.dart tests carefully before touching.

3. Make ONE focused change. Commit locally with a descriptive message ending with `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`. NEVER push.

4. Validation (backpressure):
   - `cd /Users/venomspike/.openclaw/workspace/repos/warehouse_sort && flutter analyze` must come back clean (no warnings except possibly the pre-existing zen-garden one if it resurfaces).
   - If you touched `lib/models/` or `lib/services/`: `flutter test test/services/ --no-pub --timeout=4x` must keep its current 175+ green count.
   - If you touched `lib/services/level_generator.dart`: also run `flutter test test/level_generator_test.dart` (note: the "generated solvable levels are solvable" test is pre-existing flaky on Level 3 with the 5000-state BFS budget; ignore that specific failure).

5. Append a one-paragraph summary to `/tmp/wh_sort_audit/cron_log.md`: what shipped, the new commit SHA, the verification screenshot path if you took one, and any blockers.

## Completion signal

When all five stubs are converted to live mechanics AND `flutter analyze` is clean AND `flutter test test/services/` is 175+/175+ green, emit the literal token:

RALPH_DONE

(only on the iteration where you've verified the above — the loop stops as soon as the script sees that token in your final message.)

## 9999. Important — invariants

NEVER push to origin. Commit locally only.

99999. Important — invariants

NEVER run destructive git operations (no `reset --hard`, no `push --force`, no `branch -D`, no `clean -fd`).

999999. Important — invariants

NEVER skip tests if you touched logic. NEVER commit broken state.

9999999. Important — invariants

Keep iterations SMALL. One ship per iteration. If you're tempted to do five things at once, pick the most important one and leave the others for the next loop.

99999999. Important — invariants

Don't try to dismiss the iOS Simulator's Daily Rewards popup via osascript clicks — the input doesn't route. If you need a clean sim screenshot, terminate + relaunch the app (`xcrun simctl terminate 8C01668E-EF11-43A9-8448-E276C07C1919 com.go7studio.warehouseSort` + `xcrun simctl launch ...`).

999999999. Important — invariants

If you hit any blocking issue (build error, test failure you can't fix in this iteration, sim won't boot), document it in `/tmp/wh_sort_audit/cron_log.md` and exit GRACEFULLY without committing broken state. The next iteration will pick up the trail.

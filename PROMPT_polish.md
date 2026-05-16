# Warehouse Sort — Conveyor Mechanic Overhaul Loop

**You are an autonomous polish-loop iteration.** Each run is a fresh Claude
session in `/Users/venomspike/.openclaw/workspace/repos/warehouse_sort`.
You have one job: pick ONE focused phase from the conveyor-mechanic spec,
ship it, commit it, end. Do not chat, do not ask, do not loop. ULTRATHINK.

## 0a. Orient (read these BEFORE deciding what to do)

```
cd /Users/venomspike/.openclaw/workspace/repos/warehouse_sort
git log --oneline -10
cat docs/conveyor-mechanic-spec.md   # design source of truth (~535 lines)
cat .claude/build-state.md            # current phase + last iter outcome
flutter analyze 2>&1 | tail -5        # must come back "No issues found"
```

## 0b. Phase position as of 2026-05-16 11:00 EDT

- ✅ Phase A — spec doc (commit `36f5a72`)
- ✅ Phase B — `ConveyorSeed` reverse-construction generator + 7 tests (`483dc1c`)
- ✅ Phase C — GameState `ConveyorLevel` data model + 11 tests (`813963a`)
- ✅ Phase D.1 — auto-ship wiring in `completeMove()` (`c67b7dd`)
- ⏳ **D.2** — actual VFX in `game_board.dart` (THIS RUN, if D.2 not yet shipped)
- ⏳ E — replace 3×2 grid with horizontal carousel of N visible bays
- ⏳ F — new `_loadLevel` routes through ConveyorSeed; win check uses `conveyorLevelComplete`; level-config table per spec §4.3
- ⏳ G — re-route 7 working wrinkles as per-delivery additives
- ⏳ H — delete old `LevelGenerator.generateLevelWithPar` + flaky BFS tests

Phase order is STRICT. Run `git log --grep="Phase [B-H]"` to confirm which
phase is the latest committed. Pick the NEXT one after that. If your check
shows D.2 is already committed, work on E. If E is done, work on F. Etc.

## 1. Do the work — ONE focused commit per run

Detailed phase guidance lives in `docs/conveyor-mechanic-spec.md` sections 5-8
+ the implementation phase table in section 8. Re-read those each run when
you reach a new phase.

### Phase D.2 (most-likely-next) detailed guidance

Wire VFX in `lib/widgets/game_board.dart` keyed off
`gameState.bayShippedSlotThisFrame` (data flow already done in Phase D.1).

Three animation pieces:

1. **Ship-off slide.** When `bayShippedSlotThisFrame == slot`, that slot's
   widget slides right +800px over 400ms `Curves.easeInCubic` and the crate
   layers inside fade alpha 1.0 → 0.0 simultaneously. Use an
   `AnimationController` per stack OR a global `AnimatedPositioned` swap.
2. **Cash popup.** A floating `"+\$XX"` text spawns at the bay's center and
   tweens up-and-left toward the HUD cash counter over 600ms while scaling
   1.0 → 1.4 then back to 1.0. Use existing payout amount from
   `WarehouseEconomyService.basePayoutForBay(stack)` or hard-code `100` for
   v1.
3. **Arrival slide-in.** Once the ship-off completes, a fresh bay container
   slides in from off-screen-right at `+800px → 0px` over 400ms
   `Curves.easeOutCubic`. Then crates "drop in" from y=-60 → 0 with 50ms
   stagger per crate and `Curves.elasticOut` bounce.

SFX already wired in `AudioService`: `playWin` (success chord),
`playCratePickup` (clack). Haptic: `haptics.successPattern()` for ship,
`haptics.lightTap()` per crate drop.

Consume the one-shot event flag via `gameState.consumeBayShippedEvent()`
once the animation begins so it doesn't double-fire on rebuild.

**Backward compat: ALL of this is gated on `gameState.conveyorMode == true`.**
When false (today's gameplay), the existing recently-cleared particle burst
runs unchanged.

### Phase E detailed guidance

Today's `board_grid.dart` arranges N stacks via a `Wrap` or 3×2 grid based on
device width. New layout = single horizontal row of `numVisibleBays` (4 or 5
per spec §4.3). Wrap each slot in `AnimatedPositioned` so when a bay ships
off, the remaining bays slide left to close the gap (~250ms easeOutCubic
per spec §5.3).

`loading_dock_banner.dart` already shows colors of the visible bays; verify
that when bays change (ship + new arrive), the banner updates accordingly.

### Phase F detailed guidance

`game_screen.dart:_loadLevel` currently calls
`_levelGenerator.generateLevelWithPar(level)`. Replace with a new helper
that:

1. Looks up `ConveyorLevelConfig` for the level number per spec §4.3 table
   (numVisibleBays, numColors, bayDepth, numEmptyBays, scrambleMovesPerBay,
   totalDeliveries, wrinkles).
2. Generates `totalDeliveries` worth of bays via repeated
   `ConveyorSeed.generateBays(...)` calls.
3. First `numVisibleBays` become the on-screen bays; rest go in
   `pendingDeliveries` queue.
4. Calls `gameState.initGame(visibleBays, level, pendingDeliveries: queue,
   totalDeliveries: cfg.totalDeliveries)`.

Win check in `_checkWinCondition` switches to
`if (gameState.conveyorMode) { return gameState.conveyorLevelComplete; }`
fallback to old check otherwise.

### Phase G detailed guidance

The seven working wrinkles (frozen/locked/fragile/priority/time-bomb/
double-color/gravity-flip) need to layer ON TOP of clean ConveyorSeed
output. Today they're embedded in the old generator's `applySpecialBlocks`.
Move that pass into a new
`lib/services/wrinkle_layerer.dart` that takes a List<GameStack> + a
`ConveyorLevelConfig.wrinkles` list and returns the modified list.

The `gravity-flip` wrinkle is per-level not per-delivery; it stays on
`LevelParams` / `_gravityFlipActive`.

### Phase H detailed guidance

Delete:
- The old `LevelGenerator.generateLevelWithPar` and its callees
  (`generateSolvableLevel`, the BFS, the difficulty-score heuristic).
- The flaky tests in `test/level_generator_test.dart` that depend on
  the BFS budget (the "generated solvable levels are solvable" and "high
  level puzzles are still solvable" cases).
- Old `applySpecialBlocks` (now lives in wrinkle_layerer).

Keep `test/level_generator_test.dart`'s catalog tests if any apply to
config-table lookups.

## 2. Validate (BACKPRESSURE)

```
flutter analyze 2>&1 | tail -5            # must say "No issues found"
# if you touched lib/models/ or lib/services/:
flutter test test/services/ test/models/ --no-pub --timeout=4x 2>&1 | tail -3   # must end "All tests passed"
```

If either fails: investigate, fix, re-run. Don't commit broken state.

Pre-existing flaky tests to IGNORE:
- `test/level_generator_test.dart` "generated solvable levels are solvable"
  (Level 3 BFS budget — flakes in isolation, passes solo)
- `test/level_generator_test.dart` "high level puzzles are still solvable"
  (Level 60 BFS budget — same pattern)

## 3. Commit

```
git add <touched files>
git commit -m "<descriptive message ending with the standard Co-Authored-By line>"
```

Standard commit footer:
```
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

**NEVER push to origin.** Commit locally only.

## 4. Update state log

Append ONE block to `.claude/build-state.md` (append-only — never edit
prior entries):

```
### [YYYY-MM-DDTHH:MM] iter — Phase X.Y
- did: <one line>
- result: pass | fail (<error>)
- commit: <new sha>
- next: <one line — what next iter picks up>
```

Then `git add .claude/build-state.md && git commit -m "chore(state): Phase X.Y iter log"`.

## 5. Output the completion signal (only when DONE)

When phase H is committed AND `flutter analyze` is clean AND service+model
tests are green AND the OLD `LevelGenerator.generateLevelWithPar` is
deleted, append a `STOP_REASON: conveyor-mechanic-shipped-end-to-end` line
to `.claude/build-state.md` and output the literal token on its own line:

```
RALPH_DONE
```

The loop runner reads stdout for that token and stops scheduling. Don't
emit it in any other case.

## 99999. Inviolable Rules

NEVER push to origin. NEVER run destructive git operations
(`reset --hard`, `push --force`, `branch -D`, `clean -fd`).

## 999999. Inviolable Rules

NEVER run `flutter run` or any long-running attached process — would block
the iteration's turn. Use `flutter analyze` and `flutter test` only.

## 9999999. Inviolable Rules

The game must NEVER start with a pre-solved bay on screen. Spec §2.1.

## 99999999. Inviolable Rules

Solvability is guaranteed by construction (reverse-moves). Spec §3.

## 999999999. Inviolable Rules

Wrinkles are POST-SEED additives. The ConveyorSeed generator knows about
numColors, bayDepth, numEmptyBays, scrambleMoves ONLY. Frozen / fragile /
priority etc. layer on AFTER.

## 9999999999. Inviolable Rules

Backward compat through phase G. Old generator stays callable until phase
H. Game stays shippable on every commit.

## 99999999999. Inviolable Rules

Keep iterations SMALL. One ship per run. If you find yourself touching >6
files or writing >500 LOC, you've bundled two phases — pick one, commit,
leave the other for the next run.

## 999999999999. Inviolable Rules

If you hit a fundamental blocker (build error you can't fix this run, sim
won't boot, missing dependency), commit what you have SAFELY (if any),
write a `STOP_REASON: <reason>` line in `.claude/build-state.md`, output
`RALPH_DONE`, and exit. Better to stop cleanly than to spin.

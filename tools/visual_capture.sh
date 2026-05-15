#!/usr/bin/env bash
#
# Visual-capture orchestrator. Runs the integration test that walks
# the app from boot → home → contracts → in-game, while a parallel 1Hz
# loop screenshots the simulator. After the test exits, we tag each
# captured frame with its closest state marker timestamp by scanning
# the test log.
#
# Output:
#   /tmp/wh_visual_capture/<timestamp>/
#     ├── frames/0001.png  (raw 1Hz timeline)
#     ├── frames/0002.png
#     ├── ...
#     ├── home.png          (state-tagged best frames)
#     ├── contracts.png
#     ├── in_game.png
#     └── test.log
#
# Usage: bash tools/visual_capture.sh [SIM_UUID]
#
# Default SIM_UUID is the iPhone 17 used by the rest of the workflow.

set -uo pipefail

SIM_UUID="${1:-8C01668E-EF11-43A9-8448-E276C07C1919}"
OUT_ROOT="/tmp/wh_visual_capture"
RUN_DIR="${OUT_ROOT}/$(date +%Y%m%d-%H%M%S)"
FRAMES_DIR="${RUN_DIR}/frames"
LOG_PATH="${RUN_DIR}/test.log"

mkdir -p "${FRAMES_DIR}"
echo "[visual_capture] writing to ${RUN_DIR}"

# Verify simulator is booted.
if ! xcrun simctl list devices booted | grep -q "${SIM_UUID}"; then
  echo "[visual_capture] booting simulator ${SIM_UUID}..."
  xcrun simctl boot "${SIM_UUID}" 2>/dev/null || true
  open -a Simulator
  sleep 5
fi

# Start the 1Hz screenshot loop.
echo "[visual_capture] starting 1Hz screenshot loop..."
(
  i=0
  while true; do
    fname=$(printf "%04d" "${i}")
    # Capture both the file AND the timestamp marker so we can align later.
    ts=$(date +%s.%N)
    xcrun simctl io "${SIM_UUID}" screenshot "${FRAMES_DIR}/${fname}.png" \
      >/dev/null 2>&1 \
      && echo "${ts} ${fname}.png" >> "${RUN_DIR}/frame_index.txt"
    i=$((i + 1))
    sleep 1
  done
) &
LOOP_PID=$!
echo "[visual_capture] screenshot loop pid=${LOOP_PID}"

# Run the integration test, capturing all stdout/stderr (the state
# markers we'll grep for live in this log).
echo "[visual_capture] running integration test..."
(
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
  flutter test integration_test/visual_capture_test.dart \
    -d "${SIM_UUID}" --timeout=4x 2>&1
) | tee "${LOG_PATH}"

# Stop the loop.
kill "${LOOP_PID}" 2>/dev/null || true
wait "${LOOP_PID}" 2>/dev/null

# Map state markers to frame timestamps. Each marker line has format:
#   VISUAL_CAPTURE_STATE_BEGIN: home
# But flutter test logs don't always include precise timestamps — we
# approximate by counting the relative position of the BEGIN marker
# in the test log and computing the matching frame timestamp using the
# test start time + offset.
echo "[visual_capture] tagging frames by state..."
python3 - <<PY
import re, os, time
from pathlib import Path

run_dir = Path("${RUN_DIR}")
log_path = run_dir / "test.log"
frame_index_path = run_dir / "frame_index.txt"

if not log_path.exists() or not frame_index_path.exists():
    print("missing log or frame index — bailing")
    raise SystemExit(0)

# Read frame timeline: each line is "<unix_ts> <filename>"
frames = []
for line in frame_index_path.read_text().strip().splitlines():
    parts = line.split(None, 1)
    if len(parts) == 2:
        frames.append((float(parts[0]), parts[1]))
if not frames:
    print("no frames captured")
    raise SystemExit(0)

# Read log; estimate state-begin times as a fraction of test runtime.
log_lines = log_path.read_text().splitlines()
states = []  # (state_name, line_index)
for i, line in enumerate(log_lines):
    m = re.search(r"VISUAL_CAPTURE_STATE_BEGIN:\s*(\S+)", line)
    if m:
        states.append((m.group(1), i))

if not states:
    print("no state markers found in log; frames left untagged")
    raise SystemExit(0)

# Estimate timestamp per state: each state's relative log-line position
# maps to a relative position in the frame timeline.
test_start = frames[0][0]
test_end = frames[-1][0]
total_lines = max(len(log_lines), 1)

for state_name, line_idx in states:
    frac = line_idx / total_lines
    target_ts = test_start + frac * (test_end - test_start)
    # Find closest frame.
    best = min(frames, key=lambda f: abs(f[0] - target_ts))
    src = run_dir / "frames" / best[1]
    dst = run_dir / f"{state_name}.png"
    try:
        import shutil
        shutil.copyfile(src, dst)
        print(f"  {state_name:30} ← {best[1]}")
    except FileNotFoundError:
        print(f"  {state_name:30} (frame missing)")

print(f"\nTagged frames: {run_dir}")
PY

echo "[visual_capture] DONE. Output: ${RUN_DIR}"
echo "[visual_capture] Inspect: open ${RUN_DIR}"

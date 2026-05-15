#!/usr/bin/env bash
#
# Visual-capture orchestrator (v2 — log-tail driven, no parallel loop).
#
# Runs the integration test that walks the app from boot → home →
# contracts → in-game. As each VISUAL_CAPTURE_STATE_BEGIN marker
# appears in the test stdout, immediately fires a single
# `xcrun simctl io screenshot` for that state, then waits for the
# matching END marker before moving on. No background screenshot
# loop = no concurrent simctl thrash = sim doesn't freeze.
#
# Output:
#   /tmp/wh_visual_capture/<timestamp>/
#     ├── home.png
#     ├── contracts.png
#     ├── in_game.png
#     └── test.log
#
# Usage: bash tools/visual_capture.sh [SIM_UUID] [TEST_FILE]

set -o pipefail  # NB: `set -u` (nounset) trips on empty bash arrays
                 # when accessed via "${arr[@]}" — disabled intentionally.

SIM_UUID="${1:-8C01668E-EF11-43A9-8448-E276C07C1919}"
TEST_FILE="${2:-integration_test/visual_capture_test.dart}"
OUT_ROOT="/tmp/wh_visual_capture"
RUN_DIR="${OUT_ROOT}/$(date +%Y%m%d-%H%M%S)"
LOG_PATH="${RUN_DIR}/test.log"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"

mkdir -p "${RUN_DIR}"
echo "[visual_capture] writing to ${RUN_DIR}"

# Verify simulator is booted.
if ! xcrun simctl list devices booted | grep -q "${SIM_UUID}"; then
  echo "[visual_capture] booting simulator ${SIM_UUID}..."
  xcrun simctl boot "${SIM_UUID}" 2>/dev/null || true
  open -a Simulator
  sleep 5
fi

# Start the integration test as a background process. Don't pipe to
# tee — write to a file and tail it ourselves so a slow consumer
# doesn't block the test.
echo "[visual_capture] starting integration test..."
(
  cd "${REPO_ROOT}"
  flutter test "${TEST_FILE}" \
    -d "${SIM_UUID}" --timeout=4x 2>&1
) > "${LOG_PATH}" &
TEST_PID=$!
echo "[visual_capture] test pid=${TEST_PID}"

# Tail the log looking for state markers. When BEGIN appears, wait
# 1.5s (let the pump catch up), screenshot once, mark seen.
declare -a SEEN_STATES=()
TIMEOUT_S=600
DEADLINE=$(($(date +%s) + TIMEOUT_S))

while kill -0 "${TEST_PID}" 2>/dev/null; do
  if [ $(date +%s) -gt ${DEADLINE} ]; then
    echo "[visual_capture] test exceeded ${TIMEOUT_S}s — killing"
    kill -9 "${TEST_PID}" 2>/dev/null
    break
  fi

  # Scan log for new BEGIN markers.
  if [ -f "${LOG_PATH}" ]; then
    while IFS= read -r line; do
      if [[ "${line}" =~ VISUAL_CAPTURE_STATE_BEGIN[[:space:]]+ts=[0-9.]+[[:space:]]+name=([A-Za-z0-9_]+) ]]; then
        state="${BASH_REMATCH[1]}"
        # Already captured?
        already=0
        for s in "${SEEN_STATES[@]}"; do
          if [ "${s}" = "${state}" ]; then already=1; break; fi
        done
        if [ "${already}" -eq 0 ]; then
          # Wait ~1.5s for the pump to render fresh frames, then snap.
          sleep 1.5
          echo "[visual_capture] capturing state: ${state}"
          xcrun simctl io "${SIM_UUID}" screenshot \
            "${RUN_DIR}/${state}.png" >/dev/null 2>&1 \
            && echo "  → ${RUN_DIR}/${state}.png" \
            || echo "  ✗ screenshot failed"
          SEEN_STATES+=("${state}")
        fi
      fi
    done < "${LOG_PATH}"
  fi

  sleep 0.5
done

wait "${TEST_PID}" 2>/dev/null
EXIT_CODE=$?
echo "[visual_capture] test exit code: ${EXIT_CODE}"

# Summary
echo ""
echo "[visual_capture] DONE. Captured ${#SEEN_STATES[@]} state(s):"
for s in "${SEEN_STATES[@]}"; do
  echo "  - ${s}"
done
echo "[visual_capture] Output: ${RUN_DIR}"

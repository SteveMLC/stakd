#!/usr/bin/env bash
# Walk the running warehouse_sort sim and capture every key screen state.
# Usage: bash tools/walk_app.sh [output_prefix]
#
# Output: PNG files in /tmp/wh_sort_audit/<prefix>_<state>.png
# Assumes the iPhone 17 sim (UUID below) is booted and the app is on home.
# Uses cliclick for taps; macOS-only.

set -euo pipefail

SIM_UUID="${SIM_UUID:-8C01668E-EF11-43A9-8448-E276C07C1919}"
PREFIX="${1:-walk_$(date +%H%M%S)}"
OUTDIR="/tmp/wh_sort_audit"
mkdir -p "$OUTDIR"

# Mac-screen coords for the simulator window. Computed from
#   pos=(733,37) size=(453x965), title bar ~28pt, sim res 1290x2796.
# Conversion: mac_x = 733 + (sim_x/1290)*453, mac_y = 65 + (sim_y/2796)*937
sim_to_mac() {
  local sx=$1 sy=$2
  printf "%d,%d" \
    "$((733 + sx * 453 / 1290))" \
    "$(( 65 + sy * 937 / 2796))"
}

shot() {
  local label=$1
  local out="$OUTDIR/${PREFIX}_${label}.png"
  xcrun simctl io "$SIM_UUID" screenshot "$out" >/dev/null 2>&1
  echo "  → $out"
}

tap() {
  local sx=$1 sy=$2 label=$3
  local coords
  coords=$(sim_to_mac "$sx" "$sy")
  echo ">> tap ($label) @ sim($sx,$sy) → mac($coords)"
  osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1 || true
  sleep 0.3
  cliclick "c:$coords" >/dev/null
  sleep 1.2
}

echo "▶ Walking warehouse_sort sim → $OUTDIR/${PREFIX}_*.png"

# Home screen baseline
shot "00_home"

# Tap PLAY → Contracts
tap 645 1820 "PLAY"
shot "01_contracts"

# Tap PLAY NEXT → in-game level 1
tap 645 855 "PLAY_NEXT"
shot "02_ingame"

# Tap a stack to select (sim x=440 y=550 = top-middle bay)
tap 440 550 "stack_select"
shot "03_pickup_state"

# Tap an empty/different stack to drop
tap 220 1100 "stack_drop"
shot "04_after_drop"

# Long-press a stack for multi-grab (cliclick supports d / u)
osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1
LP=$(sim_to_mac 645 550)
cliclick "dd:$LP" >/dev/null; sleep 0.8; cliclick "du:$LP" >/dev/null; sleep 0.5
shot "05_multigrab"

# Bring up the pause/settings menu (cog at top right)
tap 1170 195 "settings_cog"
shot "06_settings"

# Back to game
tap 90 195 "back_to_game"
shot "07_back_to_game"

# Restart level (bottom-left)
tap 320 2480 "restart"
shot "08_post_restart"

# Hint (bottom-right)
tap 945 2480 "hint"
shot "09_hint"

# Back to home (top-left)
tap 90 195 "back_to_home_1"
sleep 0.5
tap 90 195 "back_to_home_2"
shot "10_home_again"

# Daily Contract
tap 645 2070 "daily_contract_tile"
shot "11_daily"

# Calendar toggle
tap 1170 195 "daily_calendar_toggle"
shot "12_daily_calendar"

# Back to home
tap 90 195 "back_to_home_3"
shot "13_home_final"

# Achievements tile (bottom-left of meta grid)
tap 320 2380 "achievements_tile"
shot "14_achievements"

tap 90 195 "back_to_home_4"

# Leaderboards tile (bottom-right of meta grid)
tap 945 2380 "leaderboards_tile"
shot "15_leaderboards"

tap 90 195 "back_to_home_5"

# Forklift shop (right tile in row 1)
tap 945 2270 "forklift_shop_tile"
shot "16_forklift_shop"

tap 90 195 "back_to_home_6"

echo "✅ Walk complete. Screenshots: $OUTDIR/${PREFIX}_*.png"

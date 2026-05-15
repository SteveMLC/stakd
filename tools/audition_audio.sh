#!/usr/bin/env bash
# Audition each sound in the warehouse_sort bank through afplay.
# Steve listens + tells Walt which ones don't work — those get
# regen'd with an alternate Mixkit URL from docs/audio-sources.md
# or a different fetch source.
#
# Usage:
#   bash tools/audition_audio.sh        # play all in sequence
#   bash tools/audition_audio.sh tap    # play a single sound
#   bash tools/audition_audio.sh tap slide clear  # play subset
#
# Each sound is announced via `say` so Steve knows what he's hearing.
# 800ms gap between sounds so they don't run into each other.

set -u
SOUNDS_DIR="/Users/venomspike/.openclaw/workspace/repos/warehouse_sort/assets/sounds"

# Audit order — gameplay-frequency descending so the most-heard ones
# get listened to first.
ORDER=(
  tap
  slide
  crate_thump
  crate_pickup
  clear
  coin
  win
  levelup
  error
  klaxon
  powerup
  star_1
  star_2
  star_3
  power_sort_bomb
  streak_milestone
  forklift_idle
  music
)

play_one() {
  local name="$1"
  local path="$SOUNDS_DIR/${name}.mp3"
  if [ ! -f "$path" ]; then
    echo "  ✗ MISSING $path"
    return
  fi
  local size
  size=$(stat -f%z "$path" 2>/dev/null || stat -c%s "$path")
  echo ""
  echo "▶ $name   ($(printf '%d' $size) bytes)"
  # Announce via `say` so Steve hears the label first.
  say -v "Daniel" -r 220 "$name" 2>/dev/null
  afplay "$path"
  sleep 0.8
}

if [ "$#" -eq 0 ]; then
  echo "Auditioning ${#ORDER[@]} sounds (use Ctrl-C to stop)..."
  for s in "${ORDER[@]}"; do
    play_one "$s"
  done
else
  for s in "$@"; do
    play_one "$s"
  done
fi

echo ""
echo "Done. Flag bad sounds to Walt — he'll regen with an alternate"
echo "URL from docs/audio-sources.md or a different fetch source."

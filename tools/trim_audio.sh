#!/usr/bin/env bash
# Trim selected audio files to game-appropriate durations.
# The Mixkit downloads include decay tails that make UI sounds feel
# sluggish (1.15s tap = noticeably late, 2.69s error = painful).
# Uses ffmpeg to clip + fade-out so the trims don't pop.
#
# Source: assets/sounds/*.mp3
# Output (in-place after backup): same path
# Backup: /tmp/wh_audio_backup/<file>.mp3 (so trimming is reversible)

set -uo pipefail
SOUNDS="/Users/venomspike/.openclaw/workspace/repos/warehouse_sort/assets/sounds"
BACKUP="/tmp/wh_audio_backup"
mkdir -p "$BACKUP"

trim() {
  local name="$1" max_seconds="$2" fade_seconds="${3:-0.05}"
  local src="$SOUNDS/${name}.mp3"
  if [ ! -f "$src" ]; then
    echo "  ✗ MISSING $src"; return
  fi
  # Backup once
  if [ ! -f "$BACKUP/${name}.mp3" ]; then
    cp "$src" "$BACKUP/${name}.mp3"
  fi
  # Trim + fade. afade out covers the last `fade_seconds` of the
  # trimmed clip so the cut isn't a click.
  local fade_start
  fade_start=$(python3 -c "print(max(0, $max_seconds - $fade_seconds))")
  local tmp="$BACKUP/${name}.trimmed.mp3"
  ffmpeg -y -hide_banner -loglevel error \
    -i "$BACKUP/${name}.mp3" \
    -t "$max_seconds" \
    -af "afade=t=out:st=$fade_start:d=$fade_seconds" \
    -c:a libmp3lame -b:a 192k \
    "$tmp"
  mv "$tmp" "$src"
  local size
  size=$(stat -f%z "$src" 2>/dev/null || stat -c%s "$src")
  echo "  ✓ ${name}.mp3 trimmed to ${max_seconds}s (${size} bytes)"
}

# UI / fast-feedback sounds (need to be SHORT)
trim tap 0.18 0.04
trim error 0.40 0.08
trim slide 0.40 0.08
trim crate_thump 0.45 0.08
trim crate_pickup 0.20 0.04

# Star pops (need to be ~300ms each so the 450ms reveal interval reads)
trim star_1 0.55 0.10
trim star_2 0.55 0.10
trim star_3 0.65 0.12

# Streak claim (was 4.5s — half-second beat is right)
trim streak_milestone 0.80 0.15

# Coin (had decay tail)
trim coin 0.50 0.10

# Powerup
trim powerup 0.70 0.12

echo
echo "Trim done. Backups in $BACKUP — restore via:"
echo "  cp $BACKUP/*.mp3 $SOUNDS/"

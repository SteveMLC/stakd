#!/usr/bin/env bash
# Fetch warehouse_sort SFX from the curated manifest at
# docs/audio-sources.md — Mixkit + Freesound CC0 sounds Steve picked
# manually on 2026-05-13 (way better than the ElevenLabs regen pass
# which sounded muddy).
#
# Mixkit pages embed the MP3 inside an <audio> tag with <source src>.
# Pull the page HTML, grep the CDN URL, download the MP3.
#
# Output: /tmp/wh_audio_fetch/*.mp3
# After running, preview each + cp the good ones into assets/sounds/

set -uo pipefail
OUT="/tmp/wh_audio_fetch"
mkdir -p "$OUT"

# slot name → mixkit page URL (from docs/audio-sources.md)
declare -A SLOTS=(
  [tap]='https://mixkit.co/free-sound-effects/select-click/'
  [slide]='https://mixkit.co/free-sound-effects/fast-whoosh-transition/'
  [clear]='https://mixkit.co/free-sound-effects/achievement-bell/'
  [win]='https://mixkit.co/free-sound-effects/successful-horns-fanfare/'
  [error]='https://mixkit.co/free-sound-effects/losing-piano/'
  [coin]='https://mixkit.co/free-sound-effects/winning-a-coin-video-game/'
  [levelup]='https://mixkit.co/free-sound-effects/game-level-completed/'
  [powerup]='https://mixkit.co/free-sound-effects/quick-metal-transition-sweep/'
  [crate_thump]='https://mixkit.co/free-sound-effects/hard-pop-click/'
  [klaxon]='https://mixkit.co/free-sound-effects/basketball-buzzer/'
  [crate_pickup]='https://mixkit.co/free-sound-effects/modern-click-box-check/'
  [bay_complete]='https://mixkit.co/free-sound-effects/achievement-bell/'
  [star_1]='https://mixkit.co/free-sound-effects/relaxing-bell-chime/'
  [star_2]='https://mixkit.co/free-sound-effects/cooking-bell-ding/'
  [star_3]='https://mixkit.co/free-sound-effects/fairy-arcade-sparkle/'
  [power_sort_bomb]='https://mixkit.co/free-sound-effects/arcade-game-explosion/'
)

UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15'

fetch_one() {
  local slot="$1" page="$2"
  echo "[$(date +%H:%M:%S)] $slot ← $page"
  local html
  html=$(curl -sS -L -A "$UA" "$page")
  # Mixkit embeds the MP3 inside the page like:
  #   <audio ...><source src="https://assets.mixkit.co/active_storage/sfx/.../foo.mp3" type="audio/mpeg"></audio>
  # OR as data attributes on a button:
  #   data-audio-src="https://assets.mixkit.co/..."
  local mp3
  mp3=$(printf '%s' "$html" | grep -oE 'https://assets\.mixkit\.co/[^"]+\.mp3' | head -1)
  if [ -z "$mp3" ]; then
    # fallback: look for any .mp3 reference
    mp3=$(printf '%s' "$html" | grep -oE 'https://[a-zA-Z0-9./_-]+\.mp3' | head -1)
  fi
  if [ -z "$mp3" ]; then
    echo "  ✗ no MP3 URL found on page"
    return 1
  fi
  echo "    → $mp3"
  curl -sS -L -A "$UA" "$mp3" -o "$OUT/${slot}.mp3"
  local size
  size=$(stat -f%z "$OUT/${slot}.mp3" 2>/dev/null || stat -c%s "$OUT/${slot}.mp3")
  if [ "$size" -lt 1000 ]; then
    echo "  ✗ download too small ($size bytes) — likely failed"
    return 1
  fi
  echo "  ✓ ${slot}.mp3 ($size bytes)"
}

for slot in "${!SLOTS[@]}"; do
  fetch_one "$slot" "${SLOTS[$slot]}" || echo "  (skipped $slot)"
done

echo
echo "Files in $OUT:"
ls -lh "$OUT"

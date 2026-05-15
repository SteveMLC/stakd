#!/bin/bash
# Generate 11 warehouse-themed sound effects via ElevenLabs SFX API.
# Replaces the stock Kenney/WobbleBoxx CC0 sounds in assets/sounds/.
# Total cost ~$0.50 ($0.04 × 11). Run time ~3 min.

set -e

# ElevenLabs API key — pulled from Walt's workspace tooling.
# DO NOT commit this script with the key inline; it should be loaded
# from $ELEVENLABS_API_KEY at runtime.
: "${ELEVENLABS_API_KEY:?Set ELEVENLABS_API_KEY before running.}"

OUT=/tmp/wh_audio_gen
mkdir -p "$OUT"

gen() {
  local name="$1" dur="$2" prompt="$3"
  echo "[$(date +%H:%M:%S)] Generating $name.mp3 (${dur}s)..."
  local body
  body=$(python3 -c "import json,sys; print(json.dumps({'text': sys.argv[1], 'duration_seconds': float(sys.argv[2]), 'prompt_influence': 0.3}))" "$prompt" "$dur")
  local code
  code=$(curl -s -o "$OUT/$name.mp3" -w "%{http_code}" \
    -X POST "https://api.elevenlabs.io/v1/sound-generation" \
    -H "xi-api-key: $ELEVENLABS_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$body")
  if [ "$code" = "200" ]; then
    local size
    size=$(stat -f%z "$OUT/$name.mp3" 2>/dev/null || stat -c%s "$OUT/$name.mp3")
    echo "  OK  $name.mp3 ($size bytes)"
  else
    echo "  FAIL $name.mp3 (HTTP $code)"
    head -c 400 "$OUT/$name.mp3"; echo
  fi
}

gen tap          0.5 "Sharp metallic stamp on clipboard, single quick tap, crisp office sound, dry, no reverb"
gen slide        0.5 "Wooden crate sliding smoothly across a metal conveyor belt, short whoosh with scraping wood texture"
gen clear        0.6 "Single satisfying freight elevator ding bell, warehouse industrial chime, bright clear tone"
gen win          1.5 "Warehouse air horn blast followed by a small crowd cheering and applause, celebratory, victorious"
gen error        0.8 "Forklift reverse backup beeper, exactly three short electronic beep chirps, industrial warning"
gen coin         0.6 "Cash register ka-ching, classic till bell with coin clatter, satisfying reward sound"
gen levelup      1.8 "Industrial fanfare, rising klaxon horn sweep into triumphant brass stinger, warehouse celebration"
gen powerup      0.8 "Pneumatic piston whoosh hiss followed by a bright bell ding, mechanical power-up, factory air valve"
gen forklift_idle 1.2 "Idle forklift engine humming, low diesel rumble, smooth steady mechanical loop, no movement"
gen klaxon       1.0 "Heavy industrial warning klaxon alarm, single one-shot blast, deep loud factory alert horn"
gen crate_thump  0.5 "Heavy wooden crate landing hard on a stack of crates, single thump, solid wood impact, no echo"

echo
echo "[$(date +%H:%M:%S)] Done. Files in $OUT:"
ls -lh "$OUT"

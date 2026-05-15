#!/bin/bash
# Regenerate the 7 sounds Steve flagged as bad (2026-05-15).
# Rewritten prompts toward "polished mobile-game UI sound" rather
# than "literal warehouse field recording" — the latter produced
# muddy / oddly-timed output on the first pass.

set -e
: "${ELEVENLABS_API_KEY:?Set ELEVENLABS_API_KEY before running.}"

OUT=/tmp/wh_audio_gen
mkdir -p "$OUT"

gen() {
  local name="$1" dur="$2" prompt="$3"
  echo "[$(date +%H:%M:%S)] Generating $name.mp3 (${dur}s)..."
  local body
  body=$(python3 -c "import json,sys; print(json.dumps({'text': sys.argv[1], 'duration_seconds': float(sys.argv[2]), 'prompt_influence': 0.4}))" "$prompt" "$dur")
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

# tap: was "metallic clipboard stamp" — too dry / dull. Now a snappy
# mobile-UI click with a tiny ping.
gen tap 0.35 "Crisp short mobile game UI tap, light snappy click with a soft tonal ping, bright, dry, satisfying button press"

# coin: was "cash register ka-ching" — came out cheesy / long. Now
# a crystal coin chime, classic mobile game reward beat.
gen coin 0.45 "Bright crystal coin chime, single short metallic clink with a tiny sparkle, mobile game reward sound, satisfying, no reverb"

# crate_thump: was "wooden crate landing hard" — too muddy. Now a
# punchy wood thock for crate-on-stack feedback.
gen crate_thump 0.35 "Short percussive wooden thock, single crisp wood block impact, dry punchy game thud, no echo, no scrape"

# klaxon: was "heavy industrial alarm" — too long / intense. Now
# a quick warehouse alert horn beat.
gen klaxon 0.7 "Short warehouse warning horn, two quick deep brass alarm toots, factory alert signal, no echo, urgent but brief"

# levelup: was "rising klaxon into brass stinger" — got muddled. Now
# a bright cascading jingle.
gen levelup 1.4 "Triumphant level up jingle, bright bell chime cascade rising in pitch with sparkles, satisfying mobile game achievement reward, crystalline, no voices"

# win: was "air horn + crowd cheering" — crowd voices came out odd.
# Now a clean fanfare without voices.
gen win 1.6 "Bright musical victory fanfare, ascending bell-and-trumpet stinger, celebratory mobile game level-complete jingle, satisfying, joyful, no voices, no applause"

# music: was the legacy carry-over pad. ElevenLabs SFX max is 22s
# but a tight 22s ambient loop can carry an in-game session.
gen music 22 "Calm warehouse ambient background loop, low conveyor whirr, distant forklift hum, soft mechanical drone, subtle industrial atmosphere, no melody, no drums, seamless loop, mobile game background music"

echo
echo "[$(date +%H:%M:%S)] Done. Files in $OUT:"
ls -lh "$OUT" | grep -E "(tap|coin|crate_thump|klaxon|levelup|win|music)\.mp3"

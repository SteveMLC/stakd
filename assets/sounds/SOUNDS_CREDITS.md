# Warehouse Sort — Sound Effects Credits

All sound effects in this directory are generated via the
**ElevenLabs Sound Effects API** (commercial license) on 2026-05-15.
Each was generated from a warehouse-specific text prompt — no
upstream attribution requirement, but the prompts used to seed each
generation are preserved below for reproducibility.

## Sound files

### tap.mp3 (~9 KB)
- **Prompt:** "Sharp metallic stamp on clipboard, single quick tap, crisp office sound, dry, no reverb"
- **Duration:** 0.5s
- **Use:** stack selection, button presses

### slide.mp3 (~9 KB)
- **Prompt:** "Wooden crate sliding smoothly across a metal conveyor belt, short whoosh with scraping wood texture"
- **Duration:** 0.5s
- **Use:** layer movement between bays

### clear.mp3 (~10 KB)
- **Prompt:** "Single satisfying freight elevator ding bell, warehouse industrial chime, bright clear tone"
- **Duration:** 0.6s
- **Use:** stack completion / clear

### win.mp3 (~25 KB)
- **Prompt:** "Warehouse air horn blast followed by a small crowd cheering and applause, celebratory, victorious"
- **Duration:** 1.5s
- **Use:** level complete

### error.mp3 (~14 KB)
- **Prompt:** "Forklift reverse backup beeper, exactly three short electronic beep chirps, industrial warning"
- **Duration:** 0.8s
- **Use:** invalid move

### coin.mp3 (~10 KB)
- **Prompt:** "Cash register ka-ching, classic till bell with coin clatter, satisfying reward sound"
- **Duration:** 0.6s
- **Use:** cash payout, bonus

### levelup.mp3 (~29 KB)
- **Prompt:** "Industrial fanfare, rising klaxon horn sweep into triumphant brass stinger, warehouse celebration"
- **Duration:** 1.8s
- **Use:** warehouse level up, tier promotion

### powerup.mp3 (~14 KB)
- **Prompt:** "Pneumatic piston whoosh hiss followed by a bright bell ding, mechanical power-up, factory air valve"
- **Duration:** 0.8s
- **Use:** power-up activation

### forklift_idle.mp3 (~20 KB) — NEW
- **Prompt:** "Idle forklift engine humming, low diesel rumble, smooth steady mechanical loop, no movement"
- **Duration:** 1.2s (loopable)
- **Use:** menu ambient background

### klaxon.mp3 (~17 KB) — NEW
- **Prompt:** "Heavy industrial warning klaxon alarm, single one-shot blast, deep loud factory alert horn"
- **Duration:** 1.0s
- **Use:** level fail / jam alert

### crate_thump.mp3 (~9 KB) — NEW
- **Prompt:** "Heavy wooden crate landing hard on a stack of crates, single thump, solid wood impact, no echo"
- **Duration:** 0.5s
- **Use:** crate landing on stack

### music.mp3 (~587 KB)
- **Source:** Legacy ambient pad (carry-over from prior identity).
- **TODO:** replace with warehouse-themed ambient music (low
  conveyor whirr + distant forklift hum).

## Generation script

`tools/generate_audio.sh` — paste-ready bash script with prompts
inline. Requires `ELEVENLABS_API_KEY` env var. Reproducible: same
prompts + same API will produce equivalent (not identical) outputs.

## Cost

11 sound effects × ~$0.04 per generation = ~$0.50 total.

---

**Generated:** 2026-05-15 via ElevenLabs SFX API.
**Replaced:** Stakd-era Kenney.nl + WobbleBoxx CC0 stock sounds.

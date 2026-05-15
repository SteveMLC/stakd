# Warehouse Sort — Sound Effects Credits

Curated 2026-05-15 from the manifest at `docs/audio-sources.md`
(originally compiled 2026-05-13). Audio pipeline went through three
phases this session:

1. Original Stakd-era Kenney + WobbleBoxx CC0 stock — generic UI clicks
2. ElevenLabs SFX API generations — muddy, off-character results
3. **Mixkit curated CC0 fetch (current)** — professionally produced,
   warehouse-themed, no attribution required

The current sound bank pulls from **Mixkit's free CC0 library**
(no attribution required, commercial use OK). One sound (`music.mp3`,
22s ambient warehouse loop) is retained from the ElevenLabs phase
because Mixkit doesn't expose loopable warehouse-ambient tracks.

## Active sound bank

### Core gameplay SFX

| File | Source | License | Slot |
|---|---|---|---|
| `tap.mp3` | [Mixkit — select-click](https://mixkit.co/free-sound-effects/select-click/) | Mixkit (no attribution) | Stack selection, button presses |
| `slide.mp3` | [Mixkit — fast-whoosh-transition](https://mixkit.co/free-sound-effects/fast-whoosh-transition/) | Mixkit | Layer movement between bays |
| `clear.mp3` | [Mixkit — achievement-bell](https://mixkit.co/free-sound-effects/achievement-bell/) | Mixkit | Stack / bay completion |
| `win.mp3` | [Mixkit — successful-horns-fanfare](https://mixkit.co/free-sound-effects/successful-horns-fanfare/) | Mixkit | Level complete |
| `error.mp3` | [Mixkit — losing-piano](https://mixkit.co/free-sound-effects/losing-piano/) | Mixkit | Invalid move, level fail |
| `coin.mp3` | [Mixkit — winning-a-coin-video-game](https://mixkit.co/free-sound-effects/winning-a-coin-video-game/) | Mixkit | Cash reward |
| `levelup.mp3` | [Mixkit — game-level-completed](https://mixkit.co/free-sound-effects/game-level-completed/) | Mixkit | Warehouse level up, tier promotion |
| `powerup.mp3` | [Mixkit — quick-metal-transition-sweep](https://mixkit.co/free-sound-effects/quick-metal-transition-sweep/) | Mixkit | Power-up activation |
| `klaxon.mp3` | [Mixkit — basketball-buzzer](https://mixkit.co/free-sound-effects/basketball-buzzer/) | Mixkit | Level fail / jam alert |
| `crate_thump.mp3` | **Synthesized** (`tools/synth_crate_thump.py`) | CC0 (own work) | Crate landing impact — Mixkit "hard-pop-click" sounded synth-electronic; replaced 2026-05-15 with a procedural cardboard-box-on-concrete (18ms click + 85+130Hz damped sine body + 350Hz mid thwap, 300ms total) so it reads as a warehouse thump, not a UI bleep. |
| `crate_pickup.mp3` | [Mixkit — modern-click-box-check](https://mixkit.co/free-sound-effects/modern-click-box-check/) | Mixkit | Crate selected (NEW slot) |

### Star reveal chimes (NEW — staged completion sequence)

| File | Source | License |
|---|---|---|
| `star_1.mp3` | [Mixkit — relaxing-bell-chime](https://mixkit.co/free-sound-effects/relaxing-bell-chime/) | Mixkit |
| `star_2.mp3` | [Mixkit — cooking-bell-ding](https://mixkit.co/free-sound-effects/cooking-bell-ding/) | Mixkit |
| `star_3.mp3` | [Mixkit — fairy-arcade-sparkle](https://mixkit.co/free-sound-effects/fairy-arcade-sparkle/) | Mixkit |

### Power-ups (NEW slots)

| File | Source | License |
|---|---|---|
| `power_sort_bomb.mp3` | [Mixkit — arcade-game-explosion](https://mixkit.co/free-sound-effects/arcade-game-explosion/) | Mixkit |
| `streak_milestone.mp3` | [Mixkit — quick-positive-video-game-notification-interface](https://mixkit.co/free-sound-effects/quick-positive-video-game-notification-interface/) | Mixkit |

### Ambient

| File | Source | License | Notes |
|---|---|---|---|
| `forklift_idle.mp3` | ElevenLabs SFX API (`forklift engine humming, low diesel rumble, smooth steady mechanical loop`) | Commercial license | Loopable engine hum for menu screens |
| `music.mp3` | ElevenLabs SFX API (`Calm warehouse ambient background loop, low conveyor whirr, distant forklift hum`) | Commercial license | 22s ambient background loop |

### Zen mode (legacy CC0)

| File | Source | License |
|---|---|---|
| `zen/wind_ambient.mp3` | Carry-over from prior identity (CC0) | CC0 |
| `zen/wind_chime.mp3` | Carry-over from prior identity (CC0) | CC0 |

## Fetch script

`tools/fetch_audio.py` — reusable Python fetcher that pulls Mixkit
preview MP3s directly from page HTML (the `<source src>` URL is
embedded; no API key needed). Run any time to refresh the curated
sound bank or add new slots.

## Cost / attribution

- **Mixkit**: zero cost, zero attribution required for commercial use.
- **ElevenLabs SFX (forklift_idle + music)**: ~$0.10 total.
- **Total session audio production**: ~$0.10 (ambient only — everything
  else is free curated Mixkit).

## Attribution block

None required. All active sounds are Mixkit (no-attribution license).
The optional Freesound CC0 credit block at the bottom of the manifest
isn't applicable since no Freesound sounds made it into the final
shipped bank (all primary Mixkit picks succeeded).

---

**Updated:** 2026-05-15
**Replaced:** ElevenLabs SFX generations (muddy / off-character) +
the original Stakd-era Kenney + WobbleBoxx CC0 stock.

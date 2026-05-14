# Warehouse Sort — Audio Source Manifest

Sourced 2026-05-13. Steve to review and download.

**Scope:** 21 SFX slots + 4 music tracks per GDD §7 (Audio Design Spec), wired against the
sensory-feedback matrix in `workspace/handoffs/claude-handoff-warehouse-sort-design-2026-05-13.md` §5.

**License priority used:** Mixkit (no attribution) > Pixabay Content License (no attribution) >
Freesound CC0 (no attribution required, credit appreciated) > Uppbeat free tier (attribution required).
Anything outside those licenses was rejected so that the About-screen credit block stays short.

**Verification:** every URL below was confirmed via WebFetch / WebSearch during the 2026-05-13
sourcing pass. Anything not directly verifiable (URLs that require listening before final pick,
or genres where Mixkit returned no result) is marked **NEEDS REVIEW** with the search trail.

---

## SFX (21 slots)

| Slot ID | Trigger | Primary URL | License | Alternative URL | Notes |
|---------|---------|-------------|---------|-----------------|-------|
| `button_tap.mp3` | UI button + bay-tap select (matrix §5 row 1) | https://mixkit.co/free-sound-effects/select-click/ | Mixkit (no attribution) | https://mixkit.co/free-sound-effects/cool-interface-click-tone/ | Existing `tap.mp3` (Kenney click5.wav) already in `assets/sounds/` is the safest fallback. Pitch ±5% per crate (engine handles). |
| `crate_pickup.mp3` | Crate selected (top crate scales 1.05) | https://mixkit.co/free-sound-effects/modern-click-box-check/ | Mixkit (no attribution) | https://freesound.org/people/newagesoup/sounds/364740/ | Soft mechanical click + cardboard feel. Freesound alt (newagesoup, CC0) is literal cardboard-box fold. |
| `crate_place.mp3` | Crate lands in bay (snap/thud on wood) | https://mixkit.co/free-sound-effects/hard-pop-click/ | Mixkit (no attribution) | https://freesound.org/people/VSokorelos/sounds/346169/ | Slightly louder than pickup. Freesound alt (VSokorelos, CC0) is literal cardboard-box-drop on concrete. |
| `crate_slide.mp3` | Crate arcs source → dest (120ms ease-out) | https://mixkit.co/free-sound-effects/fast-whoosh-transition/ | Mixkit (no attribution) | https://mixkit.co/free-sound-effects/fast-small-sweep-transition/ | Existing `slide.mp3` (Kenney rollover2.wav) already in `assets/sounds/` works as a third fallback. |
| `bay_complete.mp3` | Bay door rolls down + SORTED stamp (most satisfying sound in game) | https://mixkit.co/free-sound-effects/achievement-bell/ | Mixkit (no attribution) | https://mixkit.co/free-sound-effects/bonus-earned-in-video-game/ | Ding + mechanical lock + whoosh. 0.5s target. |
| `contract_complete.mp3` | Contract finished — stamp drops + coin shower | https://mixkit.co/free-sound-effects/successful-horns-fanfare/ | Mixkit (no attribution) | https://mixkit.co/free-sound-effects/casino-bling-achievement/ | Brass + chimes per GDD. 0.8s slot — fanfare may need trim to 0.8–3s (existing `win.mp3` 1.0s is fallback). |
| `star_1.mp3` | First star pops in (low C4 chime) | https://mixkit.co/free-sound-effects/relaxing-bell-chime/ | Mixkit (no attribution) | https://freesound.org/people/mpaol2023/sounds/370179/ | Pitch the chime down ~3 semitones for low register. Freesound alt (mpaol2023, CC0) is a 3-tone chime — pull lowest tone. |
| `star_2.mp3` | Second star pops in (mid E4 chime) | https://mixkit.co/free-sound-effects/cooking-bell-ding/ | Mixkit (no attribution) | https://mixkit.co/free-sound-effects/kids-cartoon-close-bells/ | Mid register — same chime as star_1 pitched +4 semitones is also acceptable. |
| `star_3.mp3` | Third star pops in (bright G4 + sparkle tail) | https://mixkit.co/free-sound-effects/fairy-arcade-sparkle/ | Mixkit (no attribution) | https://mixkit.co/free-sound-effects/magic-wand-sparkle/ | Highest + most rewarding. 0.3s including sparkle decay tail. |
| `power_sort_bomb.mp3` | Sort-bomb explosive whoosh + cascade | https://mixkit.co/free-sound-effects/shatter-shot-explosion/ | Mixkit (no attribution) | https://mixkit.co/free-sound-effects/arcade-game-explosion/ | Dramatic but casual. 0.4s — arcade-game-explosion is closer to target duration. |
| `power_shuffle.mp3` | Shuffle power-up card-rattle + settle | https://freesound.org/people/ChrisGrundlingh/sounds/765639/ | Freesound CC0 (no attribution required) | https://mixkit.co/free-sound-effects/magic-transition-sweep-presentation/ | Mixkit has no card-shuffle primary; Freesound CC0 is the right primary. Mixkit alt is the magic-sweep variant if Steve wants more "magical" feel. |
| `power_forklift.mp3` | Forklift beep-beep + hydraulic | https://freesound.org/people/Disasteradio/sounds/197166/ | Freesound CC0 (no attribution required) | https://freesound.org/people/parabolix/sounds/352388/ | Mixkit doesn't carry forklift SFX — Freesound is the only good source. Disasteradio's reverse-beeper is clean + loopable. Parabolix's hydraulic-machine is the alt for the hydraulic portion (mix the two). |
| `power_scanner.mp3` | Scanner — 3 ascending beeps | **NEEDS REVIEW** — closest is https://freesound.org/people/zerolagtime/sounds/144418/ | Freesound CC0 (no attribution required) | https://mixkit.co/free-sound-effects/sport-start-bleeps/ | No exact "3 ascending beeps" SFX on Mixkit or Freesound. Recommendation: use Mixkit `positive-interface-beep` (0:01), pitch-shift +0/+3/+7 semitones, layer with 50ms gaps. Search trail: "scanner beep ascending three CC0" on Freesound; "scanner beep three ascending" on Mixkit (no results). |
| `power_time_freeze.mp3` | Ice crystallize + clock stop | https://freesound.org/people/GregorQuendel/sounds/422119/ | Freesound CC0 (no attribution required) | https://freesound.org/people/antonsoederberg/sounds/685253/ | Mixkit's "ice" category is all beverage sounds. Freesound CC0 ice-cracking is the only good source. GregorQuendel's "Ice Effects Sequences 01 — Breaking, Cracking" is the cleanest crystallize. |
| `power_priority_lane.mp3` | Metal gate clang + hydraulic (lane slides in) | https://mixkit.co/free-sound-effects/quick-metal-transition-sweep/ | Mixkit (no attribution) | https://mixkit.co/free-sound-effects/technology-transition-slide/ | Industrial slide. 0.3s. Both Mixkit URLs are mechanical / metal-feel transitions. |
| `combo_chain.mp3` | Ascending pitch ding on 2× consecutive correct | https://mixkit.co/free-sound-effects/fairy-arcade-sparkle/ | Mixkit (no attribution) | https://mixkit.co/free-sound-effects/winning-notification/ | Per GDD: "reuse star chimes pitched up". Engine should pitch `star_1.mp3` +30%/+60% per chain level. URL here is the standalone-fallback if the engine pitch-shift can't run. |
| `level_fail.mp3` | Gentle buzzer + crate scatter (NOT punishing) | https://mixkit.co/free-sound-effects/losing-piano/ | Mixkit (no attribution) | https://mixkit.co/free-sound-effects/lose-fairy-shine/ | "Encouraging, not punishing" per spec. Existing `error.mp3` (Kenney) is too short for this — keep `error.mp3` only for the invalid-tap red-pulse, not for jam/fail. |
| `coin_earned.mp3` | Single coin clink on reward | https://mixkit.co/free-sound-effects/winning-a-coin-video-game/ | Mixkit (no attribution) | https://mixkit.co/free-sound-effects/arcade-game-jump-coin/ | Classic. 0.1s. |
| `streak_milestone.mp3` | Streak day claim — short brass + sparkle | https://mixkit.co/free-sound-effects/game-level-completed/ | Mixkit (no attribution) | https://mixkit.co/free-sound-effects/quick-positive-video-game-notification-interface/ | 0.5s celebratory jingle. Distinct from `contract_complete` so the streak claim doesn't sound like a level win. |
| `rush_timer_warning.mp3` | Ticking clock loop, accelerating (Rush Hour <10s) | https://freesound.org/people/modusmogulus/sounds/790486/ | Freesound CC0 (no attribution required) | https://freesound.org/people/unfa/sounds/154906/ | Mixkit countdowns are all one-shots, not loops. modusmogulus's "Clock Tick 10sec (Precise Loop, CC0)" is purpose-built. Engine should pitch-shift +5%/+10%/+20% as timer drops 10s/5s/2s. |
| `rush_game_over.mp3` | Air horn buzzer (final, not harsh) | https://mixkit.co/free-sound-effects/basketball-buzzer/ | Mixkit (no attribution) | https://mixkit.co/free-sound-effects/ice-hockey-sports-buzzer/ | 0.5s. Hockey buzzer is the air-horn-ier of the two. |

---

## Music (4 tracks)

| Slot ID | When played | Primary URL | License | Alternative URL | Loop OK? |
|---------|-------------|-------------|---------|-----------------|----------|
| `music_main_menu.mp3` | Home screen + idle | https://uppbeat.io/track/pecan-pie/lo-fi-rainbow | Uppbeat free tier (**attribution required** — see block below) | https://mixkit.co/free-stock-music/lo-fi-beats/ (track: "Sweet September" by Arulo, 1:39) | Yes — both are mid-tempo and loop cleanly. Pick Mixkit primary if Steve wants zero-attribution; Uppbeat only if Steve confirms attribution is fine. |
| `music_gameplay.mp3` | Active level + contract play | https://mixkit.co/free-stock-music/lo-fi-beats/ (track: "Sleepy Cat" by Alejandro Magaña, 1:59) | Mixkit (no attribution) | https://pixabay.com/music/beats-lo-fi-loop-149702/ ("Lo-Fi (loop)" by FASSounds) | Yes — both lo-fi chill loops. Sleepy Cat is the atmospheric downtempo vibe the GDD calls out (warehouse ambience baked in is a future bake; ship clean loop first). |
| `music_rush_hour.mp3` | Rush Hour timed mode (post-launch in v1.0 floor) | https://mixkit.co/free-stock-music/tag/tension/ (track: "Epical Drums 01" by Grigoriy Nuzhny, 1:46) | Mixkit (no attribution) | https://pixabay.com/music/main-title-cinematic-tension-suspenseful-thriller-music-loop-297627/ ("Cinematic Tension - Suspenseful Thriller Music Loop") | Yes for Mixkit primary; Pixabay alt is explicitly named "Loop". Per handoff §3, Rush Hour is post-launch — Steve can defer this download. |
| `music_zen_sandbox.mp3` | Zen mode + sandbox (loop, slow tempo) | https://mixkit.co/free-stock-music/ambient/ (track: "Charlotte", 3:45, piano + electric guitar, relaxed/soothing) | Mixkit (no attribution) | https://pixabay.com/music/meditationspiritual-meditation-ambient-loop-pixabay-316844/ ("Meditation Ambient (Loop, Pixabay)") | Yes — Charlotte is long enough to trim to a 90s seamless loop. Pixabay alt is named "Loop" so it's the safer choice if Steve wants explicit loop labelling. |

**Track-page URL caveat (Mixkit music):** Mixkit's music category pages do not expose per-track
canonical URLs in the rendered HTML accessible via WebFetch (they're injected by JS). The category
URLs above (`/free-stock-music/lo-fi-beats/`, `/ambient/`, `/tag/tension/`) are the verified landing
pages — Steve clicks through to download. Track titles + artists in parentheses are the exact picks
to look for on those pages, so this is still a one-click flow.

---

## Attribution block

If Steve uses the **Uppbeat** track for the main menu (`music_main_menu.mp3` primary), add this to
the About screen. If he switches to the Mixkit alternative, no attribution is needed and this block
can be deleted.

```
Music
"Lo-Fi Rainbow" by Pecan Pie
Used under Uppbeat free license — https://uppbeat.io
```

If Steve uses any Freesound CC0 track (none of which require attribution), the following optional
credit is appreciated and matches the existing `SOUNDS_CREDITS.md` precedent:

```
Sound effects sourced from Freesound.org under Creative Commons 0
— modusmogulus, GregorQuendel, ChrisGrundlingh, Disasteradio, parabolix, newagesoup, VSokorelos
```

All Mixkit and Pixabay assets are zero-attribution and need no credit line.

---

## Slots-to-engine wiring notes

- `AudioService` (already in stakd codebase) maps method names to file paths. The 21 SFX slot IDs
  above use snake_case names that mirror GDD §7. Steve can choose to add a thin facade
  (`AudioService.playCratePickup()` etc.) or just thread through `playSfx('crate_pickup')`.
- `combo_chain` is GDD-declared as "reuse star chimes pitched up". Don't download a separate file —
  use `AudioService.playSfx('star_1', pitchShift: 1.3 ** chainLevel)`. The standalone URL in the
  table is only a fallback for if pitch-shifting at runtime is a problem.
- `rush_timer_warning` is the only true loop in the SFX bank. Everything else is one-shot.
- `error.mp3` (existing, Kenney CC0) stays in place for the invalid-tap red pulse per matrix §5
  row 2. It's not part of the 21-slot manifest because the GDD doesn't enumerate it explicitly,
  but the matrix demands it. If Steve wants a manifest entry, add as slot #22 mapped to the
  existing file.

---

## "NEEDS REVIEW" summary

1. **`power_scanner.mp3`** — no exact "3 ascending beeps" SFX exists on Mixkit or Freesound CC0.
   Recommendation in the row above: synthesize from `mixkit-positive-interface-beep` pitched
   +0/+3/+7 with 50ms gaps. Alternatives are best-effort placeholders. If Steve wants a single
   pre-baked file, he should commission via ElevenLabs Sound Effects (mentioned in existing
   `SOUNDS_CREDITS.md`) — prompt: "three quick ascending scanner beeps, 0.3 seconds total".

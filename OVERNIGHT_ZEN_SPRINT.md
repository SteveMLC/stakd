# Stakd Zen Garden: Overnight Polish Sprint
**Started:** 2026-02-08 22:35 ET
**Owner:** Walt (full autonomy)
**Goal:** Most polished zen garden experience possible by morning

---

## The Vision

*Every puzzle solved plants a seed. Watch your garden grow.*

The zen garden should feel like stepping into a Studio Ghibli painting. Soft, peaceful, alive. When users enter, they should exhale. When they solve puzzles, they should feel genuine satisfaction watching their garden grow.

**Key insight from Steve:** "The slow build of something much bigger is so fulfilling."

This isn't about flashy effects. It's about **presence** and **growth**.

---

## Current State Assessment

### ✅ Already Working
- 9-stage progression system (0-200+ puzzles)
- Sky gradients (day/dusk)
- Ground with grass coverage
- Simple trees (regular + cherry)
- Flowers (white, yellow, purple)
- Pond (empty → full)
- Bench, lantern structures
- Fireflies, petals, butterflies particles
- Mountains, clouds in background
- Swaying grass animation
- Stats overlay

### ❌ Critical Gaps

| Gap | Impact | Priority |
|-----|--------|----------|
| **No ambient sound** | Kills the zen vibe completely | 🔴 P0 |
| Trees are basic ovals | Looks cheap | 🟡 P1 |
| No growth animations | Misses the "slow build" magic | 🟡 P1 |
| No water sounds/ripples | Pond feels dead | 🟡 P1 |
| Missing torii, pagoda | Late-game feels incomplete | 🟢 P2 |
| No koi fish | Pond is lifeless | 🟢 P2 |
| No moon/sun | Night sky incomplete | 🟢 P2 |
| No seasonal variation | Infinite stage lacks variety | 🟢 P2 |

---

## Sprint Plan

### Sprint 1: Sound Foundation (22:45 - 23:30)
**Goal:** Create the audio layer that transforms the experience

1. Source/generate ambient nature sounds:
   - Soft wind loop (30s)
   - Birds chirping (gentle, not busy)
   - Water stream/pond loop
   - Night crickets (for evening mode)

2. Generate with ElevenLabs or source from Freesound:
   - Wind chime (single gentle ting)
   - Soft "bloom" sound (for plant growth)
   - Water drop/ripple

3. Create `ZenAudioService`:
   - Layered ambient playback
   - Volume ducking during events
   - Smooth crossfade between day/night ambience

### Sprint 2: Visual Refinement (23:30 - 00:30)
**Goal:** Elevate the visual quality

1. Better tree rendering:
   - CustomPainter with organic shapes
   - Trunk with texture
   - Leaf clusters with variation
   - Cherry blossoms with detail

2. Add missing structures:
   - Torii gate (simple but elegant)
   - Small pagoda silhouette
   - Wooden bridge

3. Sky enhancements:
   - Moon (with glow) for night
   - Subtle stars
   - Sun for day mode

4. Pond improvements:
   - Subtle ripple animation
   - Koi fish (simple orange shapes that swim)
   - Lily pads that bob

### Sprint 3: Growth Animations (00:30 - 01:30)
**Goal:** Make growth FEEL rewarding

1. Element reveal system:
   - `GardenElement` widget with reveal animation
   - Scale + fade in over 1-2 seconds
   - Subtle particle burst on unlock

2. Progressive growth:
   - Trees: sapling → young → full (animated growth)
   - Pond: empty → ripple → water rises → full
   - Flowers: stem emerges → bud → bloom

3. Sound triggers:
   - Soft chime when stage advances
   - Subtle rustle when new element appears

### Sprint 4: Polish & Integration (01:30 - 02:30)
**Goal:** Everything working together beautifully

1. Performance optimization:
   - Reduce rebuild frequency
   - Pre-cache animations
   - Test on real device

2. Zen mode integration:
   - Garden visible behind puzzles (subtle)
   - Smooth transition between puzzle and garden view
   - Garden button in zen mode header

3. Final touches:
   - Color palette refinement
   - Particle density tuning
   - Animation timing polish

### Sprint 5: Iteration (02:30 - 06:00)
**Goal:** Continuous refinement

- Review each element
- Adjust timing, colors, sounds
- Fix any bugs
- Add seasonal variations if time allows
- Screenshot feature for sharing

---

## Asset Requirements

### Sounds (to generate/source)
| Sound | Duration | Source |
|-------|----------|--------|
| wind_ambient.mp3 | 30s loop | ElevenLabs SFX / Freesound |
| birds_soft.mp3 | 45s loop | Freesound |
| water_stream.mp3 | 30s loop | Freesound |
| crickets_night.mp3 | 30s loop | Freesound |
| wind_chime.mp3 | 2s | ElevenLabs SFX |
| bloom_soft.mp3 | 1s | ElevenLabs SFX |
| water_ripple.mp3 | 1s | Freesound |
| stage_advance.mp3 | 2s | ElevenLabs SFX |

### Code Files to Create/Modify
- `lib/services/zen_audio_service.dart` (NEW)
- `lib/widgets/themes/zen_garden_scene.dart` (ENHANCE)
- `lib/widgets/garden/garden_element.dart` (NEW)
- `lib/widgets/garden/koi_fish.dart` (NEW)
- `lib/widgets/garden/zen_tree.dart` (NEW)
- `lib/widgets/garden/water_feature.dart` (NEW)

---

## Success Criteria

By morning, the zen garden should:
1. ✅ Have ambient audio that makes you want to stay
2. ✅ Show visible growth as puzzles are solved
3. ✅ Feel alive with subtle animations everywhere
4. ✅ Have a cohesive, beautiful color palette
5. ✅ Run smoothly at 60fps
6. ✅ Make Steve say "this is exactly what I wanted"

---

## Log

### 22:35 - Sprint Started
- Audited current state
- Created this plan
- Beginning sound sourcing...

### 22:45 - Sound Design Complete ✅
Generated 8 sounds via ElevenLabs Sound Effects API:
- wind_ambient.mp3 (30s ambient loop)
- birds_ambient.mp3 (30s ambient loop)
- crickets_night.mp3 (30s ambient loop)
- water_stream.mp3 (30s ambient loop)
- wind_chime.mp3 (3s one-shot)
- bloom.mp3 (2s one-shot)
- water_drop.mp3 (2s one-shot)
- stage_advance.mp3 (3s one-shot)

### 22:55 - ZenAudioService Complete ✅
Created layered ambient audio service:
- Automatic init and playback on garden entry
- Day/night crossfade (birds ↔ crickets)
- Water layer unlocks with pond_full
- Sound effect triggers for events

### 23:10 - Visual Improvements Complete ✅
- Sky: Twinkling stars, moon, sun with glow
- Trees: Complete rewrite with organic layered foliage
- Trees: Subtle swaying animation
- Pond: Gradient water, koi fish, lily pads
- Structures: Torii gate painter

### 23:15 - Committed and Pushed
- Commit: fddafe3
- 1202 lines added, 323 removed
- Beginning growth animation sprint...

### 23:40 - GardenElement Animation System Complete ✅
Created lib/widgets/garden/garden_element.dart:
- GardenElement wrapper with 4 reveal types (fadeScale, growUp, bloomOut, rippleIn)
- GrowingTree for staged tree transitions
- PondFillAnimation with ripple effects
- Particle burst on first reveal
- Sound triggers integrated

### 23:55 - Structure Painters Complete ✅
Added to zen_garden_scene.dart:
- PagodaPainter: 3-tier pagoda with curved roofs
- BridgePainter: Arched bridge with railings
- StreamPainter: Animated water flow with shimmer
- DragonflyPainter: Detailed dragonfly particles
- All elements wired into unlock system

### 00:00 - Current State
- zen_garden_scene.dart: 1378 lines
- 4 commits pushed: fddafe3, b1ab0bb, 917ba59
- Sound: ✅ 8 ambient/SFX sounds
- Visuals: ✅ Sky, trees, pond, koi, structures, particles
- Animations: ✅ GardenElement system created

### Next: Integration + Polish
- Wire GardenElement into actual scene elements
- Test on device
- Adjust timing and colors
- Add seasonal variations if time


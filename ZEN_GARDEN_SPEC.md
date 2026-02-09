# Stakd Zen Mode: The Infinite Garden

> "Every puzzle solved plants a seed. Watch your garden grow."

---

## Core Concept

**Each session is a fresh garden.** You start with empty earth. Every puzzle solved in that session grows your garden. When you leave, the garden fades like a sand mandala — beautiful, impermanent.

**Philosophy:** The journey IS the reward. No accumulation anxiety. Pure presence. Very zen.

**Vibe:** Studio Ghibli meets Monument Valley. Soft, peaceful, impermanent.

---

## Visual Style

- **Art Style:** Flat/vector with subtle gradients, soft shadows
- **Color Palette:** Muted earth tones, soft greens, warm sunset colors
- **Aspect:** Full-screen background that evolves
- **Animation:** Gentle, ambient (swaying grass, floating particles)

---

## Growth Stages (Milestones)

### Stage 0: Empty Canvas (0 puzzles)
- Bare earth/sand
- Single small stone
- Muted, dawn colors
- Text: "Your garden awaits..."

### Stage 1: First Signs (1-5 puzzles)
**Unlocks:**
- Pebble path begins forming
- 2-3 small stones placed
- First grass patches appear
- Subtle ground texture

### Stage 2: Taking Root (6-15 puzzles)
**Unlocks:**
- Grass spreads across 40% of ground
- Small wildflowers (3-5 clusters)
- Path extends further
- First small bush

### Stage 3: Growth (16-30 puzzles)
**Unlocks:**
- Young sapling tree (bare)
- Pond outline appears (dry)
- More flowers, varied colors
- Grass covers 70%
- Stepping stones in path

### Stage 4: Flourishing (31-50 puzzles)
**Unlocks:**
- Tree grows leaves
- Pond fills with water
- Lily pads appear
- Small wooden bench
- Butterfly particles (1-2)

### Stage 5: Bloom (51-75 puzzles)
**Unlocks:**
- Cherry blossom tree (pink petals)
- Koi fish in pond (subtle animation)
- Stone lantern
- Falling petal particles
- Bird silhouette occasionally crosses

### Stage 6: Harmony (76-100 puzzles)
**Unlocks:**
- Small wooden torii gate
- Second tree (autumn colors)
- Firefly particles (evening glow)
- Wind chime (subtle audio cue)
- Grass sways gently

### Stage 7: Sanctuary (101-150 puzzles)
**Unlocks:**
- Small pagoda/tea house silhouette
- Winding stream connects to pond
- Bridge over stream
- More wildlife (dragonflies)
- Ambient bird sounds

### Stage 8: Transcendence (151-200 puzzles)
**Unlocks:**
- Mountain backdrop appears (distant)
- Moon/sun in sky (time of day shifts)
- Clouds drift slowly
- Full ecosystem feeling
- Achievement: "Master Gardener"

### Stage 9: Infinite (200+ puzzles)
**Unlocks:**
- Seasonal variations (spring/summer/fall/winter)
- Rare events (shooting star, rainbow after rain)
- Garden continues to subtly evolve
- Bragging rights: puzzle count displayed tastefully

---

## Technical Architecture

### Data Model

```dart
class GardenState {
  int totalZenPuzzlesSolved;
  int currentStage; // 0-9
  DateTime lastPlayed;
  String currentSeason; // spring, summer, fall, winter
  List<String> unlockedElements;
  Map<String, dynamic> elementPositions;
}
```

### Scene Composition (Layers)

```
Layer 7: Particles (fireflies, petals, butterflies)
Layer 6: Foreground elements (grass tufts, flowers in front)
Layer 5: Interactive elements (bench, lantern, bridge)
Layer 4: Mid-ground (trees, pagoda, torii)
Layer 3: Pond/water
Layer 2: Path, stones, ground cover
Layer 1: Base ground texture
Layer 0: Sky/background gradient
```

### Implementation Approach

1. **Single StatefulWidget:** `ZenGardenScene`
2. **CustomPainter:** For efficient rendering
3. **Layered Stack:** Each layer is a separate widget
4. **Asset Loading:** Preload on Zen Mode entry
5. **Animation:** `AnimationController` for ambient motion
6. **Persistence:** Store in existing `StorageService`

---

## Asset Requirements

### Background/Sky
| Asset | Size | Format | Description |
|-------|------|--------|-------------|
| sky_dawn.png | 1080x600 | PNG | Soft pink/orange gradient |
| sky_day.png | 1080x600 | PNG | Light blue with soft clouds |
| sky_dusk.png | 1080x600 | PNG | Purple/orange sunset |
| sky_night.png | 1080x600 | PNG | Dark blue with stars |

### Ground Elements
| Asset | Size | Format | Description |
|-------|------|--------|-------------|
| ground_base.png | 1080x400 | PNG | Earth/sand texture, bottom of screen |
| grass_patch_1.png | 120x60 | PNG | Small grass cluster |
| grass_patch_2.png | 150x80 | PNG | Medium grass cluster |
| grass_patch_3.png | 200x100 | PNG | Large grass, swaying |
| path_stone_1.png | 80x60 | PNG | Stepping stone, round |
| path_stone_2.png | 100x70 | PNG | Stepping stone, oval |
| pebbles.png | 200x50 | PNG | Scattered small pebbles |

### Flora
| Asset | Size | Format | Description |
|-------|------|--------|-------------|
| flower_white.png | 40x50 | PNG | Small white wildflower |
| flower_yellow.png | 40x50 | PNG | Yellow wildflower |
| flower_purple.png | 45x55 | PNG | Purple wildflower |
| flower_cluster.png | 100x80 | PNG | Mixed flower bunch |
| bush_small.png | 120x100 | PNG | Small green bush |
| bush_medium.png | 180x150 | PNG | Medium bush with berries |

### Trees
| Asset | Size | Format | Description |
|-------|------|--------|-------------|
| tree_sapling.png | 100x150 | PNG | Young tree, few leaves |
| tree_young.png | 200x300 | PNG | Growing tree |
| tree_full.png | 300x400 | PNG | Full green tree |
| tree_cherry.png | 320x420 | PNG | Cherry blossom (pink) |
| tree_autumn.png | 300x400 | PNG | Orange/red autumn tree |
| tree_winter.png | 280x380 | PNG | Bare branches with snow |

### Water Features
| Asset | Size | Format | Description |
|-------|------|--------|-------------|
| pond_empty.png | 250x150 | PNG | Dry pond bed outline |
| pond_filling.png | 250x150 | PNG | Pond half-filled |
| pond_full.png | 250x150 | PNG | Full pond with reflection |
| lily_pad.png | 50x40 | PNG | Single lily pad |
| lily_flower.png | 60x50 | PNG | Lily pad with flower |
| koi_fish.png | 40x20 | PNG | Simple koi silhouette |
| stream.png | 400x60 | PNG | Winding stream segment |
| bridge.png | 150x100 | PNG | Small wooden bridge |

### Structures
| Asset | Size | Format | Description |
|-------|------|--------|-------------|
| stone_lantern.png | 60x120 | PNG | Japanese stone lantern |
| bench.png | 140x80 | PNG | Simple wooden bench |
| torii_gate.png | 200x250 | PNG | Small red torii gate |
| pagoda.png | 250x300 | PNG | Small pagoda silhouette |
| wind_chime.png | 40x80 | PNG | Hanging wind chime |

### Particles (Small, tileable)
| Asset | Size | Format | Description |
|-------|------|--------|-------------|
| petal_pink.png | 15x15 | PNG | Cherry blossom petal |
| petal_white.png | 15x15 | PNG | White petal |
| firefly.png | 10x10 | PNG | Glowing dot with halo |
| butterfly_1.png | 30x25 | PNG | Simple butterfly shape |
| dragonfly.png | 35x30 | PNG | Dragonfly silhouette |
| leaf_falling.png | 20x20 | PNG | Autumn leaf |
| snowflake.png | 15x15 | PNG | Simple snowflake |

### Distant Background
| Asset | Size | Format | Description |
|-------|------|--------|-------------|
| mountain_distant.png | 1080x200 | PNG | Distant mountain silhouette |
| clouds_1.png | 200x80 | PNG | Soft cloud |
| clouds_2.png | 300x100 | PNG | Larger cloud formation |
| moon.png | 80x80 | PNG | Full moon |
| sun.png | 100x100 | PNG | Soft sun with glow |
| bird_silhouette.png | 30x20 | PNG | Flying bird shape |

---

## Asset Sourcing Strategy

### Option A: AI Generation (Fastest)
- Use Midjourney/DALL-E for base assets
- Style prompt: "flat vector illustration, soft colors, zen garden, studio ghibli style, simple shapes, transparent background"
- Post-process in Figma/Photoshop for consistency

### Option B: Free Asset Packs
- Kenney.nl (free game assets)
- OpenGameArt.org
- itch.io asset packs
- Search: "zen garden asset pack", "nature tileset flat"

### Option C: Procedural (Code-based)
- Generate simple shapes with CustomPainter
- Gradient backgrounds
- Particle systems for petals/fireflies
- Most performant, least artistic

### Recommended: Hybrid
1. Procedural: Sky gradients, particles, water ripples
2. AI-generated: Trees, structures, unique elements
3. Simple shapes: Stones, grass (can be code or simple PNGs)

---

## Implementation Phases

### Phase 1: Foundation (Sprint 1)
- [ ] Create `GardenState` model
- [ ] Add `gardenState` to StorageService
- [ ] Create `ZenGardenScene` widget shell
- [ ] Implement sky gradient background (procedural)
- [ ] Add ground base layer
- [ ] Hook up puzzle completion → increment counter

### Phase 2: Core Growth (Sprint 2)
- [ ] Implement stage calculation logic
- [ ] Add grass patches (stages 1-3)
- [ ] Add path/stones (stages 1-3)
- [ ] Add flowers (stages 2-4)
- [ ] Basic reveal animations

### Phase 3: Life (Sprint 3)
- [ ] Add trees (stages 3-6)
- [ ] Add pond with fill animation
- [ ] Add structures (bench, lantern)
- [ ] Particle system: butterflies, petals

### Phase 4: Polish (Sprint 4)
- [ ] Add advanced structures (torii, pagoda)
- [ ] Firefly particles
- [ ] Ambient animations (swaying grass, rippling water)
- [ ] Sound integration (optional wind chime)
- [ ] Mountain backdrop

### Phase 5: Infinite (Sprint 5)
- [ ] Seasonal variation system
- [ ] Rare events (shooting star)
- [ ] Garden stats display
- [ ] Share garden screenshot feature

---

## File Structure

```
lib/
├── screens/
│   └── zen_garden_screen.dart      # Full-screen garden view
├── widgets/
│   └── garden/
│       ├── zen_garden_scene.dart   # Main scene compositor
│       ├── garden_sky.dart         # Sky gradient + clouds
│       ├── garden_ground.dart      # Ground, path, stones
│       ├── garden_flora.dart       # Grass, flowers, bushes
│       ├── garden_trees.dart       # Tree rendering
│       ├── garden_water.dart       # Pond, stream, koi
│       ├── garden_structures.dart  # Lantern, bench, pagoda
│       └── garden_particles.dart   # Fireflies, petals, etc.
├── models/
│   └── garden_state.dart           # Garden progress model
└── services/
    └── garden_service.dart         # Progress tracking logic

assets/
└── garden/
    ├── sky/
    ├── ground/
    ├── flora/
    ├── trees/
    ├── water/
    ├── structures/
    └── particles/
```

---

## Success Metrics

1. **Engagement:** Zen Mode sessions increase after garden launch
2. **Retention:** Players return to check garden growth
3. **Sharing:** Garden screenshots shared socially
4. **Feel:** Players describe it as "peaceful," "beautiful," "rewarding"

---

## Next Steps

1. ✅ Spec complete (this document)
2. ⏳ Create Codex sprint for Phase 1
3. ⏳ Source/generate initial assets
4. ⏳ Build foundation during overnight runs
5. ⏳ Iterate based on feel

---

*"The garden grows not from force, but from patience. Each puzzle, a seed. Each solve, sunlight."*

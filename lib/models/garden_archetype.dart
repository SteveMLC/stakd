/// 6 garden archetypes — assigned from user seed, drives visual bias
enum GardenArchetype {
  minimalist,    // Few elements, wide spacing, emphasis on emptiness
  stoneKeeper,   // Rock clusters, heavy grounding, earthy tones
  lanternGarden, // Warm glows, evening tones, shrine emphasis
  waterGarden,   // Ponds, streams, mist, blue-green palette
  bloomGarden,   // Flowers, petals, soft pinks and purples
  wildZen,       // Organic, layered foliage, dense but natural
}

extension GardenArchetypeExt on GardenArchetype {
  /// Human-readable name
  String get displayName {
    switch (this) {
      case GardenArchetype.minimalist: return 'The Minimalist';
      case GardenArchetype.stoneKeeper: return 'The Stone Keeper';
      case GardenArchetype.lanternGarden: return 'The Lantern Garden';
      case GardenArchetype.waterGarden: return 'The Water Garden';
      case GardenArchetype.bloomGarden: return 'The Bloom Garden';
      case GardenArchetype.wildZen: return 'The Wild Zen';
    }
  }
  
  /// Short poetic description shown to player
  String get description {
    switch (this) {
      case GardenArchetype.minimalist: return 'Fewer stones. More silence.';
      case GardenArchetype.stoneKeeper: return 'Grounded in ancient weight.';
      case GardenArchetype.lanternGarden: return 'Warm light through stillness.';
      case GardenArchetype.waterGarden: return 'Where water gathers, peace follows.';
      case GardenArchetype.bloomGarden: return 'Petals fall where patience grows.';
      case GardenArchetype.wildZen: return 'Nature, untamed but balanced.';
    }
  }
  
  /// Determine archetype from user seed
  static GardenArchetype fromSeed(int seed) {
    return GardenArchetype.values[seed.abs() % 6];
  }
  
  /// Element scale multipliers — archetype emphasizes certain elements
  /// Returns a multiplier (0.7 = smaller/less, 1.0 = normal, 1.3 = bigger/more)
  double scaleMultiplierFor(String elementFamily) {
    // Each archetype amplifies its signature elements
    switch (this) {
      case GardenArchetype.minimalist:
        // Fewer of everything, more open space
        if (elementFamily == 'flora') return 0.7;
        if (elementFamily == 'structure') return 0.8;
        return 0.85;
      case GardenArchetype.stoneKeeper:
        if (elementFamily == 'rocks') return 1.3;
        if (elementFamily == 'flora') return 0.8;
        return 1.0;
      case GardenArchetype.lanternGarden:
        if (elementFamily == 'structure') return 1.2;
        if (elementFamily == 'atmosphere') return 1.3;
        return 1.0;
      case GardenArchetype.waterGarden:
        if (elementFamily == 'water') return 1.3;
        if (elementFamily == 'atmosphere') return 1.2;
        return 0.9;
      case GardenArchetype.bloomGarden:
        if (elementFamily == 'flora') return 1.3;
        if (elementFamily == 'atmosphere') return 1.1;
        return 1.0;
      case GardenArchetype.wildZen:
        if (elementFamily == 'flora') return 1.2;
        if (elementFamily == 'rocks') return 1.1;
        if (elementFamily == 'water') return 1.1;
        return 1.0;
    }
  }
}

// Hand-tuned level seeds for Warehouse Sort v1.0 launch.
// Generated 2026-05-13 from §12 of warehouse-sort-design-v0.3.
// Levels 1-15 = Local Warehouse tier; 16-30 = Regional Hub tier.
// Past L30, the level_generator runs procedurally.
//
// Difficulty curve table (design §12):
//   1-5   | Local    | 3c 5b 2buf cap4 | 0 mod    | par +50% | 50-100   cash
//   6-10  | Local    | 4c 6b 2buf cap4 | 0 mod    | par std  | 75-150   cash
//   11-15 | Local    | 4c 6b 2buf cap4 | 1 frozen | par +10% | 100-200  cash
//   16-20 | Regional | 5c 6b 2buf cap4 | 1-2 froz | par std  | 250-400  cash
//   21-25 | Regional | 5c 7b 3buf cap4 | 2 frozen | par +10% | 400-600  cash
//   26-30 | Regional | 6c 7b 3buf cap5 | 2-3 froz | par +15% | 600-1000 cash
//
// This file is intentionally a standalone data class; it does not import the
// existing LevelGenerator/LevelParams schema. A future task will wire these
// seeds into the contract service.

/// Which business tier this level belongs to.
enum BusinessTier { local, regional }

/// A hand-tuned seed for one v1.0 launch level.
class WarehouseLevelSeed {
  final int level;
  final int seed;
  final BusinessTier tier;
  final int colors;
  final int bays;
  final int bufferBays;
  final int capacity;
  final int modifierBudget; // 0, 1, 2, or 3 Frozen crates
  final double parFactor; // 1.0 = standard, 1.5 = generous (+50%)
  final int baseCashReward;

  const WarehouseLevelSeed({
    required this.level,
    required this.seed,
    required this.tier,
    required this.colors,
    required this.bays,
    required this.bufferBays,
    required this.capacity,
    required this.modifierBudget,
    required this.parFactor,
    required this.baseCashReward,
  });
}

/// The 30 hand-tuned launch levels.
/// 15 Local (1-15) + 15 Regional (16-30).
const List<WarehouseLevelSeed> localRegionalLevelSeeds = [
  // ── Local Warehouse: tutorial band (1-5) ────────────────────────────────
  // 3 colors, 5 bays, 2 buffer, cap 4, no modifiers, generous par, cash 50-100.
  WarehouseLevelSeed(level: 1, seed: 12371, tier: BusinessTier.local,
      colors: 3, bays: 5, bufferBays: 2, capacity: 4,
      modifierBudget: 0, parFactor: 1.5, baseCashReward: 60),
  WarehouseLevelSeed(level: 2, seed: 12425, tier: BusinessTier.local,
      colors: 3, bays: 5, bufferBays: 2, capacity: 4,
      modifierBudget: 0, parFactor: 1.5, baseCashReward: 65),
  WarehouseLevelSeed(level: 3, seed: 12486, tier: BusinessTier.local,
      colors: 3, bays: 5, bufferBays: 2, capacity: 4,
      modifierBudget: 0, parFactor: 1.5, baseCashReward: 75),
  WarehouseLevelSeed(level: 4, seed: 12553, tier: BusinessTier.local,
      colors: 3, bays: 5, bufferBays: 2, capacity: 4,
      modifierBudget: 0, parFactor: 1.5, baseCashReward: 85),
  WarehouseLevelSeed(level: 5, seed: 12626, tier: BusinessTier.local,
      colors: 3, bays: 5, bufferBays: 2, capacity: 4,
      modifierBudget: 0, parFactor: 1.5, baseCashReward: 95),

  // ── Local Warehouse: bigger board (6-10) ────────────────────────────────
  // 4 colors, 6 bays, 2 buffer, cap 4, no modifiers, standard par, cash 75-150.
  WarehouseLevelSeed(level: 6, seed: 12705, tier: BusinessTier.local,
      colors: 4, bays: 6, bufferBays: 2, capacity: 4,
      modifierBudget: 0, parFactor: 1.0, baseCashReward: 90),
  WarehouseLevelSeed(level: 7, seed: 12790, tier: BusinessTier.local,
      colors: 4, bays: 6, bufferBays: 2, capacity: 4,
      modifierBudget: 0, parFactor: 1.0, baseCashReward: 100),
  WarehouseLevelSeed(level: 8, seed: 12881, tier: BusinessTier.local,
      colors: 4, bays: 6, bufferBays: 2, capacity: 4,
      modifierBudget: 0, parFactor: 1.0, baseCashReward: 115),
  WarehouseLevelSeed(level: 9, seed: 12978, tier: BusinessTier.local,
      colors: 4, bays: 6, bufferBays: 2, capacity: 4,
      modifierBudget: 0, parFactor: 1.0, baseCashReward: 130),
  WarehouseLevelSeed(level: 10, seed: 13081, tier: BusinessTier.local,
      colors: 4, bays: 6, bufferBays: 2, capacity: 4,
      modifierBudget: 0, parFactor: 1.0, baseCashReward: 145),

  // ── Local Warehouse: Frozen unlock band (11-15) ─────────────────────────
  // 4 colors, 6 bays, 2 buffer, cap 4, 1 frozen, +10% par, cash 100-200.
  WarehouseLevelSeed(level: 11, seed: 13190, tier: BusinessTier.local,
      colors: 4, bays: 6, bufferBays: 2, capacity: 4,
      modifierBudget: 1, parFactor: 1.1, baseCashReward: 120),
  WarehouseLevelSeed(level: 12, seed: 13305, tier: BusinessTier.local,
      colors: 4, bays: 6, bufferBays: 2, capacity: 4,
      modifierBudget: 1, parFactor: 1.1, baseCashReward: 135),
  WarehouseLevelSeed(level: 13, seed: 13426, tier: BusinessTier.local,
      colors: 4, bays: 6, bufferBays: 2, capacity: 4,
      modifierBudget: 1, parFactor: 1.1, baseCashReward: 150),
  WarehouseLevelSeed(level: 14, seed: 13553, tier: BusinessTier.local,
      colors: 4, bays: 6, bufferBays: 2, capacity: 4,
      modifierBudget: 1, parFactor: 1.1, baseCashReward: 170),
  WarehouseLevelSeed(level: 15, seed: 13686, tier: BusinessTier.local,
      colors: 4, bays: 6, bufferBays: 2, capacity: 4,
      modifierBudget: 1, parFactor: 1.1, baseCashReward: 190),

  // ── Regional Hub: opening band (16-20) ──────────────────────────────────
  // 5 colors, 6 bays, 2 buffer, cap 4, 1-2 frozen (alternating), std par, cash 250-400.
  WarehouseLevelSeed(level: 16, seed: 13825, tier: BusinessTier.regional,
      colors: 5, bays: 6, bufferBays: 2, capacity: 4,
      modifierBudget: 1, parFactor: 1.0, baseCashReward: 270),
  WarehouseLevelSeed(level: 17, seed: 13970, tier: BusinessTier.regional,
      colors: 5, bays: 6, bufferBays: 2, capacity: 4,
      modifierBudget: 2, parFactor: 1.0, baseCashReward: 300),
  WarehouseLevelSeed(level: 18, seed: 14121, tier: BusinessTier.regional,
      colors: 5, bays: 6, bufferBays: 2, capacity: 4,
      modifierBudget: 1, parFactor: 1.0, baseCashReward: 330),
  WarehouseLevelSeed(level: 19, seed: 14278, tier: BusinessTier.regional,
      colors: 5, bays: 6, bufferBays: 2, capacity: 4,
      modifierBudget: 2, parFactor: 1.0, baseCashReward: 360),
  WarehouseLevelSeed(level: 20, seed: 14441, tier: BusinessTier.regional,
      colors: 5, bays: 6, bufferBays: 2, capacity: 4,
      modifierBudget: 2, parFactor: 1.0, baseCashReward: 390),

  // ── Regional Hub: expanded board (21-25) ────────────────────────────────
  // 5 colors, 7 bays, 3 buffer, cap 4, 2 frozen, +10% par, cash 400-600.
  WarehouseLevelSeed(level: 21, seed: 14610, tier: BusinessTier.regional,
      colors: 5, bays: 7, bufferBays: 3, capacity: 4,
      modifierBudget: 2, parFactor: 1.1, baseCashReward: 425),
  WarehouseLevelSeed(level: 22, seed: 14785, tier: BusinessTier.regional,
      colors: 5, bays: 7, bufferBays: 3, capacity: 4,
      modifierBudget: 2, parFactor: 1.1, baseCashReward: 460),
  WarehouseLevelSeed(level: 23, seed: 14966, tier: BusinessTier.regional,
      colors: 5, bays: 7, bufferBays: 3, capacity: 4,
      modifierBudget: 2, parFactor: 1.1, baseCashReward: 495),
  WarehouseLevelSeed(level: 24, seed: 15153, tier: BusinessTier.regional,
      colors: 5, bays: 7, bufferBays: 3, capacity: 4,
      modifierBudget: 2, parFactor: 1.1, baseCashReward: 530),
  WarehouseLevelSeed(level: 25, seed: 15346, tier: BusinessTier.regional,
      colors: 5, bays: 7, bufferBays: 3, capacity: 4,
      modifierBudget: 2, parFactor: 1.1, baseCashReward: 570),

  // ── Regional Hub: endgame band (26-30) ──────────────────────────────────
  // 6 colors, 7 bays, 3 buffer, cap 5, 2-3 frozen (alternating), +15% par, cash 600-1000.
  WarehouseLevelSeed(level: 26, seed: 15545, tier: BusinessTier.regional,
      colors: 6, bays: 7, bufferBays: 3, capacity: 5,
      modifierBudget: 2, parFactor: 1.15, baseCashReward: 650),
  WarehouseLevelSeed(level: 27, seed: 15750, tier: BusinessTier.regional,
      colors: 6, bays: 7, bufferBays: 3, capacity: 5,
      modifierBudget: 3, parFactor: 1.15, baseCashReward: 730),
  WarehouseLevelSeed(level: 28, seed: 15961, tier: BusinessTier.regional,
      colors: 6, bays: 7, bufferBays: 3, capacity: 5,
      modifierBudget: 2, parFactor: 1.15, baseCashReward: 810),
  WarehouseLevelSeed(level: 29, seed: 16178, tier: BusinessTier.regional,
      colors: 6, bays: 7, bufferBays: 3, capacity: 5,
      modifierBudget: 3, parFactor: 1.15, baseCashReward: 890),
  WarehouseLevelSeed(level: 30, seed: 16401, tier: BusinessTier.regional,
      colors: 6, bays: 7, bufferBays: 3, capacity: 5,
      modifierBudget: 3, parFactor: 1.15, baseCashReward: 970),
];

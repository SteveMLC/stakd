/// Level configuration table for the conveyor mechanic.
///
/// Per `docs/conveyor-mechanic-spec.md` section 4.3, each level number
/// maps to a config tuple that controls:
///   - numVisibleBays — how many bays render on screen at any moment
///   - numColors      — distinct cargo colors in the puzzle
///   - bayDepth       — max layers per bay
///   - numEmptyBays   — workspace slots
///   - scrambleMovesPerBay — difficulty knob fed to `ConveyorSeed`
///   - totalDeliveries — target count of bays to ship this level
///   - wrinkles       — post-seed additives the layerer applies
///
/// Difficulty climbs across six bands: intro (1-5), early (6-15), mid
/// (16-30), late (31-60), endgame (61-100), procedural (100+).
///
/// Phase F wires `_loadLevel` to consult this table. Phase G's wrinkle
/// layerer reads the `wrinkles` list to decide which post-seed passes
/// apply per delivery.
library;

class ConveyorLevelConfig {
  final int numVisibleBays;
  final int numColors;
  final int bayDepth;
  final int numEmptyBays;
  final int scrambleMovesPerBay;
  final int totalDeliveries;
  final List<String> wrinkles;

  const ConveyorLevelConfig({
    required this.numVisibleBays,
    required this.numColors,
    required this.bayDepth,
    required this.numEmptyBays,
    required this.scrambleMovesPerBay,
    required this.totalDeliveries,
    required this.wrinkles,
  });

  /// Look up the difficulty band for a level number. Always returns a
  /// valid config; numbers > 1000 still get a procedural config (the
  /// procedural composer in DistrictService will eventually layer more
  /// wrinkles on top via its own pool draws).
  static ConveyorLevelConfig forLevel(int level) {
    if (level <= 5) {
      return const ConveyorLevelConfig(
        numVisibleBays: 4,
        numColors: 3,
        bayDepth: 4,
        numEmptyBays: 2,
        scrambleMovesPerBay: 24,
        totalDeliveries: 5,
        wrinkles: <String>[],
      );
    }
    if (level <= 15) {
      return const ConveyorLevelConfig(
        numVisibleBays: 4,
        numColors: 4,
        bayDepth: 4,
        numEmptyBays: 2,
        scrambleMovesPerBay: 48,
        totalDeliveries: 8,
        wrinkles: <String>['frozen'],
      );
    }
    if (level <= 30) {
      return const ConveyorLevelConfig(
        numVisibleBays: 5,
        numColors: 5,
        bayDepth: 4,
        numEmptyBays: 2,
        scrambleMovesPerBay: 80,
        totalDeliveries: 12,
        wrinkles: <String>['frozen', 'locked'],
      );
    }
    if (level <= 60) {
      return const ConveyorLevelConfig(
        numVisibleBays: 5,
        numColors: 6,
        bayDepth: 5,
        numEmptyBays: 2,
        scrambleMovesPerBay: 150,
        totalDeliveries: 18,
        wrinkles: <String>['frozen', 'locked', 'fragile', 'priority'],
      );
    }
    if (level <= 100) {
      return const ConveyorLevelConfig(
        numVisibleBays: 5,
        numColors: 7,
        bayDepth: 5,
        numEmptyBays: 2,
        scrambleMovesPerBay: 210,
        totalDeliveries: 22,
        wrinkles: <String>[
          'frozen',
          'locked',
          'fragile',
          'priority',
          'time-bomb',
        ],
      );
    }
    // 100+: full wrinkle pool, one fewer empty bay, tightest scramble.
    return const ConveyorLevelConfig(
      numVisibleBays: 5,
      numColors: 7,
      bayDepth: 5,
      numEmptyBays: 1,
      scrambleMovesPerBay: 280,
      totalDeliveries: 25,
      wrinkles: <String>[
        'frozen',
        'locked',
        'fragile',
        'priority',
        'time-bomb',
        'double-color',
        'gravity-flip',
      ],
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_sort/services/conveyor_level_config.dart';

/// Smoke tests for the `ConveyorLevelConfig.forLevel` band lookup —
/// verifies the table from spec §4.3 is honored at every band
/// boundary and that the config is internally consistent (no zeroes,
/// no impossible parameter combos).
void main() {
  group('ConveyorLevelConfig.forLevel', () {
    test('returns a valid config for every level in 1..1000', () {
      for (var level = 1; level <= 1000; level++) {
        final cfg = ConveyorLevelConfig.forLevel(level);
        expect(cfg.numVisibleBays, greaterThan(0),
            reason: 'level $level — numVisibleBays must be > 0');
        expect(cfg.numColors, greaterThanOrEqualTo(2),
            reason: 'level $level — numColors must be >= 2');
        expect(cfg.bayDepth, greaterThanOrEqualTo(2),
            reason: 'level $level — bayDepth must be >= 2');
        expect(cfg.numEmptyBays, greaterThanOrEqualTo(1),
            reason: 'level $level — numEmptyBays must be >= 1');
        expect(cfg.scrambleMovesPerBay, greaterThan(0),
            reason: 'level $level — scramble moves > 0');
        expect(cfg.totalDeliveries, greaterThanOrEqualTo(cfg.numVisibleBays),
            reason: 'level $level — totalDeliveries >= numVisibleBays '
                '(can\'t ship more than you can fit visible at once)');
        expect(cfg.wrinkles, isA<List<String>>());
      }
    });

    test('intro band (L1-5): pure puzzles, no wrinkles, 4 bays', () {
      for (final l in [1, 3, 5]) {
        final cfg = ConveyorLevelConfig.forLevel(l);
        expect(cfg.numVisibleBays, 4);
        expect(cfg.numColors, 3);
        expect(cfg.wrinkles, isEmpty);
        expect(cfg.totalDeliveries, 5);
      }
    });

    test('early band (L6-15): frozen wrinkle starts, 5 bays + 4 colors', () {
      final cfg = ConveyorLevelConfig.forLevel(10);
      expect(cfg.numColors, 4);
      expect(cfg.wrinkles, contains('frozen'));
      expect(cfg.numVisibleBays, 5);
    });

    test('mid band (L16-30): locked wrinkle joins, 6 bays (3×2 grid)', () {
      final cfg = ConveyorLevelConfig.forLevel(20);
      expect(cfg.numVisibleBays, 6,
          reason: '3×2 multi-row grid kicks in at mid-game');
      expect(cfg.wrinkles, containsAll(['frozen', 'locked']));
    });

    test('late band (L31-60): fragile + priority unlock, depth 5', () {
      final cfg = ConveyorLevelConfig.forLevel(45);
      expect(cfg.bayDepth, 5);
      expect(
        cfg.wrinkles,
        containsAll(['frozen', 'locked', 'fragile', 'priority']),
      );
    });

    test('endgame band (L61-100): time-bomb arrives, 7 colors', () {
      final cfg = ConveyorLevelConfig.forLevel(85);
      expect(cfg.numColors, 7);
      expect(cfg.wrinkles, contains('time-bomb'));
    });

    test('procedural band (L100+): full wrinkle pool, only 1 empty bay', () {
      final cfg = ConveyorLevelConfig.forLevel(150);
      expect(cfg.numEmptyBays, 1);
      expect(cfg.scrambleMovesPerBay, 280);
      expect(
        cfg.wrinkles,
        containsAll([
          'frozen',
          'locked',
          'fragile',
          'priority',
          'time-bomb',
          'double-color',
          'gravity-flip',
        ]),
      );
    });

    test('boundary: level 5 vs 6 picks different bands', () {
      final a = ConveyorLevelConfig.forLevel(5);
      final b = ConveyorLevelConfig.forLevel(6);
      expect(a.wrinkles, isEmpty);
      expect(b.wrinkles, contains('frozen'));
    });

    test('boundary: level 100 vs 101 picks different bands', () {
      final a = ConveyorLevelConfig.forLevel(100);
      final b = ConveyorLevelConfig.forLevel(101);
      expect(a.numEmptyBays, 2);
      expect(b.numEmptyBays, 1);
    });
  });
}

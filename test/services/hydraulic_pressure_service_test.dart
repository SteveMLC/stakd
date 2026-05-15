import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:warehouse_sort/services/hydraulic_pressure_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HydraulicPressureService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await HydraulicPressureService().reset();
      await HydraulicPressureService().init();
    });

    test('fresh install: pressure is 0, not venting, cannot vent', () {
      final svc = HydraulicPressureService();
      expect(svc.pressure, 0.0);
      expect(svc.isVenting, isFalse);
      expect(svc.ventMovesRemaining, 0);
      expect(svc.canVent, isFalse);
    });

    test('combo step bonus adds 0.04 per step', () {
      final svc = HydraulicPressureService();
      svc.onMove(
        now: DateTime(2026, 5, 14, 12, 0, 0),
        comboStep: 1,
        wasBayCompleted: false,
      );
      expect(svc.pressure, closeTo(0.04, 0.001));
    });

    test('bay completion adds 0.03', () {
      final svc = HydraulicPressureService();
      svc.onMove(
        now: DateTime(2026, 5, 14, 12, 0, 0),
        comboStep: 0,
        wasBayCompleted: true,
      );
      expect(svc.pressure, closeTo(0.03, 0.001));
    });

    test('first move gets no speed bonus, second within 1.5s does', () {
      final svc = HydraulicPressureService();
      final t0 = DateTime(2026, 5, 14, 12, 0, 0);
      svc.onMove(now: t0, comboStep: 0, wasBayCompleted: false);
      expect(svc.pressure, 0.0);
      // 1 second later — within the 1.5s window
      svc.onMove(
        now: t0.add(const Duration(seconds: 1)),
        comboStep: 0,
        wasBayCompleted: false,
      );
      expect(svc.pressure, closeTo(0.06, 0.001));
    });

    test('move past 1.5s gets no speed bonus', () {
      final svc = HydraulicPressureService();
      final t0 = DateTime(2026, 5, 14, 12, 0, 0);
      svc.onMove(now: t0, comboStep: 0, wasBayCompleted: false);
      svc.onMove(
        now: t0.add(const Duration(seconds: 2)),
        comboStep: 0,
        wasBayCompleted: false,
      );
      expect(svc.pressure, 0.0);
    });

    test('chain x2 / x3 / x4 add 0.12 / 0.20 / 0.35', () {
      final svc = HydraulicPressureService();
      svc.onChain(2);
      expect(svc.pressure, closeTo(0.12, 0.001));
      svc.onChain(3);
      expect(svc.pressure, closeTo(0.32, 0.001));
      svc.onChain(4);
      expect(svc.pressure, closeTo(0.67, 0.001));
    });

    test('pressure clamps to 1.0 maximum', () {
      final svc = HydraulicPressureService();
      svc.onChain(4);
      svc.onChain(4);
      svc.onChain(4); // 3 × 0.35 = 1.05 → clamped to 1.0
      expect(svc.pressure, 1.0);
      expect(svc.canVent, isTrue);
    });

    test('canVent gates VENT activation', () {
      final svc = HydraulicPressureService();
      // Not full → cannot vent.
      expect(svc.tryActivateVent(), isFalse);
      // Fill it.
      svc.onChain(4);
      svc.onChain(4);
      svc.onChain(4);
      expect(svc.canVent, isTrue);
      expect(svc.tryActivateVent(), isTrue);
      expect(svc.isVenting, isTrue);
      expect(svc.ventMovesRemaining, 4);
      expect(svc.pressure, 0.0); // pressure drains into the burst
      // Can't double-vent.
      expect(svc.canVent, isFalse);
      expect(svc.tryActivateVent(), isFalse);
    });

    test('vent burst consumes one move per onMove, ends at 0', () {
      final svc = HydraulicPressureService();
      svc.onChain(4);
      svc.onChain(4);
      svc.onChain(4);
      svc.tryActivateVent();
      expect(svc.ventMovesRemaining, 4);
      final t0 = DateTime(2026, 5, 14, 12, 0, 0);
      for (var i = 0; i < 4; i++) {
        svc.onMove(
          now: t0.add(Duration(seconds: i)),
          comboStep: 0,
          wasBayCompleted: false,
        );
      }
      expect(svc.isVenting, isFalse);
      expect(svc.ventMovesRemaining, 0);
    });

    test('chain during vent does not pump pressure', () {
      final svc = HydraulicPressureService();
      svc.onChain(4);
      svc.onChain(4);
      svc.onChain(4);
      svc.tryActivateVent();
      expect(svc.pressure, 0.0);
      svc.onChain(4);
      expect(svc.pressure, 0.0); // unchanged — burst is consuming, not filling
    });

    test('onLevelStart restores banked pressure for same contract', () async {
      final svc = HydraulicPressureService();
      svc.onLevelStart('Local Contract 1');
      svc.onChain(4); // 0.35
      await svc.onLevelComplete();
      // Simulate fresh level start (singleton state survives — that's
      // the point of the carry-over).
      svc.onLevelStart('Local Contract 1');
      expect(svc.pressure, closeTo(0.35, 0.001));
    });

    test('onLevelStart resets pressure when contract changes', () async {
      final svc = HydraulicPressureService();
      svc.onLevelStart('Local Contract 1');
      svc.onChain(4);
      await svc.onLevelComplete();
      svc.onLevelStart('Local Contract 2');
      expect(svc.pressure, 0.0);
    });

    test('onLevelFail resets pressure and wipes banked', () async {
      final svc = HydraulicPressureService();
      svc.onLevelStart('Local Contract 1');
      svc.onChain(4);
      await svc.onLevelFail();
      expect(svc.pressure, 0.0);
      // Bank wiped too.
      svc.onLevelStart('Local Contract 1');
      expect(svc.pressure, 0.0);
    });

    test('tickIdle decays pressure past 2s idle threshold', () {
      final svc = HydraulicPressureService();
      final t0 = DateTime(2026, 5, 14, 12, 0, 0);
      svc.onMove(now: t0, comboStep: 0, wasBayCompleted: true);
      final pBefore = svc.pressure;
      // 1 second idle — under threshold, no decay.
      svc.tickIdle(t0.add(const Duration(seconds: 1)));
      expect(svc.pressure, pBefore);
      // 5 seconds idle (3s past the 2s threshold). 3 × 0.01 = 0.03 decay.
      svc.onMove(now: t0, comboStep: 0, wasBayCompleted: true); // re-stamp
      final p2 = svc.pressure;
      svc.tickIdle(t0.add(const Duration(seconds: 5)));
      expect(svc.pressure, lessThan(p2));
      expect(svc.pressure, closeTo(p2 - 0.03, 0.001));
    });

    test('tickIdle no-ops while venting', () {
      final svc = HydraulicPressureService();
      svc.onChain(4);
      svc.onChain(4);
      svc.onChain(4);
      svc.tryActivateVent();
      expect(svc.isVenting, isTrue);
      // No-op — pressure is already 0 and venting.
      svc.tickIdle(DateTime(2026, 5, 14, 12, 0, 30));
      expect(svc.pressure, 0.0);
      expect(svc.isVenting, isTrue);
    });

    test('reset clears persisted bank', () async {
      final svc = HydraulicPressureService();
      svc.onLevelStart('Local Contract 1');
      svc.onChain(4);
      await svc.onLevelComplete();
      await svc.reset();
      await svc.init();
      svc.onLevelStart('Local Contract 1');
      expect(svc.pressure, 0.0);
    });

    test('vent multiplier constant matches spec', () {
      expect(HydraulicPressureService.ventCashMultiplier, 2.0);
      expect(HydraulicPressureService.ventMovesGranted, 4);
    });
  });
}

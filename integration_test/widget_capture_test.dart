// Widget-isolated visual captures. Pumps specific widgets in isolation
// with mock props so we can screenshot them without driving full
// gameplay. Used for verifying overlays + screens that are hard to
// reach via the integration-test walkthrough path (completion overlay,
// promotion ceremony, etc).
//
// Run:
//   flutter test integration_test/widget_capture_test.dart \
//     -d "<sim-uuid>" --timeout=4x

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:warehouse_sort/services/audio_service.dart';
import 'package:warehouse_sort/services/storage_service.dart';
import 'package:warehouse_sort/widgets/completion_overlay.dart';

Future<void> _bootMinimal() async {
  SharedPreferences.setMockInitialValues({});
  await StorageService().init();
  await AudioService().init();
}

Future<void> _holdForCapture(
  WidgetTester tester,
  String stateName, {
  int seconds = 4,
}) async {
  final tsBegin = DateTime.now().millisecondsSinceEpoch / 1000.0;
  // ignore: avoid_print
  print('VISUAL_CAPTURE_STATE_BEGIN ts=$tsBegin name=$stateName');
  for (var i = 0; i < seconds * 60; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final tsEnd = DateTime.now().millisecondsSinceEpoch / 1000.0;
  // ignore: avoid_print
  print('VISUAL_CAPTURE_STATE_END ts=$tsEnd name=$stateName');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('completion overlay renders with hero truck', (tester) async {
    await _bootMinimal();

    await tester.pumpWidget(
      MaterialApp(
        home: Provider<bool>(
          create: (_) => false,
          child: Builder(builder: (context) {
            return CompletionOverlay(
              stars: 3,
              moves: 14,
              par: 16,
              time: const Duration(seconds: 42),
              score: 1850,
              xpEarned: 120,
              coinsEarned: 75,
              currentStreak: 1,
              isNewMoveBest: true,
              isNewTimeBest: false,
              rpAwarded: 0,
              tierPromoted: false,
              incomeMulBefore: 1.0,
              incomeMulAfter: 1.0,
              onNextPuzzle: () {},
              onHome: () {},
            );
          }),
        ),
      ),
    );

    // Allow scale-in animation to settle.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await _holdForCapture(tester, 'completion_overlay_3star', seconds: 6);
  });
}

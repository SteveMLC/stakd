import 'package:flutter_test/flutter_test.dart';
import 'package:stakd/app.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const StakdApp());
    expect(find.text('SORTBLOOM'), findsOneWidget);
  });
}

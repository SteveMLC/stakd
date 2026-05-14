import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_sort/services/business_tier_service.dart';
import 'package:warehouse_sort/services/contract_service.dart';
import 'package:warehouse_sort/services/income_multiplier_service.dart';
import 'package:warehouse_sort/services/machinery_service.dart';
import 'package:warehouse_sort/services/warehouse_economy_service.dart';
import 'package:warehouse_sort/widgets/warehouse_hud.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: WarehouseEconomyService()),
          ChangeNotifierProvider.value(value: BusinessTierService()),
          ChangeNotifierProvider.value(value: IncomeMultiplierService()),
          ChangeNotifierProvider.value(value: MachineryService()),
        ],
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WarehouseEconomyService().reset();
    await BusinessTierService().reset();
    await IncomeMultiplierService().reset();
    await IncomeMultiplierService().init();
    await MachineryService().reset();
    await MachineryService().init();
    // computeMultiplier reads ContractService too — make sure it's clean.
    await ContractService().reset();
    await ContractService().init();
  });

  testWidgets('renders cash + WH level + tier badge', (tester) async {
    final economy = WarehouseEconomyService();
    await economy.reset();
    await economy.grantCash(1234);

    await tester.pumpWidget(_wrap(const WarehouseHud()));
    // Cash chip uses a 650ms TweenAnimationBuilder; pump past it so the
    // displayed value lands on the final amount.
    await tester.pump(const Duration(seconds: 1));

    // Cash chip formats >=1000 as k:  '1.2k'
    expect(find.text('1.2k'), findsOneWidget);
    expect(find.textContaining('WH Lv'), findsOneWidget);
    expect(find.textContaining('Local'), findsOneWidget);
  });

  testWidgets('cash chip formats >=1M as M', (tester) async {
    final economy = WarehouseEconomyService();
    await economy.reset();
    await economy.grantCash(2500000);

    await tester.pumpWidget(_wrap(const WarehouseHud()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2.5M'), findsOneWidget);
  });

  testWidgets('XP progress updates when reward awarded', (tester) async {
    final economy = WarehouseEconomyService();
    await economy.reset();

    await tester.pumpWidget(_wrap(const WarehouseHud()));
    await tester.pump();
    // Fresh: 0 XP in level 1
    expect(find.textContaining('0/100 XP'), findsOneWidget);

    await economy.awardReward(const ShipmentReward(cash: 0, xp: 50));
    await tester.pump();
    expect(find.textContaining('50/100 XP'), findsOneWidget);
  });

  testWidgets('hides tier badge when showTierBadge: false', (tester) async {
    await tester.pumpWidget(_wrap(const WarehouseHud(showTierBadge: false)));
    await tester.pump();
    expect(find.textContaining('Local'), findsNothing);
  });
}

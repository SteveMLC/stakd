import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_sort/data/local_regional_levels.dart';
import 'package:warehouse_sort/services/contract_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContractService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ContractService().reset();
    });

    test('catalog has 6 contracts covering levels 1-30', () {
      expect(ContractService.contracts.length, 6);
      expect(ContractService.contracts.first.firstLevel, 1);
      expect(ContractService.contracts.last.lastLevel, 30);
    });

    test('contractForLevel maps levels to contracts correctly', () {
      final svc = ContractService();
      expect(svc.contractForLevel(1)?.contractIndex, 0);
      expect(svc.contractForLevel(5)?.contractIndex, 0);
      expect(svc.contractForLevel(6)?.contractIndex, 1);
      expect(svc.contractForLevel(11)?.contractIndex, 2);
      expect(svc.contractForLevel(16)?.contractIndex, 3);
      expect(svc.contractForLevel(21)?.contractIndex, 4);
      expect(svc.contractForLevel(26)?.contractIndex, 5);
      expect(svc.contractForLevel(30)?.contractIndex, 5);
      expect(svc.contractForLevel(31), isNull); // past v1.0 catalog
    });

    test('tier matches expected split: Local 1-15, Regional 16-30', () {
      for (final c in ContractService.contracts) {
        if (c.lastLevel <= 15) {
          expect(c.tier, BusinessTier.local, reason: 'Contract ${c.contractIndex} should be Local');
        } else {
          expect(c.tier, BusinessTier.regional, reason: 'Contract ${c.contractIndex} should be Regional');
        }
      }
    });

    test('first contract is always unlocked, others depend on prior clear', () {
      final svc = ContractService();
      expect(svc.isContractUnlocked(ContractService.contracts[0]), isTrue);
      expect(svc.isContractUnlocked(ContractService.contracts[1]), isFalse);
    });

    test('recordLevelComplete stores stars and returns null until contract complete', () async {
      final svc = ContractService();
      await svc.reset();
      // Clear 4 of 5 levels in Local Contract 1
      for (var lvl = 1; lvl <= 4; lvl++) {
        final event = await svc.recordLevelComplete(lvl, 2, cashBonusForContract: 100);
        expect(event, isNull, reason: 'Level $lvl shouldn\'t complete the contract');
        expect(svc.starsForLevel(lvl), 2);
      }
      expect(svc.isContractCleared(ContractService.contracts[0]), isFalse);
    });

    test('recordLevelComplete fires ContractCompletion on the 5th clear', () async {
      final svc = ContractService();
      await svc.reset();
      for (var lvl = 1; lvl <= 4; lvl++) {
        await svc.recordLevelComplete(lvl, 1, cashBonusForContract: 100);
      }
      final event = await svc.recordLevelComplete(5, 3, cashBonusForContract: 100);
      expect(event, isNotNull);
      expect(event!.contract.contractIndex, 0);
      expect(event.cashBonus, 100);
      expect(event.totalStars, 4 + 3); // 4 levels @ 1★ + L5 @ 3★ = 7
    });

    test('contract-completion event fires once', () async {
      final svc = ContractService();
      await svc.reset();
      for (var lvl = 1; lvl <= 5; lvl++) {
        await svc.recordLevelComplete(lvl, 2, cashBonusForContract: 100);
      }
      // Replay level 5 — should NOT fire completion again.
      final replay = await svc.recordLevelComplete(5, 3, cashBonusForContract: 100);
      expect(replay, isNull);
      expect(svc.starsForLevel(5), 3); // best-stars-wins
    });

    test('next contract unlocks after previous cleared', () async {
      final svc = ContractService();
      await svc.reset();
      for (var lvl = 1; lvl <= 5; lvl++) {
        await svc.recordLevelComplete(lvl, 1, cashBonusForContract: 100);
      }
      expect(svc.isContractUnlocked(ContractService.contracts[1]), isTrue);
      // Contract 3 (index 2) still locked
      expect(svc.isContractUnlocked(ContractService.contracts[2]), isFalse);
    });

    test('nextSuggestedLevel skips cleared levels', () async {
      final svc = ContractService();
      await svc.reset();
      // Clear 1, 2 — next should be 3
      await svc.recordLevelComplete(1, 1, cashBonusForContract: 0);
      await svc.recordLevelComplete(2, 1, cashBonusForContract: 0);
      expect(svc.nextSuggestedLevel, 3);
    });

    test('starsForLevel returns 0 for untouched levels', () {
      expect(ContractService().starsForLevel(99), 0);
    });

    test('best-stars-wins on lower replays', () async {
      final svc = ContractService();
      await svc.reset();
      await svc.recordLevelComplete(1, 3, cashBonusForContract: 0);
      await svc.recordLevelComplete(1, 1, cashBonusForContract: 0);
      expect(svc.starsForLevel(1), 3);
    });
  });
}

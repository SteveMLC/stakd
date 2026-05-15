import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_sort/utils/number_format.dart';

void main() {
  group('formatCash', () {
    test('zero renders as "0"', () {
      expect(formatCash(0), '0');
    });

    test('small integers render without suffix', () {
      expect(formatCash(1), '1');
      expect(formatCash(42), '42');
      expect(formatCash(999), '999');
    });

    test('thousands use K suffix', () {
      expect(formatCash(1000), '1K');
      expect(formatCash(1234), '1.23K');
      expect(formatCash(9999), '9.99K');
      expect(formatCash(50000), '50K');
    });

    test('millions use M suffix', () {
      expect(formatCash(1000000), '1M');
      expect(formatCash(1500000), '1.5M');
      expect(formatCash(12345678), '12.34M');
    });

    test('billions use B suffix', () {
      expect(formatCash(1000000000), '1B');
      expect(formatCash(2500000000), '2.5B');
    });

    test('trillions use T suffix', () {
      expect(formatCash(1000000000000), '1T');
      expect(formatCash(1500000000000), '1.5T');
    });

    test('quadrillions use Qa suffix', () {
      expect(formatCash(1e15), '1Qa');
      expect(formatCash(2.5e15), '2.5Qa');
    });

    test('quintillions use Qi suffix', () {
      expect(formatCash(1e18), '1Qi');
    });

    test('sextillions use Sx suffix', () {
      expect(formatCash(1e21), '1Sx');
    });

    test('decillions use Dc suffix', () {
      expect(formatCash(1e33), '1Dc');
    });

    test('quindecillions use Qid suffix', () {
      expect(formatCash(1e48), '1Qid');
    });

    test('past Qid falls back to scientific notation', () {
      final result = formatCash(1e52);
      expect(result.contains('e'), isTrue);
    });

    test('negative values prefix with minus', () {
      expect(formatCash(-1000), '-1K');
      expect(formatCash(-2500000), '-2.5M');
      expect(formatCash(-42), '-42');
    });

    test('trailing zeros are stripped', () {
      expect(formatCash(1000), '1K');           // not "1.00K"
      expect(formatCash(1100), '1.1K');         // not "1.10K"
      expect(formatCash(1230), '1.23K');
      expect(formatCash(10_000), '10K');        // not "10.00K"
      expect(formatCash(2_000_000_000), '2B');
    });

    test('decimals override controls precision', () {
      expect(formatCash(1234, decimals: 1), '1.2K');
      expect(formatCash(1234, decimals: 0), '1K');
      expect(formatCash(1500000, decimals: 1), '1.5M');
    });
  });

  group('formatCashCompact', () {
    test('uses 1 decimal place', () {
      expect(formatCashCompact(1234), '1.2K');
      expect(formatCashCompact(1500000), '1.5M');
    });
  });

  group('formatCashWithSymbol', () {
    test('prefixes positive values with \$', () {
      expect(formatCashWithSymbol(1500000), '\$1.5M');
      expect(formatCashWithSymbol(42), '\$42');
    });

    test('handles negative values', () {
      expect(formatCashWithSymbol(-1500), '-\$1.5K');
    });
  });

  group('formatMultiplier', () {
    test('whole multipliers drop decimal', () {
      expect(formatMultiplier(1.0), '1×');
      expect(formatMultiplier(2.0), '2×');
      expect(formatMultiplier(10.0), '10×');
    });

    test('partial multipliers keep significant digits', () {
      expect(formatMultiplier(1.5), '1.5×');
      expect(formatMultiplier(2.25), '2.25×');
      expect(formatMultiplier(6.5), '6.5×');
    });

    test('trims trailing zeros', () {
      expect(formatMultiplier(1.10), '1.1×');
      expect(formatMultiplier(2.50), '2.5×');
    });
  });

  group('formatXp', () {
    test('formats with 1-decimal precision', () {
      expect(formatXp(0), '0');
      expect(formatXp(500), '500');
      expect(formatXp(1500), '1.5K');
      expect(formatXp(1500000), '1.5M');
    });
  });

  group('parseSuffixExponent', () {
    test('empty string returns 0 (ones)', () {
      expect(parseSuffixExponent(''), 0);
    });

    test('known suffixes return correct exponent', () {
      expect(parseSuffixExponent('K'), 3);
      expect(parseSuffixExponent('M'), 6);
      expect(parseSuffixExponent('B'), 9);
      expect(parseSuffixExponent('T'), 12);
      expect(parseSuffixExponent('Qa'), 15);
      expect(parseSuffixExponent('Dc'), 33);
      expect(parseSuffixExponent('Qid'), 48);
    });

    test('unknown suffix returns null', () {
      expect(parseSuffixExponent('XYZ'), isNull);
    });
  });

  group('infinite-scaling sanity checks', () {
    test('district 10 reward (~50K) reads cleanly', () {
      expect(formatCashWithSymbol(50000), '\$50K');
    });

    test('district 20 reward (~1M) reads cleanly', () {
      expect(formatCashWithSymbol(1500000), '\$1.5M');
    });

    test('district 50 reward (~1e15) reads cleanly', () {
      expect(formatCashWithSymbol(1e15), '\$1Qa');
    });

    test('district 100 reward (1e30) reads cleanly', () {
      expect(formatCashWithSymbol(1e30), '\$1No');
    });

    test('district progression is monotonic in suffix-band', () {
      // Each band of 1000× should land in the next suffix band.
      // Use double power directly — past 10^18 we exceed int max
      // (2^63 ≈ 9.2e18) so BigInt→int would overflow to the same
      // value across multiple bands.
      var prev = '';
      for (var exp = 0; exp <= 48; exp += 3) {
        final value = math.pow(10, exp).toDouble();
        final formatted = formatCash(value);
        expect(formatted, isNot(equals(prev)),
            reason: 'exp=$exp formatted=$formatted prev=$prev');
        prev = formatted;
      }
    });
  });
}

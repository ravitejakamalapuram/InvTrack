// #946: a unit-based valuation (grams of gold at a price per gram). The total
// is derived from quantity x price at the currency's precision, and a snapshot
// that changes its amount by hand stops claiming a weight.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';

import '../../valuation/valuation_fixtures.dart';

void main() {
  group('UnitHolding.value', () {
    test('10 g at 6,000 per gram is exactly 60,000.00', () {
      const h = UnitHolding(
        quantity: 10,
        unit: QuantityUnit.gram,
        unitPrice: 6000,
      );
      expect(h.value('INR'), 60000.00);
    });

    test('fractional quantity rounds half away from zero to the paisa', () {
      // 2.5 x 7234.55 = 18086.375 -> 18086.38
      const h = UnitHolding(
        quantity: 2.5,
        unit: QuantityUnit.gram,
        unitPrice: 7234.55,
      );
      expect(h.value('INR'), 18086.38);
    });

    test('a zero-fraction currency rounds to whole units', () {
      const h = UnitHolding(
        quantity: 1.5,
        unit: QuantityUnit.gram,
        unitPrice: 1001,
      );
      expect(h.value('JPY'), 1502); // 1501.5 rounds up
    });

    test('multiplies the decimals as written: 0.1 x 0.35 is 0.035 -> 0.04', () {
      const h = UnitHolding(
        quantity: 0.1,
        unit: QuantityUnit.gram,
        unitPrice: 0.35,
      );
      expect(h.value('INR'), 0.04);
    });

    test('an overflowing product has no value instead of throwing', () {
      const h = UnitHolding(
        quantity: 1e200,
        unit: QuantityUnit.gram,
        unitPrice: 1e200,
      );
      expect(h.valueOrNull('INR'), isNull);
      expect(() => h.value('INR'), throwsStateError);
      const big = UnitHolding(
        quantity: 1e10,
        unit: QuantityUnit.gram,
        unitPrice: 1e10,
      );
      expect(big.valueOrNull('INR'), isNull); // 16 digits or more
    });

    test('is deterministic for repeated fractional values', () {
      const h = UnitHolding(
        quantity: 0.1,
        unit: QuantityUnit.gram,
        unitPrice: 0.3,
      );
      expect(h.value('INR'), 0.03);
    });
  });

  group('QuantityUnit', () {
    test('converts to grams', () {
      expect(QuantityUnit.gram.gramsPerUnit, 1.0);
      expect(QuantityUnit.kilogram.gramsPerUnit, 1000.0);
      expect(QuantityUnit.sovereign.gramsPerUnit, 8.0);
      expect(QuantityUnit.tola.gramsPerUnit, closeTo(11.6638038, 1e-6));
      expect(QuantityUnit.troyOunce.gramsPerUnit, closeTo(31.1034768, 1e-6));
    });

    test('tryParse never reinterprets an unknown unit', () {
      expect(QuantityUnit.tryParse('gram'), QuantityUnit.gram);
      expect(QuantityUnit.tryParse('carat'), isNull);
      expect(QuantityUnit.tryParse(null), isNull);
    });
  });

  group('UnitHolding.isValid', () {
    test('needs finite, positive quantity and non-negative price', () {
      bool ok(double q, double p) => UnitHolding(
        quantity: q,
        unit: QuantityUnit.gram,
        unitPrice: p,
      ).isValid;
      expect(ok(10, 6000), isTrue);
      expect(ok(0, 6000), isFalse);
      expect(ok(-1, 6000), isFalse);
      expect(ok(double.nan, 6000), isFalse);
      expect(ok(10, -1), isFalse);
      expect(ok(10, double.infinity), isFalse);
    });
  });

  group('snapshot with a holding', () {
    const holding = UnitHolding(
      quantity: 10,
      unit: QuantityUnit.gram,
      unitPrice: 6000,
    );
    final base = testSnapshot('s', amount: 1, date: DateTime(2026, 4, 1));

    test('copyWith(holding) derives the amount', () {
      final s = base.copyWith(
        holding: holding,
        kind: ValuationKind.marketValue,
      );
      expect(s.amount, 60000.00);
      expect(s.holding, holding);
    });

    test('copyWith(amount) alone drops the stale holding', () {
      final s = base.copyWith(holding: holding).copyWith(amount: 59000);
      expect(s.amount, 59000);
      expect(s.holding, isNull);
    });

    test('an amount-only snapshot has no holding', () {
      expect(base.holding, isNull);
    });

    test('holding takes part in equality', () {
      expect(
        base.copyWith(holding: holding),
        isNot(equals(base.copyWith(amount: 60000))),
      );
    });
  });
}

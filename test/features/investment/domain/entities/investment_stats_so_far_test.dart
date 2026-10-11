// #954: an open investment that has returned its cost and has no current
// value keeps its figures, labelled "so far". InvestmentStats decides that
// (and "still waiting for a value") in one place, for every screen.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';

InvestmentStats _stats({
  double invested = 100000,
  double returned = 110000,
  double? currentValue,
  int missing = 0,
  int cashOnly = 0,
}) => InvestmentStats(
  totalInvested: invested,
  totalReturned: returned,
  netCashFlow: returned - invested,
  absoluteReturn: invested > 0 ? (returned - invested) / invested * 100 : 0,
  moic: invested > 0 ? returned / invested : 0,
  xirr: 0.1,
  cashFlowCount: 2,
  firstCashFlowDate: DateTime(2023, 1, 1),
  lastCashFlowDate: DateTime(2024, 1, 1),
  currentValue: currentValue,
  missingValueCount: missing,
  cashOnlyCount: cashOnly,
);

void main() {
  group('cashOnlyCount', () {
    test('defaults to 0 and is carried by copyWith', () {
      expect(InvestmentStats.empty().cashOnlyCount, 0);
      expect(
        InvestmentStats.empty().copyWith(cashOnlyCount: 2).cashOnlyCount,
        2,
      );
      expect(_stats(cashOnly: 3).copyWith().cashOnlyCount, 3);
    });

    test('is part of equality and hashCode', () {
      final base = _stats();
      final counted = _stats(cashOnly: 1);
      expect(counted == base, isFalse);
      expect(counted, _stats(cashOnly: 1));
      expect(counted.hashCode, _stats(cashOnly: 1).hashCode);
      expect(counted.hashCode == base.hashCode, isFalse);
    });
  });

  group('awaitsValue', () {
    test('is true while a holding is counted as missing', () {
      expect(_stats(missing: 1).awaitsValue, isTrue);
      expect(_stats(missing: 1, cashOnly: 1).awaitsValue, isTrue);
    });

    test('is true for stats built without values that owe money back', () {
      // Calculated before values loaded, or never with them.
      expect(_stats(returned: 52500).awaitsValue, isTrue);
    });

    test('is false once the cost is back, or with a value', () {
      expect(_stats().awaitsValue, isFalse);
      expect(_stats(returned: 100000).awaitsValue, isFalse);
      expect(_stats(returned: 52500, currentValue: 90000).awaitsValue, isFalse);
    });

    test('is true one paisa short of the cost', () {
      expect(
        _stats(invested: 1000000, returned: 999999.99).awaitsValue,
        isTrue,
      );
    });
  });

  group('returnsAreSoFar', () {
    test('is true for a counted cash-only holding', () {
      expect(_stats(cashOnly: 1).returnsAreSoFar, isTrue);
    });

    test('stays true when another open holding has a value', () {
      // The total is not enough: only the count remembers the holding.
      expect(_stats(cashOnly: 1, currentValue: 50000).returnsAreSoFar, isTrue);
    });

    test('is false while any holding awaits a value', () {
      expect(_stats(cashOnly: 1, missing: 1).returnsAreSoFar, isFalse);
    });

    test('is true for stats built without values that got the cost back', () {
      expect(_stats().returnsAreSoFar, isTrue);
      expect(_stats(returned: 100000).returnsAreSoFar, isTrue);
    });

    test('is false with a value, and for stats that owe money back', () {
      expect(_stats(currentValue: 90000).returnsAreSoFar, isFalse);
      expect(_stats(returned: 52500).returnsAreSoFar, isFalse);
    });

    test('is false for income with no money out, and for no data', () {
      expect(_stats(invested: 0, returned: 500).returnsAreSoFar, isFalse);
      expect(InvestmentStats.empty().returnsAreSoFar, isFalse);
    });
  });
}

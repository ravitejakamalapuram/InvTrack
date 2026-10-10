// #911: the gain a milestone notification announces is read from the stats,
// not summed again by the notifier (money rule 3). Gain is what the holder
// has made so far: net cash flow plus the current value of what is still
// open. Money that is paid out and put back in changes neither.
//
// Expected values, by hand:
//   Renewed FD: -10L; +10.75L and -10.75L on one day; +11.55625L.
//     Returned 22,30,625 - invested 20,75,000 = 1,55,625 = (1.155625 - 1) x
//     paid-in 10L.
//   Open rollover: -1L; +1.07L and -1.07L on one day; value 1.1449L.
//     Net -1,00,000 + value 1,14,490 = 14,490 = (1.1449 - 1) x paid-in 1L.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

final _module = FinancialCalculatorModule();

var _nextId = 0;

CashFlowEntity _flow(CashFlowType type, double amount, DateTime date) =>
    CashFlowEntity(
      id: 'cf-${_nextId++}',
      investmentId: 'inv',
      date: date,
      type: type,
      amount: amount,
      createdAt: date,
      currency: 'INR',
    );

void main() {
  group('InvestmentStats.gain', () {
    test('a renewed FD gains 1,55,625: the renewal changes nothing', () {
      final stats = _module.calculateStats([
        _flow(CashFlowType.invest, 1000000, DateTime.utc(2023, 1, 1)),
        _flow(CashFlowType.returnFlow, 1075000, DateTime.utc(2024, 1, 1)),
        _flow(CashFlowType.invest, 1075000, DateTime.utc(2024, 1, 1)),
        _flow(CashFlowType.returnFlow, 1155625, DateTime.utc(2025, 1, 1)),
      ]);

      expect(stats.gain, 155625.0);
      expect(
        stats.gain,
        closeTo((stats.moic - 1) * stats.paidInCapital, 0.005),
      );
    });

    test('an open rollover adds its current value to the net cash flow', () {
      final stats = _module.calculateStats(
        [
          _flow(CashFlowType.invest, 100000, DateTime.utc(2024, 1, 1)),
          _flow(CashFlowType.returnFlow, 107000, DateTime.utc(2025, 1, 1)),
          _flow(CashFlowType.invest, 107000, DateTime.utc(2025, 1, 1)),
        ],
        terminalValues: TerminalValues(
          flows: [
            CashFlowEntity(
              id: '${TerminalValues.idPrefix}inv',
              investmentId: 'inv',
              date: DateTime.utc(2026, 1, 1),
              type: CashFlowType.returnFlow,
              amount: 114490,
              createdAt: DateTime.utc(2026, 1, 1),
              currency: 'INR',
            ),
          ],
        ),
      );

      expect(stats.netCashFlow, -100000.0);
      expect(stats.gain, 14490.0);
      expect(
        stats.gain,
        closeTo((stats.moic - 1) * stats.paidInCapital, 0.005),
      );
    });

    test('a loss is negative and income and fees count', () {
      final stats = _module.calculateStats([
        _flow(CashFlowType.invest, 100000, DateTime.utc(2024, 1, 1)),
        _flow(CashFlowType.fee, 1000, DateTime.utc(2024, 1, 1)),
        _flow(CashFlowType.income, 5000, DateTime.utc(2024, 7, 1)),
        _flow(CashFlowType.returnFlow, 90000, DateTime.utc(2025, 1, 1)),
      ]);

      expect(stats.gain, -6000.0);
    });

    test('no data is a gain of 0', () {
      expect(InvestmentStats.empty().gain, 0.0);
    });
  });
}

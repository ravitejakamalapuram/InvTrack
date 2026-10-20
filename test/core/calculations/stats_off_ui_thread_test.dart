import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/calculations/stats_off_ui_thread.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

CashFlowEntity _flow(
  String id,
  CashFlowType type,
  double amount,
  DateTime date, {
  String investmentId = 'inv-1',
}) => CashFlowEntity(
  id: id,
  investmentId: investmentId,
  amount: amount,
  currency: 'INR',
  type: type,
  date: date,
  createdAt: DateTime(2024),
);

void _expectSameStats(InvestmentStats actual, InvestmentStats expected) {
  expect(actual.totalInvested, expected.totalInvested);
  expect(actual.paidInCapital, expected.paidInCapital);
  expect(actual.principal, expected.principal);
  expect(actual.totalReturned, expected.totalReturned);
  expect(actual.netCashFlow, expected.netCashFlow);
  expect(actual.absoluteReturn, expected.absoluteReturn);
  expect(actual.moic, expected.moic);
  expect(actual.xirr, expected.xirr);
  expect(actual.xirrMethod, expected.xirrMethod);
  expect(actual.cashFlowCount, expected.cashFlowCount);
  expect(actual.firstCashFlowDate, expected.firstCashFlowDate);
  expect(actual.lastCashFlowDate, expected.lastCashFlowDate);
  expect(actual.currentValue, expected.currentValue);
  expect(actual.currentValueDate, expected.currentValueDate);
  expect(actual.currentValueIsEstimate, expected.currentValueIsEstimate);
  expect(actual.currentValueRate, expected.currentValueRate);
  expect(actual.missingValueCount, expected.missingValueCount);
  expect(actual.cashOnlyCount, expected.cashOnlyCount);
  expect(actual.limitedHistoryCount, expected.limitedHistoryCount);
  expect(actual.returnsKnown, expected.returnsKnown);
}

void main() {
  final flows = [
    _flow('a', CashFlowType.invest, 100000, DateTime(2023, 4, 1)),
    _flow('b', CashFlowType.income, 4500, DateTime(2023, 10, 1)),
    _flow('c', CashFlowType.income, 4500, DateTime(2024, 4, 1)),
    _flow('d', CashFlowType.fee, 250, DateTime(2024, 4, 2)),
    _flow('e', CashFlowType.returnFlow, 20000, DateTime(2024, 9, 1)),
  ];
  final terminal = TerminalValues(
    flows: [_flow('tv', CashFlowType.returnFlow, 95000, DateTime(2025, 4, 1))],
  );

  group('calculateStatsOffUiThread', () {
    test(
      'a real isolate gives exactly the stats the UI isolate would',
      () async {
        final expected = FinancialCalculatorModule().calculateStats(
          flows,
          terminalValues: terminal,
        );
        expect(expected.xirr, isNotNull);

        final actual = await calculateStatsOffUiThread(
          flows,
          terminalValues: terminal,
          minFlowsForIsolate: 0,
        );

        _expectSameStats(actual, expected);
      },
    );

    test('empty input gives empty stats through the isolate too', () async {
      final actual = await calculateStatsOffUiThread(
        const [],
        minFlowsForIsolate: 0,
      );
      _expectSameStats(actual, InvestmentStats.empty());
    });

    test('big inputs go to the runner, small ones stay inline', () async {
      var runs = 0;
      Future<InvestmentStats> spy(
        InvestmentStats Function(StatsArgs) task,
        StatsArgs args,
      ) async {
        runs++;
        return task(args);
      }

      await calculateStatsOffUiThread(
        flows,
        terminalValues: terminal,
        minFlowsForIsolate: 6, // 5 flows + 1 terminal value
        runner: spy,
      );
      expect(runs, 1);

      await calculateStatsOffUiThread(
        flows,
        terminalValues: terminal,
        minFlowsForIsolate: 7,
        runner: spy,
      );
      expect(runs, 1, reason: 'under the limit nothing is sent to a runner');
    });
  });
}

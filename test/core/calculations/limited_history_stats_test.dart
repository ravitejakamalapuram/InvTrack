// #941: an investment with limited history (an opening baseline) keeps its
// value and its cash-only figures in the totals, but stays out of XIRR, MOIC
// and absolute return, which would otherwise read it as an unrealised loss or
// a 0% return.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

import '../../features/investment/valuation/valuation_fixtures.dart';

CashFlowEntity _terminal(String id, double amount, DateTime date) =>
    CashFlowEntity(
      id: 'current-value:$id',
      investmentId: id,
      date: date,
      type: CashFlowType.returnFlow,
      amount: amount,
      createdAt: date,
    );

void main() {
  final module = FinancialCalculatorModule();
  final valueDate = DateTime(2026, 10, 2);

  // A normal investment: 1,00,000 in, worth 1,20,000 a year on.
  final normalFlows = [
    testFlow('a', CashFlowType.invest, 100000, DateTime(2025, 10, 2)),
  ];
  final normalTerminal = _terminal('a', 120000, valueDate);

  // An investment with limited history: a baseline of 5,00,000 and a later
  // top-up of 50,000 and a payout of 10,000.
  final limitedFlows = [
    testFlow('b', CashFlowType.invest, 50000, DateTime(2026, 3, 1)),
    testFlow('b', CashFlowType.income, 10000, DateTime(2026, 6, 1)),
  ];
  final limitedTerminal = _terminal('b', 550000, valueDate);

  group('terminal-only input (plan test 23)', () {
    final terminal = TerminalValues(
      flows: [_terminal('b', 500000, valueDate)],
      limitedHistoryIds: const {'b'},
    );

    test('a portfolio of baselines shows data, not onboarding', () {
      final stats = module.calculateStats(const [], terminalValues: terminal);
      expect(stats.hasData, isTrue);
      expect(stats.currentValue, 500000.00);
      expect(stats.currentValueDate, valueDate);
      expect(stats.cashFlowCount, 0);
      expect(stats.returnsKnown, isFalse);
      expect(stats.xirr, isNull);
      expect(stats.limitedHistoryCount, 1);
    });

    test('no flows and no values is still empty', () {
      final stats = module.calculateStats(const []);
      expect(stats.hasData, isFalse);
      expect(stats, InvestmentStats.empty());
      expect(stats.returnsKnown, isTrue);
      expect(stats.limitedHistoryCount, 0);
    });

    test('calculateStatsByInvestment accepts terminal-only input', () {
      final byInvestment = module.calculateStatsByInvestment(
        normalFlows,
        terminalValues: {
          'a': TerminalValues(flows: [normalTerminal]),
          'b': terminal,
        },
      );
      expect(byInvestment.keys, unorderedEquals(['a', 'b']));
      expect(byInvestment['b']!.currentValue, 500000.00);
      expect(byInvestment['b']!.hasData, isTrue);
      expect(byInvestment['b']!.returnsKnown, isFalse);
      expect(byInvestment['a']!.xirr, isNotNull);
    });

    test('a terminal-only entry with no value stays out', () {
      final byInvestment = module.calculateStatsByInvestment(
        normalFlows,
        terminalValues: {'b': const TerminalValues()},
      );
      expect(byInvestment.keys, ['a']);
    });
  });

  group('limited investments in a mixed portfolio (plan test 17)', () {
    final alone = module.calculateStats(
      normalFlows,
      terminalValues: TerminalValues(flows: [normalTerminal]),
    );
    final mixed = module.calculateStats(
      [...normalFlows, ...limitedFlows],
      terminalValues: TerminalValues(
        flows: [normalTerminal, limitedTerminal],
        limitedHistoryIds: const {'b'},
      ),
    );

    test('XIRR, MOIC and return are those of the other investments only', () {
      expect(mixed.xirr, alone.xirr);
      expect(mixed.moic, alone.moic);
      expect(mixed.absoluteReturn, alone.absoluteReturn);
      expect(mixed.paidInCapital, alone.paidInCapital);
      expect(mixed.returnsKnown, isTrue);
      expect(mixed.limitedHistoryCount, 1);
    });

    test('the totals and the value still count the limited investment', () {
      expect(mixed.totalInvested, 150000);
      expect(mixed.totalReturned, 10000);
      expect(mixed.netCashFlow, -140000);
      expect(mixed.currentValue, 670000.00);
      expect(mixed.cashFlowCount, 3);
    });

    test('the limited investment alone has unknown returns', () {
      final only = module.calculateStats(
        limitedFlows,
        terminalValues: TerminalValues(
          flows: [limitedTerminal],
          limitedHistoryIds: const {'b'},
        ),
      );
      expect(only.returnsKnown, isFalse);
      expect(only.xirr, isNull);
      expect(only.totalInvested, 50000);
      expect(only.currentValue, 550000.00);
      expect(only.limitedHistoryCount, 1);
    });

    test('an id that is not in the flows or values is not counted', () {
      final stats = module.calculateStats(
        normalFlows,
        terminalValues: TerminalValues(
          flows: [normalTerminal],
          limitedHistoryIds: const {'gone'},
        ),
      );
      expect(stats.limitedHistoryCount, 0);
      expect(stats.xirr, alone.xirr);
    });
  });

  group('TerminalValues', () {
    test('withConvertedFlows keeps the limited-history ids', () {
      final values = TerminalValues(
        flows: [_terminal('b', 500000, valueDate)],
        limitedHistoryIds: const {'b'},
      );
      final converted = values.withConvertedFlows(values.flows);
      expect(converted.limitedHistoryIds, {'b'});
    });

    test('none has no limited ids', () {
      expect(TerminalValues.none.limitedHistoryIds, isEmpty);
    });
  });

  group('InvestmentStats', () {
    test('copyWith, equality and hashCode cover the new fields', () {
      final base = InvestmentStats.empty();
      final limited = base.copyWith(
        limitedHistoryCount: 2,
        returnsKnown: false,
      );
      expect(limited.limitedHistoryCount, 2);
      expect(limited.returnsKnown, isFalse);
      expect(limited == base, isFalse);
      expect(
        limited,
        base.copyWith(limitedHistoryCount: 2, returnsKnown: false),
      );
      expect(
        limited.hashCode,
        base.copyWith(limitedHistoryCount: 2, returnsKnown: false).hashCode,
      );
      expect(base.copyWith(returnsKnown: false) == base, isFalse);
    });

    test('hasData is a cash flow or a value', () {
      expect(InvestmentStats.empty().hasData, isFalse);
      expect(InvestmentStats.empty().copyWith(currentValue: 1).hasData, isTrue);
      expect(
        InvestmentStats.empty().copyWith(cashFlowCount: 1).hasData,
        isTrue,
      );
    });
  });

  group('with no limited ids, stats are what they were', () {
    test('the golden FD scenario is unchanged', () {
      final fd = testInvestment('a', type: InvestmentType.fixedDeposit, rate: 7)
          .copyWith(
            compoundingFrequency: CompoundingFrequency.quarterly,
            interestPayoutMode: InterestPayoutMode.cumulative,
          );
      final flows = [
        testFlow('a', CashFlowType.invest, 100000, DateTime(2025, 10, 2)),
      ];
      final terminal = CurrentValueCalculator.terminalValues(
        investments: [fd],
        cashFlows: flows,
        asOf: DateTime(2026, 10, 2),
      );
      final stats = module.calculateStats(flows, terminalValues: terminal);
      expect(stats.xirr, closeTo(0.071859031, 1e-6));
      expect(stats.moic, closeTo(1.071859031, 1e-6));
      expect(stats.returnsKnown, isTrue);
      expect(stats.limitedHistoryCount, 0);
    });
  });
}

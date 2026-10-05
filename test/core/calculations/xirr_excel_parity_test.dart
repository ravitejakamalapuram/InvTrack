// Excel-parity golden suite for XIRR.
//
// Every expected value below was computed independently of the app, with a
// Python bisection solver (400 halvings) on the NPV equation
//   Σ CFᵢ / (1 + r)^(daysᵢ / 365) = 0
// where daysᵢ is the number of calendar days from the earliest flow (the
// actual/365 convention Excel's XIRR uses). The `excel_doc_example` case is
// the example from Microsoft's XIRR documentation, whose published result is
// 0.373362535.
//
// Dates are date-only UTC values so the suite does not depend on the time
// zone of the machine that runs it.
//
// Tolerance is 1e-6 on the annual rate (0.0001 percentage points). Do not
// loosen it: a looser tolerance is how day-count and solver regressions slip
// through.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

const double _rateTolerance = 1e-6;

DateTime _d(int y, int m, int day) => DateTime.utc(y, m, day);

class _Flow {
  const _Flow(this.date, this.amount);
  final DateTime date;
  final double amount;
}

class _GoldenCase {
  const _GoldenCase(this.name, this.flows, this.expected);
  final String name;
  final List<_Flow> flows;
  final double expected;
}

List<_Flow> _monthly(int year, int month, int count, double amount) => [
  for (var k = 0; k < count; k++)
    _Flow(
      _d(year + (month - 1 + k) ~/ 12, (month - 1 + k) % 12 + 1, 1),
      amount,
    ),
];

final List<_GoldenCase> _cases = [
  // -1,000 then +1,100 exactly 365 days later.
  _GoldenCase('one year, 10% gain', [
    _Flow(_d(2023, 1, 1), -1000),
    _Flow(_d(2024, 1, 1), 1100),
  ], 0.1000000000),
  // Same flows over 366 days (spans 29 Feb 2024): 1.1^(365/366) - 1.
  _GoldenCase('leap year, 366 days', [
    _Flow(_d(2024, 1, 1), -1000),
    _Flow(_d(2025, 1, 1), 1100),
  ], 0.0997135859),
  _GoldenCase('two investments, one return', [
    _Flow(_d(2023, 1, 1), -1000),
    _Flow(_d(2023, 7, 1), -1000),
    _Flow(_d(2024, 1, 1), 2200),
  ], 0.1343767484),
  // Recurring deposit: 12 x -10,000 on the 1st of each month of 2023,
  // +124,200 on 1 Jan 2024.
  _GoldenCase('recurring deposit, 12 monthly instalments', [
    ..._monthly(2023, 1, 12, -10000),
    _Flow(_d(2024, 1, 1), 124200),
  ], 0.0649793821),
  // Monthly SIP: 12 x -10,000, valued at +130,000 on 1 Jan 2024.
  _GoldenCase('monthly SIP', [
    ..._monthly(2023, 1, 12, -10000),
    _Flow(_d(2024, 1, 1), 130000),
  ], 0.1566983509),
  // Microsoft's XIRR documentation example (Excel returns 0.373362535).
  _GoldenCase('Excel documentation example', [
    _Flow(_d(2008, 1, 1), -10000),
    _Flow(_d(2008, 3, 1), 2750),
    _Flow(_d(2008, 10, 30), 4250),
    _Flow(_d(2009, 2, 15), 3250),
    _Flow(_d(2009, 4, 1), 2750),
  ], 0.3733625335),
  // Open FD: 1,00,000 at 7.5% paid out quarterly (1,875 per quarter) for two
  // years, with the current value of 1,00,000 as the terminal inflow.
  _GoldenCase('open FD with quarterly payouts and current value', [
    _Flow(_d(2023, 1, 1), -100000),
    _Flow(_d(2023, 4, 1), 1875),
    _Flow(_d(2023, 7, 1), 1875),
    _Flow(_d(2023, 10, 1), 1875),
    _Flow(_d(2024, 1, 1), 1875),
    _Flow(_d(2024, 4, 1), 1875),
    _Flow(_d(2024, 7, 1), 1875),
    _Flow(_d(2024, 10, 1), 1875),
    _Flow(_d(2025, 1, 1), 1875),
    _Flow(_d(2025, 1, 1), 100000),
  ], 0.0770417481),
  // FD rolled over once: maturity and reinvestment on the same day.
  // The second year spans 29 Feb 2024 (366 days).
  _GoldenCase('FD rollover with same-day maturity and reinvestment', [
    _Flow(_d(2022, 4, 1), -1000000),
    _Flow(_d(2023, 4, 1), 1075000),
    _Flow(_d(2023, 4, 1), -1000000),
    _Flow(_d(2024, 4, 1), 1075000),
  ], 0.0748974902),
  // Investment and partial return on the same day net to -8,000.
  _GoldenCase('same-day investment and partial return', [
    _Flow(_d(2023, 1, 1), -10000),
    _Flow(_d(2023, 1, 1), 2000),
    _Flow(_d(2024, 1, 1), 8800),
  ], 0.1000000000),
  // 1% over 30 days: 1.01^(365/30) - 1.
  _GoldenCase('short holding, 30 days', [
    _Flow(_d(2023, 3, 1), -100000),
    _Flow(_d(2023, 3, 31), 101000),
  ], 0.1286952942),
  // 1% over 3 days: 1.01^(365/3) - 1.
  _GoldenCase('short holding, 3 days', [
    _Flow(_d(2023, 3, 1), -100000),
    _Flow(_d(2023, 3, 4), 101000),
  ], 2.3555764946),
  _GoldenCase('10% loss over one year', [
    _Flow(_d(2023, 1, 1), -10000),
    _Flow(_d(2024, 1, 1), 9000),
  ], -0.1000000000),
  _GoldenCase('deep loss over four years', [
    _Flow(_d(2019, 6, 15), -50000),
    _Flow(_d(2020, 6, 15), 2000),
    _Flow(_d(2023, 6, 15), 5000),
  ], -0.4271548572),
  // Same flows as 'two investments, one return', given out of date order.
  _GoldenCase('input not sorted by date', [
    _Flow(_d(2024, 1, 1), 2200),
    _Flow(_d(2023, 7, 1), -1000),
    _Flow(_d(2023, 1, 1), -1000),
  ], 0.1343767484),
  // Crore-scale amounts with a mid-life top-up.
  _GoldenCase('crore-scale amounts with a top-up', [
    _Flow(_d(2020, 4, 1), -50000000),
    _Flow(_d(2021, 9, 15), 3000000),
    _Flow(_d(2022, 12, 31), -10000000),
    _Flow(_d(2025, 3, 31), 75000000),
  ], 0.0611460336),
  // P2P loan with a same-day platform fee, four interest payments and a
  // partial recovery after a default.
  _GoldenCase('P2P loan with fee and partial default', [
    _Flow(_d(2023, 1, 10), -100000),
    _Flow(_d(2023, 1, 10), -1000),
    _Flow(_d(2023, 4, 10), 3000),
    _Flow(_d(2023, 7, 10), 3000),
    _Flow(_d(2023, 10, 10), 3000),
    _Flow(_d(2024, 1, 10), 3000),
    _Flow(_d(2024, 6, 30), 70000),
  ], -0.1426020018),
  _GoldenCase('300% return in one year', [
    _Flow(_d(2022, 1, 1), -1000),
    _Flow(_d(2023, 1, 1), 4000),
  ], 3.0000000000),
];

/// NPV at [rate] using whole calendar days / 365, independent of the solver.
double _npv(double rate, List<_Flow> flows) {
  final first = flows
      .map((f) => f.date)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  var sum = 0.0;
  for (final f in flows) {
    final days = f.date.difference(first).inDays;
    sum += f.amount / pow(1 + rate, days / 365);
  }
  return sum;
}

void main() {
  group('XirrSolver Excel parity (actual/365, tolerance 1e-6)', () {
    for (final c in _cases) {
      test(c.name, () {
        final xirr = XirrSolver.calculateXirr(
          c.flows.map((f) => f.date).toList(),
          c.flows.map((f) => f.amount).toList(),
        );
        expect(xirr, isNotNull);
        expect(xirr, closeTo(c.expected, _rateTolerance));
      });
    }
  });

  group('XirrSolver returns a true root (NPV residual)', () {
    for (final c in _cases) {
      test(c.name, () {
        final xirr = XirrSolver.calculateXirr(
          c.flows.map((f) => f.date).toList(),
          c.flows.map((f) => f.amount).toList(),
        )!;
        final gross = c.flows.fold<double>(0, (s, f) => s + f.amount.abs());
        // A real root leaves an NPV that is a rounding error relative to the
        // money involved. A fallback approximation leaves a large residual.
        expect(_npv(xirr, c.flows).abs() / gross, lessThan(1e-6));
      });
    }
  });

  // A15 (#760, CALC-11): Excel's XIRR counts whole calendar days and ignores
  // the time of day, so these cases use local DateTime values on purpose,
  // unlike the date-only UTC cases above.
  group('XirrSolver Excel parity with local dates (CALC-11)', () {
    test('an investment made at 21:30 and +8% on the same date a year later '
        'gives 8.0000%', () {
      // Flooring the milliseconds counts 364 days and gives 0.0802283701.
      final xirr = XirrSolver.calculateXirr(
        [DateTime(2025, 4, 1, 21, 30), DateTime(2026, 4, 1)],
        [-100000.0, 108000.0],
      );
      expect(xirr, closeTo(0.08, _rateTolerance));
    });

    test('1 Mar to 31 Mar 2023 is 30 days across a DST change', () {
      // Only guards the DST case on a machine whose zone changes clocks
      // between the two dates, for example TZ=Europe/London (26 Mar 2023),
      // where flooring the milliseconds counts 29 days and gives
      // 0.1334169536.
      final xirr = XirrSolver.calculateXirr(
        [DateTime(2023, 3, 1), DateTime(2023, 3, 31)],
        [-100.0, 101.0],
      );
      // 1.01^(365/30) - 1
      expect(xirr, closeTo(0.1286952941593904, _rateTolerance));
    });
  });

  group('FinancialCalculator.calculateXirrFromCashFlows parity', () {
    CashFlowEntity cf(
      String id,
      DateTime date,
      CashFlowType type,
      double amt,
    ) => CashFlowEntity(
      id: id,
      investmentId: 'p2p',
      date: date,
      type: type,
      amount: amt,
      createdAt: _d(2023, 1, 10),
    );

    test('P2P loan: invest, fee, income and return types map to signs', () {
      // Same flows as the 'P2P loan with fee and partial default' case.
      final flows = [
        cf('1', _d(2023, 1, 10), CashFlowType.invest, 100000),
        cf('2', _d(2023, 1, 10), CashFlowType.fee, 1000),
        cf('3', _d(2023, 4, 10), CashFlowType.income, 3000),
        cf('4', _d(2023, 7, 10), CashFlowType.income, 3000),
        cf('5', _d(2023, 10, 10), CashFlowType.income, 3000),
        cf('6', _d(2024, 1, 10), CashFlowType.income, 3000),
        cf('7', _d(2024, 6, 30), CashFlowType.returnFlow, 70000),
      ];
      expect(
        FinancialCalculator.calculateXirrFromCashFlows(flows),
        closeTo(-0.1426020018, _rateTolerance),
      );
    });

    test('recurring deposit through cash-flow entities', () {
      final flows = [
        for (var m = 1; m <= 12; m++)
          cf('$m', _d(2023, m, 1), CashFlowType.invest, 10000),
        cf('13', _d(2024, 1, 1), CashFlowType.returnFlow, 124200),
      ];
      expect(
        FinancialCalculator.calculateXirrFromCashFlows(flows),
        closeTo(0.0649793821, _rateTolerance),
      );
    });
  });
}

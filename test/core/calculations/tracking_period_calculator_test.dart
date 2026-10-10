// #941: tracking-period performance runs from a dated opening baseline to the
// ending value. It reuses FinancialCalculatorModule.calculateStats (money
// rule 3) with a start flow that exists only in memory.
//
// Expected values, worked out independently in Python (actual/365):
//   5,00,000 on 2026-01-01 -> 5,30,000 on 2026-07-01 (181 days):
//   absolute return 6.00%, XIRR (1.06)^(365/181) - 1 = 0.12468568
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/tracking_period_calculator.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

import '../../features/investment/valuation/valuation_fixtures.dart';

final _today = DateTime(2026, 10, 2);

InvestmentValuationSnapshot _baseline(
  double amount,
  DateTime date, {
  ValuationKind kind = ValuationKind.carryingValue,
}) => testSnapshot(
  'base',
  amount: amount,
  date: date,
  kind: kind,
  provenance: ValuationProvenance.openingBaseline,
);

TrackingPeriod _build(
  List<InvestmentValuationSnapshot> snapshots, {
  List<CashFlowEntity> flows = const [],
  DateTime? asOf,
}) => TrackingPeriodCalculator.build(
  investment: testInvestment('i1'),
  cashFlows: flows,
  snapshots: snapshots,
  asOf: asOf ?? _today,
);

void main() {
  group('baseline to a newer value (plan test 10)', () {
    final baseline = _baseline(500000, DateTime(2026, 1, 1));
    final newer = testSnapshot(
      'jul',
      amount: 530000,
      date: DateTime(2026, 7, 1),
    );

    test('absolute return 6.00% and annualised 0.124686 over 181 days', () {
      final period = _build([baseline, newer]);
      expect(period.state, TrackingPeriodState.ready);
      expect(period.start, DateTime(2026, 1, 1));
      expect(period.end, DateTime(2026, 7, 1));
      expect(period.days, 181);
      expect(period.showsAnnualised, isTrue);

      final stats = TrackingPeriodCalculator.stats(period)!;
      expect(stats.absoluteReturn, closeTo(6.00, 1e-9));
      expect(stats.xirr, closeTo(0.124686, 1e-6));
      expect(stats.moic, closeTo(1.06, 1e-12));
    });

    test('the start is an in-memory flow that is never an actual one', () {
      final period = _build([baseline, newer]);
      final start = period.flows.single;
      expect(start.id, startsWith(TrackingPeriodCalculator.startIdPrefix));
      expect(start.type, CashFlowType.invest);
      expect(start.amount, 500000);
      expect(start.date, DateTime(2026, 1, 1));
      expect(start.currency, 'INR');
      expect(period.terminal!.date, DateTime(2026, 7, 1));
      expect(period.terminal!.amount, 530000);
    });

    test('flows on or before the baseline day are left out, later ones in', () {
      final flows = [
        testFlow('i1', CashFlowType.invest, 400000, DateTime(2023, 5, 1)),
        testFlow('i1', CashFlowType.income, 7, DateTime(2026, 1, 1)),
        testFlow('i1', CashFlowType.income, 5000, DateTime(2026, 4, 1)),
      ];
      final period = _build([baseline, newer], flows: flows);
      expect(period.flows, hasLength(2));
      expect(period.flows.last.amount, 5000);
      // The income received in the period is part of its return.
      final stats = TrackingPeriodCalculator.stats(period)!;
      expect(stats.absoluteReturn, closeTo(7.00, 1e-9));
    });
  });

  group('under 90 days', () {
    test('only the absolute return is annualised away', () {
      final baseline = _baseline(500000, DateTime(2026, 8, 1));
      final newer = testSnapshot(
        'n',
        amount: 510000,
        date: DateTime(2026, 9, 1),
      );
      final period = _build([baseline, newer]);
      expect(period.days, 31);
      expect(period.days! < InvestmentStats.shortHoldingDays, isTrue);
      expect(period.showsAnnualised, isFalse);
      expect(
        TrackingPeriodCalculator.stats(period)!.absoluteReturn,
        closeTo(2.00, 1e-9),
      );
    });
  });

  group('a baseline with no newer value', () {
    test('a market value needs a newer value, and shows no figure', () {
      final period = _build([
        _baseline(
          500000,
          DateTime(2026, 1, 1),
          kind: ValuationKind.marketValue,
        ),
      ]);
      expect(period.state, TrackingPeriodState.needsNewerValue);
      expect(TrackingPeriodCalculator.stats(period), isNull);
    });

    test('a market value is ready once a newer snapshot exists', () {
      final period = _build([
        _baseline(
          500000,
          DateTime(2026, 1, 1),
          kind: ValuationKind.marketValue,
        ),
        testSnapshot(
          'n',
          amount: 520000,
          date: DateTime(2026, 6, 1),
          kind: ValuationKind.marketValue,
        ),
      ]);
      expect(period.state, TrackingPeriodState.ready);
      expect(
        TrackingPeriodCalculator.stats(period)!.absoluteReturn,
        closeTo(4.00, 1e-9),
      );
    });

    test('a carrying value is rolled forward by principal after the start', () {
      final flows = [
        testFlow('i1', CashFlowType.returnFlow, 20000, DateTime(2026, 3, 1)),
      ];
      final period = _build([
        _baseline(500000, DateTime(2026, 1, 1)),
      ], flows: flows);
      expect(period.state, TrackingPeriodState.ready);
      expect(period.end, DateTime(2026, 3, 1));
      expect(period.terminal!.amount, 480000);
      final stats = TrackingPeriodCalculator.stats(period)!;
      // 20,000 came back and 4,80,000 is left of 5,00,000: no gain, no loss.
      expect(stats.absoluteReturn, closeTo(0.0, 1e-9));
    });

    test('a carrying value with nothing since has no elapsed time', () {
      final period = _build([_baseline(500000, DateTime(2026, 1, 1))]);
      expect(period.state, TrackingPeriodState.noElapsedTime);
      expect(TrackingPeriodCalculator.stats(period), isNull);
    });
  });

  group('no tracking period', () {
    test('without a live baseline there is none', () {
      final period = _build([
        testSnapshot('m', amount: 1, date: DateTime(2026, 1, 1)),
      ]);
      expect(period.state, TrackingPeriodState.notStarted);
      expect(period.start, isNull);
      expect(TrackingPeriodCalculator.stats(period), isNull);
    });

    test('a cleared baseline is no baseline', () {
      final cleared = _baseline(
        500000,
        DateTime(2026, 1, 1),
      ).copyWith(deletedAt: DateTime.utc(2026, 2, 1));
      expect(_build([cleared]).state, TrackingPeriodState.notStarted);
    });

    test('principal in another currency leaves the end value unavailable', () {
      final flows = [
        testFlow(
          'i1',
          CashFlowType.invest,
          10,
          DateTime(2026, 3, 1),
          currency: 'USD',
        ),
      ];
      final period = _build([
        _baseline(500000, DateTime(2026, 1, 1)),
      ], flows: flows);
      expect(period.state, TrackingPeriodState.valueUnavailable);
      expect(TrackingPeriodCalculator.stats(period), isNull);
    });

    test('a first flow after a newer snapshot still has an end value', () {
      final flows = [
        testFlow('i1', CashFlowType.invest, 50000, DateTime(2026, 8, 1)),
      ];
      final period = _build([
        _baseline(500000, DateTime(2026, 1, 1)),
        testSnapshot('jul', amount: 530000, date: DateTime(2026, 7, 1)),
      ], flows: flows);
      expect(period.state, TrackingPeriodState.ready);
      expect(period.start, DateTime(2026, 1, 1));
      expect(period.end, DateTime(2026, 8, 1));
      expect(period.terminal!.amount, 580000.00);
      expect(period.flows.map((f) => f.amount), [500000.00, 50000.00]);
    });
  });

  group('conversion', () {
    test('withConverted replaces the flows and the end value', () {
      final baseline = _baseline(500000, DateTime(2026, 1, 1));
      final newer = testSnapshot(
        'n',
        amount: 530000,
        date: DateTime(2026, 7, 1),
      );
      final period = _build([baseline, newer]);
      final doubled = period.withConverted(
        flows: [for (final f in period.flows) f.copyWith(amount: f.amount * 2)],
        terminal: period.terminal!.copyWith(amount: 1060000),
      );
      expect(doubled.state, TrackingPeriodState.ready);
      expect(
        TrackingPeriodCalculator.stats(doubled)!.absoluteReturn,
        closeTo(6.00, 1e-9),
      );
    });

    test('a value dropped by conversion leaves the period unavailable', () {
      final period = _build([
        _baseline(500000, DateTime(2026, 1, 1)),
        testSnapshot('n', amount: 530000, date: DateTime(2026, 7, 1)),
      ]);
      final dropped = period.withConverted(flows: period.flows, terminal: null);
      expect(dropped.state, TrackingPeriodState.valueUnavailable);
      expect(TrackingPeriodCalculator.stats(dropped), isNull);
    });
  });
}

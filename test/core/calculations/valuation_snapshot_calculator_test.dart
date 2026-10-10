// #941: CurrentValueCalculator with dated valuation snapshots. A snapshot is a
// valuation, not a cash flow: it is carried forward only by known principal
// movements, and only for the kinds that roll forward.
//
// Expected values were worked out by hand and, for the XIRR figures,
// independently in Python (actual/365, as Excel):
//   history imported after a baseline (plan test 9):
//     -4,00,000 on 2023-05-01, +30,000 on 2025-02-01, +5,00,000 on 2026-01-01
//     -> XIRR 0.11340345, MOIC 1.325
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
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

Map<String, List<InvestmentValuationSnapshot>> _by(
  List<InvestmentValuationSnapshot> snapshots,
) => {'i1': snapshots};

InvestmentValuation? _valuation(
  InvestmentEntity investment,
  List<CashFlowEntity> flows,
  List<InvestmentValuationSnapshot> snapshots, {
  DateTime? asOf,
}) => CurrentValueCalculator.valuationOf(
  investment,
  flows,
  asOf: asOf ?? _today,
  snapshots: _by(snapshots),
);

void main() {
  final investment = testInvestment('i1');
  final module = FinancialCalculatorModule();

  group('a baseline with no history (plan test 1)', () {
    final baseline = _baseline(500000, _today);

    test('is valued on its own date, with lifetime history limited', () {
      final v = _valuation(investment, const [], [baseline]);
      expect(v?.amount, 500000.00);
      expect(v!.currency, 'INR');
      expect(v.date, _today);
      expect(v.source, ValuationSource.manual);
      expect(v.kind, ValuationKind.carryingValue);
      expect(v.provenance, ValuationProvenance.openingBaseline);
      expect(v.historyLimited, isTrue);
      expect(v.trackingStart, _today);
      expect(v.isEstimate, isFalse);
    });

    test('terminalValues values an investment that has no cash flows', () {
      final t = CurrentValueCalculator.terminalValues(
        investments: [investment],
        cashFlows: const [],
        asOf: _today,
        snapshots: _by([baseline]),
      );
      expect(t.flows, hasLength(1));
      expect(t.flows.single.amount, 500000.00);
      expect(t.flows.single.id, 'current-value:i1');
      expect(t.flows.single.date, _today);
      expect(t.flows.single.type, CashFlowType.returnFlow);
      expect(t.limitedHistoryIds, {'i1'});
      expect(t.missingValueCount, 0);
    });

    test('lifetime XIRR, MOIC and return are unknown, the value is not', () {
      final t = CurrentValueCalculator.terminalValues(
        investments: [investment],
        cashFlows: const [],
        asOf: _today,
        snapshots: _by([baseline]),
      );
      final stats = module.calculateStats(const [], terminalValues: t);
      expect(stats.currentValue, 500000.00);
      expect(stats.cashFlowCount, 0);
      expect(stats.hasData, isTrue);
      expect(stats.xirr, isNull);
      expect(stats.returnsKnown, isFalse);
      expect(stats.limitedHistoryCount, 1);
      // Cash-only figures stay cash-only: the value is not money received.
      expect(stats.totalInvested, 0);
      expect(stats.totalReturned, 0);
      expect(stats.netCashFlow, 0);
    });

    test('a closed investment has no value, its snapshot is kept', () {
      final closed = testInvestment('i1', status: InvestmentStatus.closed);
      expect(_valuation(closed, const [], [baseline]), isNull);
    });
  });

  group('principal repayment is applied once (plan test 2)', () {
    final baseline = _baseline(500000, DateTime(2026, 1, 1));

    test('a RETURN after the baseline lowers the carried value', () {
      final flows = [
        testFlow('i1', CashFlowType.returnFlow, 20000, DateTime(2026, 3, 1)),
      ];
      final v = _valuation(investment, flows, [baseline]);
      expect(v?.amount, 480000.00);
      expect(v!.date, DateTime(2026, 3, 1));
    });

    test('evaluating twice gives the same value and mutates nothing', () {
      final flows = List<CashFlowEntity>.unmodifiable([
        testFlow('i1', CashFlowType.returnFlow, 20000, DateTime(2026, 3, 1)),
      ]);
      final snapshots = List<InvestmentValuationSnapshot>.unmodifiable([
        baseline,
      ]);
      final first = _valuation(investment, flows, snapshots)!;
      final second = _valuation(investment, flows, snapshots)!;
      expect(first.amount, 480000.00);
      expect(second.amount, 480000.00);
      expect(flows, hasLength(1));
      expect(snapshots, hasLength(1));
    });

    test('a RETURN on the baseline day is history already in the value', () {
      final flows = [
        testFlow('i1', CashFlowType.returnFlow, 20000, DateTime(2026, 1, 1)),
      ];
      final v = _valuation(investment, flows, [baseline])!;
      expect(v.amount, 500000.00);
      expect(v.date, DateTime(2026, 1, 1));
    });

    test('a RETURN before the baseline changes nothing', () {
      final flows = [
        testFlow('i1', CashFlowType.returnFlow, 20000, DateTime(2025, 12, 1)),
      ];
      expect(_valuation(investment, flows, [baseline])!.amount, 500000.00);
    });

    test('an INVEST after the baseline raises it', () {
      final flows = [
        testFlow('i1', CashFlowType.invest, 10000, DateTime(2026, 2, 1)),
      ];
      expect(_valuation(investment, flows, [baseline])!.amount, 510000.00);
    });

    test('principal moved in another currency makes the value unavailable', () {
      final flows = [
        testFlow(
          'i1',
          CashFlowType.invest,
          100,
          DateTime(2026, 2, 1),
          currency: 'USD',
        ),
      ];
      expect(_valuation(investment, flows, [baseline]), isNull);
      final t = CurrentValueCalculator.terminalValues(
        investments: [investment],
        cashFlows: flows,
        asOf: _today,
        snapshots: _by([baseline]),
      );
      expect(t.flows, isEmpty);
      expect(t.missingValueCount, 1);
    });
  });

  group('income is not principal (plan test 3)', () {
    test('an INCOME receipt leaves the carried value alone', () {
      final flows = [
        testFlow('i1', CashFlowType.income, 5000, DateTime(2026, 3, 1)),
        testFlow('i1', CashFlowType.fee, 100, DateTime(2026, 3, 2)),
      ];
      final v = _valuation(investment, flows, [
        _baseline(500000, DateTime(2026, 1, 1)),
      ])!;
      expect(v.amount, 500000.00);
    });
  });

  group('kind matrix (plan tests 4 and 11)', () {
    final flows = [
      testFlow('i1', CashFlowType.invest, 10000, DateTime(2026, 2, 1)),
      testFlow('i1', CashFlowType.returnFlow, 20000, DateTime(2026, 3, 1)),
      testFlow('i1', CashFlowType.income, 5000, DateTime(2026, 4, 1)),
    ];
    final date = DateTime(2026, 1, 1);

    test('a carrying value rolls forward by INVEST and RETURN', () {
      final v = _valuation(investment, flows, [
        _baseline(500000, date, kind: ValuationKind.carryingValue),
      ])!;
      expect(v.amount, 490000.00);
      expect(v.staleFlowCount, 0);
    });

    test('principal outstanding rolls forward like a carrying value', () {
      final v = _valuation(investment, flows, [
        _baseline(500000, date, kind: ValuationKind.principalOutstanding),
      ])!;
      expect(v.amount, 490000.00);
    });

    test('a market value is not moved by cash flows and says it may be '
        'out of date', () {
      final v = _valuation(investment, flows, [
        _baseline(500000, date, kind: ValuationKind.marketValue),
      ])!;
      expect(v.amount, 500000.00);
      expect(v.kind, ValuationKind.marketValue);
      // INVEST and RETURN happened after it; INCOME is not counted.
      expect(v.staleFlowCount, 2);
    });

    test('gold: later INVEST and INCOME do not invent a price', () {
      final gold = testInvestment('i1', type: InvestmentType.gold);
      final v = _valuation(
        gold,
        [
          testFlow('i1', CashFlowType.invest, 10000, DateTime(2026, 3, 1)),
          testFlow('i1', CashFlowType.income, 500, DateTime(2026, 4, 1)),
        ],
        [_baseline(500000, date, kind: ValuationKind.marketValue)],
      )!;
      expect(v.amount, 500000.00);
      expect(v.staleFlowCount, 1);
    });

    test('a market value in INR is unmoved by a USD flow', () {
      final v = _valuation(
        investment,
        [
          testFlow(
            'i1',
            CashFlowType.invest,
            100,
            DateTime(2026, 3, 1),
            currency: 'USD',
          ),
        ],
        [_baseline(500000, date, kind: ValuationKind.marketValue)],
      )!;
      expect(v.amount, 500000.00);
    });
  });

  group('snapshots and the first cash flow', () {
    final flows = [
      testFlow('i1', CashFlowType.invest, 100000, DateTime(2026, 2, 1)),
    ];

    test('a manual snapshot dated before every cash flow stays missing', () {
      final manual = testSnapshot(
        'm',
        amount: 90000,
        date: DateTime(2026, 1, 1),
      );
      expect(_valuation(investment, flows, [manual]), isNull);
    });

    test('an opening baseline may precede the first cash flow', () {
      final v = _valuation(investment, flows, [
        _baseline(500000, DateTime(2026, 1, 1)),
      ])!;
      expect(v.amount, 600000.00);
    });

    test('a snapshot dated on or after a flow is carried from its date', () {
      final manual = testSnapshot(
        'm',
        amount: 90000,
        date: DateTime(2026, 3, 1),
      );
      final v = _valuation(investment, flows, [manual])!;
      expect(v.amount, 90000);
      expect(v.date, DateTime(2026, 3, 1));
      expect(v.historyLimited, isFalse);
    });
  });

  group('the latest applicable snapshot is used (plan test 5)', () {
    final jan = testSnapshot('a', amount: 400000, date: DateTime(2026, 1, 1));
    final jun = testSnapshot('b', amount: 450000, date: DateTime(2026, 6, 1));

    test('by the as-of day, never summed', () {
      expect(
        _valuation(investment, const [], [
          jan,
          jun,
        ], asOf: DateTime(2025, 12, 31)),
        isNull,
      );
      expect(
        _valuation(investment, const [], [
          jan,
          jun,
        ], asOf: DateTime(2026, 3, 1))!.amount,
        400000.00,
      );
      expect(
        _valuation(investment, const [], [
          jan,
          jun,
        ], asOf: DateTime(2026, 12, 1))!.amount,
        450000.00,
      );
    });

    test('a baseline stays limited when a newer manual snapshot wins', () {
      final base = _baseline(400000, DateTime(2026, 1, 1));
      final v = _valuation(investment, const [], [base, jun])!;
      expect(v.amount, 450000.00);
      expect(v.provenance, ValuationProvenance.manual);
      expect(v.historyLimited, isTrue);
      expect(v.trackingStart, DateTime(2026, 1, 1));
    });
  });

  group(
    'no snapshots: today\'s behaviour, unchanged (plan tests 8 and 19)',
    () {
      final fd =
          testInvestment(
            'i1',
            type: InvestmentType.fixedDeposit,
            rate: 7,
          ).copyWith(
            compoundingFrequency: CompoundingFrequency.quarterly,
            interestPayoutMode: InterestPayoutMode.cumulative,
          );
      final fdFlows = [
        testFlow('i1', CashFlowType.invest, 100000, DateTime(2025, 10, 2)),
      ];

      test(
        'an empty snapshot map gives exactly the legacy terminal values',
        () {
          final legacy = CurrentValueCalculator.terminalValues(
            investments: [fd],
            cashFlows: fdFlows,
            asOf: _today,
          );
          final withEmpty = CurrentValueCalculator.terminalValues(
            investments: [fd],
            cashFlows: fdFlows,
            asOf: _today,
            snapshots: const {},
          );
          expect(withEmpty.flows.single.amount, legacy.flows.single.amount);
          expect(withEmpty.flows.single.date, legacy.flows.single.date);
          expect(withEmpty.isEstimate, legacy.isEstimate);
          expect(withEmpty.rate, legacy.rate);
          expect(withEmpty.missingValueCount, legacy.missingValueCount);
          expect(withEmpty.limitedHistoryIds, isEmpty);
        },
      );

      test('a legacy manual value with no snapshot reads as before', () {
        final legacy = testInvestment(
          'i1',
          compatValue: 125000.55,
          compatDate: DateTime(2026, 10, 1),
        );
        final flows = [
          testFlow('i1', CashFlowType.invest, 100000, DateTime(2025, 10, 1)),
        ];
        final a = CurrentValueCalculator.valuationOf(
          legacy,
          flows,
          asOf: _today,
        )!;
        final b = _valuation(legacy, flows, const [])!;
        expect(b.amount, a.amount);
        expect(b.date, a.date);
        expect(b.source, a.source);
        expect(b.kind, ValuationKind.carryingValue);
        expect(b.provenance, ValuationProvenance.manual);
        expect(b.historyLimited, isFalse);
      });

      test(
        'a cleared compat after the snapshot falls back to the estimate',
        () {
          // An older app cleared the value after the snapshot was written.
          final cleared = fd.copyWith(updatedAt: DateTime.utc(2026, 9, 1));
          final snapshot = testSnapshot(
            's',
            amount: 90000,
            date: DateTime(2026, 3, 1),
            updatedAt: DateTime.utc(2026, 3, 1),
          );
          final v = _valuation(cleared, fdFlows, [snapshot])!;
          expect(v.source, ValuationSource.accruedInterest);
        },
      );

      test(
        'snapshots of an investment in another currency are history only',
        () {
          final usd = testSnapshot(
            'u',
            amount: 1000,
            date: DateTime(2026, 3, 1),
            currency: 'USD',
          );
          expect(_valuation(investment, const [], [usd]), isNull);
        },
      );
    },
  );

  group('history added after a baseline (plan test 9)', () {
    final baseline = _baseline(500000, DateTime(2026, 1, 1));
    final history = [
      testFlow('i1', CashFlowType.invest, 400000, DateTime(2023, 5, 1)),
      testFlow('i1', CashFlowType.income, 30000, DateTime(2025, 2, 1)),
    ];

    test('nothing changes by itself: the value stays, lifetime stays unknown, '
        'a review is due', () {
      final v = _valuation(investment, history, [baseline])!;
      expect(v.amount, 500000.00);
      expect(v.historyLimited, isTrue);
      expect(v.historyReviewNeeded, isTrue);
      final t = CurrentValueCalculator.terminalValues(
        investments: [investment],
        cashFlows: history,
        asOf: _today,
        snapshots: _by([baseline]),
      );
      final stats = module.calculateStats(history, terminalValues: t);
      expect(stats.xirr, isNull);
      expect(stats.returnsKnown, isFalse);
    });

    test('no review is due while every flow comes after the baseline', () {
      final later = [
        testFlow('i1', CashFlowType.income, 100, DateTime(2026, 2, 1)),
      ];
      expect(
        _valuation(investment, later, [baseline])!.historyReviewNeeded,
        isFalse,
      );
    });

    test('after the baseline is confirmed as a normal snapshot, lifetime '
        'metrics start and the snapshot is kept', () {
      final rebased = baseline.copyWith(provenance: ValuationProvenance.manual);
      final v = _valuation(investment, history, [rebased])!;
      expect(v.historyLimited, isFalse);
      expect(v.amount, 500000.00);
      final t = CurrentValueCalculator.terminalValues(
        investments: [investment],
        cashFlows: history,
        asOf: _today,
        snapshots: _by([rebased]),
      );
      final stats = module.calculateStats(history, terminalValues: t);
      expect(stats.xirr, closeTo(0.113403, 1e-6));
      expect(stats.moic, closeTo(1.325, 1e-9));
      expect(stats.returnsKnown, isTrue);
      expect(stats.limitedHistoryCount, 0);
    });
  });

  group('describeClear (plan test 7)', () {
    final fd = testInvestment(
      'i1',
      type: InvestmentType.fixedDeposit,
      rate: 7,
    ).copyWith(interestPayoutMode: InterestPayoutMode.cumulative);

    ClearValuationImpact impact(
      InvestmentEntity inv,
      List<CashFlowEntity> flows,
      List<InvestmentValuationSnapshot> snapshots,
      String clearing,
    ) => CurrentValueCalculator.describeClear(
      investment: inv,
      cashFlows: flows,
      snapshots: snapshots,
      snapshotId: clearing,
      asOf: _today,
    );

    test(
      'the only snapshot of an investment: lifetime metrics unavailable',
      () {
        final only = testSnapshot('a', amount: 1, date: DateTime(2026, 1, 1));
        final got = impact(investment, const [], [only], 'a');
        expect(got.kind, ClearImpactKind.unavailable);
        expect(got.date, isNull);
      },
    );

    test('an earlier snapshot then applies, and the dialog names its date', () {
      final early = testSnapshot('a', amount: 1, date: DateTime(2026, 1, 1));
      final late = testSnapshot('b', amount: 2, date: DateTime(2026, 5, 1));
      final got = impact(investment, const [], [early, late], 'b');
      expect(got.kind, ClearImpactKind.earlierSnapshot);
      expect(got.date, DateTime(2026, 1, 1));
    });

    test('a fixed deposit falls back to the estimate', () {
      final only = testSnapshot('a', amount: 1, date: DateTime(2026, 1, 1));
      final flows = [
        testFlow('i1', CashFlowType.invest, 100000, DateTime(2025, 10, 2)),
      ];
      final got = impact(fd, flows, [only], 'a');
      expect(got.kind, ClearImpactKind.estimate);
    });

    test('a snapshot already cleared is not counted as remaining', () {
      final early = testSnapshot(
        'a',
        amount: 1,
        date: DateTime(2026, 1, 1),
        deletedAt: DateTime.utc(2026, 2, 1),
      );
      final late = testSnapshot('b', amount: 2, date: DateTime(2026, 5, 1));
      final got = impact(investment, const [], [early, late], 'b');
      expect(got.kind, ClearImpactKind.unavailable);
    });
  });

  group('default kind by investment type', () {
    test('lending types carry, everything else is a market value', () {
      for (final type in CurrentValueCalculator.estimableTypes) {
        expect(
          CurrentValueCalculator.defaultKind(type),
          ValuationKind.carryingValue,
        );
      }
      for (final type in [
        InvestmentType.gold,
        InvestmentType.realEstate,
        InvestmentType.stocks,
        InvestmentType.other,
      ]) {
        expect(
          CurrentValueCalculator.defaultKind(type),
          ValuationKind.marketValue,
        );
      }
    });
  });
}

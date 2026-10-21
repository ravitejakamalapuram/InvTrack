import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/reporting/metric_value.dart';
import 'package:inv_tracker/core/reporting/report_definition.dart';
import 'package:inv_tracker/core/reporting/report_engine.dart';
import 'package:inv_tracker/core/reporting/report_period.dart';
import 'package:inv_tracker/core/reporting/report_result.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

InvestmentEntity inv(
  String id, {
  InvestmentType type = InvestmentType.fixedDeposit,
  bool archived = false,
  String currency = 'INR',
}) => InvestmentEntity(
  id: id,
  name: id,
  type: type,
  status: InvestmentStatus.open,
  createdAt: DateTime(2023, 1, 1),
  updatedAt: DateTime(2023, 1, 1),
  isArchived: archived,
  currency: currency,
);

var _n = 0;
CashFlowEntity cf(
  String investmentId,
  DateTime date,
  CashFlowType type,
  double amount, {
  String currency = 'INR',
}) => CashFlowEntity(
  id: 'cf${_n++}',
  investmentId: investmentId,
  date: date,
  type: type,
  amount: amount,
  createdAt: date,
  currency: currency,
);

/// INR is the base. USD converts at 80; any other currency has no rate.
Future<List<CashFlowEntity>> fakeToBase(
  List<CashFlowEntity> flows,
  String base,
) async => [
  for (final f in flows)
    if (f.currency == base)
      f
    else if (f.currency == 'USD')
      f.copyWith(amount: f.amount * 80, currency: base),
];

const all = ReportDefinition(
  id: 't',
  metrics: [
    ReportMetric.invested,
    ReportMetric.returned,
    ReportMetric.income,
    ReportMetric.fees,
    ReportMetric.netCashFlow,
  ],
);

void main() {
  final engine = ReportEngine(
    toBase: fakeToBase,
    now: () => DateTime(2024, 5, 20),
  );
  final march = ReportPeriod.month(2024, 3);

  ReportInputs inputs(
    List<CashFlowEntity> flows, {
    List<InvestmentEntity>? investments,
    double? opening,
    double? closing,
  }) => ReportInputs(
    investments: investments ?? [inv('a'), inv('b')],
    cashFlows: flows,
    baseCurrency: 'INR',
    openingValue: opening,
    closingValue: closing,
  );

  double v(ReportResult r, ReportMetric m) => r.totals[m]!.valueOrNull!;

  test(
    'totals use half-open window and split invest/fee/return/income',
    () async {
      final r = await engine.run(
        all,
        march,
        inputs([
          cf('a', DateTime(2024, 3, 1), CashFlowType.invest, 1000.10),
          cf('a', DateTime(2024, 3, 31, 22), CashFlowType.income, 50.05),
          cf('b', DateTime(2024, 3, 15), CashFlowType.returnFlow, 200),
          cf('b', DateTime(2024, 3, 15), CashFlowType.fee, 10),
          cf('a', DateTime(2024, 4, 1), CashFlowType.invest, 9999), // outside
          cf('a', DateTime(2024, 2, 29), CashFlowType.invest, 9999), // outside
        ]),
      );
      expect(v(r, ReportMetric.invested), closeTo(1000.10, 1e-9));
      expect(v(r, ReportMetric.fees), 10);
      expect(v(r, ReportMetric.returned), 200);
      expect(v(r, ReportMetric.income), closeTo(50.05, 1e-9));
      expect(v(r, ReportMetric.netCashFlow), closeTo(-760.05, 1e-9));
      expect(r.notes, isEmpty);
    },
  );

  test(
    'foreign flows are converted; a flow with no rate is left out and noted',
    () async {
      final r = await engine.run(
        all,
        march,
        inputs([
          cf(
            'a',
            DateTime(2024, 3, 2),
            CashFlowType.invest,
            100,
            currency: 'USD',
          ),
          cf(
            'a',
            DateTime(2024, 3, 3),
            CashFlowType.invest,
            500,
            currency: 'EUR',
          ),
          cf('a', DateTime(2024, 3, 4), CashFlowType.invest, 7),
        ]),
      );
      expect(v(r, ReportMetric.invested), 8007);
      expect(r.notes, [const ReportNote(ReportNoteKind.excludedFlows, 1)]);
    },
  );

  test('archived investments are excluded and noted', () async {
    final r = await engine.run(
      all,
      march,
      inputs(
        [
          cf('a', DateTime(2024, 3, 2), CashFlowType.invest, 100),
          cf('z', DateTime(2024, 3, 2), CashFlowType.invest, 900),
        ],
        investments: [inv('a'), inv('z', archived: true)],
      ),
    );
    expect(v(r, ReportMetric.invested), 100);
    expect(r.notes, [const ReportNote(ReportNoteKind.archivedExcluded, 1)]);
  });

  test('empty period gives known zeros for flows', () async {
    final r = await engine.run(all, march, inputs([]));
    expect(r.totals[ReportMetric.invested], const Known(0));
    expect(r.totals[ReportMetric.netCashFlow], const Known(0));
  });

  group('valuation metrics', () {
    const def = ReportDefinition(
      id: 'v',
      metrics: [
        ReportMetric.periodXirr,
        ReportMetric.portfolioValueStart,
        ReportMetric.portfolioValueEnd,
      ],
    );
    final fy = ReportPeriod.fy(2023);

    test('unknown, not zero, when values are missing', () async {
      final r = await engine.run(
        def,
        fy,
        inputs([cf('a', DateTime(2023, 6, 1), CashFlowType.invest, 1000)]),
      );
      expect(
        r.totals[ReportMetric.periodXirr],
        const Unknown(UnknownReason.awaitingValue),
      );
      expect(
        r.totals[ReportMetric.portfolioValueStart],
        const Unknown(UnknownReason.awaitingValue),
      );
      expect(
        r.totals[ReportMetric.portfolioValueEnd],
        const Unknown(UnknownReason.awaitingValue),
      );
    });

    test('xirr from opening, flows and closing, 1e-6', () async {
      // -1000 at 1 Apr 2023, +1100 at 1 Apr 2024 (366 days, actual/365).
      final r = await engine.run(
        def,
        fy,
        inputs([], opening: 1000, closing: 1100),
      );
      final x = r.totals[ReportMetric.periodXirr]!.valueOrNull!;
      expect(x, closeTo(_expectedXirr(), 1e-6));
      expect(r.totals[ReportMetric.portfolioValueStart], const Known(1000));
      expect(r.totals[ReportMetric.portfolioValueEnd], const Known(1100));
    });

    test('nothing to solve is unknown', () async {
      final r = await engine.run(def, fy, inputs([], opening: 0, closing: 0));
      expect(
        r.totals[ReportMetric.periodXirr],
        const Unknown(UnknownReason.notApplicable),
      );
    });
  });

  group('comparison', () {
    const def = ReportDefinition(
      id: 'c',
      metrics: [ReportMetric.invested, ReportMetric.periodXirr],
      comparePrevious: true,
    );
    final flows = [
      cf('a', DateTime(2024, 3, 5), CashFlowType.invest, 150),
      cf('a', DateTime(2024, 2, 5), CashFlowType.invest, 100),
    ];

    test('change and percent against the previous period', () async {
      final r = await engine.run(def, march, inputs(flows));
      expect(r.previous![ReportMetric.invested], const Known(100));
      expect(r.change(ReportMetric.invested), const Known(50));
      expect(r.changePercent(ReportMetric.invested), const Known(50));
    });

    test('previous of zero gives no percent, not infinity', () async {
      final r = await engine.run(
        def,
        ReportPeriod.month(2024, 4),
        inputs([cf('a', DateTime(2024, 4, 5), CashFlowType.invest, 5)]),
      );
      expect(r.previous![ReportMetric.invested], const Known(0));
      expect(
        r.changePercent(ReportMetric.invested),
        const Unknown(UnknownReason.notApplicable),
      );
    });

    test('valuation metrics are unknown in the previous period', () async {
      final r = await engine.run(def, march, inputs(flows));
      expect(
        r.previous![ReportMetric.periodXirr],
        const Unknown(UnknownReason.notApplicable),
      );
      expect(
        r.change(ReportMetric.periodXirr),
        const Unknown(UnknownReason.notApplicable),
      );
    });
  });

  group('breakdowns', () {
    const def = ReportDefinition(
      id: 'b',
      metrics: [ReportMetric.invested, ReportMetric.periodXirr],
      breakdowns: [
        Breakdown.byInvestmentType,
        Breakdown.byCurrency,
        Breakdown.byMonth,
      ],
    );
    final fy = ReportPeriod.fy(2023);
    final flows = [
      cf('a', DateTime(2023, 4, 1), CashFlowType.invest, 100),
      cf('b', DateTime(2023, 5, 9), CashFlowType.invest, 10, currency: 'USD'),
      cf('a', DateTime(2024, 3, 31), CashFlowType.invest, 5),
    ];
    final invs = [inv('a'), inv('b', type: InvestmentType.stocks)];

    test('every breakdown sums to the total', () async {
      final r = await engine.run(def, fy, inputs(flows, investments: invs));
      final total = v(r, ReportMetric.invested);
      expect(total, 905);
      for (final b in Breakdown.values) {
        final sum = r.breakdowns[b]!.fold<double>(
          0,
          (s, row) => s + row.values[ReportMetric.invested]!.valueOrNull!,
        );
        expect(sum, total, reason: '$b');
      }
    });

    test('keys and order', () async {
      final r = await engine.run(def, fy, inputs(flows, investments: invs));
      expect(r.breakdowns[Breakdown.byInvestmentType]!.map((e) => e.key), [
        'fixedDeposit',
        'stocks',
      ]);
      expect(r.breakdowns[Breakdown.byCurrency]!.map((e) => e.key), [
        'INR',
        'USD',
      ]);
      final months = r.breakdowns[Breakdown.byMonth]!;
      expect(months.length, 12);
      expect(months.first.key, '2023-04');
      expect(months.last.key, '2024-03');
      expect(months[1].values[ReportMetric.invested], const Known(800));
      expect(months[2].values[ReportMetric.invested], const Known(0));
    });

    test('valuation metrics are not computed per row', () async {
      final r = await engine.run(def, fy, inputs(flows, investments: invs));
      expect(
        r.breakdowns[Breakdown.byCurrency]!.first.values[ReportMetric
            .periodXirr],
        const Unknown(UnknownReason.notApplicable),
      );
    });
  });

  test('result is immutable', () async {
    final r = await engine.run(all, march, inputs([]));
    expect(
      () => r.totals[ReportMetric.invested] = const Known(1),
      throwsUnsupportedError,
    );
    expect(
      () => r.notes.add(const ReportNote(ReportNoteKind.excludedFlows, 1)),
      throwsUnsupportedError,
    );
  });
}

// -1000 on 2023-04-01, +1100 on 2024-04-01 = 366 days: 1.1^(365/366)-1.
double _expectedXirr() => pow(1.1, 365 / 366).toDouble() - 1;

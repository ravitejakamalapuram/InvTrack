// A71: an undefined XIRR (an open investment without a current value, too few
// flows, or no solution) must stay undefined in the calculator, the list sort,
// the weekly summary, the reports and the health score. It must never be
// counted as a 0% return.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_enums.dart';
import 'package:inv_tracker/features/portfolio_health/domain/services/portfolio_health_calculator.dart';
import 'package:inv_tracker/features/reports/data/services/performance_report_service.dart';
import 'package:inv_tracker/features/reports/data/services/report_cache_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_type.dart';
import 'package:inv_tracker/features/reports/presentation/providers/weekly_summary_provider.dart';

import '../../mocks/mock_currency_conversion_service.dart';

CashFlowEntity _flow(
  String id,
  String investmentId,
  CashFlowType type,
  double amount,
  DateTime date,
) => CashFlowEntity(
  id: id,
  investmentId: investmentId,
  type: type,
  amount: amount,
  currency: 'INR',
  date: date,
  createdAt: date,
);

InvestmentEntity _investment(
  String id,
  InvestmentStatus status, {
  InvestmentType type = InvestmentType.fixedDeposit,
}) => InvestmentEntity(
  id: id,
  name: 'Investment $id',
  type: type,
  status: status,
  currency: 'INR',
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

// A: −83,800 on 2024-10-01, +96,800 on 2026-10-01 → XIRR 0.074770 (730 days,
// actual/365: (96800 / 83800) ^ (365 / 730) − 1).
// B: open, a single INVEST → undefined.
// C: −1,00,000 on 2025-10-01, +90,000 on 2026-10-01 → XIRR −0.100000.
const _xirrA = 0.0747703312412693;
const _xirrC = -0.1;

final _flowsA = [
  _flow('a1', 'A', CashFlowType.invest, 83800, DateTime(2024, 10, 1)),
  _flow('a2', 'A', CashFlowType.returnFlow, 96800, DateTime(2026, 10, 1)),
];
final _flowsB = [
  _flow('b1', 'B', CashFlowType.invest, 100000, DateTime(2025, 10, 1)),
];
final _flowsC = [
  _flow('c1', 'C', CashFlowType.invest, 100000, DateTime(2025, 10, 1)),
  _flow('c2', 'C', CashFlowType.returnFlow, 90000, DateTime(2026, 10, 1)),
];

class _NoCache implements ReportCacheService {
  @override
  T? get<T>(ReportType type, DateTime start, DateTime end) => null;
  @override
  void set<T>(ReportType type, DateTime start, DateTime end, T value) {}
  @override
  void clearType(ReportType type) {}
  @override
  void clearAll() {}
  @override
  void cleanupExpired() {}
  @override
  Map<String, dynamic> getStats() => {};
  @override
  void startPeriodicCleanup() {}
  @override
  void dispose() {}
}

/// A container whose streams hold investments A (closed), B (open) and C
/// (open) with the flows above, all in the base currency INR.
ProviderContainer _container({List<Override> extraOverrides = const []}) {
  final investments = [
    _investment('A', InvestmentStatus.closed),
    _investment('B', InvestmentStatus.open),
    _investment('C', InvestmentStatus.open),
  ];
  final flows = [..._flowsA, ..._flowsB, ..._flowsC];
  return ProviderContainer(
    overrides: [
      isAuthenticatedProvider.overrideWith((ref) => true),
      allInvestmentsProvider.overrideWith((ref) => Stream.value(investments)),
      archivedInvestmentsProvider.overrideWith((ref) => Stream.value([])),
      allCashFlowsStreamProvider.overrideWith((ref) => Stream.value(flows)),
      for (final id in ['A', 'B', 'C'])
        cashFlowsByInvestmentProvider(id).overrideWith(
          (ref) => Stream.value([
            for (final cf in flows)
              if (cf.investmentId == id) cf,
          ]),
        ),
      currencyCodeProvider.overrideWith((ref) => 'INR'),
      currencyConversionServiceProvider.overrideWith(
        (ref) => MockCurrencyConversionService(),
      ),
      reportCacheServiceProvider.overrideWithValue(_NoCache()),
      ...extraOverrides,
    ],
  );
}

Future<List<String>> _sortedIds(
  ProviderContainer container,
  InvestmentSort sort,
) async {
  final sub = container.listen(filteredInvestmentsProvider, (_, _) {});
  addTearDown(sub.close);
  container.read(investmentListStateProvider.notifier).setSort(sort);
  // Let the streams, the conversion and the XIRR isolate settle.
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return [for (final inv in sub.read().requireValue) inv.id];
}

void main() {
  group('FinancialCalculator XIRR', () {
    test('a single INVEST of −1,00,000 has an undefined XIRR, not 0.0', () {
      final xirr = FinancialCalculator.calculateXirrFromCashFlows([
        _flow('x', 'X', CashFlowType.invest, 100000, DateTime(2025, 1, 1)),
      ]);
      expect(xirr, isNull);
    });

    test('the module returns undefined for flows with no sign change', () {
      final module = FinancialCalculatorModule();
      expect(module.calculateXirrFromCashFlows(_flowsB), isNull);
      expect(module.calculateXirr([DateTime(2025, 1, 1)], [-100000]), isNull);
    });

    test('stats carry a null XIRR when it is undefined', () {
      final stats = FinancialCalculatorModule().calculateStats(_flowsB);
      expect(stats.xirr, isNull);
      expect(stats.xirrMethod, XirrMethod.undefined);
    });
  });

  group('XIRR sort', () {
    test('xirrDesc gives A, C, B: undefined last', () async {
      final container = _container();
      addTearDown(container.dispose);
      expect(await _sortedIds(container, InvestmentSort.xirrDesc), [
        'A',
        'C',
        'B',
      ]);
    });

    test('xirrAsc gives C, A, B: undefined last', () async {
      final container = _container();
      addTearDown(container.dispose);
      expect(await _sortedIds(container, InvestmentSort.xirrAsc), [
        'C',
        'A',
        'B',
      ]);
    });
  });

  group('Weekly summary', () {
    test('an undefined XIRR never beats a negative one', () async {
      final start = DateTime(2026, 9, 28);
      final end = DateTime(2026, 10, 4, 23, 59, 59);
      final container = _container(
        extraOverrides: [
          cashFlowsInDateRangeProvider((
            start: start,
            end: end,
          )).overrideWith((ref) => Stream.value([_flowsA[1], _flowsC[1]])),
        ],
      );
      addTearDown(container.dispose);
      container.listen(
        cashFlowsInDateRangeProvider((start: start, end: end)),
        (_, _) {},
      );
      container.listen(activeInvestmentXirrResultMapProvider, (_, _) {});
      await container.read(activeInvestmentXirrResultMapProvider.future);
      final weekly = weeklySummaryProvider((
        periodStart: start,
        periodEnd: end,
      ));
      container.listen(weekly, (_, _) {});
      final summary = await container.read(weekly.future);

      expect(summary.topPerformer?.id, 'C');
      expect(summary.topPerformerXirr, closeTo(_xirrC, 1e-6));
    });
  });

  group('Portfolio health returns component', () {
    test('leaves an open FD with no payout out of the weighted XIRR', () {
      // Closed: ₹10,00,000 → ₹10,80,000 over 365 days = XIRR 8.0000%.
      final closedFlows = [
        _flow('h1', 'H1', CashFlowType.invest, 1000000, DateTime(2025, 1, 1)),
        _flow(
          'h2',
          'H1',
          CashFlowType.returnFlow,
          1080000,
          DateTime(2026, 1, 1),
        ),
      ];
      // Open FD of ₹10,00,000 with no payout yet: XIRR undefined.
      final openFlows = [
        _flow('h3', 'H2', CashFlowType.invest, 1000000, DateTime(2025, 6, 1)),
      ];
      final module = FinancialCalculatorModule();
      final closedStats = module.calculateStats(closedFlows);
      expect(closedStats.xirr, closeTo(0.08, 1e-6));

      final score = PortfolioHealthCalculator.calculate(
        investments: [
          _investment('H1', InvestmentStatus.closed),
          _investment('H2', InvestmentStatus.open),
        ],
        investmentStats: {
          'H1': closedStats,
          'H2': module.calculateStats(openFlows),
        },
        allCashFlows: [...closedFlows, ...openFlows],
        goalProgress: [],
      );

      // A weighted XIRR of 0.080000 against 6% inflation scores
      // 60 + (0.08 − 0.06) / 0.05 × 20 = 68.0. Counting the FD as 0% would
      // give 0.040000 and 40 + 0.04 / 0.06 × 20 = 53.33.
      expect(score.returnsPerformance.score, closeTo(68.0, 1e-6));
    });
  });

  group('Performance report', () {
    test('average and median XIRR leave out undefined investments', () {
      final report = PerformanceReportService().generateReport(
        allInvestments: [
          _investment('A', InvestmentStatus.closed),
          _investment('B', InvestmentStatus.open),
          _investment('C', InvestmentStatus.open),
        ],
        allCashFlows: [..._flowsA, ..._flowsB, ..._flowsC],
      );

      const expected = (_xirrA + _xirrC) / 2; // −0.012615
      expect(report.averageXIRR, closeTo(expected, 1e-6));
      expect(report.medianXIRR, closeTo(expected, 1e-6));
      expect(
        [for (final p in report.topPerformers) p.investment.id],
        ['A', 'C'],
      );
      expect(
        [for (final p in report.bottomPerformers) p.investment.id],
        ['C', 'A'],
      );
    });

    test('average and median XIRR are undefined when no XIRR is', () {
      final report = PerformanceReportService().generateReport(
        allInvestments: [_investment('B', InvestmentStatus.open)],
        allCashFlows: _flowsB,
      );

      expect(report.averageXIRR, isNull);
      expect(report.medianXIRR, isNull);
    });
  });
}

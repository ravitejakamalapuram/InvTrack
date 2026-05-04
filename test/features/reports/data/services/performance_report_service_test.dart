import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/reports/data/services/performance_report_service.dart';

/// Helper to build a simple investment with a known approximate XIRR.
///
/// Invest [principal] on [investDate] and get back [maturityAmount] on
/// a date roughly one year later.  The actual XIRR produced by the
/// calculator is not asserted; only ordering across investments is tested.
InvestmentEntity _makeInvestment(String id, String name) => InvestmentEntity(
      id: id,
      name: name,
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.open,
      startDate: DateTime(2023, 1, 1),
      createdAt: DateTime(2023, 1, 1),
      updatedAt: DateTime(2023, 1, 1),
      currency: 'USD',
    );

/// Creates a pair of cashflows: an investment on Jan 1 2023 and a return on
/// Jan 1 2024, giving [principal] in and [maturityAmount] out.
List<CashFlowEntity> _makeCashFlows(
  String investmentId,
  double principal,
  double maturityAmount,
) =>
    [
      CashFlowEntity(
        id: '$investmentId-in',
        investmentId: investmentId,
        amount: principal,
        date: DateTime(2023, 1, 1),
        type: CashFlowType.invest,
        currency: 'USD',
        createdAt: DateTime(2023, 1, 1),
      ),
      CashFlowEntity(
        id: '$investmentId-out',
        investmentId: investmentId,
        amount: maturityAmount,
        date: DateTime(2024, 1, 1),
        type: CashFlowType.returnFlow,
        currency: 'USD',
        createdAt: DateTime(2024, 1, 1),
      ),
    ];

void main() {
  group('PerformanceReportService', () {
    late PerformanceReportService service;

    setUp(() {
      service = PerformanceReportService();
    });

    // ── topPerformers ──────────────────────────────────────────────────────

    test('topPerformers is sorted descending by XIRR (highest first)', () {
      // Two investments with clearly different XIRRs
      final investments = [
        _makeInvestment('low', 'Low Performer'),
        _makeInvestment('high', 'High Performer'),
      ];

      final cashFlows = [
        ..._makeCashFlows('low', 10000, 10500),   // ~5%
        ..._makeCashFlows('high', 10000, 15000),  // ~50%
      ];

      final report = service.generateReport(
        allInvestments: investments,
        allCashFlows: cashFlows,
      );

      expect(report.topPerformers, isNotEmpty);
      expect(report.topPerformers.first.investment.id, 'high');

      // Verify descending order
      for (var i = 0; i < report.topPerformers.length - 1; i++) {
        expect(
          report.topPerformers[i].xirr,
          greaterThanOrEqualTo(report.topPerformers[i + 1].xirr),
        );
      }
    });

    // ── bottomPerformers ordering after double-reverse fix ─────────────────

    test(
        'bottomPerformers contains the investments with lowest XIRR '
        'and is sorted descending (best-of-worst first)', () {
      // 6 investments so top5 != bottom5
      final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
      // Returns scale: a=60%, b=50%, c=40%, d=20%, e=10%, f=-5%
      final maturityAmounts = [16000.0, 15000.0, 14000.0, 12000.0, 11000.0, 9500.0];

      final investments = ids
          .map((id) => _makeInvestment(id, 'Investment $id'))
          .toList();

      final cashFlows = <CashFlowEntity>[];
      for (var i = 0; i < ids.length; i++) {
        cashFlows.addAll(_makeCashFlows(ids[i], 10000, maturityAmounts[i]));
      }

      final report = service.generateReport(
        allInvestments: investments,
        allCashFlows: cashFlows,
      );

      // There are 6 investments, so top5 = {a,b,c,d,e} and bottom5 = {b,c,d,e,f}
      expect(report.topPerformers.length, 5);
      expect(report.bottomPerformers.length, 5);

      // bottomPerformers must include the absolute worst performer 'f'
      final bottomIds = report.bottomPerformers.map((p) => p.investment.id).toSet();
      expect(bottomIds, contains('f'));

      // topPerformers must include the absolute best performer 'a'
      final topIds = report.topPerformers.map((p) => p.investment.id).toSet();
      expect(topIds, contains('a'));

      // After the double-reverse fix, bottomPerformers is sorted DESCENDING:
      // i.e. bottomPerformers[0].xirr >= bottomPerformers[last].xirr
      for (var i = 0; i < report.bottomPerformers.length - 1; i++) {
        expect(
          report.bottomPerformers[i].xirr,
          greaterThanOrEqualTo(report.bottomPerformers[i + 1].xirr),
          reason:
              'bottomPerformers should be sorted descending (best-of-worst '
              'first) after the double-reverse fix',
        );
      }

      // The last element in bottomPerformers should be the worst ('f')
      expect(report.bottomPerformers.last.investment.id, 'f');
    });

    test('bottomPerformers last element has the lowest XIRR overall', () {
      final ids = ['g1', 'g2', 'g3', 'g4', 'g5', 'g6'];
      // Create clearly differentiated XIRRs via maturity amounts
      final maturityAmounts = [20000.0, 18000.0, 15000.0, 12000.0, 11000.0, 8000.0];

      final investments = ids
          .map((id) => _makeInvestment(id, 'Inv $id'))
          .toList();
      final cashFlows = <CashFlowEntity>[];
      for (var i = 0; i < ids.length; i++) {
        cashFlows.addAll(_makeCashFlows(ids[i], 10000, maturityAmounts[i]));
      }

      final report = service.generateReport(
        allInvestments: investments,
        allCashFlows: cashFlows,
      );

      // 'g6' has the lowest return (8000 on 10000 invested → negative XIRR)
      expect(report.bottomPerformers.last.investment.id, 'g6');
      expect(report.bottomPerformers.last.xirr, lessThan(0));
    });

    // ── Regression: previous code only reversed once ────────────────────────

    test(
        'regression: bottomPerformers first element is NOT the absolute worst '
        'performer (it is the best-of-worst)', () {
      // With 6 investments, old code (single reverse) had the worst (f) FIRST.
      // New code (double reverse) should have worst (f) LAST.
      final ids = ['r1', 'r2', 'r3', 'r4', 'r5', 'r6'];
      final maturityAmounts = [17000.0, 15000.0, 13000.0, 11500.0, 10500.0, 9000.0];

      final investments = ids
          .map((id) => _makeInvestment(id, 'Inv $id'))
          .toList();
      final cashFlows = <CashFlowEntity>[];
      for (var i = 0; i < ids.length; i++) {
        cashFlows.addAll(_makeCashFlows(ids[i], 10000, maturityAmounts[i]));
      }

      final report = service.generateReport(
        allInvestments: investments,
        allCashFlows: cashFlows,
      );

      // 'r6' is the worst performer (9000 < 10000 invested)
      expect(report.bottomPerformers.first.investment.id, isNot('r6'),
          reason:
              'After double-reverse fix, worst performer should be last, not first');
      expect(report.bottomPerformers.last.investment.id, 'r6',
          reason:
              'After double-reverse fix, worst performer should be last in bottomPerformers');
    });

    // ── Edge cases ─────────────────────────────────────────────────────────

    test('investments without cashflows are excluded from report', () {
      final investments = [
        _makeInvestment('with-flows', 'Has Flows'),
        _makeInvestment('no-flows', 'No Flows'),
      ];

      final cashFlows = _makeCashFlows('with-flows', 10000, 11000);

      final report = service.generateReport(
        allInvestments: investments,
        allCashFlows: cashFlows,
      );

      expect(report.totalInvestments, 1);
      expect(report.allPerformances.first.investment.id, 'with-flows');
    });

    test('returns empty report for no investments', () {
      final report = service.generateReport(
        allInvestments: [],
        allCashFlows: [],
      );

      expect(report.totalInvestments, 0);
      expect(report.topPerformers, isEmpty);
      expect(report.bottomPerformers, isEmpty);
      expect(report.averageXIRR, 0.0);
      expect(report.medianXIRR, 0.0);
      expect(report.profitableCount, 0);
      expect(report.lossCount, 0);
    });

    test('profitableCount and lossCount are computed correctly', () {
      final ids = ['p1', 'p2', 'loss1'];
      // p1 and p2 are profitable, loss1 is not
      final maturityAmounts = [12000.0, 11000.0, 9000.0];

      final investments = ids
          .map((id) => _makeInvestment(id, 'Inv $id'))
          .toList();
      final cashFlows = <CashFlowEntity>[];
      for (var i = 0; i < ids.length; i++) {
        cashFlows.addAll(_makeCashFlows(ids[i], 10000, maturityAmounts[i]));
      }

      final report = service.generateReport(
        allInvestments: investments,
        allCashFlows: cashFlows,
      );

      expect(report.profitableCount, 2);
      expect(report.lossCount, 1);
      expect(report.profitabilityRate, closeTo(66.67, 0.01));
    });

    test('topPerformers limited to 5 even when more investments exist', () {
      final ids = List.generate(10, (i) => 'inv$i');
      final investments = ids
          .map((id) => _makeInvestment(id, 'Inv $id'))
          .toList();
      final cashFlows = <CashFlowEntity>[];
      for (var i = 0; i < ids.length; i++) {
        // Give each a different return, 10000 base + i*1000
        cashFlows.addAll(_makeCashFlows(ids[i], 10000, 10000 + (i + 1) * 1000.0));
      }

      final report = service.generateReport(
        allInvestments: investments,
        allCashFlows: cashFlows,
      );

      expect(report.topPerformers.length, 5);
      expect(report.bottomPerformers.length, 5);
    });

    test('averageXIRR is the mean of all investment XIRRs', () {
      final investments = [
        _makeInvestment('avg1', 'Avg1'),
        _makeInvestment('avg2', 'Avg2'),
      ];
      // Both have similar returns to make average easy to reason about
      final cashFlows = [
        ..._makeCashFlows('avg1', 10000, 11000), // ~10%
        ..._makeCashFlows('avg2', 10000, 11000), // ~10%
      ];

      final report = service.generateReport(
        allInvestments: investments,
        allCashFlows: cashFlows,
      );

      // Both XIRRs are equal so average == medianXIRR
      expect(report.averageXIRR, closeTo(report.medianXIRR, 0.0001));
      expect(report.averageXIRR, greaterThan(0));
    });

    test('milestone achievements are generated for investments above 10% gain', () {
      final investment = _makeInvestment('big-gain', 'Big Gain');
      // 10000 → 21000: ~110% absolute return → should trigger 10, 25, 50, 100 milestones
      final cashFlows = _makeCashFlows('big-gain', 10000, 21000);

      final report = service.generateReport(
        allInvestments: [investment],
        allCashFlows: cashFlows,
      );

      expect(report.recentMilestones, isNotEmpty);
      final percentages =
          report.recentMilestones.map((m) => m.milestonePercentage).toSet();
      expect(percentages, containsAll([10.0, 25.0, 50.0, 100.0]));
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/reports/data/services/report_cache_service.dart';
import 'package:inv_tracker/features/reports/data/services/weekly_summary_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_type.dart';

/// Mock cache service that returns null (no cache)
class MockReportCacheService implements ReportCacheService {
  @override
  T? get<T>(ReportType type, DateTime start, DateTime end) => null;

  @override
  void set<T>(ReportType type, DateTime start, DateTime end, T value) {}

  @override
  void clear(ReportType type) {}

  @override
  void clearAll() {}

  @override
  void clearType(ReportType type) {}

  @override
  void cleanupExpired() {}

  @override
  Map<String, dynamic> getStats() => {};
}

void main() {
  group('WeeklySummaryService', () {
    late WeeklySummaryService service;
    late DateTime weekStart;
    late DateTime weekEnd;

    setUp(() {
      service = WeeklySummaryService(cacheService: MockReportCacheService());
      // Week of Jan 1-7, 2024 (Monday to Sunday)
      weekStart = DateTime(2024, 1, 1);
      weekEnd = DateTime(2024, 1, 7, 23, 59, 59);
    });

    test('should calculate totals for the week', () async {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 10000,
          date: DateTime(2024, 1, 2),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 2),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          amount: 500,
          date: DateTime(2024, 1, 3),
          type: CashFlowType.income,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 3),
        ),
        CashFlowEntity(
          id: '3',
          investmentId: 'inv2',
          amount: 11000,
          date: DateTime(2024, 1, 5),
          type: CashFlowType.returnFlow,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 5),
        ),
      ];

      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Test Investment 1',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 12, 1),
          createdAt: DateTime(2023, 12, 1),
          updatedAt: DateTime(2023, 12, 1),
          currency: 'USD',
        ),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: investments,
        xirrMap: {},
      );

      expect(summary.totalInvested, 10000.0);
      expect(summary.totalIncome, 500.0);
      // totalReturns = RETURN + INCOME flows = 11000 + 500 = 11500
      expect(summary.totalReturns, 11500.0);
      // Net = totalReturns - invested = 11500 - 10000 = 1500
      expect(summary.netPosition, 1500.0);
    });

    test('should handle empty data', () async {
      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: [],
        allInvestments: [],
        xirrMap: {},
      );

      expect(summary.totalInvested, 0);
      expect(summary.totalIncome, 0);
      expect(summary.totalReturns, 0);
      expect(summary.netPosition, 0);
      expect(summary.topPerformer, isNull);
      expect(summary.topPerformerXirr, isNull);
    });

    test('should filter transactions outside the week', () async {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 10000,
          date: DateTime(2023, 12, 31), // Before week
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2023, 12, 31),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          amount: 5000,
          date: DateTime(2024, 1, 3), // During week
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 3),
        ),
        CashFlowEntity(
          id: '3',
          investmentId: 'inv1',
          amount: 500,
          date: DateTime(2024, 1, 9), // 2 days after week (outside filter range)
          type: CashFlowType.income,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 9),
        ),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      expect(summary.totalInvested, 5000.0); // Only transaction during week
      expect(summary.totalIncome, 0.0); // Income is after week
    });

    test('should identify new investments created during the week', () async {
      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Old Investment',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 12, 1),
          createdAt: DateTime(2023, 12, 1),
          updatedAt: DateTime(2023, 12, 1),
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv2',
          name: 'New Investment',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: DateTime(2024, 1, 3),
          createdAt: DateTime(2024, 1, 3),
          updatedAt: DateTime(2024, 1, 3),
          currency: 'USD',
        ),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: [],
        allInvestments: investments,
        xirrMap: {},
      );

      expect(summary.newInvestments.length, 1);
      expect(summary.newInvestments.first.id, 'inv2');
    });

    test('should identify upcoming maturities', () async {
      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Maturing Soon',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 6, 1),
          createdAt: DateTime(2023, 6, 1),
          updatedAt: DateTime(2023, 6, 1),
          maturityDate: DateTime(2024, 1, 10), // 3 days after week end
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv2',
          name: 'Maturing Later',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 6, 1),
          createdAt: DateTime(2023, 6, 1),
          updatedAt: DateTime(2023, 6, 1),
          maturityDate: DateTime(2024, 2, 1), // Too far in future
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv3',
          name: 'Already Closed',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.closed,
          startDate: DateTime(2023, 6, 1),
          createdAt: DateTime(2023, 6, 1),
          updatedAt: DateTime(2023, 12, 1),
          closedAt: DateTime(2023, 12, 1),
          maturityDate: DateTime(2024, 1, 10),
          currency: 'USD',
        ),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: [],
        allInvestments: investments,
        xirrMap: {},
      );

      expect(summary.upcomingMaturities.length, 1);
      expect(summary.upcomingMaturities.first.id, 'inv1');
    });

    test('should find top performer by XIRR', () async {
      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Low Performer',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 6, 1),
          createdAt: DateTime(2023, 6, 1),
          updatedAt: DateTime(2023, 6, 1),
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv2',
          name: 'Top Performer',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 6, 1),
          createdAt: DateTime(2023, 6, 1),
          updatedAt: DateTime(2023, 6, 1),
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv3',
          name: 'Closed Investment',
          type: InvestmentType.stocks,
          status: InvestmentStatus.closed,
          startDate: DateTime(2023, 6, 1),
          createdAt: DateTime(2023, 6, 1),
          updatedAt: DateTime(2023, 12, 1),
          closedAt: DateTime(2023, 12, 1),
          currency: 'USD',
        ),
      ];

      final xirrMap = {
        'inv1': 0.05, // 5%
        'inv2': 0.15, // 15% - Best performer
        'inv3': 0.10, // 10% - But closed, should be excluded
      };

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: [],
        allInvestments: investments,
        xirrMap: xirrMap,
      );

      expect(summary.topPerformer?.id, 'inv2');
      expect(summary.topPerformerXirr, 0.15);
    });
  });
}

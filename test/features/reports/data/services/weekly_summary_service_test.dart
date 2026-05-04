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
  void clearType(ReportType type) {}

  @override
  void clearAll() {}

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

    // ── Tests added to cover O(N) refactor (single-pass loop optimization) ──

    test('should calculate previousWeekNet from prior week cashflows', () async {
      // Current week: Jan 1-7, 2024
      // Previous week: Dec 25-31, 2023
      final cashFlows = [
        // Previous week invest
        CashFlowEntity(
          id: 'prev1',
          investmentId: 'inv1',
          amount: 5000,
          date: DateTime(2023, 12, 27),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2023, 12, 27),
        ),
        // Previous week returnFlow
        CashFlowEntity(
          id: 'prev2',
          investmentId: 'inv1',
          amount: 3000,
          date: DateTime(2023, 12, 28),
          type: CashFlowType.returnFlow,
          currency: 'USD',
          createdAt: DateTime(2023, 12, 28),
        ),
        // Previous week income
        CashFlowEntity(
          id: 'prev3',
          investmentId: 'inv1',
          amount: 200,
          date: DateTime(2023, 12, 29),
          type: CashFlowType.income,
          currency: 'USD',
          createdAt: DateTime(2023, 12, 29),
        ),
        // Current week (should NOT affect previousWeekNet)
        CashFlowEntity(
          id: 'cur1',
          investmentId: 'inv1',
          amount: 10000,
          date: DateTime(2024, 1, 3),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 3),
        ),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      // prevWeekNet = (prevReturned + prevIncome) - prevInvested
      //             = (3000 + 200) - 5000 = -1800
      expect(summary.previousWeekNet, -1800.0);
    });

    test('previousWeekNet is zero when no cashflows in prior week', () async {
      final cashFlows = [
        CashFlowEntity(
          id: 'cur1',
          investmentId: 'inv1',
          amount: 10000,
          date: DateTime(2024, 1, 3),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 3),
        ),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      expect(summary.previousWeekNet, 0.0);
    });

    test('should generate daily cashflows with correct outflows and inflows', () async {
      final cashFlows = [
        // Monday Jan 1: invest outflow
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 1000,
          date: DateTime(2024, 1, 1),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 1),
        ),
        // Monday Jan 1: fee outflow
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          amount: 50,
          date: DateTime(2024, 1, 1),
          type: CashFlowType.fee,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 1),
        ),
        // Wednesday Jan 3: returnFlow inflow
        CashFlowEntity(
          id: '3',
          investmentId: 'inv1',
          amount: 2000,
          date: DateTime(2024, 1, 3),
          type: CashFlowType.returnFlow,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 3),
        ),
        // Wednesday Jan 3: income inflow
        CashFlowEntity(
          id: '4',
          investmentId: 'inv1',
          amount: 100,
          date: DateTime(2024, 1, 3),
          type: CashFlowType.income,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 3),
        ),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      // Should have 7 daily entries for the week
      expect(summary.dailyCashFlows.length, 7);

      // Monday (index 0, dayOfWeek=0): outflows=1000+50=1050, inflows=0
      final monday = summary.dailyCashFlows[0];
      expect(monday.dayOfWeek, 0);
      expect(monday.outflows, 1050.0);
      expect(monday.inflows, 0.0);
      expect(monday.net, -1050.0);

      // Wednesday (index 2, dayOfWeek=2): outflows=0, inflows=2000+100=2100
      final wednesday = summary.dailyCashFlows[2];
      expect(wednesday.dayOfWeek, 2);
      expect(wednesday.outflows, 0.0);
      expect(wednesday.inflows, 2100.0);
      expect(wednesday.net, 2100.0);

      // Tuesday (index 1, dayOfWeek=1): no flows
      final tuesday = summary.dailyCashFlows[1];
      expect(tuesday.outflows, 0.0);
      expect(tuesday.inflows, 0.0);
    });

    test('fee cashflows counted as outflows in totals (not in invested)', () async {
      // Fee flows are NOT counted in totalInvested but affect dailyCashFlows outflows
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 1000,
          date: DateTime(2024, 1, 2),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 2),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          amount: 50,
          date: DateTime(2024, 1, 2),
          type: CashFlowType.fee,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 2),
        ),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      // totalInvested counts only invest-type flows
      expect(summary.totalInvested, 1000.0);
      // fee is not counted in totalInvested
      expect(summary.totalReturns, 0.0);
      expect(summary.totalIncome, 0.0);
      // netPosition = (returned + income) - invested = (0 + 0) - 1000 = -1000
      expect(summary.netPosition, -1000.0);

      // But in dailyCashFlows, Tuesday should have outflows for both invest+fee
      final tuesday = summary.dailyCashFlows.firstWhere(
        (d) => d.date.day == 2,
      );
      expect(tuesday.outflows, 1050.0); // invest + fee
    });

    test('should correctly compute netPosition as (returned + income) - invested', () async {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 20000,
          date: DateTime(2024, 1, 2),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 2),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          amount: 15000,
          date: DateTime(2024, 1, 4),
          type: CashFlowType.returnFlow,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 4),
        ),
        CashFlowEntity(
          id: '3',
          investmentId: 'inv1',
          amount: 1000,
          date: DateTime(2024, 1, 5),
          type: CashFlowType.income,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 5),
        ),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      expect(summary.totalInvested, 20000.0);
      expect(summary.totalReturns, 16000.0); // returnFlow + income
      expect(summary.totalIncome, 1000.0);
      expect(summary.netPosition, -4000.0); // (15000+1000) - 20000
    });

    test('closed investments are excluded from top performer search', () async {
      final investments = [
        InvestmentEntity(
          id: 'inv_open',
          name: 'Open Low Performer',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv_closed',
          name: 'Closed High Performer',
          type: InvestmentType.stocks,
          status: InvestmentStatus.closed,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 12, 1),
          closedAt: DateTime(2023, 12, 1),
          currency: 'USD',
        ),
      ];

      final xirrMap = {
        'inv_open': 0.05,  // 5% - open
        'inv_closed': 0.50, // 50% - closed, should NOT be picked
      };

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: [],
        allInvestments: investments,
        xirrMap: xirrMap,
      );

      expect(summary.topPerformer?.id, 'inv_open');
      expect(summary.topPerformerXirr, 0.05);
    });

    test('upcoming maturities exclude investments maturing exactly on periodEnd', () async {
      // Maturity exactly on periodEnd should be excluded (must be AFTER periodEnd)
      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Matures on Week End',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 6, 1),
          createdAt: DateTime(2023, 6, 1),
          updatedAt: DateTime(2023, 6, 1),
          maturityDate: weekEnd, // Exactly on periodEnd - should be excluded
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv2',
          name: 'Matures Just After Week End',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 6, 1),
          createdAt: DateTime(2023, 6, 1),
          updatedAt: DateTime(2023, 6, 1),
          maturityDate: weekEnd.add(const Duration(days: 1)), // Day after periodEnd - included
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
      expect(summary.upcomingMaturities.first.id, 'inv2');
    });

    test('dailyCashFlows has correct dayOfWeek values (0=Monday)', () async {
      // weekStart is DateTime(2024, 1, 1) which is a Monday
      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: [],
        allInvestments: [],
        xirrMap: {},
      );

      expect(summary.dailyCashFlows.length, 7);
      expect(summary.dailyCashFlows[0].dayOfWeek, 0); // Monday
      expect(summary.dailyCashFlows[1].dayOfWeek, 1); // Tuesday
      expect(summary.dailyCashFlows[6].dayOfWeek, 6); // Sunday
    });

    test('multiple investments created same day all added to newInvestments', () async {
      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'New A',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2024, 1, 3),
          createdAt: DateTime(2024, 1, 3),
          updatedAt: DateTime(2024, 1, 3),
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv2',
          name: 'New B',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: DateTime(2024, 1, 3),
          createdAt: DateTime(2024, 1, 3),
          updatedAt: DateTime(2024, 1, 3),
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv3',
          name: 'Old',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
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

      expect(summary.newInvestments.length, 2);
      expect(summary.newInvestments.map((i) => i.id), containsAll(['inv1', 'inv2']));
    });
  });
}

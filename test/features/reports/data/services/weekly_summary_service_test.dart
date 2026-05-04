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
  });

  // -----------------------------------------------------------------------
  // Tests specifically covering the single-pass aggregation refactoring
  // -----------------------------------------------------------------------

  group('WeeklySummaryService - single-pass aggregation (weekly totals)', () {
    late WeeklySummaryService service;
    late DateTime weekStart;
    late DateTime weekEnd;

    setUp(() {
      service = WeeklySummaryService(cacheService: MockReportCacheService());
      weekStart = DateTime(2024, 1, 1);
      weekEnd = DateTime(2024, 1, 7, 23, 59, 59);
    });

    CashFlowEntity _cf(
      String id,
      CashFlowType type,
      double amount,
      DateTime date,
    ) {
      return CashFlowEntity(
        id: id,
        investmentId: 'inv1',
        amount: amount,
        date: date,
        type: type,
        currency: 'USD',
        createdAt: date,
      );
    }

    test('fee type is excluded from invested/returned/income totals', () async {
      // fee is an outflow but NOT tracked in invested/returned/income in generateSummary
      final cashFlows = [
        _cf('1', CashFlowType.invest, 5000, DateTime(2024, 1, 3)),
        _cf('2', CashFlowType.fee, 200, DateTime(2024, 1, 3)),
        _cf('3', CashFlowType.income, 100, DateTime(2024, 1, 4)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      expect(summary.totalInvested, 5000.0);
      expect(summary.totalIncome, 100.0);
      // fee does not contribute to totalInvested or totalReturns
      expect(summary.totalReturns, 100.0);
      expect(summary.netPosition, (100.0) - 5000.0);
    });

    test('multiple invest flows are accumulated correctly', () async {
      final cashFlows = [
        _cf('1', CashFlowType.invest, 1000, DateTime(2024, 1, 1)),
        _cf('2', CashFlowType.invest, 2500, DateTime(2024, 1, 3)),
        _cf('3', CashFlowType.invest, 500, DateTime(2024, 1, 5)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      expect(summary.totalInvested, 4000.0);
      expect(summary.totalReturns, 0.0);
      expect(summary.netPosition, -4000.0);
    });

    test('multiple returnFlow flows are accumulated correctly', () async {
      final cashFlows = [
        _cf('1', CashFlowType.returnFlow, 3000, DateTime(2024, 1, 2)),
        _cf('2', CashFlowType.returnFlow, 1500, DateTime(2024, 1, 4)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      expect(summary.totalInvested, 0.0);
      // totalReturns = returnFlow + income
      expect(summary.totalReturns, 4500.0);
      expect(summary.netPosition, 4500.0);
    });

    test('multiple income flows are accumulated correctly', () async {
      final cashFlows = [
        _cf('1', CashFlowType.income, 200, DateTime(2024, 1, 2)),
        _cf('2', CashFlowType.income, 350, DateTime(2024, 1, 6)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      expect(summary.totalIncome, 550.0);
      expect(summary.totalReturns, 550.0); // income counts toward totalReturns
      expect(summary.netPosition, 550.0);
    });

    test('all four cashflow types in same week produce correct totals', () async {
      final cashFlows = [
        _cf('1', CashFlowType.invest, 10000, DateTime(2024, 1, 1)),
        _cf('2', CashFlowType.returnFlow, 6000, DateTime(2024, 1, 2)),
        _cf('3', CashFlowType.income, 400, DateTime(2024, 1, 3)),
        _cf('4', CashFlowType.fee, 150, DateTime(2024, 1, 4)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      // Only invest counts toward totalInvested
      expect(summary.totalInvested, 10000.0);
      expect(summary.totalIncome, 400.0);
      // totalReturns = returnFlow + income (fee excluded)
      expect(summary.totalReturns, 6400.0);
      // netPosition = (returned + income) - invested = 6400 - 10000
      expect(summary.netPosition, -3600.0);
    });

    test('zero-amount cashflows do not affect totals', () async {
      final cashFlows = [
        _cf('1', CashFlowType.invest, 0, DateTime(2024, 1, 2)),
        _cf('2', CashFlowType.income, 0, DateTime(2024, 1, 3)),
        _cf('3', CashFlowType.returnFlow, 0, DateTime(2024, 1, 4)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      expect(summary.totalInvested, 0.0);
      expect(summary.totalIncome, 0.0);
      expect(summary.totalReturns, 0.0);
      expect(summary.netPosition, 0.0);
    });

    test('netPosition equals (returnFlow + income) minus invest', () async {
      final cashFlows = [
        _cf('1', CashFlowType.invest, 8000, DateTime(2024, 1, 1)),
        _cf('2', CashFlowType.returnFlow, 5000, DateTime(2024, 1, 2)),
        _cf('3', CashFlowType.income, 750, DateTime(2024, 1, 3)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      final expected = (5000.0 + 750.0) - 8000.0;
      expect(summary.netPosition, expected);
    });
  });

  group('WeeklySummaryService - single-pass aggregation (daily cash flows)', () {
    late WeeklySummaryService service;
    late DateTime weekStart;
    late DateTime weekEnd;

    setUp(() {
      service = WeeklySummaryService(cacheService: MockReportCacheService());
      weekStart = DateTime(2024, 1, 1); // Monday
      weekEnd = DateTime(2024, 1, 7, 23, 59, 59); // Sunday
    });

    CashFlowEntity _cf(
      String id,
      CashFlowType type,
      double amount,
      DateTime date,
    ) {
      return CashFlowEntity(
        id: id,
        investmentId: 'inv1',
        amount: amount,
        date: date,
        type: type,
        currency: 'USD',
        createdAt: date,
      );
    }

    test('generates one DailyCashFlow entry for each day of the week', () async {
      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: [],
        allInvestments: [],
        xirrMap: {},
      );

      expect(summary.dailyCashFlows.length, 7);
    });

    test('invest type goes to outflows in daily breakdown', () async {
      final cashFlows = [
        _cf('1', CashFlowType.invest, 1500, DateTime(2024, 1, 3)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      final wednesday = summary.dailyCashFlows.firstWhere(
        (d) => d.date.day == 3,
      );
      expect(wednesday.outflows, 1500.0);
      expect(wednesday.inflows, 0.0);
    });

    test('fee type goes to outflows in daily breakdown', () async {
      final cashFlows = [
        _cf('1', CashFlowType.fee, 50, DateTime(2024, 1, 4)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      final thursday = summary.dailyCashFlows.firstWhere(
        (d) => d.date.day == 4,
      );
      expect(thursday.outflows, 50.0);
      expect(thursday.inflows, 0.0);
    });

    test('returnFlow type goes to inflows in daily breakdown', () async {
      final cashFlows = [
        _cf('1', CashFlowType.returnFlow, 2000, DateTime(2024, 1, 5)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      final friday = summary.dailyCashFlows.firstWhere(
        (d) => d.date.day == 5,
      );
      expect(friday.inflows, 2000.0);
      expect(friday.outflows, 0.0);
    });

    test('income type goes to inflows in daily breakdown', () async {
      final cashFlows = [
        _cf('1', CashFlowType.income, 300, DateTime(2024, 1, 6)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      final saturday = summary.dailyCashFlows.firstWhere(
        (d) => d.date.day == 6,
      );
      expect(saturday.inflows, 300.0);
      expect(saturday.outflows, 0.0);
    });

    test('invest and fee both accumulate into outflows on same day', () async {
      final cashFlows = [
        _cf('1', CashFlowType.invest, 4000, DateTime(2024, 1, 2)),
        _cf('2', CashFlowType.fee, 100, DateTime(2024, 1, 2)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      final tuesday = summary.dailyCashFlows.firstWhere(
        (d) => d.date.day == 2,
      );
      expect(tuesday.outflows, 4100.0);
      expect(tuesday.inflows, 0.0);
    });

    test('returnFlow and income both accumulate into inflows on same day', () async {
      final cashFlows = [
        _cf('1', CashFlowType.returnFlow, 5000, DateTime(2024, 1, 3)),
        _cf('2', CashFlowType.income, 250, DateTime(2024, 1, 3)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      final wednesday = summary.dailyCashFlows.firstWhere(
        (d) => d.date.day == 3,
      );
      expect(wednesday.inflows, 5250.0);
      expect(wednesday.outflows, 0.0);
    });

    test('multiple cashflows of same type on same day accumulate', () async {
      final cashFlows = [
        _cf('1', CashFlowType.invest, 1000, DateTime(2024, 1, 1)),
        _cf('2', CashFlowType.invest, 2000, DateTime(2024, 1, 1)),
        _cf('3', CashFlowType.invest, 500, DateTime(2024, 1, 1)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      final monday = summary.dailyCashFlows.firstWhere(
        (d) => d.date.day == 1,
      );
      expect(monday.outflows, 3500.0);
    });

    test('days with no cashflows have zero outflows and inflows', () async {
      final cashFlows = [
        _cf('1', CashFlowType.invest, 1000, DateTime(2024, 1, 1)), // Monday only
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      // Every day except Monday should be zero
      for (final day in summary.dailyCashFlows.where((d) => d.date.day != 1)) {
        expect(day.outflows, 0.0, reason: 'Expected 0 outflows on ${day.date}');
        expect(day.inflows, 0.0, reason: 'Expected 0 inflows on ${day.date}');
      }
    });

    test('dayOfWeek is 0 for Monday and 6 for Sunday', () async {
      final summary = await service.generateSummary(
        periodStart: weekStart, // Monday Jan 1 2024
        periodEnd: weekEnd,     // Sunday Jan 7 2024
        allCashFlows: [],
        allInvestments: [],
        xirrMap: {},
      );

      // Jan 1 2024 is a Monday (weekday=1), so dayOfWeek should be 0
      final monday = summary.dailyCashFlows.firstWhere((d) => d.date.day == 1);
      expect(monday.dayOfWeek, 0);

      // Jan 7 2024 is a Sunday (weekday=7), so dayOfWeek should be 6
      final sunday = summary.dailyCashFlows.firstWhere((d) => d.date.day == 7);
      expect(sunday.dayOfWeek, 6);
    });
  });

  group('WeeklySummaryService - single-pass aggregation (previousWeekNet)', () {
    late WeeklySummaryService service;
    late DateTime weekStart;
    late DateTime weekEnd;

    setUp(() {
      service = WeeklySummaryService(cacheService: MockReportCacheService());
      weekStart = DateTime(2024, 1, 8);  // Second week Monday
      weekEnd = DateTime(2024, 1, 14, 23, 59, 59);
    });

    CashFlowEntity _cf(
      String id,
      CashFlowType type,
      double amount,
      DateTime date,
    ) {
      return CashFlowEntity(
        id: id,
        investmentId: 'inv1',
        amount: amount,
        date: date,
        type: type,
        currency: 'USD',
        createdAt: date,
      );
    }

    test('previousWeekNet counts returnFlow as inflow', () async {
      // Prev week: Jan 1-7
      final cashFlows = [
        _cf('1', CashFlowType.returnFlow, 3000, DateTime(2024, 1, 3)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      // _calculateNetPosition: returned - invested = 3000 - 0
      expect(summary.previousWeekNet, 3000.0);
    });

    test('previousWeekNet counts income as inflow', () async {
      final cashFlows = [
        _cf('1', CashFlowType.income, 500, DateTime(2024, 1, 5)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      // income treated same as returnFlow in _calculateNetPosition
      expect(summary.previousWeekNet, 500.0);
    });

    test('previousWeekNet counts invest as outflow', () async {
      final cashFlows = [
        _cf('1', CashFlowType.invest, 8000, DateTime(2024, 1, 2)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      // returned - invested = 0 - 8000
      expect(summary.previousWeekNet, -8000.0);
    });

    test('previousWeekNet excludes fee type from calculation', () async {
      final cashFlows = [
        _cf('1', CashFlowType.invest, 5000, DateTime(2024, 1, 2)),
        _cf('2', CashFlowType.fee, 200, DateTime(2024, 1, 3)),
        _cf('3', CashFlowType.returnFlow, 2000, DateTime(2024, 1, 4)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      // fee is not counted: returned(2000) - invested(5000) = -3000
      expect(summary.previousWeekNet, -3000.0);
    });

    test('previousWeekNet with mixed types computes correctly', () async {
      final cashFlows = [
        _cf('1', CashFlowType.invest, 10000, DateTime(2024, 1, 1)),
        _cf('2', CashFlowType.returnFlow, 4000, DateTime(2024, 1, 2)),
        _cf('3', CashFlowType.income, 600, DateTime(2024, 1, 3)),
        _cf('4', CashFlowType.fee, 100, DateTime(2024, 1, 4)),
      ];

      final summary = await service.generateSummary(
        periodStart: weekStart,
        periodEnd: weekEnd,
        allCashFlows: cashFlows,
        allInvestments: [],
        xirrMap: {},
      );

      // returned = returnFlow + income = 4000 + 600 = 4600
      // invested = 10000
      // net = 4600 - 10000 = -5400 (fee excluded)
      expect(summary.previousWeekNet, -5400.0);
    });

    test('previousWeekNet is zero when previous week has no cashflows', () async {
      // All cashflows are in the current week (Jan 8-14), not previous week
      final cashFlows = [
        _cf('1', CashFlowType.invest, 5000, DateTime(2024, 1, 10)),
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
  });
}

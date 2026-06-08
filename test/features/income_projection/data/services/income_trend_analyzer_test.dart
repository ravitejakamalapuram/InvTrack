import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/income_projection/data/services/income_trend_analyzer.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';
import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/core/calculations/modules/currency_module.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/calculations/modules/projection_module.dart';
import 'package:inv_tracker/core/calculations/modules/portfolio_health_module.dart';

void main() {
  late IncomeTrendAnalyzer analyzer;
  late CalculationEngine engine;

  setUp(() {
    analyzer = IncomeTrendAnalyzer();
    
    // Set up calculation engine with identity currency conversion (no conversion needed for USD)
    engine = CalculationEngine();
    engine.registerModule(CurrencyConverterModule(null)); // null = no conversion needed
    engine.registerModule(FinancialCalculatorModule());
    engine.registerModule(ProjectionCalculatorModule());
    engine.registerModule(PortfolioHealthModule());
  });

  group('IncomeTrendAnalyzer - Growth Metrics', () {
    test('should calculate positive MoM growth', () async {
      final now = DateTime.now();
      final investments = [_createInvestment('inv-1')];
      final cashFlows = [
        _createIncome(1200, DateTime(now.year, now.month, 1), 'inv-1'), // Current month
        _createIncome(1000, DateTime(now.year, now.month - 1, 1), 'inv-1'), // Previous month
        _createIncome(1000, DateTime(now.year, now.month - 2, 1), 'inv-1'),
      ];

      final report = await analyzer.generateReport(investments: investments,
        cashFlows: cashFlows,
        expectedCashFlows: [],
        engine: engine,
        baseCurrency: 'USD',
      );

      // MoM = (1200 - 1000) / 1000 * 100 = 20%
      expect(report.momGrowth, closeTo(20.0, 0.1));
    });

    test('should calculate negative MoM growth', () async {
      final now = DateTime.now();
      final investments = [_createInvestment('inv-1')];
      final cashFlows = [
        _createIncome(800, DateTime(now.year, now.month, 1), 'inv-1'), // Current month
        _createIncome(1000, DateTime(now.year, now.month - 1, 1), 'inv-1'), // Previous month
        _createIncome(1000, DateTime(now.year, now.month - 2, 1), 'inv-1'),
      ];

      final report = await analyzer.generateReport(investments: investments,
        cashFlows: cashFlows,
        expectedCashFlows: [],
        engine: engine,
        baseCurrency: 'USD',
      );

      // MoM = (800 - 1000) / 1000 * 100 = -20%
      expect(report.momGrowth, closeTo(-20.0, 0.1));
    });

    test('should return 0 MoM when fewer than 2 months', () async {
      final now = DateTime.now();
      final investments = [_createInvestment('inv-1')];
      final cashFlows = [
        _createIncome(1000, DateTime(now.year, now.month, 1), 'inv-1'),
      ];

      final report = await analyzer.generateReport(investments: investments,
        cashFlows: cashFlows,
        expectedCashFlows: [],
        engine: engine,
        baseCurrency: 'USD',
      );

      expect(report.momGrowth, 0.0);
    });

    test('should calculate QoQ growth', () async {
      final now = DateTime.now();
      final investments = [_createInvestment('inv-1')];
      final cashFlows = _createMonthlyIncome(
        investmentId: 'inv-1',
        startMonth: now.subtract(const Duration(days: 180)),
        count: 12,
        amounts: [
          // Current quarter (last 3 months): 1200, 1200, 1200 = 3600
          1200, 1200, 1200,
          // Previous quarter (months 4-6): 1000, 1000, 1000 = 3000
          1000, 1000, 1000,
          // Older months
          900, 900, 900, 800, 800, 800,
        ],
      );

      final report = await analyzer.generateReport(investments: investments,
        cashFlows: cashFlows,
        expectedCashFlows: [],
        engine: engine,
        baseCurrency: 'USD',
      );

      // QoQ growth should be positive (current > previous)
      expect(report.qoqGrowth, greaterThan(0.0));
    });
  });

  group('IncomeTrendAnalyzer - Income Sources & HHI', () {
    test('should calculate well-diversified portfolio (low HHI)', () async {
      final now = DateTime.now();
      final investments = [
        _createInvestment('inv-1', name: 'Investment 1'),
        _createInvestment('inv-2', name: 'Investment 2'),
        _createInvestment('inv-3', name: 'Investment 3'),
      ];
      final cashFlows = [
        _createIncome(1000, DateTime(now.year, now.month, 1), 'inv-1'), // 33.3%
        _createIncome(1000, DateTime(now.year, now.month, 1), 'inv-2'), // 33.3%
        _createIncome(1000, DateTime(now.year, now.month, 1), 'inv-3'), // 33.3%
      ];

      final report = await analyzer.generateReport(investments: investments,
        cashFlows: cashFlows,
        expectedCashFlows: [],
        engine: engine,
        baseCurrency: 'USD',
      );

      // HHI = 0.333^2 + 0.333^2 + 0.333^2 ≈ 0.33 (moderate)
      expect(report.diversificationScore, lessThan(0.40));
      expect(report.incomeSources.length, 3);
    });

    test('should calculate concentrated portfolio (high HHI)', () async {
      final now = DateTime.now();
      final investments = [
        _createInvestment('inv-1', name: 'Investment 1'),
        _createInvestment('inv-2', name: 'Investment 2'),
      ];
      final cashFlows = [
        _createIncome(9000, DateTime(now.year, now.month, 1), 'inv-1'), // 90%
        _createIncome(1000, DateTime(now.year, now.month, 1), 'inv-2'), // 10%
      ];

      final report = await analyzer.generateReport(investments: investments,
        cashFlows: cashFlows,
        expectedCashFlows: [],
        engine: engine,
        baseCurrency: 'USD',
      );

      // HHI = 0.9^2 + 0.1^2 = 0.81 + 0.01 = 0.82 (very high concentration)
      expect(report.diversificationScore, greaterThan(0.70));
      expect(report.incomeSources.first.percentage, closeTo(90.0, 0.1));
    });
  });

  group('IncomeTrendAnalyzer - Platform Reliability', () {
    test('should calculate 100% reliability when all payments on time', () async {
      final investments = [
        _createInvestment('inv-1', platform: 'LenDenClub'),
      ];
      final expectedCashFlows = [
        _createExpectedFlow('inv-1', DateTime(2024, 6, 5), DateTime(2024, 6, 5)), // On time
        _createExpectedFlow('inv-1', DateTime(2024, 5, 5), DateTime(2024, 5, 5)), // On time
        _createExpectedFlow('inv-1', DateTime(2024, 4, 5), DateTime(2024, 4, 5)), // On time
      ];

      final report = await analyzer.generateReport(investments: investments,
        cashFlows: [],
        expectedCashFlows: expectedCashFlows,
        engine: engine,
        baseCurrency: 'USD',
      );

      expect(report.platformReliability.length, 1);
      expect(report.platformReliability.first.platform, 'LenDenClub');
      expect(report.platformReliability.first.onTimeRate, 1.0);
      expect(report.platformReliability.first.averageDelayDays, 0.0);
    });

    test('should calculate reliability with some late payments', () async {
      final investments = [
        _createInvestment('inv-1', platform: 'Grip'),
      ];
      final expectedCashFlows = [
        _createExpectedFlow('inv-1', DateTime(2024, 6, 5), DateTime(2024, 6, 8)), // Late (+3 days)
        _createExpectedFlow('inv-1', DateTime(2024, 5, 5), DateTime(2024, 5, 5)), // On time
        _createExpectedFlow('inv-1', DateTime(2024, 4, 5), DateTime(2024, 4, 10)), // Late (+5 days)
        _createExpectedFlow('inv-1', DateTime(2024, 3, 5), DateTime(2024, 3, 5)), // On time
      ];

      final report = await analyzer.generateReport(investments: investments,
        cashFlows: [],
        expectedCashFlows: expectedCashFlows,
        engine: engine,
        baseCurrency: 'USD',
      );

      expect(report.platformReliability.length, 1);
      // 3 out of 4 on-time (within 3 days tolerance) = 75%
      // (+3 days is considered on-time, +5 days is late)
      expect(report.platformReliability.first.onTimeRate, closeTo(0.75, 0.01));
      // Average delay: (3 + 0 + 5 + 0) / 4 = 2 days
      expect(report.platformReliability.first.averageDelayDays, closeTo(2.0, 0.5));
    });

    test('should sort platforms by reliability', () async {
      final investments = [
        _createInvestment('inv-1', platform: 'LenDenClub'),
        _createInvestment('inv-2', platform: 'Grip'),
      ];
      final expectedCashFlows = [
        // LenDenClub: 100% on-time
        _createExpectedFlow('inv-1', DateTime(2024, 6, 5), DateTime(2024, 6, 5)),
        _createExpectedFlow('inv-1', DateTime(2024, 5, 5), DateTime(2024, 5, 5)),
        // Grip: 50% on-time
        _createExpectedFlow('inv-2', DateTime(2024, 6, 5), DateTime(2024, 6, 10)),
        _createExpectedFlow('inv-2', DateTime(2024, 5, 5), DateTime(2024, 5, 5)),
      ];

      final report = await analyzer.generateReport(investments: investments,
        cashFlows: [],
        expectedCashFlows: expectedCashFlows,
        engine: engine,
        baseCurrency: 'USD',
      );

      expect(report.platformReliability.length, 2);
      // Should be sorted by onTimeRate descending
      expect(report.platformReliability.first.platform, 'LenDenClub');
      expect(report.platformReliability.first.onTimeRate, 1.0);
      expect(report.platformReliability.last.platform, 'Grip');
      expect(report.platformReliability.last.onTimeRate, closeTo(0.50, 0.01));
    });
  });

  group('IncomeTrendAnalyzer - Auto-Insights', () {
    test('should generate strong growth insight', () async {
      final now = DateTime.now();
      final investments = [_createInvestment('inv-1')];
      final cashFlows = [
        _createIncome(1200, DateTime(now.year, now.month, 1), 'inv-1'), // +20% MoM
        _createIncome(1000, DateTime(now.year, now.month - 1, 1), 'inv-1'),
      ];

      final report = await analyzer.generateReport(investments: investments,
        cashFlows: cashFlows,
        expectedCashFlows: [],
        engine: engine,
        baseCurrency: 'USD',
      );

      expect(report.insights.any((i) => i.contains('Strong growth') || i.contains('Positive growth')), true);
    });

    test('should generate diversification warning for concentrated portfolio', () async {
      final now = DateTime.now();
      final investments = [
        _createInvestment('inv-1', name: 'Top Source'),
        _createInvestment('inv-2', name: 'Minor Source'),
      ];
      final cashFlows = [
        _createIncome(9000, DateTime(now.year, now.month, 1), 'inv-1'), // 90%
        _createIncome(1000, DateTime(now.year, now.month, 1), 'inv-2'), // 10%
      ];

      final report = await analyzer.generateReport(investments: investments,
        cashFlows: cashFlows,
        expectedCashFlows: [],
        engine: engine,
        baseCurrency: 'USD',
      );

      expect(report.insights.any((i) => i.contains('Consider diversifying')), true);
    });

    test('should generate platform reliability warning', () async {
      final investments = [_createInvestment('inv-1', platform: 'SlowPlatform')];
      final expectedCashFlows = [
        _createExpectedFlow('inv-1', DateTime(2024, 6, 5), DateTime(2024, 6, 10)), // Late
        _createExpectedFlow('inv-1', DateTime(2024, 5, 5), DateTime(2024, 5, 10)), // Late
        _createExpectedFlow('inv-1', DateTime(2024, 4, 5), DateTime(2024, 4, 10)), // Late
        _createExpectedFlow('inv-1', DateTime(2024, 3, 5), DateTime(2024, 3, 10)), // Late
      ];

      final report = await analyzer.generateReport(investments: investments,
        cashFlows: [],
        expectedCashFlows: expectedCashFlows,
        engine: engine,
        baseCurrency: 'USD',
      );

      expect(report.insights.any((i) => i.contains('frequently late')), true);
    });
  });
}

/// Helper to create expected cash flow
ExpectedCashFlowEntity _createExpectedFlow(
  String investmentId,
  DateTime expectedDate,
  DateTime? actualDate,
) {
  return ExpectedCashFlowEntity(
    id: 'ecf-${expectedDate.millisecondsSinceEpoch}-$investmentId',
    investmentId: investmentId,
    expectedDate: expectedDate,
    expectedAmount: 1000,
    currency: 'USD',
    predictionSource: PredictionSource.wma,
    status: actualDate != null
      ? ExpectedCashFlowStatus.received
      : ExpectedCashFlowStatus.upcoming,
    actualDate: actualDate,
    actualAmount: actualDate != null ? 1000 : null,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

/// Helper to create test investment
InvestmentEntity _createInvestment(String id, {String name = 'Test Investment', String? platform}) {
  return InvestmentEntity(
    id: id,
    name: name,
    type: InvestmentType.p2pLending,
    status: InvestmentStatus.open,
    currency: 'USD',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    platform: platform,
  );
}

/// Helper to create income cash flow
CashFlowEntity _createIncome(double amount, DateTime date, String investmentId) {
  return CashFlowEntity(
    id: 'cf-${date.millisecondsSinceEpoch}-$investmentId',
    investmentId: investmentId,
    amount: amount,
    currency: 'USD',
    type: CashFlowType.income,
    date: date,
    createdAt: DateTime.now(),
  );
}

/// Helper to create monthly income series
List<CashFlowEntity> _createMonthlyIncome({
  required String investmentId,
  required DateTime startMonth,
  required int count,
  required List<double> amounts,
}) {
  final cashFlows = <CashFlowEntity>[];
  for (int i = 0; i < count && i < amounts.length; i++) {
    final date = DateTime(
      startMonth.year,
      startMonth.month + (count - 1 - i),
      1,
    );
    cashFlows.add(_createIncome(amounts[i], date, investmentId));
  }
  return cashFlows.reversed.toList();
}

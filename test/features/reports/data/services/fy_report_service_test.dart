import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/core/calculations/modules/currency_module.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/reports/data/services/fy_report_service.dart';

void main() {
  group('FYReportService', () {
    late FYReportService service;
    const int fyYear = 2023; // FY 2023-24 (Apr 1, 2023 - Mar 31, 2024)

    setUp(() {
      final engine = CalculationEngine()
        ..registerModule(CurrencyConverterModule(null))
        ..registerModule(FinancialCalculatorModule());
      service = FYReportService(engine);
    });

    test('should calculate FY totals correctly', () async {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 10000,
          date: DateTime(2023, 5, 1), // Within FY
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2023, 5, 1),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          amount: 500,
          date: DateTime(2023, 6, 1),
          type: CashFlowType.income,
          notes: 'Dividend',
          currency: 'USD',
          createdAt: DateTime(2023, 6, 1),
        ),
        CashFlowEntity(
          id: '3',
          investmentId: 'inv1',
          amount: 11000,
          date: DateTime(2024, 3, 15),
          type: CashFlowType.returnFlow,
          currency: 'USD',
          createdAt: DateTime(2024, 3, 15),
        ),
        CashFlowEntity(
          id: '4',
          investmentId: 'inv1',
          amount: 100,
          date: DateTime(2023, 7, 1),
          type: CashFlowType.fee,
          currency: 'USD',
          createdAt: DateTime(2023, 7, 1),
        ),
      ];

      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Test Investment',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 5, 1),
          createdAt: DateTime(2023, 5, 1),
          updatedAt: DateTime(2023, 5, 1),
          currency: 'USD',
        ),
      ];

      final report = await service.generateReport(
        fyYear: fyYear,
        allCashFlows: cashFlows,
        allInvestments: investments,
        baseCurrency: 'USD',
      );

      expect(report.totalInvested, 10000.0);
      expect(report.totalIncome, 500.0);
      expect(report.totalReturns, 11000.0);
      expect(report.totalFees, 100.0);
      expect(report.netCashFlow, 1400.0); // (500 + 11000) - (10000 + 100)
      expect(report.fyLabel, '2023-24');
    });

    test('should filter out cashflows outside FY period', () async {
      final cashFlows = [
        // Before FY start (Mar 30, 2023 - should be excluded)
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 1000,
          date: DateTime(2023, 3, 30),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2023, 3, 30),
        ),
        // Within FY (May 1, 2023)
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          amount: 2000,
          date: DateTime(2023, 5, 1),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2023, 5, 1),
        ),
        // After FY end (Apr 2, 2024 - should be excluded)
        CashFlowEntity(
          id: '3',
          investmentId: 'inv1',
          amount: 3000,
          date: DateTime(2024, 4, 2),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2024, 4, 2),
        ),
      ];

      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Test Investment',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
      ];

      final report = await service.generateReport(
        fyYear: fyYear,
        allCashFlows: cashFlows,
        allInvestments: investments,
        baseCurrency: 'USD',
      );

      expect(report.totalInvested, 2000.0); // Only May 1 transaction included
    });

    test('should categorize dividend and interest income', () async {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 500,
          date: DateTime(2023, 6, 1),
          type: CashFlowType.income,
          notes: 'Dividend payment',
          currency: 'USD',
          createdAt: DateTime(2023, 6, 1),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv2',
          amount: 300,
          date: DateTime(2023, 7, 1),
          type: CashFlowType.income,
          notes: 'Interest earned',
          currency: 'USD',
          createdAt: DateTime(2023, 7, 1),
        ),
      ];

      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Stock A',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv2',
          name: 'FD B',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
      ];

      final report = await service.generateReport(
        fyYear: fyYear,
        allCashFlows: cashFlows,
        allInvestments: investments,
        baseCurrency: 'USD',
      );

      expect(report.totalIncome, 800.0);
      expect(report.dividendIncome, 500.0);
      expect(report.interestIncome, 300.0);
    });

    test('should handle empty data', () async {
      final report = await service.generateReport(
        fyYear: fyYear,
        allCashFlows: [],
        allInvestments: [],
        baseCurrency: 'USD',
      );

      expect(report.totalInvested, 0.0);
      expect(report.totalIncome, 0.0);
      expect(report.totalReturns, 0.0);
      expect(report.totalFees, 0.0);
      expect(report.netCashFlow, 0.0);
      expect(report.dividendIncome, 0.0);
      expect(report.interestIncome, 0.0);
    });

    test('should calculate correct FY start and end dates', () async {
      final report = await service.generateReport(
        fyYear: fyYear,
        allCashFlows: [],
        allInvestments: [],
        baseCurrency: 'USD',
      );

      expect(report.fyStart.year, 2023);
      expect(report.fyStart.month, 4);
      expect(report.fyStart.day, 1);

      expect(report.fyEnd.year, 2024);
      expect(report.fyEnd.month, 3);
      expect(report.fyEnd.day, 31);
    });

    test('should generate monthly breakdown with 12 months', () async {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 1000,
          date: DateTime(2023, 4, 15),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2023, 4, 15),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          amount: 2000,
          date: DateTime(2023, 12, 20),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2023, 12, 20),
        ),
      ];

      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Test Investment',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
      ];

      final report = await service.generateReport(
        fyYear: fyYear,
        allCashFlows: cashFlows,
        allInvestments: investments,
        baseCurrency: 'USD',
      );

      expect(report.monthlyBreakdown.length, 12); // All 12 months of FY
    });

    test('should apply currency conversion correctly for multi-currency portfolios', () async {
      // 1 EUR = 1.2 USD, 1 USD = 80 INR
      final mockService = MockCurrencyConversionService({
        'EUR_USD': 1.2,
        'USD_EUR': 1 / 1.2,
        'EUR_INR': 96.0,
        'USD_INR': 80.0,
      });

      final multiCurrencyEngine = CalculationEngine()
        ..registerModule(CurrencyConverterModule(mockService))
        ..registerModule(FinancialCalculatorModule());

      final serviceWithConversion = FYReportService(multiCurrencyEngine);

      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv-eur',
          amount: 1000, // 1000 EUR
          date: DateTime(2023, 5, 1),
          type: CashFlowType.invest,
          currency: 'EUR',
          createdAt: DateTime(2023, 5, 1),
        ),
      ];

      final investments = [
        InvestmentEntity(
          id: 'inv-eur',
          name: 'EUR Stock',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 5, 1),
          createdAt: DateTime(2023, 5, 1),
          updatedAt: DateTime(2023, 5, 1),
          currency: 'EUR',
        ),
      ];

      // Generate report with baseCurrency USD -> 1000 EUR becomes 1200 USD
      final reportUSD = await serviceWithConversion.generateReport(
        fyYear: fyYear,
        allCashFlows: cashFlows,
        allInvestments: investments,
        baseCurrency: 'USD',
      );

      // Generate report with baseCurrency INR -> 1000 EUR becomes 96000 INR
      final reportINR = await serviceWithConversion.generateReport(
        fyYear: fyYear,
        allCashFlows: cashFlows,
        allInvestments: investments,
        baseCurrency: 'INR',
      );

      expect(reportUSD.totalInvested, 1200.0);
      expect(reportINR.totalInvested, 96000.0);
      expect(reportUSD.totalInvested, isNot(equals(reportINR.totalInvested)));
    });
  });
}

class MockCurrencyConversionService implements CurrencyConversionService {
  final Map<String, double> rates;

  MockCurrencyConversionService(this.rates);

  @override
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async {
    if (from == to) return amount;
    final key = '${from}_$to';
    final rate = rates[key];
    if (rate == null) {
      throw CurrencyConversionException('Rate not found');
    }
    return amount * rate;
  }

  @override
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async {
    if (from == to) return 1.0;
    return rates['${from}_$to'];
  }

  @override
  Future<double> getHistoricalRate(DateTime date, String from, String to) async {
    return convert(amount: 1.0, from: from, to: to);
  }

  @override
  Future<double> getLiveRate(String from, String to) async {
    return convert(amount: 1.0, from: from, to: to);
  }

  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async {
    final Map<String, double> results = {};
    for (final entry in requests.entries) {
      final key = entry.key;
      final req = entry.value;
      final rate = rates['${req.from}_$to'];
      if (rate == null) {
        throw CurrencyConversionException('Rate not found for ${req.from}');
      }
      results[key] = rate;
    }
    return results;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

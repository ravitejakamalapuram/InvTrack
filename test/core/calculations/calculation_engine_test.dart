import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/core/calculations/modules/currency_module.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/calculations/modules/portfolio_health_module.dart';
import 'package:inv_tracker/core/calculations/modules/projection_module.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

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

void main() {
  group('CalculationEngine & Modules - Exhaustive Math Validation', () {
    late CalculationEngine identityEngine;
    late CalculationEngine conversionEngine;
    late MockCurrencyConversionService mockService;

    setUp(() {
      identityEngine = CalculationEngine();
      identityEngine.registerModule(CurrencyConverterModule(null));
      identityEngine.registerModule(FinancialCalculatorModule());
      identityEngine.registerModule(ProjectionCalculatorModule());
      identityEngine.registerModule(PortfolioHealthModule(identityEngine));

      mockService = MockCurrencyConversionService({
        'USD_INR': 80.0,
        'INR_USD': 0.0125,
        'EUR_INR': 90.0,
      });
      conversionEngine = CalculationEngine();
      conversionEngine.registerModule(CurrencyConverterModule(mockService));
      conversionEngine.registerModule(FinancialCalculatorModule());
      conversionEngine.registerModule(ProjectionCalculatorModule());
      conversionEngine.registerModule(PortfolioHealthModule(conversionEngine));
    });

    group('Core Facade Registry', () {
      test('should retrieve modules and verify types', () {
        expect(identityEngine.financial, isA<FinancialCalculatorModule>());
        expect(identityEngine.projection, isA<ProjectionCalculatorModule>());
        expect(identityEngine.currency, isA<CurrencyConverterModule>());
        expect(identityEngine.health, isA<PortfolioHealthModule>());
      });

      test('throws StateError for unregistered modules', () {
        final incompleteEngine = CalculationEngine();
        expect(() => incompleteEngine.financial, throwsStateError);
      });
    });

    group('FinancialCalculatorModule - Advanced returns & edge cases', () {
      test('CAGR, MOIC, absolute return standard values', () {
        final f = identityEngine.financial;
        expect(f.calculateCAGR(1000, 2000, 5), closeTo(0.1487, 0.0001));
        expect(f.calculateMOIC(1000, 2500), 2.5);
        expect(f.calculateAbsoluteReturn(1000, 1500), 50.0);
        expect(f.calculateNetCashFlow(1000, 1500), 500.0);
      });

      test('protects against division-by-zero on zero principal/invested inputs', () {
        final f = identityEngine.financial;
        expect(f.calculateCAGR(0, 100, 5), 0.0);
        expect(f.calculateMOIC(0, 100), 0.0);
        expect(f.calculateAbsoluteReturn(0, 100), 0.0);
      });

      test('calculateXirr resolves standard returns', () {
        final dates = [DateTime(2023, 1, 1), DateTime(2024, 1, 1)];
        final amounts = [-1000.0, 1100.0];
        expect(identityEngine.financial.calculateXirr(dates, amounts), closeTo(0.10, 0.0001));
      });

      test('calculateStats with empty cash flows returns empty metrics object', () {
        final stats = identityEngine.financial.calculateStats([]);
        expect(stats.totalInvested, 0.0);
        expect(stats.totalReturned, 0.0);
        expect(stats.netCashFlow, 0.0);
        expect(stats.absoluteReturn, 0.0);
        expect(stats.moic, 0.0);
        expect(stats.xirr, 0.0);
      });

      test('calculateStats skips XIRR calculation when includeXirr is false', () {
        final cashFlows = [
          CashFlowEntity(
            id: '1',
            investmentId: 'test',
            date: DateTime(2023, 1, 1),
            type: CashFlowType.invest,
            amount: 1000.0,
            createdAt: DateTime.now(),
          ),
          CashFlowEntity(
            id: '2',
            investmentId: 'test',
            date: DateTime(2024, 1, 1),
            type: CashFlowType.returnFlow,
            amount: 1200.0,
            createdAt: DateTime.now(),
          ),
        ];

        final stats = identityEngine.financial.calculateStats(cashFlows, includeXirr: false);
        expect(stats.totalInvested, 1000.0);
        expect(stats.totalReturned, 1200.0);
        expect(stats.netCashFlow, 200.0);
        expect(stats.xirr, 0.0); // skipped!
      });
    });

    group('ProjectionCalculatorModule - Compound math & dates', () {
      test('nominal rate to Effective Annual Rate (EAR) under various compounding options', () {
        final p = identityEngine.projection;

        // Simple Interest -> nominal = EAR
        expect(p.calculateEffectiveAnnualRate(nominalRate: 12.0, compounding: CompoundingFrequency.none), closeTo(12.0, 0.0001));

        // Daily compounding -> (1 + 0.12/365)^365 - 1 = ~12.747%
        expect(p.calculateEffectiveAnnualRate(nominalRate: 12.0, compounding: CompoundingFrequency.daily), closeTo(12.747, 0.01));

        // Quarterly compounding -> (1 + 0.12/4)^4 - 1 = ~12.55%
        expect(p.calculateEffectiveAnnualRate(nominalRate: 12.0, compounding: CompoundingFrequency.quarterly), closeTo(12.55, 0.01));

        // Annual compounding -> 12%
        expect(p.calculateEffectiveAnnualRate(nominalRate: 12.0, compounding: CompoundingFrequency.annual), closeTo(12.0, 0.0001));
      });

      test('maturity value for compounding vs simple interest over multi-year periods', () {
        final p = identityEngine.projection;

        // Simple interest: 1000 principal, 10% rate, 36 months (3 years) -> 1300
        expect(
          p.calculateMaturityValue(principal: 1000, annualRate: 10, tenureMonths: 36, compounding: CompoundingFrequency.none),
          1300.0,
        );

        // Annual compound interest: 1000 principal, 10% rate, 36 months (3 years) -> 1000 * 1.1^3 = 1331
        expect(
          p.calculateMaturityValue(principal: 1000, annualRate: 10, tenureMonths: 36, compounding: CompoundingFrequency.annual),
          closeTo(1331.0, 0.001),
        );
      });

      test('maturity date boundary conditions including leap years and month lengths', () {
        final p = identityEngine.projection;

        // Leap year boundary: Feb 28, 2024 (leap year) + 24 months -> Feb 28, 2026
        final startLeap = DateTime(2024, 2, 28);
        expect(p.calculateMaturityDate(startDate: startLeap, tenureMonths: 24), DateTime(2026, 2, 28));

        // Month boundary capping: Jan 31, 2024 + 1 month -> Feb 29, 2024 (since 2024 is a leap year)
        final startJan31 = DateTime(2024, 1, 31);
        expect(p.calculateMaturityDate(startDate: startJan31, tenureMonths: 1), DateTime(2024, 2, 29));

        // Month boundary capping: Jan 31, 2023 + 1 month -> Feb 28, 2023 (non-leap year)
        final startJan31NonLeap = DateTime(2023, 1, 31);
        expect(p.calculateMaturityDate(startDate: startJan31NonLeap, tenureMonths: 1), DateTime(2023, 2, 28));
      });
    });

    group('CurrencyConverterModule - Multi-currency stubs and strategies', () {
      test('live conversion with mock rates', () async {
        final c = conversionEngine.currency;
        expect(c.isAvailable, isTrue);

        final converted = await c.convert(amount: 100.0, from: 'USD', to: 'INR');
        expect(converted, 8000.0);
      });

      test('batch conversion of cash flows with mock rates', () async {
        final c = conversionEngine.currency;
        final cashFlows = [
          CashFlowEntity(
            id: 'cf-1',
            investmentId: 'inv-1',
            date: DateTime(2023, 1, 1),
            type: CashFlowType.invest,
            amount: 100.0,
            currency: 'USD',
            createdAt: DateTime.now(),
          ),
          CashFlowEntity(
            id: 'cf-2',
            investmentId: 'inv-1',
            date: DateTime(2023, 1, 1),
            type: CashFlowType.returnFlow,
            amount: 50.0,
            currency: 'EUR',
            createdAt: DateTime.now(),
          ),
        ];

        final convertedList = await c.batchConvert(cashFlows: cashFlows, baseCurrency: 'INR');
        expect(convertedList[0].amount, 8000.0);
        expect(convertedList[0].currency, 'INR');
        expect(convertedList[1].amount, 4500.0);
        expect(convertedList[1].currency, 'INR');
      });

      test('fallback strategy application on conversion failure', () async {
        final c = conversionEngine.currency;

        // Strategy: throwError should raise exception when currency conversion service fails to find conversion rates
        expect(
          () => c.convert(amount: 100.0, from: 'GBP', to: 'INR', fallbackStrategy: ConversionFallbackStrategy.throwError),
          throwsException,
        );

        // Strategy: useOriginal should keep the original amount and currency
        final original = await c.convert(amount: 100.0, from: 'GBP', to: 'INR', fallbackStrategy: ConversionFallbackStrategy.useOriginal);
        expect(original, 100.0);
      });
    });

    group('PortfolioHealthModule - Multi-currency weighting math', () {
      test('converts stats to base currency before computing score values', () async {
        final List<InvestmentEntity> investments = [
          InvestmentEntity(
            id: 'inv-usd',
            name: 'US Tech',
            type: InvestmentType.stocks,
            status: InvestmentStatus.open,
            currency: 'USD',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          InvestmentEntity(
            id: 'inv-inr',
            name: 'Local FD',
            type: InvestmentType.fixedDeposit,
            status: InvestmentStatus.open,
            currency: 'INR',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Raw stats are defined in original currencies
        final statsMap = {
          'inv-usd': const InvestmentStats(
            totalInvested: 100.0, // USD
            totalReturned: 110.0, // USD
            netCashFlow: 10.0,
            absoluteReturn: 10.0,
            moic: 1.1,
            xirr: 0.10,
            cashFlowCount: 2,
          ),
          'inv-inr': const InvestmentStats(
            totalInvested: 8000.0, // INR
            totalReturned: 8800.0, // INR
            netCashFlow: 800.0,
            absoluteReturn: 10.0,
            moic: 1.1,
            xirr: 0.10,
            cashFlowCount: 2,
          ),
        };

        // When baseCurrency is 'INR', USD stats should be converted to INR.
        // 100 USD becomes 8000 INR.
        // Portfolio will have equal weights: 8000 INR (Tech) and 8000 INR (FD).
        final score = await conversionEngine.health.calculate(
          investments: investments,
          investmentStats: statsMap,
          allCashFlows: const [],
          goalProgress: const [],
          baseCurrency: 'INR',
        );

        // Overall score should resolve successfully and both return/diversification must be positive
        expect(score.overallScore, greaterThan(0));
        expect(score.overallScore, lessThanOrEqualTo(100));
        expect(score.diversification.score, greaterThan(0)); // diversified!
      });
    });
  });
}

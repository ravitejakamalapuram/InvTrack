import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/income_projection/data/services/smart_amount_predictor.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

void main() {
  late SmartAmountPredictor predictor;

  setUp(() {
    predictor = SmartAmountPredictor();
  });

  group('SmartAmountPredictor - WMA Prediction', () {
    test('should return fixed amount (0.0) when fewer than 3 payments', () {
      final investment = _createTestInvestment();
      final cashFlows = [
        _createCashFlow(1000, DateTime(2024, 1, 1)),
        _createCashFlow(1020, DateTime(2024, 2, 1)),
      ];

      final result = predictor.predictAmount(
        investment: investment,
        historicalIncome: cashFlows,
        expectedDate: DateTime(2024, 3, 1),
      );

      expect(result.predictedAmount, 0.0);
      expect(result.varianceFactor, 0.0);
      expect(result.platformDelayDays, 0);
    });

    test('should calculate WMA with 3 payments (weights: 30%, 25%, 20%)', () {
      final investment = _createTestInvestment();
      final cashFlows = [
        _createCashFlow(1000, DateTime(2024, 3, 1)), // Most recent: 30%
        _createCashFlow(1100, DateTime(2024, 2, 1)), // 25%
        _createCashFlow(1200, DateTime(2024, 1, 1)), // 20%
      ];

      final result = predictor.predictAmount(
        investment: investment,
        historicalIncome: cashFlows,
        expectedDate: DateTime(2024, 4, 1),
      );

      // WMA = (1000*0.30 + 1100*0.25 + 1200*0.20) / (0.30+0.25+0.20)
      //     = (300 + 275 + 240) / 0.75 = 815 / 0.75 = 1086.67
      expect(result.predictedAmount, closeTo(1086.67, 1.0));
    });

    test('should calculate WMA with 6+ payments (all weights used)', () {
      final investment = _createTestInvestment();
      final cashFlows = [
        _createCashFlow(1000, DateTime(2024, 6, 1)), // 30%
        _createCashFlow(1020, DateTime(2024, 5, 1)), // 25%
        _createCashFlow(1010, DateTime(2024, 4, 1)), // 20%
        _createCashFlow(1030, DateTime(2024, 3, 1)), // 15%
        _createCashFlow(1015, DateTime(2024, 2, 1)), // 7%
        _createCashFlow(1025, DateTime(2024, 1, 1)), // 3%
        _createCashFlow(1005, DateTime(2023, 12, 1)), // Ignored (only last 6)
      ];

      final result = predictor.predictAmount(
        investment: investment,
        historicalIncome: cashFlows,
        expectedDate: DateTime(2024, 7, 1),
      );

      // WMA = (1000*0.30 + 1020*0.25 + 1010*0.20 + 1030*0.15 + 1015*0.07 + 1025*0.03)
      //     = (300 + 255 + 202 + 154.5 + 71.05 + 30.75) = 1013.3
      expect(result.predictedAmount, closeTo(1013.3, 1.0));
    });

    test('should filter only income transactions', () {
      final investment = _createTestInvestment();
      final cashFlows = [
        _createCashFlow(1000, DateTime(2024, 3, 1), type: CashFlowType.income),
        _createCashFlow(5000, DateTime(2024, 2, 15), type: CashFlowType.invest), // Ignored
        _createCashFlow(1100, DateTime(2024, 2, 1), type: CashFlowType.income),
        _createCashFlow(100, DateTime(2024, 1, 20), type: CashFlowType.fee), // Ignored
        _createCashFlow(1200, DateTime(2024, 1, 1), type: CashFlowType.income),
      ];

      final result = predictor.predictAmount(
        investment: investment,
        historicalIncome: cashFlows,
        expectedDate: DateTime(2024, 4, 1),
      );

      // Should only use the 3 income payments (1000, 1100, 1200)
      expect(result.predictedAmount, closeTo(1086.67, 1.0));
    });
  });

  group('SmartAmountPredictor - Variance Calculation', () {
    test('should calculate low variance for stable payments', () {
      final investment = _createTestInvestment();
      final cashFlows = [
        _createCashFlow(1000, DateTime(2024, 6, 1)),
        _createCashFlow(1020, DateTime(2024, 5, 1)), // +2%
        _createCashFlow(1010, DateTime(2024, 4, 1)), // -1%
        _createCashFlow(1030, DateTime(2024, 3, 1)), // +2%
      ];

      final result = predictor.predictAmount(
        investment: investment,
        historicalIncome: cashFlows,
        expectedDate: DateTime(2024, 7, 1),
      );

      // Variance should be low (<15% coefficient of variation)
      expect(result.varianceFactor, lessThan(0.15));
    });

    test('should calculate high variance for volatile payments', () {
      final investment = _createTestInvestment();
      final cashFlows = [
        _createCashFlow(850, DateTime(2024, 6, 1)), // -15%
        _createCashFlow(1150, DateTime(2024, 5, 1)), // +15%
        _createCashFlow(900, DateTime(2024, 4, 1)), // -10%
        _createCashFlow(1100, DateTime(2024, 3, 1)), // +10%
      ];

      final result = predictor.predictAmount(
        investment: investment,
        historicalIncome: cashFlows,
        expectedDate: DateTime(2024, 7, 1),
      );

      // Variance should be high (>10%)
      expect(result.varianceFactor, greaterThan(0.10));
    });
  });

  group('SmartAmountPredictor - Platform Delay Learning', () {
    test('should return 0 delay when no frequency data', () {
      final investment = _createTestInvestment(frequency: null);
      final cashFlows = [
        _createCashFlow(1000, DateTime(2024, 6, 1)),
        _createCashFlow(1000, DateTime(2024, 5, 1)),
        _createCashFlow(1000, DateTime(2024, 4, 1)),
        _createCashFlow(1000, DateTime(2024, 3, 1)),
      ];

      final result = predictor.predictAmount(
        investment: investment,
        historicalIncome: cashFlows,
        expectedDate: DateTime(2024, 7, 1),
      );

      expect(result.platformDelayDays, 0);
    });

    test('should return 0 delay when fewer than 4 payments', () {
      final investment = _createTestInvestment();
      final cashFlows = [
        _createCashFlow(1000, DateTime(2024, 3, 1)),
        _createCashFlow(1000, DateTime(2024, 2, 1)),
        _createCashFlow(1000, DateTime(2024, 1, 1)),
      ];

      final result = predictor.predictAmount(
        investment: investment,
        historicalIncome: cashFlows,
        expectedDate: DateTime(2024, 4, 1),
      );

      expect(result.platformDelayDays, 0);
    });

    test('should learn consistent +2 day platform delay', () {
      final investment = _createTestInvestment();
      final cashFlows = [
        _createCashFlow(1000, DateTime(2024, 6, 7)), // Expected 5th, actual 7th (+2)
        _createCashFlow(1000, DateTime(2024, 5, 7)), // Expected 5th, actual 7th (+2)
        _createCashFlow(1000, DateTime(2024, 4, 7)), // Expected 5th, actual 7th (+2)
        _createCashFlow(1000, DateTime(2024, 3, 7)), // Expected 5th, actual 7th (+2)
        _createCashFlow(1000, DateTime(2024, 2, 5)), // Baseline
      ];

      final result = predictor.predictAmount(
        investment: investment,
        historicalIncome: cashFlows,
        expectedDate: DateTime(2024, 7, 5),
      );

      // Should detect consistent +2 day delay
      expect(result.platformDelayDays, 2);
    });
  });

  group('SmartAmountPredictor - Seasonal Adjustment', () {
    test('should not apply seasonal bonus when not in Q4', () {
      final investment = _createTestInvestment();
      final cashFlows = [
        _createCashFlow(1000, DateTime(2024, 6, 1)),
        _createCashFlow(1000, DateTime(2024, 5, 1)),
        _createCashFlow(1000, DateTime(2024, 4, 1)),
      ];

      final result = predictor.predictAmount(
        investment: investment,
        historicalIncome: cashFlows,
        expectedDate: DateTime(2024, 7, 1), // July (not Q4)
      );

      expect(result.isSeasonalBonus, false);
    });

    test('should not apply seasonal bonus when insufficient data', () {
      final investment = _createTestInvestment();
      final cashFlows = [
        _createCashFlow(1200, DateTime(2024, 11, 1)), // Q4
        _createCashFlow(1000, DateTime(2024, 10, 1)), // Q4
        _createCashFlow(1000, DateTime(2024, 9, 1)),
        _createCashFlow(1000, DateTime(2024, 8, 1)),
      ];

      final result = predictor.predictAmount(
        investment: investment,
        historicalIncome: cashFlows,
        expectedDate: DateTime(2024, 12, 1), // Q4
      );

      // Need at least 8 payments for seasonal detection
      expect(result.isSeasonalBonus, false);
    });
  });

  group('SmartAmountPredictor - predictAmountSimple', () {
    test('should return predicted amount without full result object', () {
      final investment = _createTestInvestment();
      final cashFlows = [
        _createCashFlow(1000, DateTime(2024, 3, 1)),
        _createCashFlow(1100, DateTime(2024, 2, 1)),
        _createCashFlow(1200, DateTime(2024, 1, 1)),
      ];

      final amount = predictor.predictAmountSimple(
        investment: investment,
        historicalIncome: cashFlows,
        expectedDate: DateTime(2024, 4, 1),
      );

      expect(amount, closeTo(1086.67, 1.0));
    });
  });
}

/// Helper to create test investment
InvestmentEntity _createTestInvestment({IncomeFrequency? frequency = IncomeFrequency.monthly}) {
  return InvestmentEntity(
    id: 'test-inv',
    name: 'Test Investment',
    type: InvestmentType.p2pLending,
    status: InvestmentStatus.open,
    currency: 'USD',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    incomeFrequency: frequency,
  );
}

/// Helper to create test cash flow
CashFlowEntity _createCashFlow(
  double amount,
  DateTime date, {
  CashFlowType type = CashFlowType.income,
}) {
  return CashFlowEntity(
    id: 'cf-${date.millisecondsSinceEpoch}',
    investmentId: 'test-inv',
    amount: amount,
    currency: 'USD',
    type: type,
    date: date,
    createdAt: DateTime.now(),
  );
}

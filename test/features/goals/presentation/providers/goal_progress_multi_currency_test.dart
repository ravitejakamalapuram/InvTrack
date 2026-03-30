import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

import '../../../../mocks/mock_currency_conversion_service.dart';

/// **Multi-Currency Goal Progress Tests (TDD)**
///
/// **Rule 21.3 Compliance:** Goal progress % MUST remain stable when base currency changes.
/// Only display currency should change, not the underlying percentage.
///
/// **Bug Report (FIXED):**
/// - Goal % was changing when switching from USD to EUR
/// - FIRE progress % was changing when switching currencies
/// - Root cause: `goalProgressListProvider` converted cash flows but NOT goal target amount
/// - Fix: Normalize both sides of the ratio (cash flows AND target amount) to base currency
///
/// **Expected Behavior:**
/// - Progress % calculated in base currency should be currency-invariant
/// - Switching USD → EUR → INR should give same % (within rounding error)
/// - Only display amounts change, not progress percentage
void main() {
  group('Multi-Currency Goal Progress - TDD Tests', () {
    late MockCurrencyConversionService mockConversionService;
    late BatchCurrencyConverter batchConverter;

    setUp(() {
      mockConversionService = MockCurrencyConversionService();
      batchConverter = BatchCurrencyConverter(mockConversionService);
    });

    /// **Scenario:** US investment (USD) with returns toward a \$10,000 goal
    /// - Invested: \$5,000, Returns: \$2,500 → Net: \$2,500 progress (25%)
    /// - Base currency switches: USD → EUR → INR
    /// - Expected: Progress stays 25% regardless of display currency
    ///
    /// **This test demonstrates multi-currency compliance:**
    /// - calculateMultiCurrency should give same % regardless of baseCurrency
    /// - Only display amounts should change, not the percentage
    test('calculateMultiCurrency: goal progress % remains stable when base currency changes', () async {
      // Arrange: Create goal and investment in USD
      final goal = GoalEntity(
        id: 'goal1',
        name: 'Emergency Fund',
        type: GoalType.targetAmount,
        targetAmount: 10000, // \$10,000 target
        trackingMode: GoalTrackingMode.selected,
        linkedInvestmentIds: ['inv1'],
        icon: '💰',
        colorValue: 0xFF3B82F6,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        currency: 'USD',
      );

      final investment = InvestmentEntity(
        id: 'inv1',
        name: 'US Stocks',
        type: InvestmentType.stocks,
        status: InvestmentStatus.open,
        currency: 'USD',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final cashFlows = [
        CashFlowEntity(
          id: 'cf1',
          investmentId: 'inv1',
          type: CashFlowType.invest,
          amount: 5000, // \$5,000 invested
          currency: 'USD',
          date: DateTime(2024, 1, 1),
          createdAt: DateTime(2024, 1, 1),
        ),
        CashFlowEntity(
          id: 'cf2',
          investmentId: 'inv1',
          type: CashFlowType.returnFlow,
          amount: 2500, // \$2,500 returns
          currency: 'USD',
          date: DateTime(2024, 6, 1),
          createdAt: DateTime(2024, 6, 1),
        ),
      ];

      // Act: Calculate progress with different base currencies
      final progressUSD = await GoalProgressCalculator.calculateMultiCurrency(
        goal: goal,
        allInvestments: [investment],
        allCashFlows: cashFlows,
        batchConverter: batchConverter,
        baseCurrency: 'USD',
      );

      final progressEUR = await GoalProgressCalculator.calculateMultiCurrency(
        goal: goal,
        allInvestments: [investment],
        allCashFlows: cashFlows,
        batchConverter: batchConverter,
        baseCurrency: 'EUR',
      );

      final progressINR = await GoalProgressCalculator.calculateMultiCurrency(
        goal: goal,
        allInvestments: [investment],
        allCashFlows: cashFlows,
        batchConverter: batchConverter,
        baseCurrency: 'INR',
      );

      // Assert: Progress % should be same (25%) in all currencies
      // Net value = \$2,500 (returns) / \$10,000 (target) = 25%
      expect(progressUSD.progressPercent, closeTo(25.0, 0.1),
          reason: 'USD: \$2,500 / \$10,000 = 25%');
      expect(progressEUR.progressPercent, closeTo(25.0, 0.1),
          reason: 'EUR: Should still be 25% (€2,300 / €9,200 ≈ 25%)');
      expect(progressINR.progressPercent, closeTo(25.0, 0.1),
          reason: 'INR: Should still be 25% (₹207,800 / ₹831,200 ≈ 25%)');

      // Verify current amounts ARE different (correct currency conversion)
      // USD: \$2,500
      // EUR: \$2,500 * 83 / 90 = €2,305.56 (USD → INR → EUR)
      // INR: \$2,500 * 83 = ₹207,500
      expect(progressUSD.currentAmount, closeTo(2500, 1));
      expect(progressEUR.currentAmount, closeTo(2305.56, 10)); // Allow tolerance for conversion
      expect(progressINR.currentAmount, closeTo(207500, 100));
    });

  });
}



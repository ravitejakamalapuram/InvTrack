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

      // Verify original data unchanged after currency conversions (Rule 21.3)
      // Goal entity MUST remain immutable
      expect(goal.currency, equals('USD'),
          reason: 'Goal currency must not change after base currency conversion');
      expect(goal.targetAmount, equals(10000),
          reason: 'Goal target amount must not change after conversion');

      // CashFlow entities MUST remain immutable
      expect(cashFlows[0].currency, equals('USD'),
          reason: 'CashFlow[0] currency must not change after conversion');
      expect(cashFlows[0].amount, equals(5000),
          reason: 'CashFlow[0] amount must not change after conversion');
      expect(cashFlows[1].currency, equals('USD'),
          reason: 'CashFlow[1] currency must not change after conversion');
      expect(cashFlows[1].amount, equals(2500),
          reason: 'CashFlow[1] amount must not change after conversion');

      // Investment entity MUST remain immutable
      expect(investment.currency, equals('USD'),
          reason: 'Investment currency must not change after conversion');
    });

    /// **REGRESSION TEST for Multi-Currency Percentage Bug (PR #311)**
    ///
    /// **Scenario:** Goal with currency matching cash flows (INR),
    /// displayed in different base currencies (INR vs USD).
    ///
    /// **Bug (Fixed in #311):** Progress % changed when switching display currency
    /// because targetAmount was not converted to baseCurrency.
    ///
    /// **Expected:** Progress % remains stable (~6%) regardless of display currency.
    /// This is Rule 21.3: Both amounts must be in same currency before ratio calc.
    test('REGRESSION: goal progress % stable across currency switches (Rule 21.3)', () async {
      // Arrange: Create goal WITH currency field matching cash flows (correct data)
      final goal = GoalEntity(
        id: 'goal1',
        name: '₹50K Monthly Income',
        type: GoalType.incomeTarget,
        targetAmount: 600000, // ₹6L annual
        targetMonthlyIncome: 50000, // ₹50K/month
        trackingMode: GoalTrackingMode.byType,
        linkedTypes: [InvestmentType.fixedDeposit],
        icon: '💰',
        colorValue: 0xFFFBBF24,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        currency: 'INR', // ✅ Matches cash flow currency for correct percentages
      );

      // Cash flows are in INR (realistic production scenario)
      final investment = InvestmentEntity(
        id: 'inv1',
        name: 'HDFC FD',
        type: InvestmentType.fixedDeposit,
        status: InvestmentStatus.open,
        currency: 'INR',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final cashFlows = [
        CashFlowEntity(
          id: 'cf1',
          investmentId: 'inv1',
          type: CashFlowType.invest,
          amount: 500000, // ₹5L invested
          currency: 'INR',
          date: DateTime(2024, 1, 1),
          createdAt: DateTime(2024, 1, 1),
        ),
        // Quarterly income payments (₹9,063 × 4 = ₹36,252/year)
        ...List.generate(4, (i) => CashFlowEntity(
          id: 'cf-income-$i',
          investmentId: 'inv1',
          type: CashFlowType.income,
          amount: 9063, // ₹9,063 quarterly
          currency: 'INR',
          date: DateTime(2024, 1 + i * 3, 1),
          createdAt: DateTime(2024, 1 + i * 3, 1),
        )),
      ];

      // Act: Calculate with base currency = INR (user's preference)
      final progressINR = await GoalProgressCalculator.calculateMultiCurrency(
        goal: goal,
        allInvestments: [investment],
        allCashFlows: cashFlows,
        batchConverter: batchConverter,
        baseCurrency: 'INR',
      );

      // Act: Calculate with base currency = USD (currency switch)
      final progressUSD = await GoalProgressCalculator.calculateMultiCurrency(
        goal: goal,
        allInvestments: [investment],
        allCashFlows: cashFlows,
        batchConverter: batchConverter,
        baseCurrency: 'USD',
      );

      // Assert: Monthly income is ₹36,252 / 12 months = ₹3,021/month
      // Target: ₹50,000/month
      // Expected progress: 3,021 / 50,000 = 6.04%
      //
      // REGRESSION TEST: Verifies that when goal currency matches cash flow currency,
      // progress % is calculated correctly regardless of display currency.
      //
      // Before multi-currency fix: Progress would break when switching currencies
      // After fix: Progress remains stable at ~6% whether displayed in INR or USD
      expect(progressINR.progressPercent, greaterThan(5.0),
          reason: 'Progress should be ~6% (₹3,021 / ₹50,000)');
      expect(progressINR.progressPercent, lessThan(10.0),
          reason: 'Progress should be reasonable, not inflated');

      // Most importantly: percentage MUST be stable across currency switches
      expect((progressINR.progressPercent - progressUSD.progressPercent).abs(), lessThan(0.5),
          reason: 'Percentage must remain stable when switching USD↔INR (Rule 21.3)');

      // Verify the goal has correct currency
      expect(goal.currency, equals('INR'),
          reason: 'Goal currency must match cash flow currency');
    });

  });
}



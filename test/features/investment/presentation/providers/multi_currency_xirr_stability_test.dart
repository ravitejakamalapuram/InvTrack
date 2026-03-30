/// TDD test for multi-currency XIRR/returns stability
///
/// **Bug:** XIRR and returns % should remain identical when switching display currency
/// **Rule 21.3:** Percentages must be calculated in consistent base currency
///
/// This test verifies that derived calculations (XIRR, absolute return %) are
/// currency-invariant.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';

import '../../../../mocks/mock_currency_conversion_service.dart';

/// **Multi-Currency XIRR/Returns Stability Tests (TDD)**
///
/// **Rule 21.3 Compliance:** XIRR and absolute return % MUST remain stable when base currency changes.
/// Only display amounts should change, not the underlying percentages/ratios.
///
/// **Bug Report:**
/// - XIRR changes when switching from USD to EUR
/// - Absolute return % changes when switching currencies
/// - Root cause: Calculations using mixed currencies without conversion
///
/// **Expected Behavior:**
/// - XIRR calculated in base currency should be currency-invariant
/// - Switching USD → EUR → INR should give same XIRR (within rounding error)
/// - Absolute return % and MOIC should also be stable
void main() {
  group('Multi-Currency XIRR Stability Tests', () {
    late MockCurrencyConversionService mockConversionService;
    late BatchCurrencyConverter batchConverter;

    setUp(() {
      mockConversionService = MockCurrencyConversionService();
      batchConverter = BatchCurrencyConverter(mockConversionService);
    });

    /// **Scenario:** US investment (USD) with \$10k invested, \$500 dividend, \$12k current value
    /// - Base currency switches: USD → EUR → INR
    /// - Expected: XIRR, return %, MOIC remain identical across all currencies
    test('XIRR remains identical when switching from USD to EUR to INR', () async {
      // Create multi-currency cash flows for an investment
      final cashFlows = <CashFlowEntity>[
        CashFlowEntity(
          id: 'cf1',
          investmentId: 'test-inv-1',
          amount: 10000,
          currency: 'USD',
          type: CashFlowType.invest, // Outflow
          date: DateTime(2024, 1, 1),
          createdAt: DateTime.now(),
        ),
        CashFlowEntity(
          id: 'cf2',
          investmentId: 'test-inv-1',
          amount: 500,
          currency: 'USD',
          type: CashFlowType.income, // Inflow (dividend)
          date: DateTime(2024, 6, 1),
          createdAt: DateTime.now(),
        ),
        CashFlowEntity(
          id: 'cf3',
          investmentId: 'test-inv-1',
          amount: 12000,
          currency: 'USD',
          type: CashFlowType.returnFlow, // Inflow (current value)
          date: DateTime(2024, 12, 31),
          createdAt: DateTime.now(),
        ),
      ];

      // Test with USD as base currency
      final convertedCashFlowsUSD = await batchConverter.batchConvert(
        cashFlows: cashFlows,
        baseCurrency: 'USD',
      );
      final statsUSD = calculateStats(convertedCashFlowsUSD);

      // Test with EUR as base currency
      final convertedCashFlowsEUR = await batchConverter.batchConvert(
        cashFlows: cashFlows,
        baseCurrency: 'EUR',
      );
      final statsEUR = calculateStats(convertedCashFlowsEUR);

      // Test with INR as base currency
      final convertedCashFlowsINR = await batchConverter.batchConvert(
        cashFlows: cashFlows,
        baseCurrency: 'INR',
      );
      final statsINR = calculateStats(convertedCashFlowsINR);

      // ✅ CRITICAL ASSERTION: XIRR must be identical across all currencies
      expect(
        statsUSD.xirr,
        closeTo(statsEUR.xirr, 0.0001),
        reason: 'XIRR should be identical when calculated in USD vs EUR',
      );
      expect(
        statsUSD.xirr,
        closeTo(statsINR.xirr, 0.0001),
        reason: 'XIRR should be identical when calculated in USD vs INR',
      );

      // ✅ CRITICAL ASSERTION: Absolute return % must be identical
      expect(
        statsUSD.absoluteReturn,
        closeTo(statsEUR.absoluteReturn, 0.01),
        reason: 'Absolute return % should be identical when calculated in USD vs EUR',
      );
      expect(
        statsUSD.absoluteReturn,
        closeTo(statsINR.absoluteReturn, 0.01),
        reason: 'Absolute return % should be identical when calculated in USD vs INR',
      );

      // ✅ CRITICAL ASSERTION: MOIC must be identical
      expect(
        statsUSD.moic,
        closeTo(statsEUR.moic, 0.01),
        reason: 'MOIC should be identical when calculated in USD vs EUR',
      );
      expect(
        statsUSD.moic,
        closeTo(statsINR.moic, 0.01),
        reason: 'MOIC should be identical when calculated in USD vs INR',
      );

      // Print debug information
      print('USD: XIRR=${statsUSD.xirr}, Return=${statsUSD.absoluteReturn}%, MOIC=${statsUSD.moic}x');
      print('EUR: XIRR=${statsEUR.xirr}, Return=${statsEUR.absoluteReturn}%, MOIC=${statsEUR.moic}x');
      print('INR: XIRR=${statsINR.xirr}, Return=${statsINR.absoluteReturn}%, MOIC=${statsINR.moic}x');
    });
  });
}


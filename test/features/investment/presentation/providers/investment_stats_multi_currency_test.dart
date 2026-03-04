import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';

void main() {
  group('InvestmentStats Multi-Currency Tests', () {
    test('KNOWN ISSUE: stats aggregate mixed currencies without conversion',
        () {
      // This test documents the current bug where InvestmentStats
      // aggregates amounts directly without currency conversion.
      // This violates Rule 21.3: "All monetary displays MUST convert to base currency"

      final mixedCurrencyCashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv_1',
          type: CashFlowType.invest,
          amount: 1000,
          currency: 'USD', // $1,000 USD
          date: DateTime(2024, 1, 1),
          notes: 'US investment',
          createdAt: DateTime(2024, 1, 1),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv_1',
          type: CashFlowType.invest,
          amount: 50000,
          currency: 'INR', // ₹50,000 INR
          date: DateTime(2024, 2, 1),
          notes: 'Indian investment',
          createdAt: DateTime(2024, 2, 1),
        ),
        CashFlowEntity(
          id: '3',
          investmentId: 'inv_1',
          type: CashFlowType.returnFlow, // Use returnFlow instead of withdraw
          amount: 500,
          currency: 'USD', // $500 USD return
          date: DateTime(2024, 3, 1),
          notes: 'Partial return',
          createdAt: DateTime(2024, 3, 1),
        ),
      ];

      // Use calculateStats directly (it's a pure function)
      final stats = calculateStats(mixedCurrencyCashFlows);

      // BUG: Current implementation adds raw amounts regardless of currency
      // Expected (if converted to USD at ~83.12 INR/USD):
      //   Total Invested = $1,000 + ($50,000 / 83.12)
      //                  = $1,000 + $601.54
      //                  = $1,601.54
      //   Total Returned = $500
      //   Net Cash Flow = $500 - $1,601.54 = -$1,101.54
      //
      // Actual (current buggy behavior):
      //   Total Invested = 1000 + 50000 = 51,000 (mixed units!)
      //   Total Returned = 500
      //   Net Cash Flow = 500 - 51,000 = -50,500

      expect(stats.totalInvested, 51000.0,
          reason:
              'BUG: Stats aggregate mixed currencies without conversion. '
              'This should be ~1601.54 USD after proper conversion.');

      expect(stats.totalReturned, 500.0,
          reason: 'Total returned is correct (single currency)');

      expect(stats.netCashFlow, -50500.0,
          reason:
              'BUG: Net cash flow uses mixed currencies. '
              'Should be ~-1101.54 USD after proper conversion.');

      // Document the fix needed:
      // 1. InvestmentStats should accept base currency parameter
      // 2. Use CurrencyConversionService to convert each cash flow to base currency
      // 3. Then aggregate the converted amounts
      // 4. Similar to how multiCurrencyInvestedAmount works in multi_currency_providers.dart
    });

    test('verifies cash flows preserve original currency (Rule 21.2)', () {
      // This test verifies that original currency data is preserved
      // (which is correct behavior)

      final mixedCurrencyCashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv_1',
          type: CashFlowType.invest,
          amount: 1000,
          currency: 'USD',
          date: DateTime(2024, 1, 1),
          notes: 'US investment',
          createdAt: DateTime(2024, 1, 1),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv_1',
          type: CashFlowType.invest,
          amount: 50000,
          currency: 'INR',
          date: DateTime(2024, 2, 1),
          notes: 'Indian investment',
          createdAt: DateTime(2024, 2, 1),
        ),
      ];

      // ✅ CORRECT: Original amounts and currencies are preserved in entities
      expect(mixedCurrencyCashFlows[0].amount, 1000);
      expect(mixedCurrencyCashFlows[0].currency, 'USD');
      expect(mixedCurrencyCashFlows[1].amount, 50000);
      expect(mixedCurrencyCashFlows[1].currency, 'INR');
    });
  });
}


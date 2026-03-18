import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/multi_currency_providers.dart';

void main() {
  group('Multi-Currency Stats Providers', () {
    test(
      'multiCurrencyInvestmentStats converts to base currency before aggregation',
      () async {
        // Mock cash flows with mixed currencies
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
            type: CashFlowType.returnFlow,
            amount: 500,
            currency: 'USD', // $500 USD return
            date: DateTime(2024, 3, 1),
            notes: 'Partial return',
            createdAt: DateTime(2024, 3, 1),
          ),
        ];

        // Mock conversion service with fixed rates
        final mockConversionService = _MockCurrencyConversionService();

        final container = ProviderContainer(
          overrides: [
            // Override the stream provider to return data immediately
            cashFlowsByInvestmentProvider('inv_1').overrideWith(
              (ref) => Stream.fromIterable([mixedCurrencyCashFlows]),
            ),
            currencyConversionServiceProvider.overrideWithValue(
              mockConversionService,
            ),
            currencyCodeProvider.overrideWith((ref) => 'USD'),
          ],
        );

        // Keep the provider alive by listening to it
        final subscription = container.listen(
          cashFlowsByInvestmentProvider('inv_1'),
          (previous, next) {},
        );

        try {
          final stats = await container.read(
            multiCurrencyInvestmentStatsProvider('inv_1').future,
          );

          // Expected (with conversion at 83.12 INR/USD):
          //   Total Invested = $1,000 + ($50,000 / 83.12) = $1,000 + $601.54 = $1,601.54
          //   Total Returned = $500
          //   Net Cash Flow = $500 - $1,601.54 = -$1,101.54

          expect(
            stats.totalInvested,
            closeTo(1601.54, 0.01),
            reason: 'Should convert INR to USD before summing',
          );
          expect(
            stats.totalReturned,
            500.0,
            reason: 'Total returned is correct (single currency)',
          );
          expect(
            stats.netCashFlow,
            closeTo(-1101.54, 0.01),
            reason: 'Net cash flow should use converted amounts',
          );
        } finally {
          subscription.close();
          container.dispose();
        }
      },
    );
  });
}

/// Mock currency conversion service with fixed rates
class _MockCurrencyConversionService implements CurrencyConversionService {
  @override
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async {
    // Fixed conversion rate: 1 USD = 83.12 INR
    if (from == to) return amount;
    if (from == 'INR' && to == 'USD') {
      return amount / 83.12;
    }
    if (from == 'USD' && to == 'INR') {
      return amount * 83.12;
    }
    return amount; // Default: no conversion
  }

  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async {
    final results = <String, double>{};
    for (final entry in requests.entries) {
      final converted = await convert(
        amount: entry.value.amount,
        from: entry.value.from,
        to: to,
        date: entry.value.date,
      );
      results[entry.key] = converted;
    }
    return results;
  }

  @override
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async {
    return null; // No cached rates in mock
  }

  @override
  ConversionMetrics get metrics => ConversionMetrics();

  @override
  void resetCircuitBreaker() {}

  @override
  void resetMetrics() {}

  // Helper method for testing (not part of interface)
  Future<double?> getExchangeRate({
    required String from,
    required String to,
    DateTime? date,
  }) async {
    if (from == to) return 1.0;
    if (from == 'INR' && to == 'USD') return 1 / 83.12;
    if (from == 'USD' && to == 'INR') return 83.12;
    return null;
  }

  // Helper method for testing (not part of interface)
  @override
  Future<void> clearCache() async {}

  @override
  Future<void> preloadRates(
    Set<String> currencies,
    String baseCurrency,
  ) async {}

  @override
  Future<double> getRate({
    required String from,
    required String to,
    DateTime? date,
  }) async {
    if (from == to) return 1.0;
    if (from == 'INR' && to == 'USD') return 1 / 83.12;
    if (from == 'USD' && to == 'INR') return 83.12;
    return 1.0;
  }

  @override
  Future<double> getHistoricalRate(
    DateTime date,
    String from,
    String to,
  ) async {
    return getRate(from: from, to: to, date: date);
  }

  @override
  Future<double> getLiveRate(String from, String to) async {
    return getRate(from: from, to: to);
  }

  @override
  Future<Map<String, double>> batchConvert({
    required Map<String, double> amounts,
    required String to,
  }) async {
    final result = <String, double>{};
    for (final entry in amounts.entries) {
      final from = entry.key;
      final amount = entry.value;
      result[from] = await convert(amount: amount, from: from, to: to);
    }
    return result;
  }

  @override
  Future<void> refreshLiveCacheOnAppStart() async {}

  @override
  Future<void> refreshLiveCacheIfStale() async {}

  @override
  void dispose() {}
}

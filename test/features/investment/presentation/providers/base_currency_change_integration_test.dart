/// Integration tests for base currency changes
///
/// Verifies that changing the base currency in settings immediately updates
/// all summary statistics across the app (Rule 21.3 compliance).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/multi_currency_providers.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';

void main() {
  group('Base Currency Change Integration Tests', () {
    late ProviderContainer container;
    late _MockCurrencyConversionService mockConversionService;
    late FakeAnalyticsService fakeAnalytics;

    setUp(() {
      mockConversionService = _MockCurrencyConversionService();
      fakeAnalytics = FakeAnalyticsService();
    });

    tearDown(() {
      container.dispose();
      fakeAnalytics.reset();
    });

    test('changing base currency from USD to EUR updates global stats', () async {
      // Setup: Create cash flows in mixed currencies
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
          amount: 900,
          currency: 'EUR', // €900 EUR
          date: DateTime(2024, 2, 1),
          notes: 'European investment',
          createdAt: DateTime(2024, 2, 1),
        ),
      ];

      // Initialize with USD as base currency
      SharedPreferences.setMockInitialValues({'currency': 'USD'});
      final prefs = await SharedPreferences.getInstance();

      container = ProviderContainer(
        overrides: [
          validCashFlowsProvider.overrideWith(
            (ref) => AsyncValue.data(mixedCurrencyCashFlows),
          ),
          currencyConversionServiceProvider.overrideWithValue(mockConversionService),
          sharedPreferencesProvider.overrideWithValue(prefs),
          analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        ],
      );

      // Keep the provider alive
      final subscription = container.listen(
        validCashFlowsProvider,
        (previous, next) {},
      );

      try {
        // Step 1: Verify stats in USD (base currency)
        final statsInUSD = await container.read(multiCurrencyGlobalStatsProvider.future);

        // Expected in USD (1 EUR = 1.1 USD):
        //   Total Invested = $1,000 + (€900 * 1.1) = $1,000 + $990 = $1,990
        expect(statsInUSD.totalInvested, closeTo(1990.0, 0.01),
            reason: 'Should convert EUR to USD before summing');

        // Step 2: Change base currency to EUR
        await container.read(settingsProvider.notifier).setCurrency('EUR');

        // Step 3: Invalidate the stats provider to force recalculation
        container.invalidate(multiCurrencyGlobalStatsProvider);

        // Step 4: Verify stats in EUR (new base currency)
        final statsInEUR = await container.read(multiCurrencyGlobalStatsProvider.future);

        // Expected in EUR (1 USD = 0.91 EUR):
        //   Total Invested = ($1,000 * 0.91) + €900 = €910 + €900 = €1,810
        expect(statsInEUR.totalInvested, closeTo(1810.0, 0.01),
            reason: 'Should convert USD to EUR after currency change');
      } finally {
        subscription.close();
      }
    });

    test('changing base currency updates investment-specific stats', () async {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv_1',
          type: CashFlowType.invest,
          amount: 1000,
          currency: 'USD',
          date: DateTime(2024, 1, 1),
          notes: 'Investment',
          createdAt: DateTime(2024, 1, 1),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv_1',
          type: CashFlowType.returnFlow,
          amount: 500,
          currency: 'EUR',
          date: DateTime(2024, 2, 1),
          notes: 'Return',
          createdAt: DateTime(2024, 2, 1),
        ),
      ];

      SharedPreferences.setMockInitialValues({'currency': 'USD'});
      final prefs = await SharedPreferences.getInstance();

      container = ProviderContainer(
        overrides: [
          cashFlowsByInvestmentProvider('inv_1').overrideWith(
            (ref) => Stream.fromIterable([cashFlows]),
          ),
          currencyConversionServiceProvider.overrideWithValue(mockConversionService),
          sharedPreferencesProvider.overrideWithValue(prefs),
          analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        ],
      );

      final subscription = container.listen(
        cashFlowsByInvestmentProvider('inv_1'),
        (previous, next) {},
      );

      try {
        // Stats in USD
        final statsInUSD = await container.read(
          multiCurrencyInvestmentStatsProvider('inv_1').future,
        );
        expect(statsInUSD.totalInvested, 1000.0);
        expect(statsInUSD.totalReturned, closeTo(550.0, 0.01)); // €500 * 1.1 = $550

        // Change to EUR
        await container.read(settingsProvider.notifier).setCurrency('EUR');
        container.invalidate(multiCurrencyInvestmentStatsProvider('inv_1'));

        // Stats in EUR
        final statsInEUR = await container.read(
          multiCurrencyInvestmentStatsProvider('inv_1').future,
        );
        expect(statsInEUR.totalInvested, closeTo(910.0, 0.01)); // $1000 * 0.91 = €910
        expect(statsInEUR.totalReturned, 500.0);
      } finally {
        subscription.close();
      }
    });
  });
}

/// Mock currency conversion service with fixed rates
class _MockCurrencyConversionService implements CurrencyConversionService {
  // Fixed rates: 1 EUR = 1.1 USD, 1 USD = 0.91 EUR
  @override
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async {
    if (from == to) return amount;
    if (from == 'EUR' && to == 'USD') return amount * 1.1;
    if (from == 'USD' && to == 'EUR') return amount * 0.91;
    return amount;
  }

  @override
  Future<double?> getExchangeRate({required String from, required String to, DateTime? date}) async {
    if (from == to) return 1.0;
    if (from == 'EUR' && to == 'USD') return 1.1;
    if (from == 'USD' && to == 'EUR') return 0.91;
    return null;
  }

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> preloadRates(Set<String> currencies, String baseCurrency) async {}

  @override
  Future<double> getRate({required String from, required String to, DateTime? date}) async {
    return (await getExchangeRate(from: from, to: to, date: date)) ?? 1.0;
  }

  @override
  Future<double> getHistoricalRate(DateTime date, String from, String to) async {
    return getRate(from: from, to: to, date: date);
  }

  @override
  Future<double> getLiveRate(String from, String to) async {
    return getRate(from: from, to: to);
  }

  @override
  Future<Map<String, double>> batchConvert({required Map<String, double> amounts, required String to}) async {
    final result = <String, double>{};
    for (final entry in amounts.entries) {
      result[entry.key] = await convert(amount: entry.value, from: entry.key, to: to);
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


import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/connectivity_provider.dart';
import 'package:inv_tracker/core/services/connectivity_service.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/settings/presentation/providers/currency_switch_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';

// Mock classes
class MockCurrencyConversionService extends Mock
    implements CurrencyConversionService {}

class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  // Register fallback values for mocktail
  setUpAll(() {
    registerFallbackValue(DateTime.now());
  });

  group('CurrencySwitchProvider - Parallel Rate Fetching Tests', () {
    late ProviderContainer container;
    late MockCurrencyConversionService mockConversionService;
    late MockConnectivityService mockConnectivityService;
    late FakeAnalyticsService fakeAnalytics;
    late SharedPreferences prefs;

    setUp(() async {
      // Initialize mocks
      mockConversionService = MockCurrencyConversionService();
      mockConnectivityService = MockConnectivityService();
      fakeAnalytics = FakeAnalyticsService();

      // Setup SharedPreferences
      SharedPreferences.setMockInitialValues({
        'currency': 'USD',
        'locale': 'en_US',
      });
      prefs = await SharedPreferences.getInstance();

      // Default mock behaviors
      when(() => mockConnectivityService.checkConnectivity())
          .thenAnswer((_) async => true);
      when(() => mockConversionService.clearCache()).thenAnswer((_) async {});
    });

    tearDown(() {
      container.dispose();
      fakeAnalytics.reset();
    });

    group('Parallel Fetching with Multiple Currencies', () {
      test('fetches rates in parallel for multiple currencies', () async {
        // Create investments with different currencies
        final investments = [
          InvestmentEntity(
            id: '1',
            name: 'US Stocks',
            type: InvestmentType.stocks,
            status: InvestmentStatus.open,
            currency: 'USD',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          InvestmentEntity(
            id: '2',
            name: 'European Bonds',
            type: InvestmentType.bonds,
            status: InvestmentStatus.open,
            currency: 'EUR',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          InvestmentEntity(
            id: '3',
            name: 'UK Property',
            type: InvestmentType.realEstate,
            status: InvestmentStatus.open,
            currency: 'GBP',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Create cashflows with different currencies
        final cashFlows = [
          CashFlowEntity(
            id: 't1',
            investmentId: '1',
            date: DateTime(2024, 1, 1),
            type: CashFlowType.invest,
            amount: 1000,
            currency: 'USD',
            createdAt: DateTime.now(),
          ),
          CashFlowEntity(
            id: 't2',
            investmentId: '2',
            date: DateTime(2024, 1, 1),
            type: CashFlowType.invest,
            amount: 2000,
            currency: 'EUR',
            createdAt: DateTime.now(),
          ),
          CashFlowEntity(
            id: 't3',
            investmentId: '3',
            date: DateTime(2024, 1, 1),
            type: CashFlowType.invest,
            amount: 3000,
            currency: 'GBP',
            createdAt: DateTime.now(),
          ),
        ];

        // Track concurrent API calls
        final apiCallTimestamps = <DateTime>[];

        // Mock getRate to simulate parallel execution
        when(() => mockConversionService.getRate(
              from: any(named: 'from'),
              to: any(named: 'to'),
              date: any(named: 'date'),
            )).thenAnswer((_) async {
          apiCallTimestamps.add(DateTime.now());
          // Simulate network delay
          await Future.delayed(const Duration(milliseconds: 100));
          return 1.2; // Mock exchange rate
        });

        // Create container with mock investments and cashflows
        container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            analyticsServiceProvider.overrideWithValue(fakeAnalytics),
            currencyConversionServiceProvider
                .overrideWithValue(mockConversionService),
            connectivityServiceProvider
                .overrideWithValue(mockConnectivityService),
            allInvestmentsProvider
                .overrideWith((ref) => Stream.value(investments)),
            // Mock cashflows stream with different currencies
            allCashFlowsStreamProvider
                .overrideWith((ref) => Stream.value(cashFlows)),
            // Override validCashFlowsProvider directly to ensure cashflows are available
            validCashFlowsProvider
                .overrideWith((ref) => AsyncValue.data(cashFlows)),
            // Mock authenticated state
            isAuthenticatedProvider.overrideWith((ref) => true),
          ],
        );

        // Keep provider alive by listening to it
        final subscription = container.listen(
          currencySwitchProvider,
          (previous, next) {},
        );

        final notifier = container.read(currencySwitchProvider.notifier);

        // Trigger currency switch using immediate method
        await notifier.switchCurrencyImmediate('INR');

        // Close subscription after operation completes
        subscription.close();

        // Verify all rates were fetched
        verify(() => mockConversionService.getRate(
              from: 'USD',
              to: 'INR',
              date: any(named: 'date'),
            )).called(greaterThan(0));

        verify(() => mockConversionService.getRate(
              from: 'EUR',
              to: 'INR',
              date: any(named: 'date'),
            )).called(greaterThan(0));

        verify(() => mockConversionService.getRate(
              from: 'GBP',
              to: 'INR',
              date: any(named: 'date'),
            )).called(greaterThan(0));

        // Verify parallel execution (all calls within 50ms window)
        if (apiCallTimestamps.length >= 3) {
          final firstCall = apiCallTimestamps.first;
          final lastCall = apiCallTimestamps.last;
          final timeDiff = lastCall.difference(firstCall).inMilliseconds;

          // All calls should start within 50ms (parallel execution)
          expect(timeDiff, lessThan(50),
              reason: 'Calls should be parallel, not sequential');
        }

        // Verify success state
        final state = container.read(currencySwitchProvider);
        expect(state.isSuccess, true);
      });

      test('updates progress during parallel fetching', () async {
        // Create investments with different currencies
        final investments = [
          InvestmentEntity(
            id: '1',
            name: 'Investment 1',
            type: InvestmentType.stocks,
            status: InvestmentStatus.open,
            currency: 'USD',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          InvestmentEntity(
            id: '2',
            name: 'Investment 2',
            type: InvestmentType.bonds,
            status: InvestmentStatus.open,
            currency: 'EUR',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Create cashflows with different currencies
        final cashFlows = [
          CashFlowEntity(
            id: 't1',
            investmentId: '1',
            date: DateTime(2024, 1, 1),
            type: CashFlowType.invest,
            amount: 1000,
            currency: 'USD',
            createdAt: DateTime.now(),
          ),
          CashFlowEntity(
            id: 't2',
            investmentId: '2',
            date: DateTime(2024, 1, 1),
            type: CashFlowType.invest,
            amount: 2000,
            currency: 'EUR',
            createdAt: DateTime.now(),
          ),
        ];

        // Mock getRate with delay
        when(() => mockConversionService.getRate(
              from: any(named: 'from'),
              to: any(named: 'to'),
              date: any(named: 'date'),
            )).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 1.2;
        });

        // Create container
        container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            analyticsServiceProvider.overrideWithValue(fakeAnalytics),
            currencyConversionServiceProvider
                .overrideWithValue(mockConversionService),
            connectivityServiceProvider
                .overrideWithValue(mockConnectivityService),
            allInvestmentsProvider
                .overrideWith((ref) => Stream.value(investments)),
            // Mock cashflows stream with different currencies
            allCashFlowsStreamProvider
                .overrideWith((ref) => Stream.value(cashFlows)),
            // Override validCashFlowsProvider directly to ensure cashflows are available
            validCashFlowsProvider
                .overrideWith((ref) => AsyncValue.data(cashFlows)),
            // Mock authenticated state
            isAuthenticatedProvider.overrideWith((ref) => true),
          ],
        );

        final notifier = container.read(currencySwitchProvider.notifier);

        // Listen to state changes
        final states = <CurrencySwitchStatus>[];
        container.listen(
          currencySwitchProvider,
          (previous, next) => states.add(next),
          fireImmediately: true,
        );

        // Trigger switch using immediate method
        await notifier.switchCurrencyImmediate('INR');

        // Verify we got progress updates
        final fetchingStates =
            states.where((s) => s.isFetchingRates).toList();
        expect(fetchingStates.isNotEmpty, true,
            reason: 'Should have fetching states');

        // Verify final success state
        expect(states.last.isSuccess, true);
      });
    });

    group('Error Handling During Parallel Fetching', () {
      test('handles rate fetch failure gracefully', () async {
        final investments = [
          InvestmentEntity(
            id: '1',
            name: 'Investment',
            type: InvestmentType.stocks,
            status: InvestmentStatus.open,
            currency: 'USD',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        final cashFlows = [
          CashFlowEntity(
            id: 't1',
            investmentId: '1',
            date: DateTime(2024, 1, 1),
            type: CashFlowType.invest,
            amount: 1000,
            currency: 'USD',
            createdAt: DateTime.now(),
          ),
        ];

        // Mock getRate to throw error
        when(() => mockConversionService.getRate(
              from: any(named: 'from'),
              to: any(named: 'to'),
              date: any(named: 'date'),
            )).thenThrow(Exception('API error'));

        container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            analyticsServiceProvider.overrideWithValue(fakeAnalytics),
            currencyConversionServiceProvider
                .overrideWithValue(mockConversionService),
            connectivityServiceProvider
                .overrideWithValue(mockConnectivityService),
            allInvestmentsProvider
                .overrideWith((ref) => Stream.value(investments)),
            // Mock cashflows stream
            allCashFlowsStreamProvider
                .overrideWith((ref) => Stream.value(cashFlows)),
            // Override validCashFlowsProvider directly to ensure cashflows are available
            validCashFlowsProvider
                .overrideWith((ref) => AsyncValue.data(cashFlows)),
            // Mock authenticated state
            isAuthenticatedProvider.overrideWith((ref) => true),
          ],
        );

        final notifier = container.read(currencySwitchProvider.notifier);

        // Trigger switch using immediate method
        await notifier.switchCurrencyImmediate('INR');

        // Should be in failed state
        final state = container.read(currencySwitchProvider);
        expect(state.isFailed, true);
      });
    });
  });
}



// #980 (money rule 2): cashflow_added.amount_range bucketed the cash flow's
// native amount, so USD 1,000 and INR 1,000 landed in the same bucket. It
// buckets the amount in the user's base currency; without a rate it says
// 'unknown' and never the native amount under the base currency's buckets.
// Rate in the mock service: 1 USD = 83 INR.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

import '../../../../helpers/analytics_privacy.dart';
import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_currency_conversion_service.dart';
import '../../../../mocks/mock_notification_service.dart';
import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../data/repositories/mock_investment_repository.dart';

/// Offline, with no cached rate to fall back on.
class _OfflineConversionService extends MockCurrencyConversionService {
  @override
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async {
    if (from == to) return amount;
    throw Exception('offline');
  }

  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async => throw Exception('offline');

  @override
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async => from == to ? 1.0 : null;
}

void main() {
  late FakeAnalyticsService analytics;

  setUp(() => analytics = FakeAnalyticsService());

  ProviderContainer containerFor(
    String baseCurrency, {
    CurrencyConversionService? conversion,
    bool brokenConversionProvider = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(
          FakeInvestmentRepository(),
        ),
        goalRepositoryProvider.overrideWithValue(FakeGoalRepository()),
        analyticsServiceProvider.overrideWithValue(analytics),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        // Not overridden, the real provider throws in a test: it needs
        // Firebase, as it can in the app before sign-in completes.
        if (!brokenConversionProvider)
          currencyConversionServiceProvider.overrideWithValue(conversion),
        isAuthenticatedProvider.overrideWithValue(true),
        currencyCodeProvider.overrideWithValue(baseCurrency),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Adds an INVEST cash flow of [amount] in [currency] and returns the
  /// cashflow_added events logged for it.
  Future<List<({String name, Map<String, Object>? parameters})>> add(
    ProviderContainer container,
    double amount,
    String currency,
  ) async {
    await container
        .read(investmentNotifierProvider.notifier)
        .addCashFlow(
          investmentId: 'inv-1',
          type: CashFlowType.invest,
          amount: amount,
          date: DateTime(2026, 1, 1),
          currency: currency,
        );
    // The event is logged without making the save wait for a rate.
    await pumpEventQueue();
    final events = analytics.loggedEvents
        .where((e) => e.name == 'cashflow_added')
        .toList();
    for (final event in events) {
      expectPrivacySafe(
        event,
        allowedStrings: {
          'flow_type': {'invest'},
          'amount_range': allowedAmountRanges,
        },
      );
    }
    return events;
  }

  String rangeOf(
    List<({String name, Map<String, Object>? parameters})> events,
  ) {
    expect(events, hasLength(1));
    return events.single.parameters!['amount_range']! as String;
  }

  test(
    'USD 1,000 and INR 1,000 land in different buckets for an INR user',
    () async {
      final container = containerFor(
        'INR',
        conversion: MockCurrencyConversionService(),
      );

      final usd = rangeOf(await add(container, 1000, 'USD'));
      analytics.reset();
      final inr = rangeOf(await add(container, 1000, 'INR'));

      // USD 1,000 is INR 83,000.
      expect(usd, '50k_1L');
      expect(inr, '1k_10k');
    },
  );

  test('a flow in another currency is bucketed after conversion, not by its '
      'native amount', () async {
    // INR 83,000 is USD 1,000. Its native 83,000 would be '50k_1L'.
    final container = containerFor(
      'USD',
      conversion: MockCurrencyConversionService(),
    );

    expect(rangeOf(await add(container, 83000, 'INR')), '1k_10k');
  });

  test('a flow in the base currency is bucketed as before, with no rate '
      'needed', () async {
    final container = containerFor('INR', conversion: null);

    expect(rangeOf(await add(container, 25000, 'INR')), '10k_50k');
  });

  test('offline with no rate, the bucket is unknown', () async {
    final container = containerFor(
      'INR',
      conversion: _OfflineConversionService(),
    );

    final events = await add(container, 1000, 'USD');

    expect(events.single.parameters, {
      'flow_type': 'invest',
      'amount_range': 'unknown',
    });
  });

  test('without a conversion service, the bucket is unknown', () async {
    final container = containerFor('INR', conversion: null);

    expect(rangeOf(await add(container, 1000, 'USD')), 'unknown');
  });

  test('an unknown currency gives unknown, never the native amount', () async {
    // The mock service rejects currencies it has no rate for.
    final container = containerFor(
      'INR',
      conversion: MockCurrencyConversionService(),
    );

    expect(rangeOf(await add(container, 1000, 'XYZ')), 'unknown');
  });

  test('a failing rate never fails the save', () async {
    final container = containerFor(
      'INR',
      conversion: _OfflineConversionService(),
    );

    await add(container, 1000, 'USD');

    final saved = await container
        .read(investmentRepositoryProvider)
        .getAllCashFlows();
    expect(saved.single.amount, 1000);
    expect(saved.single.currency, 'USD');
  });

  test('a conversion provider that throws never fails the save', () async {
    final container = containerFor('INR', brokenConversionProvider: true);

    expect(rangeOf(await add(container, 1000, 'USD')), 'unknown');

    final saved = await container
        .read(investmentRepositoryProvider)
        .getAllCashFlows();
    expect(saved.single.currency, 'USD');
  });

  test(
    'a flow in the base currency needs no conversion provider at all',
    () async {
      final container = containerFor('INR', brokenConversionProvider: true);

      expect(rangeOf(await add(container, 1000, 'INR')), '1k_10k');
    },
  );
}

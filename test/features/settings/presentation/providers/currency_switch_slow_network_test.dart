// A81: changing the base currency first stamps the user's records that have
// no currency (A03-F1). With a few hundred such records on a slow network
// that stamp ran past Firestore's 30-second transaction limit, so the change
// failed with LegacyCurrencyStampException (Crashlytics, v3.73.3) and could
// never succeed for that user.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/providers/connectivity_provider.dart';
import 'package:inv_tracker/core/services/connectivity_service.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/settings/data/services/legacy_currency_backfill_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/currency_switch_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_legacy_currency_firestore.dart';
import '../../../../mocks/mock_analytics_service.dart';

class _MockConversion extends Mock implements CurrencyConversionService {}

class _MockConnectivity extends Mock implements ConnectivityService {}

void main() {
  late FakeLegacyCurrencyFirestore firestore;
  late SharedPreferences prefs;
  late _MockConversion conversion;
  late _MockConnectivity connectivity;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'currency': 'INR',
      'locale': 'en_IN',
    });
    prefs = await SharedPreferences.getInstance();

    // 500 older cash flows saved without a currency, on a connection where
    // each transaction read takes 200 ms.
    firestore = FakeLegacyCurrencyFirestore()
      ..transactionReadLatency = const Duration(milliseconds: 200);
    for (var i = 0; i < 500; i++) {
      firestore.put('cashflows', 'cf-$i', {
        'investmentId': 'fd',
        'date': Timestamp.fromDate(DateTime(2022, 4, 1)),
        'type': 'INVEST',
        'amount': 1000.0,
      });
    }
    // This user confirmed that their older records are in INR.
    await LegacyCurrencyBackfillService(
      firestore: firestore,
      userId: firestore.uid,
      prefs: prefs,
    ).confirm('INR');

    conversion = _MockConversion();
    when(() => conversion.clearCache()).thenAnswer((_) async {});
    when(
      () => conversion.getRate(
        from: any(named: 'from'),
        to: any(named: 'to'),
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async => 0.012);
    connectivity = _MockConnectivity();
    when(() => connectivity.checkConnectivity()).thenAnswer((_) async => true);
  });

  // testWidgets runs on a fake clock, so the reads and the 30 s transaction
  // limit take no real time.
  testWidgets('500 older records on a slow network: INR to USD succeeds and '
      'every record keeps INR', (tester) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        currencyConversionServiceProvider.overrideWithValue(conversion),
        connectivityServiceProvider.overrideWithValue(connectivity),
        isAuthenticatedProvider.overrideWith((ref) => true),
        allInvestmentsProvider.overrideWith((ref) => Stream.value(const [])),
        allCashFlowsStreamProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        validCashFlowsProvider.overrideWithValue(const AsyncValue.data([])),
        legacyCurrencyBackfillServiceProvider.overrideWithValue(
          LegacyCurrencyBackfillService(
            firestore: firestore,
            userId: firestore.uid,
            prefs: prefs,
          ),
        ),
      ],
    );
    // Dispose in finally: testWidgets checks for pending timers before
    // addTearDown callbacks run.
    try {
      // The provider is auto-dispose; the Settings tile keeps it alive.
      container.listen(currencySwitchProvider, (_, _) {});

      container
          .read(currencySwitchProvider.notifier)
          .switchCurrencyImmediate('USD');
      await tester.pump(const Duration(minutes: 3));

      final status = container.read(currencySwitchProvider);
      expect(status.unstampedLegacyCurrency, isNull);
      expect(status.isSuccess, isTrue);
      expect(container.read(currencyCodeProvider), 'USD');
      expect(firestore.updatedDocs, 500);
      expect(firestore.stored('cashflows', 'cf-0')!['currency'], 'INR');
      expect(firestore.stored('cashflows', 'cf-499')!['currency'], 'INR');
    } finally {
      container.dispose();
    }
  });
}

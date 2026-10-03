// A03-F1: a base-currency change must first stamp records that have no
// currency with the OLD base currency. Otherwise they are relabelled with the
// new one at read time and their amounts change currency without conversion.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/providers/connectivity_provider.dart';
import 'package:inv_tracker/core/services/connectivity_service.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
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

Map<String, dynamic> legacyFdInvest() => {
  'investmentId': 'fd',
  'date': Timestamp.fromDate(DateTime(2022, 4, 1)),
  'type': 'INVEST',
  'amount': 1000000.0,
  'createdAt': Timestamp.fromDate(DateTime(2022, 4, 1)),
};

void main() {
  late FakeLegacyCurrencyFirestore firestore;
  late ProviderContainer container;
  late _MockConnectivity connectivity;
  late _MockConversion conversion;
  late SharedPreferences prefs;

  ProviderContainer makeContainer({
    List<CashFlowEntity> cashFlows = const [],
  }) => ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
      currencyConversionServiceProvider.overrideWithValue(conversion),
      connectivityServiceProvider.overrideWithValue(connectivity),
      isAuthenticatedProvider.overrideWith((ref) => true),
      allInvestmentsProvider.overrideWith((ref) => Stream.value(const [])),
      allCashFlowsStreamProvider.overrideWith((ref) => Stream.value(cashFlows)),
      validCashFlowsProvider.overrideWithValue(AsyncValue.data(cashFlows)),
      legacyCurrencyBackfillServiceProvider.overrideWithValue(
        LegacyCurrencyBackfillService(
          firestore: firestore,
          userId: firestore.uid,
          prefs: prefs,
        ),
      ),
    ],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'currency': 'INR',
      'locale': 'en_IN',
    });
    prefs = await SharedPreferences.getInstance();
    firestore = FakeLegacyCurrencyFirestore()
      ..put('investments', 'fd', {'name': 'FD'})
      ..put('cashflows', 'cf-1', legacyFdInvest());
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

    container = makeContainer();
  });

  tearDown(() => container.dispose());

  test('INR to USD: legacy records are stamped INR before USD applies, so '
      'the FD still reads as INR 10,00,000', () async {
    await container
        .read(currencySwitchProvider.notifier)
        .switchCurrencyImmediate('USD');

    expect(container.read(currencySwitchProvider).isSuccess, isTrue);
    expect(container.read(currencyCodeProvider), 'USD');
    expect(firestore.stored('investments', 'fd')!['currency'], 'INR');
    expect(firestore.stored('cashflows', 'cf-1')!['currency'], 'INR');

    final mapped = FirestoreInvestmentRepository.cashFlowFromFirestore(
      firestore.stored('cashflows', 'cf-1')!,
      'cf-1',
      baseCurrency: container.read(currencyCodeProvider),
    );
    expect(mapped.currency, 'INR');
    expect(mapped.amount, 1000000.0);
  });

  test('a failed stamp blocks the change and says why', () async {
    firestore.transactionError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );

    await container
        .read(currencySwitchProvider.notifier)
        .switchCurrencyImmediate('USD');

    final status = container.read(currencySwitchProvider);
    expect(status.isFailed, isTrue);
    expect(status.targetCurrency, 'USD');
    expect(status.unstampedLegacyCurrency, 'INR');
    expect(container.read(currencyCodeProvider), 'INR');
    expect(prefs.getString('currency'), 'INR');
    expect(
      firestore.stored('cashflows', 'cf-1')!.containsKey('currency'),
      isFalse,
    );
  });

  test('a failed server scan also blocks the change', () async {
    firestore.readError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );

    await container
        .read(currencySwitchProvider.notifier)
        .switchCurrencyImmediate('USD');

    final status = container.read(currencySwitchProvider);
    expect(status.isFailed, isTrue);
    expect(status.unstampedLegacyCurrency, 'INR');
    expect(container.read(currencyCodeProvider), 'INR');
  });

  test(
    'a later failure (rates) is not reported as a stamping failure',
    () async {
      when(
        () => conversion.getRate(
          from: any(named: 'from'),
          to: any(named: 'to'),
          date: any(named: 'date'),
        ),
      ).thenThrow(Exception('rate api down'));
      container.dispose();
      container = makeContainer(
        cashFlows: [
          FirestoreInvestmentRepository.cashFlowFromFirestore(
            {...legacyFdInvest(), 'currency': 'INR'},
            'cf-1',
            baseCurrency: 'INR',
          ),
        ],
      );
      await container
          .read(currencySwitchProvider.notifier)
          .switchCurrencyImmediate('USD');

      final status = container.read(currencySwitchProvider);
      expect(status.isFailed, isTrue);
      expect(status.unstampedLegacyCurrency, isNull);
      // Stamping had already succeeded and is kept: INR is still correct.
      expect(firestore.stored('cashflows', 'cf-1')!['currency'], 'INR');
    },
  );

  test('fresh install: the device default INR was never confirmed for this '
      'account, so a USD user switching to USD gets no INR stamp', () async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container.dispose();
    container = makeContainer();
    expect(container.read(currencyCodeProvider), 'INR');

    await container
        .read(currencySwitchProvider.notifier)
        .switchCurrencyImmediate('USD');

    expect(container.read(currencySwitchProvider).isSuccess, isTrue);
    expect(container.read(currencyCodeProvider), 'USD');
    expect(firestore.readOptions, isEmpty);
    expect(
      firestore.stored('cashflows', 'cf-1')!.containsKey('currency'),
      isFalse,
    );
    // The record is relabelled, not converted: it reads as USD 10,00,000.
    final mapped = FirestoreInvestmentRepository.cashFlowFromFirestore(
      firestore.stored('cashflows', 'cf-1')!,
      'cf-1',
      baseCurrency: container.read(currencyCodeProvider),
    );
    expect(mapped.currency, 'USD');
    expect(mapped.amount, 1000000.0);
  });

  test(
    'a currency confirmed by another user on this device is not used',
    () async {
      SharedPreferences.setMockInitialValues({'currency': 'USD'});
      prefs = await SharedPreferences.getInstance();
      await LegacyCurrencyBackfillService(
        firestore: FakeLegacyCurrencyFirestore(uid: 'uid-a'),
        userId: 'uid-a',
        prefs: prefs,
      ).confirm('USD');
      container.dispose();
      container = makeContainer();

      await container
          .read(currencySwitchProvider.notifier)
          .switchCurrencyImmediate('EUR');

      expect(container.read(currencySwitchProvider).isSuccess, isTrue);
      expect(
        firestore.stored('cashflows', 'cf-1')!.containsKey('currency'),
        isFalse,
      );
    },
  );

  test('offline: nothing is stamped and the change is not applied', () async {
    when(() => connectivity.checkConnectivity()).thenAnswer((_) async => false);

    await container
        .read(currencySwitchProvider.notifier)
        .switchCurrencyImmediate('USD');

    expect(container.read(currencySwitchProvider).isFailed, isTrue);
    expect(container.read(currencyCodeProvider), 'INR');
    expect(firestore.readOptions, isEmpty);
  });
}

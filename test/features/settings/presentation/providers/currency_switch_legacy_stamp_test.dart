// A03-F1: a base-currency change must first stamp records that have no
// currency with the OLD base currency. Otherwise they are relabelled with the
// new one at read time and their amounts change currency without conversion.
import 'dart:async';

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
    LegacyCurrencyBackfillService Function()? backfill,
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
      if (backfill != null)
        legacyCurrencyBackfillServiceProvider.overrideWith((ref) => backfill())
      else
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

  // The provider is auto-dispose; the Settings tile keeps it alive in the app.
  void keepAlive() => container.listen(currencySwitchProvider, (_, _) {});

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

  group('not yet confirmed: the user is asked at switch time', () {
    late List<String> asked;

    setUp(() async {
      // Prefs hold INR, but the user never confirmed it for their older
      // records: they tapped Not Now, dismissed the dialog, or were offline
      // at launch.
      SharedPreferences.setMockInitialValues({
        'currency': 'INR',
        'locale': 'en_IN',
      });
      prefs = await SharedPreferences.getInstance();
      container.dispose();
      container = makeContainer();
      asked = [];
    });

    LegacyCurrencyQuestion answer(bool? reply) => (currency) async {
      asked.add(currency);
      return reply;
    };

    test('yes: records are confirmed and stamped INR before USD applies, so '
        'the FD still reads as INR 10,00,000', () async {
      await container
          .read(currencySwitchProvider.notifier)
          .switchCurrencyImmediate('USD', askLegacyCurrency: answer(true));

      expect(asked, ['INR']);
      expect(container.read(currencySwitchProvider).isSuccess, isTrue);
      expect(container.read(currencyCodeProvider), 'USD');
      expect(firestore.stored('cashflows', 'cf-1')!['currency'], 'INR');
      expect(firestore.stored('investments', 'fd')!['currency'], 'INR');
      expect(
        container
            .read(legacyCurrencyBackfillServiceProvider)!
            .isConfirmedFor('INR'),
        isTrue,
      );
      final mapped = FirestoreInvestmentRepository.cashFlowFromFirestore(
        firestore.stored('cashflows', 'cf-1')!,
        'cf-1',
        baseCurrency: container.read(currencyCodeProvider),
      );
      expect(mapped.currency, 'INR');
      expect(mapped.amount, 1000000.0);
    });

    test('after the start-up prompt was dismissed 3 times, a change still '
        'asks first and stamps only on yes', () async {
      final backfill = container.read(legacyCurrencyBackfillServiceProvider)!;
      for (var i = 0; i < 3; i++) {
        await backfill.recordPromptDismissed();
      }
      expect(backfill.mayPromptAtStart, isFalse);

      await container
          .read(currencySwitchProvider.notifier)
          .switchCurrencyImmediate('USD', askLegacyCurrency: answer(true));

      expect(asked, ['INR']);
      expect(firestore.stored('cashflows', 'cf-1')!['currency'], 'INR');
      expect(container.read(currencyCodeProvider), 'USD');
    });

    test('no (fresh install, device default INR is wrong): the change applies '
        'without an INR stamp', () async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container.dispose();
      container = makeContainer();
      expect(container.read(currencyCodeProvider), 'INR');

      await container
          .read(currencySwitchProvider.notifier)
          .switchCurrencyImmediate('USD', askLegacyCurrency: answer(false));

      expect(asked, ['INR']);
      expect(container.read(currencySwitchProvider).isSuccess, isTrue);
      expect(container.read(currencyCodeProvider), 'USD');
      expect(
        firestore.stored('cashflows', 'cf-1')!.containsKey('currency'),
        isFalse,
      );
      // The user said the records are not INR: they follow the new currency.
      final mapped = FirestoreInvestmentRepository.cashFlowFromFirestore(
        firestore.stored('cashflows', 'cf-1')!,
        'cf-1',
        baseCurrency: container.read(currencyCodeProvider),
      );
      expect(mapped.currency, 'USD');
    });

    test('cancel: the change is not applied and nothing is stamped', () async {
      await container
          .read(currencySwitchProvider.notifier)
          .switchCurrencyImmediate('USD', askLegacyCurrency: answer(null));

      expect(asked, ['INR']);
      expect(container.read(currencySwitchProvider).isFailed, isFalse);
      expect(container.read(currencySwitchProvider).isSuccess, isFalse);
      expect(container.read(currencyCodeProvider), 'INR');
      expect(prefs.getString('currency'), 'INR');
      expect(
        firestore.stored('cashflows', 'cf-1')!.containsKey('currency'),
        isFalse,
      );
    });

    test('no way to ask: the change is not applied', () async {
      await container
          .read(currencySwitchProvider.notifier)
          .switchCurrencyImmediate('USD');

      expect(container.read(currencyCodeProvider), 'INR');
      expect(
        firestore.stored('cashflows', 'cf-1')!.containsKey('currency'),
        isFalse,
      );
    });

    test('no records without a currency: nothing is asked', () async {
      firestore.put('cashflows', 'cf-1', {
        ...legacyFdInvest(),
        'currency': 'INR',
      });
      firestore.put('investments', 'fd', {'name': 'FD', 'currency': 'INR'});

      await container
          .read(currencySwitchProvider.notifier)
          .switchCurrencyImmediate('USD', askLegacyCurrency: answer(true));

      expect(asked, isEmpty);
      expect(container.read(currencySwitchProvider).isSuccess, isTrue);
      expect(container.read(currencyCodeProvider), 'USD');
    });

    // Each question waits until the test answers it.
    final gates = <Completer<bool?>>[];
    Future<bool?> gated(String currency) {
      asked.add(currency);
      final gate = Completer<bool?>();
      gates.add(gate);
      return gate.future;
    }

    test('overlapping changes: a second change is refused while the first '
        'asks, so a stale question can never override the answer', () async {
      gates.clear();
      keepAlive();
      final notifier = container.read(currencySwitchProvider.notifier);
      final first = notifier.switchCurrencyImmediate(
        'USD',
        askLegacyCurrency: gated,
      );
      await pumpEventQueue();
      expect(asked, ['INR']);
      // The tile is disabled while the question is open.
      expect(container.read(currencySwitchProvider).isBusy, isTrue);

      final second = notifier.switchCurrencyImmediate(
        'EUR',
        askLegacyCurrency: gated,
      );
      await pumpEventQueue();
      expect(asked, ['INR'], reason: 'the second change must not ask');

      // No: the records are not INR, so they follow USD.
      gates[0].complete(false);
      await first;
      // If a stale "shown in INR" question was asked anyway, answer it yes.
      for (final gate in gates.skip(1)) {
        gate.complete(true);
      }
      await second;

      expect(asked, ['INR']);
      expect(container.read(currencyCodeProvider), 'USD');
      expect(
        firestore.stored('cashflows', 'cf-1')!.containsKey('currency'),
        isFalse,
      );
      expect(
        container
            .read(legacyCurrencyBackfillServiceProvider)!
            .confirmedCurrency,
        isNull,
      );
    });

    test('base currency changed elsewhere while the question is open: the '
        'answer about INR stamps and confirms nothing', () async {
      gates.clear();
      keepAlive();
      final first = container
          .read(currencySwitchProvider.notifier)
          .switchCurrencyImmediate('USD', askLegacyCurrency: gated);
      await pumpEventQueue();
      expect(asked, ['INR']);

      await container.read(settingsProvider.notifier).setCurrency('GBP');
      gates[0].complete(true);
      await first;

      expect(container.read(currencyCodeProvider), 'GBP');
      expect(container.read(currencySwitchProvider).isSuccess, isFalse);
      expect(
        firestore.stored('cashflows', 'cf-1')!.containsKey('currency'),
        isFalse,
      );
      expect(
        container
            .read(legacyCurrencyBackfillServiceProvider)!
            .confirmedCurrency,
        isNull,
      );
    });

    test('another user signed in while the question is open: the answer is '
        'not saved or used for either user', () async {
      gates.clear();
      final userA = LegacyCurrencyBackfillService(
        firestore: firestore,
        userId: firestore.uid,
        prefs: prefs,
      );
      final firestoreB = FakeLegacyCurrencyFirestore(uid: 'uid-b')
        ..put('cashflows', 'cf-b', legacyFdInvest());
      final userB = LegacyCurrencyBackfillService(
        firestore: firestoreB,
        userId: 'uid-b',
        prefs: prefs,
      );
      var current = userA;
      container.dispose();
      container = makeContainer(backfill: () => current);
      keepAlive();

      final first = container
          .read(currencySwitchProvider.notifier)
          .switchCurrencyImmediate('USD', askLegacyCurrency: gated);
      await pumpEventQueue();
      expect(asked, ['INR']);

      current = userB;
      container.invalidate(legacyCurrencyBackfillServiceProvider);
      gates[0].complete(true);
      await first;

      expect(userA.confirmedCurrency, isNull);
      expect(userB.confirmedCurrency, isNull);
      expect(
        firestore.stored('cashflows', 'cf-1')!.containsKey('currency'),
        isFalse,
      );
      expect(
        firestoreB.stored('cashflows', 'cf-b')!.containsKey('currency'),
        isFalse,
      );
      expect(container.read(currencyCodeProvider), 'INR');
    });

    test('the check for such records fails: the change is blocked', () async {
      firestore.readError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      await container
          .read(currencySwitchProvider.notifier)
          .switchCurrencyImmediate('USD', askLegacyCurrency: answer(true));

      expect(asked, isEmpty);
      final status = container.read(currencySwitchProvider);
      expect(status.isFailed, isTrue);
      expect(status.unstampedLegacyCurrency, 'INR');
      expect(container.read(currencyCodeProvider), 'INR');
    });
  });

  test('base currency changed elsewhere during stamping: the change does not '
      'overwrite it', () async {
    firestore.readGate = Completer<void>();
    keepAlive();
    final first = container
        .read(currencySwitchProvider.notifier)
        .switchCurrencyImmediate('USD');
    await pumpEventQueue();

    await container.read(settingsProvider.notifier).setCurrency('GBP');
    firestore.readGate!.complete();
    await first;

    expect(container.read(currencyCodeProvider), 'GBP');
    expect(container.read(currencySwitchProvider).isSuccess, isFalse);
    // The user confirmed INR for these records, so the stamp itself is right.
    expect(firestore.stored('cashflows', 'cf-1')!['currency'], 'INR');
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

      final asked = <String>[];
      await container
          .read(currencySwitchProvider.notifier)
          .switchCurrencyImmediate(
            'EUR',
            askLegacyCurrency: (currency) async {
              asked.add(currency);
              return false;
            },
          );

      // This user is asked instead of inheriting the other user's answer.
      expect(asked, ['USD']);
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

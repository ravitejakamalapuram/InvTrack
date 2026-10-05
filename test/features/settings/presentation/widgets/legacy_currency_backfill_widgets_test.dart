// A03-F1: the one-time stamp runs after sign-in, only with a currency the
// user confirmed for their account, and a base-currency change
// that could not stamp legacy records tells the user why it was not applied.
// A user who never confirmed is asked again when changing currency.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/services/legacy_currency_backfill_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/currency_switch_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/legacy_currency_backfill_initializer.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_legacy_currency_firestore.dart';

Widget _localized(Widget Function(AppLocalizations l10n) build) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(builder: (context) => build(AppLocalizations.of(context))),
  ),
);

void main() {
  group('currencySwitchFailureMessage', () {
    testWidgets('explains a blocked change when legacy records could not be '
        'stamped', (tester) async {
      const status = CurrencySwitchStatus.failed(
        targetCurrency: 'USD',
        unstampedLegacyCurrency: 'INR',
      );
      await tester.pumpWidget(
        _localized((l10n) => Text(currencySwitchFailureMessage(l10n, status))),
      );

      const expected =
          'Currency not changed to USD. Older records saved without a '
          'currency must first be marked as INR so their amounts stay '
          'correct, and that could not be finished. Connect to the internet '
          'and try again.';
      expect(find.text(expected), findsOneWidget);
      expect(find.bySemanticsLabel(expected), findsOneWidget);
    });

    testWidgets('keeps the generic message for other failures', (tester) async {
      const status = CurrencySwitchStatus.failed(targetCurrency: 'USD');
      await tester.pumpWidget(
        _localized((l10n) => Text(currencySwitchFailureMessage(l10n, status))),
      );

      expect(
        find.text('Failed to switch to USD. Please try again.'),
        findsOneWidget,
      );
    });
  });

  group('LegacyCurrencyBackfillInitializer', () {
    late FakeLegacyCurrencyFirestore firestore;
    late SharedPreferences prefs;

    const title = 'Older records have no currency';
    String message(String c) =>
        'Some records were saved before the app supported currencies. They '
        'are shown in $c now. If they were entered in $c, mark them so they '
        'stay in $c when you change your currency. If not, choose Not Now '
        'and change your currency in Settings first.';

    Future<void> startWith(Map<String, Object> initialPrefs) async {
      SharedPreferences.setMockInitialValues(initialPrefs);
      prefs = await SharedPreferences.getInstance();
    }

    setUp(() async {
      await startWith({});
      firestore = FakeLegacyCurrencyFirestore()
        ..put('cashflows', 'cf-1', {'amount': 10.0})
        ..put('goals', 'g-1', {'name': 'x', 'currency': 'USD'});
    });

    Widget app(
      LegacyCurrencyBackfillService? service, {
      bool switchRunning = false,
    }) => ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        securityProvider.overrideWith(_Unlocked.new),
        legacyCurrencyBackfillServiceProvider.overrideWithValue(service),
        if (switchRunning) currencySwitchProvider.overrideWith(_BusySwitch.new),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LegacyCurrencyBackfillInitializer(child: SizedBox()),
      ),
    );

    LegacyCurrencyBackfillService service() => LegacyCurrencyBackfillService(
      firestore: firestore,
      userId: firestore.uid,
      prefs: prefs,
    );

    bool cashFlowStamped() =>
        firestore.stored('cashflows', 'cf-1')!.containsKey('currency');

    testWidgets('fresh install: stamps nothing with the device default INR '
        'and asks first', (tester) async {
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();

      expect(cashFlowStamped(), isFalse);
      expect(service().isComplete, isFalse);
      expect(find.text(title), findsOneWidget);
      expect(find.text(message('INR')), findsOneWidget);
      expect(find.bySemanticsLabel(message('INR')), findsOneWidget);
      expect(find.text('Mark as INR'), findsOneWidget);
    });

    testWidgets('Not Now stamps nothing and asks again on the next start', (
      tester,
    ) async {
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      expect(cashFlowStamped(), isFalse);
      expect(service().confirmedCurrency, isNull);
      expect(service().isComplete, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    });

    testWidgets('confirming stamps the shown currency once', (tester) async {
      await startWith({'currency': 'GBP'});
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();
      expect(find.text(message('GBP')), findsOneWidget);

      await tester.tap(find.text('Mark as GBP'));
      await tester.pumpAndSettle();

      expect(firestore.stored('cashflows', 'cf-1')!['currency'], 'GBP');
      expect(firestore.stored('goals', 'g-1')!['currency'], 'USD');
      expect(service().confirmedCurrency, 'GBP');
      expect(service().isComplete, isTrue);

      // A later start neither asks nor rescans.
      final reads = firestore.readOptions.length;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
      expect(firestore.readOptions.length, reads);
    });

    testWidgets('a confirmed user is stamped without asking again', (
      tester,
    ) async {
      await startWith({'currency': 'GBP'});
      await service().confirm('GBP');
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      expect(firestore.stored('cashflows', 'cf-1')!['currency'], 'GBP');
    });

    testWidgets("shared device: another user's confirmation is not used", (
      tester,
    ) async {
      await startWith({'currency': 'USD'});
      await LegacyCurrencyBackfillService(
        firestore: FakeLegacyCurrencyFirestore(uid: 'uid-a'),
        userId: 'uid-a',
        prefs: prefs,
      ).confirm('USD');
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();

      expect(cashFlowStamped(), isFalse);
      expect(find.text(message('USD')), findsOneWidget);
    });

    testWidgets('a base-currency change is running: the start-up question is '
        'not stacked over its own question', (tester) async {
      await tester.pumpWidget(app(service(), switchRunning: true));
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      expect(cashFlowStamped(), isFalse);
      expect(service().confirmedCurrency, isNull);
      expect(service().promptDismissals, 0);
    });

    testWidgets('no legacy records: never asks', (tester) async {
      firestore = FakeLegacyCurrencyFirestore()
        ..put('goals', 'g-1', {'name': 'x', 'currency': 'USD'});
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      expect(service().isComplete, isTrue);
    });

    testWidgets('offline: neither asks nor stamps, and retries on the next '
        'start', (tester) async {
      firestore.readError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
      expect(cashFlowStamped(), isFalse);
      expect(service().isComplete, isFalse);

      firestore.readError = null;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    });

    testWidgets('signed out: does nothing', (tester) async {
      await tester.pumpWidget(app(null));
      await tester.pumpAndSettle();
      expect(firestore.readOptions, isEmpty);
    });

    // A base currency the test can change while the start-up check runs,
    // standing in for a switch made in Settings.
    final testCurrency = NotifierProvider<_TestCurrency, String>(
      _TestCurrency.new,
    );
    Widget appWithCurrency(LegacyCurrencyBackfillService service) =>
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            securityProvider.overrideWith(_Unlocked.new),
            legacyCurrencyBackfillServiceProvider.overrideWithValue(service),
            currencyCodeProvider.overrideWith((ref) => ref.watch(testCurrency)),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LegacyCurrencyBackfillInitializer(child: SizedBox()),
          ),
        );
    void switchTo(WidgetTester tester, String currency) =>
        ProviderScope.containerOf(
          tester.element(find.byType(SizedBox).first),
        ).read(testCurrency.notifier).set(currency);

    testWidgets('a currency change during the server scan: does not ask about, '
        'or stamp, the old currency', (tester) async {
      firestore.readGate = Completer<void>();
      await tester.pumpWidget(appWithCurrency(service()));
      await tester.pump();

      // The user switches INR to USD in Settings while the scan is running.
      switchTo(tester, 'USD');
      await tester.pump();
      firestore.readGate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('Mark as INR'), findsNothing);
      expect(find.text(message('INR')), findsNothing);
      expect(cashFlowStamped(), isFalse);
      expect(service().confirmedCurrency, isNull);
    });

    testWidgets('a currency change while the prompt is open: confirming the '
        'old currency stamps nothing', (tester) async {
      await tester.pumpWidget(appWithCurrency(service()));
      await tester.pumpAndSettle();
      expect(find.text('Mark as INR'), findsOneWidget);

      switchTo(tester, 'USD');
      await tester.pump();
      await tester.tap(find.text('Mark as INR'));
      await tester.pumpAndSettle();

      expect(cashFlowStamped(), isFalse);
      expect(service().confirmedCurrency, isNull);
      expect(service().isComplete, isFalse);
    });

    testWidgets('asks at most once per app session, even after signing out '
        'and in again', (tester) async {
      final holder =
          NotifierProvider<_ServiceHolder, LegacyCurrencyBackfillService?>(
            _ServiceHolder.new,
          );
      _ServiceHolder.initial = service();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            securityProvider.overrideWith(_Unlocked.new),
            legacyCurrencyBackfillServiceProvider.overrideWith(
              (ref) => ref.watch(holder),
            ),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LegacyCurrencyBackfillInitializer(child: SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SizedBox).first),
      );
      container.read(holder.notifier).set(null);
      await tester.pumpAndSettle();
      container.read(holder.notifier).set(service());
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
    });

    // Signs user A out and user B in on the same device. B has no records
    // without a currency, so any question shown is about A's records.
    Future<void> switchUserToB(WidgetTester tester) async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SizedBox).first),
      );
      final holder = _ServiceHolder.provider;
      container.read(holder.notifier).set(null);
      await tester.pump();
      container
          .read(holder.notifier)
          .set(
            LegacyCurrencyBackfillService(
              firestore: FakeLegacyCurrencyFirestore(uid: 'uid-b'),
              userId: 'uid-b',
              prefs: prefs,
            ),
          );
      await tester.pump();
    }

    Widget appWithUserSwitch() {
      _ServiceHolder.initial = service();
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          securityProvider.overrideWith(_Unlocked.new),
          legacyCurrencyBackfillServiceProvider.overrideWith(
            (ref) => ref.watch(_ServiceHolder.provider),
          ),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LegacyCurrencyBackfillInitializer(child: SizedBox()),
        ),
      );
    }

    testWidgets('a user switch during the server scan: B is not asked about '
        "A's records and nothing is stored for A", (tester) async {
      firestore.readGate = Completer<void>();
      await tester.pumpWidget(appWithUserSwitch());
      await tester.pump();

      await switchUserToB(tester);
      firestore.readGate!.complete();
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      expect(service().confirmedCurrency, isNull);
      expect(service().promptDismissals, 0);
      expect(cashFlowStamped(), isFalse);
    });

    testWidgets("a user switch while A's question is open: B's answer is not "
        "stored as A's", (tester) async {
      await tester.pumpWidget(appWithUserSwitch());
      await tester.pumpAndSettle();
      expect(find.text('Mark as INR'), findsOneWidget);

      await switchUserToB(tester);
      await tester.tap(find.text('Mark as INR'));
      await tester.pumpAndSettle();

      expect(service().confirmedCurrency, isNull);
      expect(service().promptDismissals, 0);
      expect(cashFlowStamped(), isFalse);
    });

    testWidgets('stops asking at start after 3 dismissals, per user', (
      tester,
    ) async {
      for (var i = 0; i < 2; i++) {
        await service().recordPromptDismissed();
      }
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();
      expect(service().promptDismissals, 3);
      expect(service().mayPromptAtStart, isFalse);

      // Next start: no prompt and no server scan.
      final reads = firestore.readOptions.length;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
      expect(firestore.readOptions.length, reads);
      expect(cashFlowStamped(), isFalse);

      // Another user on this device still gets asked.
      expect(
        LegacyCurrencyBackfillService(
          firestore: firestore,
          userId: 'uid-b',
          prefs: prefs,
        ).mayPromptAtStart,
        isTrue,
      );
    });

    testWidgets('tapping outside the prompt counts as a dismissal', (
      tester,
    ) async {
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
      expect(service().promptDismissals, 1);
      expect(cashFlowStamped(), isFalse);
    });

    testWidgets('a base-currency change starts while the prompt is open: Not '
        'Now is not counted as a dismissal', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            securityProvider.overrideWith(_Unlocked.new),
            legacyCurrencyBackfillServiceProvider.overrideWithValue(service()),
            currencySwitchProvider.overrideWith(_LateSwitch.new),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LegacyCurrencyBackfillInitializer(child: SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);

      // A change queued before the prompt opened starts now and is still
      // checking records, so the base currency is still INR.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LegacyCurrencyBackfillInitializer)),
      );
      (container.read(currencySwitchProvider.notifier) as _LateSwitch)
          .startChecking();
      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(service().promptDismissals, 0);
      expect(service().mayPromptAtStart, isTrue);
      expect(cashFlowStamped(), isFalse);
      expect(service().confirmedCurrency, isNull);
    });
  });

  group('askLegacyCurrencyBeforeSwitch', () {
    const message =
        'Your older records are shown in INR. Were they entered in INR? If '
        'yes, they stay in INR after you change to USD. If no, they will be '
        'shown in USD.';

    Future<List<bool?>> ask(
      WidgetTester tester,
      Future<void> Function() respond,
    ) async {
      final answers = <bool?>[];
      await tester.pumpWidget(
        _localized(
          (_) => Builder(
            builder: (context) => TextButton(
              onPressed: () async => answers.add(
                await askLegacyCurrencyBeforeSwitch(
                  context,
                  currency: 'INR',
                  newCurrency: 'USD',
                ),
              ),
              child: const Text('change'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('change'));
      await tester.pumpAndSettle();

      expect(find.text('Older records have no currency'), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.bySemanticsLabel(message), findsOneWidget);
      expect(find.text('Yes, INR'), findsOneWidget);
      expect(find.text('No, show in USD'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await respond();
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
      return answers;
    }

    testWidgets('yes', (tester) async {
      expect(await ask(tester, () => tester.tap(find.text('Yes, INR'))), [
        true,
      ]);
    });

    testWidgets('no', (tester) async {
      expect(
        await ask(tester, () => tester.tap(find.text('No, show in USD'))),
        [false],
      );
    });

    testWidgets('cancel', (tester) async {
      expect(await ask(tester, () => tester.tap(find.text('Cancel'))), [null]);
    });

    testWidgets('tapping outside cancels the change', (tester) async {
      expect(await ask(tester, () => tester.tapAt(const Offset(5, 5))), [null]);
    });
  });
}

class _TestCurrency extends Notifier<String> {
  @override
  String build() => 'INR';

  void set(String currency) => state = currency;
}

class _ServiceHolder extends Notifier<LegacyCurrencyBackfillService?> {
  static LegacyCurrencyBackfillService? initial;

  static final provider =
      NotifierProvider<_ServiceHolder, LegacyCurrencyBackfillService?>(
        _ServiceHolder.new,
      );

  @override
  LegacyCurrencyBackfillService? build() => initial;

  void set(LegacyCurrencyBackfillService? service) => state = service;
}

/// A base-currency change that is checking older records (its own question
/// may be open).
class _BusySwitch extends CurrencySwitch {
  @override
  CurrencySwitchStatus build() =>
      const CurrencySwitchStatus.checkingRecords(targetCurrency: 'USD');
}

/// A base-currency change that starts after the start-up question opened.
class _LateSwitch extends CurrencySwitch {
  @override
  CurrencySwitchStatus build() => const CurrencySwitchStatus.idle();

  void startChecking() =>
      state = const CurrencySwitchStatus.checkingRecords(targetCurrency: 'USD');
}

/// No PIN set. The question waits while the app is locked (A113), and the
/// real notifier reads as locked here, with no secure storage in tests.
class _Unlocked extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
}

// A04: users whose investments were saved as US dollars by mistake (merge,
// CSV import or restore before A03) are asked once, after sign-in, whether
// those investments were in their base currency. Nothing is rewritten
// without a Change answer, only ticked investments change, and the change
// can be undone from the snackbar or from Data & Account.
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/services/legacy_currency_backfill_service.dart';
import 'package:inv_tracker/features/settings/data/services/usd_tag_repair_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/currency_switch_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/legacy_currency_backfill_initializer.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/usd_tag_repair_prompt.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_legacy_currency_firestore.dart';
import '../../../../mocks/mock_analytics_service.dart';

void main() {
  late FakeLegacyCurrencyFirestore firestore;
  late SharedPreferences prefs;
  late FakeAnalyticsService analytics;

  const title = 'Investments recorded in US dollars';
  const message =
      'We found 2 investments recorded in US dollars. Were these in ₹ (INR)?';
  const detail =
      'Older versions of the app could save amounts as US dollars by '
      'mistake when importing, merging or restoring. Changing the currency '
      'keeps every amount as it is. You can undo it on this device in '
      'Settings > Data & Account.';

  Future<void> startWith(Map<String, Object> initialPrefs) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    prefs = await SharedPreferences.getInstance();
  }

  setUp(() async {
    await startWith({});
    analytics = FakeAnalyticsService();
    firestore = FakeLegacyCurrencyFirestore()
      ..put('investments', 'inv-merged', {
        'name': 'Merged FD',
        'notes': 'Merged from: FD A, FD B',
        'currency': 'USD',
      })
      ..put('cashflows', 'cf-m1', {
        'investmentId': 'inv-merged',
        'type': 'INVEST',
        'amount': 500000.0,
        'currency': 'USD',
      })
      ..put('cashflows', 'cf-m2', {
        'investmentId': 'inv-merged',
        'type': 'INVEST',
        'amount': 300000.0,
        'currency': 'USD',
      })
      ..put('investments', 'inv-imported', {
        'name': 'Imported bond',
        'currency': 'USD',
      })
      ..put('cashflows', 'cf-i1', {
        'investmentId': 'inv-imported',
        'type': 'INVEST',
        'amount': 100000.0,
        'currency': 'USD',
      })
      ..put('investments', 'inv-inr', {'name': 'SBI FD', 'currency': 'INR'})
      ..put('cashflows', 'cf-r1', {
        'investmentId': 'inv-inr',
        'type': 'INVEST',
        'amount': 200000.0,
        'currency': 'INR',
      });
  });

  UsdTagRepairService service([String? uid]) => UsdTagRepairService(
    firestore: firestore,
    userId: uid ?? firestore.uid,
    prefs: prefs,
  );

  String? currencyOf(String collection, String id) =>
      firestore.stored(collection, id)!['currency'] as String?;

  // A base currency the test can change, standing in for Settings.
  final testCurrency = NotifierProvider<_TestCurrency, String>(
    _TestCurrency.new,
  );

  Widget app({
    UsdTagRepairService? repair,
    bool useHolder = false,
    LegacyCurrencyBackfillService? legacy,
    bool switchRunning = false,
    bool controllableCurrency = false,
    bool locked = false,
    bool withLegacyInitializer = false,
  }) => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      securityProvider.overrideWith(
        locked ? _TestSecurity.locked : _TestSecurity.new,
      ),
      analyticsServiceProvider.overrideWithValue(analytics),
      if (useHolder)
        usdTagRepairServiceProvider.overrideWith(
          (ref) => ref.watch(_ServiceHolder.provider),
        )
      else
        usdTagRepairServiceProvider.overrideWithValue(repair),
      legacyCurrencyBackfillServiceProvider.overrideWithValue(legacy),
      if (switchRunning) currencySwitchProvider.overrideWith(_BusySwitch.new),
      if (controllableCurrency)
        currencyCodeProvider.overrideWith((ref) => ref.watch(testCurrency)),
    ],
    child: MaterialApp(
      navigatorKey: rootNavigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // As in app.dart: the question about records without a currency wraps
      // this one.
      home: Scaffold(
        body: withLegacyInitializer
            ? const LegacyCurrencyBackfillInitializer(
                child: UsdTagRepairInitializer(child: SizedBox()),
              )
            : const UsdTagRepairInitializer(child: SizedBox()),
      ),
    ),
  );

  Future<void> restart(WidgetTester tester, Widget next) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(next);
    await tester.pumpAndSettle();
  }

  bool? ticked(WidgetTester tester, String name) => tester
      .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, name))
      .value;

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SizedBox).first));

  group('UsdTagRepairInitializer', () {
    testWidgets('asks once, naming the count and the base currency, and '
        'previews the investments without amounts', (tester) async {
      await tester.pumpWidget(app(repair: service()));
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.bySemanticsLabel(message), findsOneWidget);
      expect(find.text(detail), findsOneWidget);
      expect(find.text('Imported bond'), findsOneWidget);
      expect(find.text('1 cash flow'), findsOneWidget);
      expect(find.text('Merged FD'), findsOneWidget);
      expect(find.text('2 cash flows · Merged'), findsOneWidget);
      expect(find.text('SBI FD'), findsNothing);
      expect(find.text('Keep in US dollars'), findsOneWidget);
      expect(find.text('Change to INR'), findsOneWidget);
      // Only merged investments start ticked: the app's own merge is the one
      // case known to have written US dollars. An imported investment may
      // really be in US dollars, so the user ticks it.
      expect(ticked(tester, 'Merged FD'), isTrue);
      expect(ticked(tester, 'Imported bond'), isFalse);
      // No amount appears in the preview, so privacy mode has nothing to
      // hide here.
      expect(find.textContaining(RegExp(r'\d{3}')), findsNothing);
      expect(currencyOf('cashflows', 'cf-m1'), 'USD');
      expect(firestore.transactionCount, 0);
      expect(analytics.loggedEvents, hasLength(1));
      expect(analytics.loggedEvents.single.name, 'usd_tag_repair');
      expect(analytics.loggedEvents.single.parameters, {
        'action': 'prompted',
        'flagged': 2,
        'fixed': 0,
      });
    });

    testWidgets('Change rewrites only the ticked investments, logs counts '
        'only, and is not asked again', (tester) async {
      await tester.pumpWidget(app(repair: service()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change to INR'));
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      expect(currencyOf('investments', 'inv-merged'), 'INR');
      expect(currencyOf('cashflows', 'cf-m1'), 'INR');
      expect(currencyOf('cashflows', 'cf-m2'), 'INR');
      expect(firestore.stored('cashflows', 'cf-m1')!['amount'], 500000.0);
      expect(currencyOf('investments', 'inv-imported'), 'USD');
      expect(currencyOf('cashflows', 'cf-i1'), 'USD');
      expect(find.text('1 investment changed to INR.'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(analytics.loggedEvents.last.name, 'usd_tag_repair');
      expect(analytics.loggedEvents.last.parameters, {
        'action': 'fixed',
        'flagged': 2,
        'fixed': 1,
      });
      expect(service().isResolved, isTrue);

      final reads = firestore.readOptions.length;
      await restart(tester, app(repair: service()));
      expect(find.text(title), findsNothing);
      expect(firestore.readOptions.length, reads);
    });

    testWidgets('an investment changed elsewhere before Change is not '
        'counted as fixed', (tester) async {
      await tester.pumpWidget(app(repair: service()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Imported bond'));
      await tester.pump();
      // Another device sets the imported bond's cash flow to INR while the
      // question is open; the repair re-reads it and leaves that investment
      // alone.
      firestore.put('cashflows', 'cf-i1', {
        'investmentId': 'inv-imported',
        'type': 'INVEST',
        'amount': 100000.0,
        'currency': 'INR',
      });
      await tester.tap(find.text('Change to INR'));
      await tester.pumpAndSettle();

      expect(currencyOf('investments', 'inv-merged'), 'INR');
      expect(currencyOf('investments', 'inv-imported'), 'USD');
      expect(find.text('1 investment changed to INR.'), findsOneWidget);
      expect(analytics.loggedEvents.last.parameters, {
        'action': 'fixed',
        'flagged': 2,
        'fixed': 1,
      });
    });

    testWidgets('Change when another device already fixed everything says '
        'nothing changed and offers no Undo', (tester) async {
      await tester.pumpWidget(app(repair: service()));
      await tester.pumpAndSettle();

      // Another device relabels the merged investment while the question is
      // open.
      for (final (collection, id) in [
        ('investments', 'inv-merged'),
        ('cashflows', 'cf-m1'),
        ('cashflows', 'cf-m2'),
      ]) {
        firestore.stored(collection, id)!['currency'] = 'INR';
      }
      await tester.tap(find.text('Change to INR'));
      await tester.pumpAndSettle();

      expect(find.text('0 investments changed to INR.'), findsNothing);
      expect(
        find.text(
          'Nothing needed changing. These investments are no longer '
          'recorded in US dollars.',
        ),
        findsOneWidget,
      );
      expect(find.text('Undo'), findsNothing);
      expect(analytics.loggedEvents.last.parameters, {
        'action': 'fixed',
        'flagged': 2,
        'fixed': 0,
      });
      expect(service().isResolved, isTrue);
    });

    testWidgets('the count after Change leaves out entries from an earlier '
        'interrupted run', (tester) async {
      // Process death after an earlier backup was saved, before its write.
      await prefs.setString(
        'usd_tag_repair_backup_${firestore.uid}',
        jsonEncode([
          {
            'c': 'cashflows',
            'id': 'cf-i1',
            'inv': 'inv-imported',
            'from': 'USD',
            'to': 'INR',
          },
        ]),
      );
      await tester.pumpWidget(app(repair: service()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change to INR'));
      await tester.pumpAndSettle();

      expect(currencyOf('cashflows', 'cf-i1'), 'USD');
      expect(find.text('1 investment changed to INR.'), findsOneWidget);
      expect(analytics.loggedEvents.last.parameters, {
        'action': 'fixed',
        'flagged': 2,
        'fixed': 1,
      });
    });

    testWidgets('Change is disabled when nothing is ticked', (tester) async {
      await tester.pumpWidget(app(repair: service()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Merged FD'));
      await tester.pump();
      await tester.tap(find.text('Change to INR'));
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
      expect(firestore.transactionCount, 0);
    });

    testWidgets('Undo in the snackbar puts back US dollars', (tester) async {
      await tester.pumpWidget(app(repair: service()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Imported bond'));
      await tester.pump();
      await tester.tap(find.text('Change to INR'));
      await tester.pumpAndSettle();
      expect(find.text('2 investments changed to INR.'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(currencyOf('investments', 'inv-merged'), 'USD');
      expect(currencyOf('cashflows', 'cf-m1'), 'USD');
      expect(currencyOf('cashflows', 'cf-i1'), 'USD');
      expect(service().hasBackup, isFalse);
      expect(find.text('The US dollar fix was undone.'), findsOneWidget);
      expect(analytics.loggedEvents.last.parameters, {
        'action': 'undone',
        'investments': 2,
      });
    });

    testWidgets('Keep writes nothing and is not asked again', (tester) async {
      await tester.pumpWidget(app(repair: service()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep in US dollars'));
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      expect(firestore.transactionCount, 0);
      expect(service().isResolved, isTrue);
      expect(service().hasBackup, isFalse);
      expect(analytics.loggedEvents.last.parameters, {
        'action': 'kept',
        'flagged': 2,
        'fixed': 0,
      });

      final reads = firestore.readOptions.length;
      await restart(tester, app(repair: service()));
      expect(find.text(title), findsNothing);
      expect(firestore.readOptions.length, reads);
    });

    testWidgets('Keep is remembered for the account: a new install or phone '
        'is not asked again', (tester) async {
      await tester.pumpWidget(app(repair: service()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep in US dollars'));
      await tester.pumpAndSettle();
      expect(firestore.userFields, contains(UsdTagRepairService.resolvedField));

      // Reinstall: this device's preferences are gone (allowBackup is off).
      await startWith({});
      await restart(tester, app(repair: service()));

      expect(find.text(title), findsNothing);
      expect(find.text('Merged FD'), findsNothing);
      expect(firestore.transactionCount, 0);
      expect(service().isResolved, isTrue);
    });

    testWidgets('answered on another device: one read of the answer, no '
        'scan, no question', (tester) async {
      firestore.userFields = {
        UsdTagRepairService.resolvedField: DateTime.utc(2026, 10, 2),
      };
      await tester.pumpWidget(app(repair: service()));
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      expect(firestore.userDocReadOptions, hasLength(1));
      expect(firestore.userDocReadOptions.single?.source, Source.server);
      expect(firestore.readOptions, isEmpty);
    });

    testWidgets('closing the question without an answer asks again on the '
        'next start, not in the same session', (tester) async {
      await tester.pumpWidget(app(repair: service()));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
      expect(service().isResolved, isFalse);
      expect(firestore.transactionCount, 0);

      await restart(tester, app(repair: service()));
      expect(find.text(title), findsOneWidget);
    });

    testWidgets('base currency USD: never asks and reads nothing', (
      tester,
    ) async {
      await startWith({'currency': 'USD'});
      await tester.pumpWidget(app(repair: service()));
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      expect(firestore.readOptions, isEmpty);
      // A later change to a non-USD currency can still ask.
      expect(service().isResolved, isFalse);
    });

    testWidgets('nothing wrongly tagged: records the check and does not scan '
        'again', (tester) async {
      firestore.data.remove('investments');
      firestore.data.remove('cashflows');
      await tester.pumpWidget(app(repair: service()));
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      expect(service().isResolved, isTrue);
      expect(analytics.loggedEvents, isEmpty);
    });

    testWidgets('offline: asks nothing, records nothing, and asks on the '
        'next start', (tester) async {
      firestore.readError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await tester.pumpWidget(app(repair: service()));
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
      expect(service().isResolved, isFalse);

      firestore.readError = null;
      await restart(tester, app(repair: service()));
      expect(find.text(title), findsOneWidget);
    });

    testWidgets('a failed change says so, is not recorded as answered, and '
        'is asked again on the next start', (tester) async {
      await tester.pumpWidget(app(repair: service()));
      await tester.pumpAndSettle();
      firestore.transactionError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      await tester.tap(find.text('Change to INR'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not finish changing the currency. Check your connection. '
          'We will ask again the next time the app starts.',
        ),
        findsOneWidget,
      );
      expect(currencyOf('cashflows', 'cf-m1'), 'USD');
      expect(service().isResolved, isFalse);

      firestore.transactionError = null;
      await restart(tester, app(repair: service()));
      expect(find.text(title), findsOneWidget);
    });

    testWidgets('the question about records without a currency goes first', (
      tester,
    ) async {
      firestore.put('cashflows', 'cf-legacy', {
        'investmentId': 'inv-inr',
        'amount': 10.0,
      });
      final legacy = LegacyCurrencyBackfillService(
        firestore: firestore,
        userId: firestore.uid,
        prefs: prefs,
      );
      await tester.pumpWidget(
        app(repair: service(), legacy: legacy, withLegacyInitializer: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Older records have no currency'), findsOneWidget);
      expect(find.text(title), findsNothing);
      // One shared check (investments, then cash flows, where it stops); the
      // US dollar scan never ran.
      expect(firestore.readOptions, hasLength(2));
      expect(service().isResolved, isFalse);
    });

    testWidgets('first start after the update, no records without a '
        'currency: asks on this start, after one shared check', (tester) async {
      final legacy = LegacyCurrencyBackfillService(
        firestore: firestore,
        userId: firestore.uid,
        prefs: prefs,
      );
      expect(legacy.isComplete, isFalse);
      await tester.pumpWidget(
        app(repair: service(), legacy: legacy, withLegacyInitializer: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Older records have no currency'), findsNothing);
      expect(legacy.isComplete, isTrue);
      expect(find.text(title), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      // 7 collections for the currency check, read once for both questions,
      // then 4 for the US dollar scan.
      expect(firestore.readOptions, hasLength(11));
    });

    testWidgets('records without a currency already confirmed: nothing to '
        'wait for, asks on this start', (tester) async {
      firestore.put('cashflows', 'cf-legacy', {
        'investmentId': 'inv-inr',
        'amount': 10.0,
      });
      await prefs.setString(
        'legacy_currency_confirmed_${firestore.uid}',
        'INR',
      );
      final legacy = LegacyCurrencyBackfillService(
        firestore: firestore,
        userId: firestore.uid,
        prefs: prefs,
      );
      await tester.pumpWidget(app(repair: service(), legacy: legacy));
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
    });

    testWidgets('the currency check fails offline: asks nothing and asks on '
        'the next start', (tester) async {
      final legacy = LegacyCurrencyBackfillService(
        firestore: firestore,
        userId: firestore.uid,
        prefs: prefs,
      );
      firestore.readError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await tester.pumpWidget(
        app(repair: service(), legacy: legacy, withLegacyInitializer: true),
      );
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
      expect(service().isResolved, isFalse);

      firestore.readError = null;
      await restart(
        tester,
        app(repair: service(), legacy: legacy, withLegacyInitializer: true),
      );
      expect(find.text(title), findsOneWidget);
    });

    testWidgets('asks once the question about records without a currency '
        'is settled', (tester) async {
      await prefs.setBool(
        'legacy_currency_backfill_done_${firestore.uid}',
        true,
      );
      final legacy = LegacyCurrencyBackfillService(
        firestore: firestore,
        userId: firestore.uid,
        prefs: prefs,
      );
      await tester.pumpWidget(app(repair: service(), legacy: legacy));
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
    });

    testWidgets('app lock: investment names are not shown over the lock '
        'screen; asked after unlocking', (tester) async {
      await tester.pumpWidget(app(repair: service(), locked: true));
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      expect(find.text('Merged FD'), findsNothing);

      (container(tester).read(securityProvider.notifier) as _TestSecurity)
          .unlock();
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
      expect(find.text('Merged FD'), findsOneWidget);
    });

    testWidgets('removed while waiting for unlock: stops quietly and asks '
        'on the next start', (tester) async {
      await tester.pumpWidget(app(repair: service(), locked: true));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(service().isResolved, isFalse);
      await restart(tester, app(repair: service()));
      expect(find.text(title), findsOneWidget);
    });

    testWidgets('a base-currency change is running: not shown over it', (
      tester,
    ) async {
      await tester.pumpWidget(app(repair: service(), switchRunning: true));
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      expect(service().isResolved, isFalse);
    });

    testWidgets('a currency change during the scan: does not ask about the '
        'old currency', (tester) async {
      firestore.readGate = Completer<void>();
      await tester.pumpWidget(
        app(repair: service(), controllableCurrency: true),
      );
      await tester.pump();

      container(tester).read(testCurrency.notifier).set('EUR');
      await tester.pump();
      firestore.readGate!.complete();
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      expect(service().isResolved, isFalse);
    });

    testWidgets('a currency change during a scan that finds nothing: the '
        'old currency is not recorded as checked', (tester) async {
      firestore.data.remove('investments');
      firestore.data.remove('cashflows');
      firestore.readGate = Completer<void>();
      await tester.pumpWidget(
        app(repair: service(), controllableCurrency: true),
      );
      await tester.pump();

      container(tester).read(testCurrency.notifier).set('EUR');
      await tester.pump();
      firestore.readGate!.complete();
      await tester.pumpAndSettle();

      expect(service().isResolved, isFalse);
      expect(firestore.userFields, isNull);
    });

    testWidgets('a currency change while the question is open: Change '
        'writes nothing', (tester) async {
      await tester.pumpWidget(
        app(repair: service(), controllableCurrency: true),
      );
      await tester.pumpAndSettle();

      container(tester).read(testCurrency.notifier).set('EUR');
      await tester.pump();
      await tester.tap(find.text('Change to INR'));
      await tester.pumpAndSettle();

      expect(currencyOf('cashflows', 'cf-m1'), 'USD');
      expect(firestore.transactionCount, 0);
      expect(service().isResolved, isFalse);
    });

    testWidgets('another user signs in while the question is open: their '
        'data is not changed and nothing is recorded', (tester) async {
      _ServiceHolder.initial = service();
      await tester.pumpWidget(app(useHolder: true));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);

      container(
        tester,
      ).read(_ServiceHolder.provider.notifier).set(service('uid-b'));
      await tester.pump();
      await tester.tap(find.text('Change to INR'));
      await tester.pumpAndSettle();

      expect(currencyOf('cashflows', 'cf-m1'), 'USD');
      expect(firestore.transactionCount, 0);
      expect(service().isResolved, isFalse);
      expect(service('uid-b').isResolved, isFalse);
    });
  });

  group('UsdTagRepairUndoTile', () {
    Widget tileApp(UsdTagRepairService? repair) => ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        analyticsServiceProvider.overrideWithValue(analytics),
        usdTagRepairServiceProvider.overrideWithValue(repair),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: UsdTagRepairUndoTile()),
      ),
    );

    testWidgets('is hidden when there is nothing to undo', (tester) async {
      await tester.pumpWidget(tileApp(service()));
      expect(find.byType(ListTile), findsNothing);

      await tester.pumpWidget(tileApp(null));
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('undoes the fix after confirmation', (tester) async {
      await service().repair({'inv-merged', 'inv-imported'}, 'INR');
      await tester.pumpWidget(tileApp(service()));

      expect(find.text('Undo the US dollar fix'), findsOneWidget);
      expect(
        find.text('Show 2 investments in US dollars again'),
        findsOneWidget,
      );

      await tester.tap(find.text('Undo the US dollar fix'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          '2 investments will be shown in US dollars again. Their amounts '
          'do not change.',
        ),
        findsOneWidget,
      );
      // Cancel changes nothing.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(currencyOf('cashflows', 'cf-m1'), 'INR');

      await tester.tap(find.text('Undo the US dollar fix'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(currencyOf('cashflows', 'cf-m1'), 'USD');
      expect(currencyOf('cashflows', 'cf-i1'), 'USD');
      expect(find.text('Undo the US dollar fix'), findsNothing);
      expect(find.text('The US dollar fix was undone.'), findsOneWidget);
    });

    testWidgets('another user signs in while the confirmation is open: '
        'nothing is undone', (tester) async {
      await service().repair({'inv-merged'}, 'INR');
      _ServiceHolder.initial = service();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            analyticsServiceProvider.overrideWithValue(analytics),
            usdTagRepairServiceProvider.overrideWith(
              (ref) => ref.watch(_ServiceHolder.provider),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: UsdTagRepairUndoTile()),
          ),
        ),
      );
      await tester.tap(find.text('Undo the US dollar fix'));
      await tester.pumpAndSettle();

      ProviderScope.containerOf(
        tester.element(find.byType(UsdTagRepairUndoTile)),
      ).read(_ServiceHolder.provider.notifier).set(service('uid-b'));
      await tester.pump();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(currencyOf('cashflows', 'cf-m1'), 'INR');
      expect(firestore.transactionCount, 1);
      expect(service().hasBackup, isTrue);
    });

    testWidgets('a failed undo says so and keeps the tile', (tester) async {
      await service().repair({'inv-merged'}, 'INR');
      await tester.pumpWidget(tileApp(service()));
      firestore.transactionError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      await tester.tap(find.text('Undo the US dollar fix'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not undo the fix. Check your connection and try '
          'again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Undo the US dollar fix'), findsOneWidget);
      expect(currencyOf('cashflows', 'cf-m1'), 'INR');
    });
  });
}

class _TestCurrency extends Notifier<String> {
  @override
  String build() => 'INR';

  void set(String currency) => state = currency;
}

class _ServiceHolder extends Notifier<UsdTagRepairService?> {
  static UsdTagRepairService? initial;

  static final provider =
      NotifierProvider<_ServiceHolder, UsdTagRepairService?>(
        _ServiceHolder.new,
      );

  @override
  UsdTagRepairService? build() => initial;

  void set(UsdTagRepairService? service) => state = service;
}

class _TestSecurity extends SecurityNotifier {
  _TestSecurity() : _locked = false;
  _TestSecurity.locked() : _locked = true;

  final bool _locked;

  @override
  SecurityState build() => SecurityState(hasPin: _locked, isLocked: _locked);

  void unlock() => state = state.copyWith(isLocked: false);
}

class _BusySwitch extends CurrencySwitch {
  @override
  CurrencySwitchStatus build() =>
      const CurrencySwitchStatus.checkingRecords(targetCurrency: 'USD');
}

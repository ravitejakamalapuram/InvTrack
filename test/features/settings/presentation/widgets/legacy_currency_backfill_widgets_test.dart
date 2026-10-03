// A03-F1: the one-time stamp runs after sign-in, and a base-currency change
// that could not stamp legacy records tells the user why it was not applied.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
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

    setUp(() async {
      SharedPreferences.setMockInitialValues({'currency': 'GBP'});
      prefs = await SharedPreferences.getInstance();
      firestore = FakeLegacyCurrencyFirestore()
        ..put('cashflows', 'cf-1', {'amount': 10.0})
        ..put('goals', 'g-1', {'name': 'x', 'currency': 'USD'});
    });

    Widget app(LegacyCurrencyBackfillService? service) => ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        legacyCurrencyBackfillServiceProvider.overrideWithValue(service),
      ],
      child: const MaterialApp(
        home: LegacyCurrencyBackfillInitializer(child: SizedBox()),
      ),
    );

    LegacyCurrencyBackfillService service() => LegacyCurrencyBackfillService(
      firestore: firestore,
      userId: firestore.uid,
      prefs: prefs,
    );

    testWidgets('stamps with the base currency shown today, once per user', (
      tester,
    ) async {
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();

      expect(firestore.stored('cashflows', 'cf-1')!['currency'], 'GBP');
      expect(firestore.stored('goals', 'g-1')!['currency'], 'USD');
      expect(service().isComplete, isTrue);

      // A later start does not rescan.
      final reads = firestore.readOptions.length;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();
      expect(firestore.readOptions.length, reads);
    });

    testWidgets('offline: keeps the read-time fallback and retries on the '
        'next start', (tester) async {
      firestore.readError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();
      expect(
        firestore.stored('cashflows', 'cf-1')!.containsKey('currency'),
        isFalse,
      );
      expect(service().isComplete, isFalse);

      firestore.readError = null;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(service()));
      await tester.pumpAndSettle();
      expect(firestore.stored('cashflows', 'cf-1')!['currency'], 'GBP');
    });

    testWidgets('signed out: does nothing', (tester) async {
      await tester.pumpWidget(app(null));
      await tester.pumpAndSettle();
      expect(firestore.readOptions, isEmpty);
    });
  });
}

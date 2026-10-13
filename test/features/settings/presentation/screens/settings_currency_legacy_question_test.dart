// A89: drives the real Settings screen through a base-currency change while
// older records (saved without a currency) are unconfirmed. The provider and
// the dialog are tested on their own; this pins the wiring between them in
// `_CurrencyTileState._switchCurrency`, so a broken wiring cannot relabel
// users' amounts while CI stays green.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/providers/connectivity_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/services/connectivity_service.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/services/legacy_currency_backfill_service.dart';
import 'package:inv_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_auth_repository.dart';
import '../../../../mocks/fake_legacy_currency_firestore.dart';
import '../../../../mocks/mock_analytics_service.dart';

class _MockCrashlyticsService extends Mock implements CrashlyticsService {}

class _MockConversion extends Mock implements CurrencyConversionService {}

class _MockConnectivity extends Mock implements ConnectivityService {}

class _TestSecurityNotifier extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
}

void main() {
  late FakeLegacyCurrencyFirestore firestore;
  late SharedPreferences prefs;
  late ProviderContainer container;

  Future<AppLocalizations> pumpSettings(WidgetTester tester) async {
    // Base INR, never confirmed for the older records.
    SharedPreferences.setMockInitialValues({
      'currency': 'INR',
      'locale': 'en_IN',
    });
    prefs = await SharedPreferences.getInstance();
    // One cash flow saved without a currency.
    firestore = FakeLegacyCurrencyFirestore()
      ..put('investments', 'fd', {'name': 'FD'})
      ..put('cashflows', 'cf-1', {
        'investmentId': 'fd',
        'date': Timestamp.fromDate(DateTime(2022, 4, 1)),
        'type': 'INVEST',
        'amount': 1000000.0,
        'createdAt': Timestamp.fromDate(DateTime(2022, 4, 1)),
      });

    final conversion = _MockConversion();
    when(() => conversion.clearCache()).thenAnswer((_) async {});
    when(
      () => conversion.getRate(
        from: any(named: 'from'),
        to: any(named: 'to'),
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async => 0.012);
    final connectivity = _MockConnectivity();
    when(() => connectivity.checkConnectivity()).thenAnswer((_) async => true);

    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(googleUser),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
          securityProvider.overrideWith(_TestSecurityNotifier.new),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          crashlyticsServiceProvider.overrideWithValue(
            _MockCrashlyticsService(),
          ),
          googleSignInInitializedProvider.overrideWith((ref) async {}),
          currencyConversionServiceProvider.overrideWithValue(conversion),
          connectivityServiceProvider.overrideWithValue(connectivity),
          isAuthenticatedProvider.overrideWith((ref) => true),
          allInvestmentsProvider.overrideWith((ref) => Stream.value(const [])),
          allCashFlowsStreamProvider.overrideWith(
            (ref) => Stream.value(const <CashFlowEntity>[]),
          ),
          validCashFlowsProvider.overrideWithValue(
            const AsyncValue.data(<CashFlowEntity>[]),
          ),
          legacyCurrencyBackfillServiceProvider.overrideWithValue(
            LegacyCurrencyBackfillService(
              firestore: firestore,
              userId: firestore.uid,
              prefs: prefs,
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    return AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  }

  /// Taps the Currency tile, picks USD and lets the 300 ms debounce and the
  /// record check run until the question is on screen.
  Future<void> pickUsd(WidgetTester tester, AppLocalizations l10n) async {
    await tester.tap(find.widgetWithText(SettingsValueTile, l10n.currency));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.currencyUSD));
    // The tile's busy spinner animates while the question is open, so pump
    // past the debounce and the dialog's entrance instead of settling.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    // Every case below answers this question, so it must be on screen.
    expect(
      find.text(l10n.legacyCurrencySwitchPromptMessage('INR', 'USD')),
      findsOneWidget,
    );
  }

  bool stamped() =>
      firestore.stored('cashflows', 'cf-1')!.containsKey('currency');

  testWidgets('picking USD asks whether older records were entered in INR, '
      'with Cancel, No and Yes', (tester) async {
    final l10n = await pumpSettings(tester);
    await pickUsd(tester, l10n);

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(
        of: dialog,
        matching: find.text(
          l10n.legacyCurrencySwitchPromptMessage('INR', 'USD'),
        ),
      ),
      findsOneWidget,
    );
    for (final label in [
      l10n.cancel,
      l10n.legacyCurrencySwitchPromptNo('USD'),
      l10n.legacyCurrencySwitchPromptYes('INR'),
    ]) {
      expect(
        find.descendant(of: dialog, matching: find.text(label)),
        findsOneWidget,
      );
    }
    // Nothing happens while the question is open.
    expect(stamped(), isFalse);
    expect(container.read(currencyCodeProvider), 'INR');

    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
  });

  testWidgets('Yes, INR: the cash flow is stored as INR and the base '
      'currency becomes USD', (tester) async {
    final l10n = await pumpSettings(tester);
    await pickUsd(tester, l10n);

    await tester.tap(find.text(l10n.legacyCurrencySwitchPromptYes('INR')));
    await tester.pumpAndSettle();
    // Let the success snackbar and its delayed reset finish.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(firestore.stored('cashflows', 'cf-1')!['currency'], 'INR');
    expect(container.read(currencyCodeProvider), 'USD');
    expect(prefs.getString('currency'), 'USD');
  });

  testWidgets('No, USD: nothing is stamped and the base currency becomes USD', (
    tester,
  ) async {
    final l10n = await pumpSettings(tester);
    await pickUsd(tester, l10n);

    await tester.tap(find.text(l10n.legacyCurrencySwitchPromptNo('USD')));
    await tester.pumpAndSettle();
    // Let the success snackbar and its delayed reset finish.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(stamped(), isFalse);
    expect(container.read(currencyCodeProvider), 'USD');
    expect(prefs.getString('currency'), 'USD');
  });

  testWidgets('Cancel: nothing is stamped and the base currency stays INR', (
    tester,
  ) async {
    final l10n = await pumpSettings(tester);
    await pickUsd(tester, l10n);

    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    // Let the success snackbar and its delayed reset finish.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(stamped(), isFalse);
    expect(container.read(currencyCodeProvider), 'INR');
    expect(prefs.getString('currency'), 'INR');
  });

  testWidgets('tap outside: nothing is stamped and the base currency stays '
      'INR', (tester) async {
    final l10n = await pumpSettings(tester);
    await pickUsd(tester, l10n);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    // Let the success snackbar and its delayed reset finish.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(stamped(), isFalse);
    expect(container.read(currencyCodeProvider), 'INR');
    expect(prefs.getString('currency'), 'INR');
  });
}

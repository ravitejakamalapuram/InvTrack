/// A28 / ARCH-05: when the portfolio fails to load, the FIRE card and screen
/// show the error and a Retry action instead of loading indefinitely, and
/// show no FIRE number or amount computed from an empty portfolio.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/fire_number/presentation/screens/fire_dashboard_screen.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_dashboard_card.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cardError = "Couldn't load your FIRE progress";

final _settings = FireSettingsEntity(
  id: 'fire',
  monthlyExpenses: 50000,
  birthYear: DateTime.now().year - 30,
  targetFireAge: 45,
  isSetupComplete: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// Pumps [home] with cash flows that always fail to load. Returns a counter
/// of cash-flow subscriptions, so a test can see that Retry reloads them.
///
/// [productionRetry] keeps Riverpod's default retry policy, as main.dart
/// does. Without it nothing reloads the cash flows except the Retry action.
Future<int Function()> _pumpWithFailingPortfolio(
  WidgetTester tester,
  Widget home, {
  bool privacyMode = false,
  bool productionRetry = true,
}) async {
  SharedPreferences.setMockInitialValues({'privacy_mode_enabled': privacyMode});
  final prefs = await SharedPreferences.getInstance();
  var cashFlowSubscriptions = 0;

  await tester.pumpWidget(
    ProviderScope(
      retry: productionRetry ? null : (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        currencySymbolProvider.overrideWith((ref) => '₹'),
        currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
        fireSettingsProvider.overrideWith((ref) => Stream.value(_settings)),
        allInvestmentsProvider.overrideWith((ref) => Stream.value(const [])),
        allCashFlowsStreamProvider.overrideWith((ref) {
          cashFlowSubscriptions++;
          return Stream.error(Exception('permission-denied'));
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return () => cashFlowSubscriptions;
}

void main() {
  for (final privacyMode in [false, true]) {
    testWidgets(
      'FIRE card shows the load error and a Retry action, not a skeleton or '
      'a FIRE number (privacy mode: $privacyMode)',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpWithFailingPortfolio(
          tester,
          const Scaffold(body: FireDashboardCard()),
          privacyMode: privacyMode,
        );

        expect(find.text(_cardError), findsOneWidget);
        expect(find.bySemanticsLabel(_cardError), findsOneWidget);
        expect(
          find.ancestor(
            of: find.text('Retry'),
            matching: find.byWidgetPredicate((w) => w is TextButton),
          ),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Retry'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.textContaining('₹'), findsNothing);
        expect(find.textContaining('%'), findsNothing);

        semantics.dispose();
      },
    );
  }

  testWidgets('Retry on the FIRE card reloads the portfolio', (tester) async {
    final subscriptions = await _pumpWithFailingPortfolio(
      tester,
      const Scaffold(body: FireDashboardCard()),
      productionRetry: false,
    );
    final before = subscriptions();

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(subscriptions(), before + 1);
  });

  testWidgets(
    'FIRE screen shows the load error and Retry, not an endless spinner',
    (tester) async {
      await _pumpWithFailingPortfolio(tester, const FireDashboardScreen());

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text('Failed to load FIRE data. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing);
    },
  );

  testWidgets('Retry on the FIRE screen reloads the portfolio', (tester) async {
    final subscriptions = await _pumpWithFailingPortfolio(
      tester,
      const FireDashboardScreen(),
      productionRetry: false,
    );
    final before = subscriptions();

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(subscriptions(), before + 1);
  });
}

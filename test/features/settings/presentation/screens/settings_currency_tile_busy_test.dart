// A03-F1: while a base-currency change checks older records (and its own
// question may be open), the Currency tile is disabled, so a second change
// cannot start and ask a stale question.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/currency_switch_provider.dart';
import 'package:inv_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_auth_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';

class _MockCrashlyticsService extends Mock implements CrashlyticsService {}

class _TestSecurityNotifier extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
}

class _CheckingRecords extends CurrencySwitch {
  @override
  CurrencySwitchStatus build() =>
      const CurrencySwitchStatus.checkingRecords(targetCurrency: 'USD');
}

void main() {
  testWidgets('checking older records: the Currency tile shows Loading, is '
      'announced as disabled, and does not open the picker', (tester) async {
    SharedPreferences.setMockInitialValues({'currency': 'INR'});
    final prefs = await SharedPreferences.getInstance();
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
          currencySwitchProvider.overrideWith(_CheckingRecords.new),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    // The busy spinner animates forever, so pump instead of settling.
    await tester.pump(const Duration(milliseconds: 500));
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    final tile = find.widgetWithText(SettingsValueTile, l10n.currency);
    expect(tile, findsOneWidget);
    // The spinner replaces the currency code while the check runs.
    expect(
      find.descendant(
        of: tile,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(find.descendant(of: tile, matching: find.text('INR')), findsNothing);
    expect(
      tester.getSemantics(
        find.ancestor(of: tile, matching: find.byType(Semantics)).first,
      ),
      matchesSemantics(
        label: '${l10n.currency}, ${l10n.loading}',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );

    await tester.tap(tile);
    // The busy spinner animates forever, so pump instead of settling.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(l10n.selectCurrency), findsNothing);
  });
}

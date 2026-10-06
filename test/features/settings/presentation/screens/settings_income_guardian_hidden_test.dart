// A42: Income Guardian is hidden until something generates expected cash
// flows. Its Settings tile promised "Automated income tracking and payment
// alerts" to every user, for alerts that could never fire.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/screens/settings_screen.dart';
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

Future<void> _pump(
  WidgetTester tester, {
  required bool overridesAllowed,
  Map<String, Object> stored = const {},
}) async {
  SharedPreferences.setMockInitialValues({'currency': 'INR', ...stored});
  final prefs = await SharedPreferences.getInstance();
  // Tall enough that every section of the list is built.
  await tester.binding.setSurfaceSize(const Size(800, 6000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(googleUser),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        featureFlagOverridesAllowedProvider.overrideWithValue(overridesAllowed),
        securityProvider.overrideWith(_TestSecurityNotifier.new),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        crashlyticsServiceProvider.overrideWithValue(_MockCrashlyticsService()),
        googleSignInInitializedProvider.overrideWith((ref) async {}),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('release build: Settings has no Income Guardian tile', (
    tester,
  ) async {
    await _pump(
      tester,
      overridesAllowed: false,
      // A value left on the device from Debug Settings must not bring it back.
      stored: {'feature_flag_income_guardian': true},
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    // The neighbouring sections are still there.
    expect(find.text(l10n.dataAndAccount), findsWidgets);
    expect(find.textContaining('Income Guardian'), findsNothing);
    expect(
      find.text('Automated income tracking and payment alerts'),
      findsNothing,
    );
    expect(find.bySemanticsLabel(RegExp('Income Guardian')), findsNothing);
  });

  testWidgets('with the flag on (Debug Settings) the tile is shown', (
    tester,
  ) async {
    await _pump(
      tester,
      overridesAllowed: true,
      stored: {'feature_flag_income_guardian': true},
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    expect(
      find.text('Automated income tracking and payment alerts'),
      findsOneWidget,
    );
    // Both labels come from the string file, not from code.
    expect(find.text(l10n.incomeGuardianSettingsSubtitle), findsOneWidget);
    expect(find.text(l10n.incomeGuardianSettings), findsWidgets);
    expect(
      find.bySemanticsLabel(RegExp(l10n.incomeGuardianSettingsSubtitle)),
      findsOneWidget,
    );
  });
}

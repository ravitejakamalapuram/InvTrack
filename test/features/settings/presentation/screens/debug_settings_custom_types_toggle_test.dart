// #936: the custom investment types flag has a toggle in Debug Settings (the
// feature-flag rule), and flipping it changes the flag the form reads.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/settings/presentation/screens/debug_settings_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockCrashlyticsService extends Mock implements CrashlyticsService {}

void main() {
  testWidgets('the toggle turns custom investment types on and off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final crashlytics = _MockCrashlyticsService();
    when(() => crashlytics.isCrashlyticsCollectionEnabled).thenReturn(false);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        featureFlagOverridesAllowedProvider.overrideWithValue(true),
        crashlyticsServiceProvider.overrideWithValue(crashlytics),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DebugSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Custom Investment Types'), findsOneWidget);
    expect(
      find.text('Reusable labels for investments of type Other'),
      findsOneWidget,
    );
    expect(container.read(isCustomInvestmentTypesEnabledProvider), isFalse);

    final toggle = find.byWidgetPredicate(
      (w) =>
          w is Switch &&
          find
              .ancestor(
                of: find.byWidget(w),
                matching: find.widgetWithText(
                  ListTile,
                  'Custom Investment Types',
                ),
              )
              .evaluate()
              .isNotEmpty,
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(container.read(isCustomInvestmentTypesEnabledProvider), isTrue);
    expect(find.text('Custom investment types enabled'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(container.read(isCustomInvestmentTypesEnabledProvider), isFalse);
  });
}

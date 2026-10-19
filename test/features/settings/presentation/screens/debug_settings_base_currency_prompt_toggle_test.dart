// A31 (#772): the base currency prompt flag has a toggle in Debug Settings
// (the feature-flag rule), and flipping it changes what the Add Investment
// screen reads (firstInvestmentFormEnabledProvider). Without the toggle nobody
// can see the new form on a debug build.
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
  testWidgets('the toggle turns the base currency prompt on and off', (
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

    expect(find.text('Base Currency Prompt'), findsOneWidget);
    expect(
      find.text(
        'Asks new users to confirm a currency from their country and keeps it on their profile',
      ),
      findsOneWidget,
    );
    expect(container.read(isBaseCurrencyPromptEnabledProvider), isFalse);

    final toggle = find.byWidgetPredicate(
      (w) =>
          w is Switch &&
          find
              .ancestor(
                of: find.byWidget(w),
                matching: find.widgetWithText(ListTile, 'Base Currency Prompt'),
              )
              .evaluate()
              .isNotEmpty,
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(container.read(isBaseCurrencyPromptEnabledProvider), isTrue);
    expect(find.text('Base Currency Prompt enabled'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(container.read(isBaseCurrencyPromptEnabledProvider), isFalse);
    // The first message goes, then the next one in the queue shows.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Base Currency Prompt disabled'), findsOneWidget);
  });
}

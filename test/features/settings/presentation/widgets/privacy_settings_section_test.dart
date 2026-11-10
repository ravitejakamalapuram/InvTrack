import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/privacy/privacy_choices.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/privacy_settings_section.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopApplier implements PrivacyCollectionApplier {
  @override
  Future<void> setAnalytics(bool enabled) async {}
  @override
  Future<void> setPerformance(bool enabled) async {}
  @override
  Future<void> setCrashReports(bool enabled) async {}
}

Future<SharedPreferences> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        privacyCollectionApplierProvider.overrideWithValue(_NoopApplier()),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: PrivacySettingsSection()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

void main() {
  testWidgets('shows both switches on, with the no-amounts promise', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('PRIVACY'), findsOneWidget);
    expect(find.text('Share usage data'), findsOneWidget);
    expect(find.text('Send crash reports'), findsOneWidget);
    expect(find.textContaining('No amounts or names'), findsNWidgets(2));
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches, hasLength(2));
    expect(switches.every((s) => s.value), isTrue);
  });

  testWidgets('tapping a switch turns it off and remembers it', (tester) async {
    final prefs = await _pump(tester);

    await tester.tap(find.text('Share usage data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send crash reports'));
    await tester.pumpAndSettle();

    expect(prefs.getBool(privacyAnalyticsKey), isFalse);
    expect(prefs.getBool(privacyCrashReportsKey), isFalse);
    expect(
      tester.widgetList<Switch>(find.byType(Switch)).every((s) => !s.value),
      isTrue,
    );
  });

  testWidgets('switches have spoken labels', (tester) async {
    await _pump(tester);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('Share usage data')), findsWidgets);
    handle.dispose();
  });
}

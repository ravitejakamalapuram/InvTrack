import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/consent_service.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/screens/security_settings_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConsent extends ConsentService {
  _FakeConsent(this._p) : super(_p);
  final SharedPreferences _p;
  final calls = <String>[];
  @override
  Future<void> setAnalytics(bool v) async {
    calls.add('analytics:$v');
    await _p.setBool(analyticsConsentPrefKey, v);
  }

  @override
  Future<void> setCrashReporting(bool v) async {
    calls.add('crash:$v');
    await _p.setBool(crashReportingConsentPrefKey, v);
  }
}

class _TestSecurityNotifier extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
}

void main() {
  testWidgets('Privacy toggles default on and switch off', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fake = _FakeConsent(prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          consentServiceProvider.overrideWithValue(fake),
          securityProvider.overrideWith(_TestSecurityNotifier.new),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SecuritySettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final analyticsTile = find.byKey(const Key('consent_analytics_toggle'));
    final crashTile = find.byKey(const Key('consent_crash_toggle'));
    final analytics = find.descendant(
      of: analyticsTile,
      matching: find.byType(SwitchListTile),
    );
    final crash = find.descendant(
      of: crashTile,
      matching: find.byType(SwitchListTile),
    );
    await tester.scrollUntilVisible(analyticsTile, 200);
    expect(tester.widget<SwitchListTile>(analytics).value, isTrue);
    expect(tester.widget<SwitchListTile>(crash).value, isTrue);

    await tester.tap(analytics);
    await tester.pumpAndSettle();
    await tester.tap(crash);
    await tester.pumpAndSettle();

    expect(fake.calls, ['analytics:false', 'crash:false']);
    expect(tester.widget<SwitchListTile>(analytics).value, isFalse);
    expect(tester.widget<SwitchListTile>(crash).value, isFalse);
  });
}

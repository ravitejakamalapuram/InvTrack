// #1012: in a release build, five taps on the app version in About unlock a
// Feature flags screen. It shows the flag switches and no data tool.
//
// A release build is simulated by overriding developerToolsAvailableProvider
// with its release value (false).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/providers/debug_mode_provider.dart';
import 'package:inv_tracker/core/providers/feature_flag_unlock_provider.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/package_info_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/screens/about_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/feature_flags_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mocks/fake_auth_repository.dart';
import '../../../mocks/mock_analytics_service.dart';

class _MockCrashlyticsService extends Mock implements CrashlyticsService {}

class _TestSecurityNotifier extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState();
}

const _versionText = 'Version 1.2.3 (45)';
final _packageInfo = PackageInfo(
  appName: 'InvTrack',
  packageName: 'com.invtracker.inv_tracker',
  version: '1.2.3',
  buildNumber: '45',
);

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  late SharedPreferences prefs;
  late FakeAnalyticsService analytics;
  late FakeAuthRepository auth;

  List<Override> releaseOverrides() => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    developerToolsAvailableProvider.overrideWithValue(false),
    packageInfoProvider.overrideWith((ref) async => _packageInfo),
    authRepositoryProvider.overrideWithValue(auth),
    securityProvider.overrideWith(_TestSecurityNotifier.new),
    analyticsServiceProvider.overrideWithValue(analytics),
    crashlyticsServiceProvider.overrideWithValue(_MockCrashlyticsService()),
    googleSignInInitializedProvider.overrideWith((ref) async {}),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    analytics = FakeAnalyticsService();
    auth = FakeAuthRepository(googleUser);
  });

  Future<void> tapVersion(WidgetTester tester, int times) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.text(_versionText), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();
  }

  group('About, release build', () {
    Future<ProviderContainer> pumpAbout(WidgetTester tester) async {
      final c = ProviderContainer(overrides: releaseOverrides());
      addTearDown(c.dispose);
      c.listen(authStateProvider, (_, _) {});
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: _app(const AboutScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('four taps unlock nothing', (tester) async {
      final c = await pumpAbout(tester);

      await tapVersion(tester, 4);

      expect(c.read(featureFlagUnlockProvider), isFalse);
      expect(find.text('Feature flags unlocked'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('five taps unlock, ten taps lock again', (tester) async {
      final c = await pumpAbout(tester);

      await tapVersion(tester, 5);
      expect(c.read(featureFlagUnlockProvider), isTrue);
      expect(find.text('Feature flags unlocked'), findsOneWidget);

      // Let the first toast leave before the second can show.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 3));
      }
      await tapVersion(tester, 5);
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.read(featureFlagUnlockProvider), isFalse);
      expect(find.text('Feature flags locked'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('taps spread over more than the window do not count', (
      tester,
    ) async {
      final c = await pumpAbout(tester);

      await tapVersion(tester, 3);
      await tester.pump(const Duration(seconds: 4));
      await tapVersion(tester, 2);

      expect(c.read(featureFlagUnlockProvider), isFalse);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('five slow taps, each under 3 s apart but over 3 s in all, '
        'unlock nothing', (tester) async {
      final c = await pumpAbout(tester);

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text(_versionText), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 2000));
      }

      expect(c.read(featureFlagUnlockProvider), isFalse);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('sends no analytics event and no log for the unlock', (
      tester,
    ) async {
      await pumpAbout(tester);

      await tapVersion(tester, 5);

      expect(analytics.loggedEvents, isEmpty);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Settings, release build', () {
    Future<ProviderContainer> pumpSettings(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = ProviderContainer(overrides: releaseOverrides());
      addTearDown(c.dispose);
      c.listen(authStateProvider, (_, _) {});
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: _app(const SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('locked: no Developer section, no Feature flags entry', (
      tester,
    ) async {
      await pumpSettings(tester);

      expect(find.text('Feature flags'), findsNothing);
      expect(find.text('Developer'), findsNothing);
      expect(find.text('Debug Settings'), findsNothing);
    });

    testWidgets(
      'unlocked: Feature flags entry shows, Debug Settings does not',
      (tester) async {
        final c = await pumpSettings(tester);

        c.read(featureFlagUnlockProvider.notifier).toggle();
        await tester.pumpAndSettle();

        expect(find.text('Feature flags'), findsOneWidget);
        expect(find.text('Debug Settings'), findsNothing);
      },
    );

    testWidgets('unlocked, then signed out: the entry is gone', (tester) async {
      final c = await pumpSettings(tester);
      c.read(featureFlagUnlockProvider.notifier).toggle();
      await tester.pumpAndSettle();
      expect(find.text('Feature flags'), findsOneWidget);

      await auth.signOut();
      await tester.pumpAndSettle();

      expect(c.read(featureFlagUnlockProvider), isFalse);
      expect(find.text('Feature flags'), findsNothing);
    });

    testWidgets('the entry opens a screen with switches and no data tools', (
      tester,
    ) async {
      final c = await pumpSettings(tester);
      c.read(featureFlagUnlockProvider.notifier).toggle();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Feature flags'));
      await tester.pumpAndSettle();

      expect(find.byType(FeatureFlagsScreen), findsOneWidget);
      expect(find.text('First Investment Flow'), findsOneWidget);
      for (final dataTool in [
        'Seed Demo Data',
        'Clear Sample Data',
        'Crashlytics',
        'Debug Mode',
      ]) {
        expect(find.textContaining(dataTool), findsNothing, reason: dataTool);
      }
    });

    testWidgets('a switch flipped there turns the feature on', (tester) async {
      final c = await pumpSettings(tester);
      c.read(featureFlagUnlockProvider.notifier).toggle();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Feature flags'));
      await tester.pumpAndSettle();
      expect(c.read(isFirstInvestmentFlowEnabledProvider), isFalse);

      await tester.tap(find.text('First Investment Flow'));
      await tester.pumpAndSettle();

      expect(c.read(isFirstInvestmentFlowEnabledProvider), isTrue);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  // The feature-flag screen is compiled into release builds, so it must not
  // reach any data tool, now or after a later edit.
  group('source guards', () {
    test('the flag switches carry no hard-coded English subtitle', () {
      final source = File(
        'lib/features/settings/presentation/widgets/feature_flags_section.dart',
      ).readAsStringSync();
      expect(
        RegExp(r"subtitle:\s*'").hasMatch(source),
        isFalse,
        reason: 'Subtitles come from app_en.arb so every locale can translate',
      );
    });

    test('the Help FAQ says five taps, like the gesture does', () {
      final arb =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      for (final key in [
        'howToEnableDebugModeAnswer',
        'howToDisableDebugModeAnswer',
        'tapVersionToEnable',
      ]) {
        final text = arb[key] as String;
        expect(text, contains('5 times'), reason: key);
        expect(text, isNot(contains('7 times')), reason: key);
      }
    });

    test('Feature flags screen and section import no data tool', () {
      const banned = [
        'debug_settings_screen',
        'seed_data_provider',
        'sample_data_provider',
        'crashlytics_settings_section',
        'crashlytics_service',
        'debug_mode_provider',
      ];
      for (final path in [
        'lib/features/settings/presentation/screens/feature_flags_screen.dart',
        'lib/features/settings/presentation/widgets/feature_flags_section.dart',
      ]) {
        final imports = File(
          path,
        ).readAsLinesSync().where((l) => l.startsWith('import '));
        for (final b in banned) {
          expect(
            imports.where((l) => l.contains(b)),
            isEmpty,
            reason: '$path must not import $b',
          );
        }
      }
    });

    test('the unlock is held in memory and never written to storage', () {
      final source = File(
        'lib/core/providers/feature_flag_unlock_provider.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('SharedPreferences')));
      expect(source, isNot(contains('sharedPreferencesProvider')));
      expect(source, isNot(contains('analytics')));
    });
  });
}

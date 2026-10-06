// A35 (#779): release builds must have no reachable debug tools.
//
// Tests run in a debug build, so the release configuration is simulated by
// overriding developerToolsAvailableProvider with its release value (false).
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/providers/debug_mode_provider.dart';
import 'package:inv_tracker/core/providers/package_info_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/screens/about_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/help_faq_screen.dart';
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

const _debugPrefKey = 'debug_mode_enabled';
const _versionText = 'Version 1.2.3 (45)';
const _tapHint = 'Tap version 7 times to enable debug mode';

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

  Future<void> givenPrefs(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
  }

  ProviderContainer container({required bool toolsAvailable}) {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        developerToolsAvailableProvider.overrideWithValue(toolsAvailable),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('developerToolsAvailableProvider', () {
    test('is off exactly when the build is a release build', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(developerToolsAvailableProvider), !kReleaseMode);
    });
  });

  group('debugModeProvider in a release configuration', () {
    test('ignores debug mode persisted by an older release', () async {
      await givenPrefs({_debugPrefKey: true});
      final c = container(toolsAvailable: false);

      expect(c.read(debugModeProvider), isFalse);
    });

    test('toggle and setEnabled cannot turn it on', () async {
      await givenPrefs({});
      final c = container(toolsAvailable: false);

      expect(await c.read(debugModeProvider.notifier).toggle(), isFalse);
      await c.read(debugModeProvider.notifier).setEnabled(true);

      expect(c.read(debugModeProvider), isFalse);
      expect(prefs.getBool(_debugPrefKey), isNull);
    });

    test('debug builds keep the persisted toggle (control)', () async {
      await givenPrefs({_debugPrefKey: true});
      final c = container(toolsAvailable: true);

      expect(c.read(debugModeProvider), isTrue);
      expect(await c.read(debugModeProvider.notifier).toggle(), isFalse);
      expect(prefs.getBool(_debugPrefKey), isFalse);
    });
  });

  group('About: 7-tap unlock', () {
    Future<ProviderContainer> pumpAbout(
      WidgetTester tester, {
      required bool toolsAvailable,
    }) async {
      await givenPrefs({});
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          developerToolsAvailableProvider.overrideWithValue(toolsAvailable),
          packageInfoProvider.overrideWith((ref) async => _packageInfo),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: _app(const AboutScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return c;
    }

    Future<void> tapVersion7Times(WidgetTester tester) async {
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.text(_versionText), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump();
    }

    testWidgets('release: 7 taps do nothing and nothing hints at them', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final c = await pumpAbout(tester, toolsAvailable: false);

      await tapVersion7Times(tester);

      expect(c.read(debugModeProvider), isFalse);
      expect(prefs.getBool(_debugPrefKey), isNull);
      expect(find.text('🛠️ Debug mode enabled'), findsNothing);

      // The version is plain text: no button role, no "tap 7 times" hint.
      expect(find.bySemanticsLabel(RegExp('7 times')), findsNothing);
      final versionNode = tester.getSemantics(find.text(_versionText));
      expect(versionNode.label, contains(_versionText));
      expect(versionNode, containsSemantics(isButton: false));
      expect(find.text(_tapHint), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      handle.dispose();
    });

    testWidgets('debug build: 7 taps still enable debug mode (control)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final c = await pumpAbout(tester, toolsAvailable: true);
      expect(find.bySemanticsLabel(RegExp('7 times')), findsOneWidget);

      await tapVersion7Times(tester);

      expect(c.read(debugModeProvider), isTrue);
      expect(find.text('🛠️ Debug mode enabled'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      handle.dispose();
    });
  });

  group('Settings: Developer tile', () {
    Future<void> pumpSettings(
      WidgetTester tester, {
      required bool toolsAvailable,
    }) async {
      // Debug mode left on by an older release build.
      await givenPrefs({_debugPrefKey: true});
      final crashlytics = _MockCrashlyticsService();
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
            crashlyticsServiceProvider.overrideWithValue(crashlytics),
            googleSignInInitializedProvider.overrideWith((ref) async {}),
            developerToolsAvailableProvider.overrideWithValue(toolsAvailable),
          ],
          child: _app(const SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('release: no route to Debug Settings', (tester) async {
      await pumpSettings(tester, toolsAvailable: false);

      expect(find.text('Developer'), findsNothing);
      expect(find.text('Debug Settings'), findsNothing);
    });

    testWidgets('debug build: tile still shown (control)', (tester) async {
      await pumpSettings(tester, toolsAvailable: true);

      expect(find.text('Debug Settings'), findsOneWidget);
    });
  });

  group('Help & FAQ', () {
    const debugQuestions = [
      'How do I enable debug mode?',
      'What is debug mode for?',
      'How do I disable debug mode?',
    ];

    // Tall enough that the lazy ListView builds every FAQ section.
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(
        800,
        20000,
      );
      binding.platformDispatcher.views.first.devicePixelRatio = 1;
    });
    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    testWidgets('release: does not explain how to unlock debug mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const HelpFaqScreen(showDeveloperFaq: false)),
      );
      await tester.pumpAndSettle();

      for (final q in debugQuestions) {
        expect(find.text(q, skipOffstage: false), findsNothing);
      }
      expect(find.text('Advanced Features', skipOffstage: false), findsNothing);
    });

    testWidgets('debug build: keeps the developer FAQ (control)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const HelpFaqScreen(showDeveloperFaq: true)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Advanced Features', skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  testWidgets('release: Help opened from About hides the developer FAQ', (
    tester,
  ) async {
    await givenPrefs({});
    tester.view.physicalSize = const Size(800, 20000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          developerToolsAvailableProvider.overrideWithValue(false),
          packageInfoProvider.overrideWith((ref) async => _packageInfo),
        ],
        child: _app(const AboutScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Help & FAQ'));
    await tester.pumpAndSettle();

    expect(find.byType(HelpFaqScreen), findsOneWidget);
    expect(find.text('Advanced Features', skipOffstage: false), findsNothing);
  });

  // kReleaseMode is a compile-time constant, so tests (debug builds) cannot
  // exercise the release branch. These source guards stop a second, ungated
  // entry point from slipping in.
  group('release-only guards in source', () {
    Iterable<File> libDartFiles() => Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.contains('${Platform.pathSeparator}generated'))
        .where((f) => !f.path.endsWith('.g.dart'));

    test('DebugSettingsScreen is opened only behind the release switch', () {
      final uses = <String>[];
      for (final file in libDartFiles()) {
        if (file.path.endsWith('debug_settings_screen.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('import ') || line.startsWith('//')) continue;
          if (RegExp(r'\bDebugSettingsScreen\b').hasMatch(line)) {
            uses.add('${file.path}:${i + 1}');
          }
        }
      }
      final settings =
          'lib/features/settings/presentation/screens/'
          'settings_screen.dart';
      expect(uses, hasLength(1), reason: 'Entry points: $uses');
      expect(uses.single, startsWith('$settings:'));

      final lines = File(settings).readAsLinesSync();
      final useLine = int.parse(uses.single.split(':').last) - 1;
      final guardLine = lines.lastIndexWhere(
        (l) => l.trim().startsWith('if (!kReleaseMode && '),
        useLine,
      );
      // Deliberate tripwires: the guard must be written as
      // `if (!kReleaseMode && ...` and sit within 20 lines of the screen's only
      // use. A failure after moving or rewording that code means: check the
      // Developer section is still behind the compile-time kReleaseMode
      // constant, then update this test.
      expect(
        guardLine,
        isNot(-1),
        reason:
            'No `if (!kReleaseMode && ...` guard above the DebugSettingsScreen '
            'use (source tripwire; see comment above)',
      );
      expect(
        useLine - guardLine,
        lessThan(20),
        reason:
            'The kReleaseMode guard must wrap the Developer section; the '
            '20-line limit is a source tripwire (see comment above)',
      );
    });

    test('GoRouter diagnostics follow the developer-tools switch', () {
      const followsSwitch = 'ref.watch(developerToolsAvailableProvider)';
      final settings = <String>[];
      for (final file in libDartFiles()) {
        // Compare without whitespace, so a formatter that wraps the value
        // over several lines does not break the check.
        final source = file.readAsStringSync().replaceAll(RegExp(r'\s+'), '');
        for (final m in RegExp(
          r'debugLogDiagnostics:(ref\.watch\([^)]*\)|[^,)]+)',
        ).allMatches(source)) {
          settings.add(m.group(1)!.replaceAll(',)', ')'));
        }
      }
      // The app router follows the switch; any other router may only turn
      // diagnostics off outright.
      expect(settings, contains(followsSwitch));
      expect(
        settings,
        everyElement(anyOf(followsSwitch, 'false')),
        reason: 'Release builds must not log route paths',
      );
    });
  });
}

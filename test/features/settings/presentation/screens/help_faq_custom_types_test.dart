// #936: the Help & FAQ entry about custom types is shown only while the
// feature flag is on, so the FAQ never points at a feature users cannot see
// (see #903). Opened from About, the screen follows the flag.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/debug_mode_provider.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/package_info_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/settings/presentation/screens/about_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/help_faq_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _question = 'Can I give an Other investment a more specific type?';

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

  testWidgets('shown when the screen is told the feature is on', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const HelpFaqScreen(showDeveloperFaq: false, showCustomTypesFaq: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_question, skipOffstage: false), findsOneWidget);
    expect(
      find.textContaining('does not change how the investment is calculated'),
      findsOneWidget,
    );
  });

  testWidgets('not shown otherwise, which is the default', (tester) async {
    await tester.pumpWidget(_app(const HelpFaqScreen(showDeveloperFaq: false)));
    await tester.pumpAndSettle();

    expect(find.text(_question, skipOffstage: false), findsNothing);
  });

  group('opened from About', () {
    Future<void> openHelp(WidgetTester tester, {required bool flag}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            developerToolsAvailableProvider.overrideWithValue(false),
            isCustomInvestmentTypesEnabledProvider.overrideWithValue(flag),
            packageInfoProvider.overrideWith((ref) async => _packageInfo),
          ],
          child: _app(const AboutScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Help & FAQ'));
      await tester.pumpAndSettle();
      expect(find.byType(HelpFaqScreen), findsOneWidget);
    }

    testWidgets('flag on: the entry is there', (tester) async {
      await openHelp(tester, flag: true);
      expect(find.text(_question, skipOffstage: false), findsOneWidget);
    });

    testWidgets('flag off: no entry', (tester) async {
      await openHelp(tester, flag: false);
      expect(find.text(_question, skipOffstage: false), findsNothing);
    });
  });
}

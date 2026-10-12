// A105: the Help & FAQ section about Income Guardian is shown only while the
// feature is visible, so the FAQ never describes something users cannot see.
// Opened from About, the screen follows isIncomeGuardianEnabledProvider.
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
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _l10n = AppLocalizationsEn();

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

void _expectSection({required bool visible}) {
  final matcher = visible ? findsOneWidget : findsNothing;
  expect(find.text(_l10n.incomeGuardianSection, skipOffstage: false), matcher);
  expect(find.text(_l10n.whatIsIncomeGuardian, skipOffstage: false), matcher);
  expect(
    find.text(_l10n.howDoesIncomeProjectionWork, skipOffstage: false),
    matcher,
  );
}

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
        const HelpFaqScreen(
          showDeveloperFaq: false,
          showIncomeGuardianFaq: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    _expectSection(visible: true);
  });

  testWidgets('hidden otherwise, which is the default', (tester) async {
    await tester.pumpWidget(_app(const HelpFaqScreen(showDeveloperFaq: false)));
    await tester.pumpAndSettle();

    _expectSection(visible: false);
    // The neighbouring section is untouched.
    expect(
      find.text(_l10n.portfolioHealthSection, skipOffstage: false),
      findsOneWidget,
    );
  });

  group('opened from About', () {
    Future<void> openHelp(
      WidgetTester tester, {
      required bool flag,
      bool portfolioHealthFlag = false,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            developerToolsAvailableProvider.overrideWithValue(false),
            isIncomeGuardianEnabledProvider.overrideWithValue(flag),
            isPortfolioHealthEnabledProvider.overrideWithValue(
              portfolioHealthFlag,
            ),
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

    testWidgets('flag on: the section is there', (tester) async {
      await openHelp(tester, flag: true);
      _expectSection(visible: true);
    });

    testWidgets('flag off: no section', (tester) async {
      await openHelp(tester, flag: false);
      _expectSection(visible: false);
    });

    // A105 and A129 both add a flag-driven parameter to the same screen. Each
    // flag must reach its own parameter, independent of the other.
    testWidgets('each flag drives only its own FAQ', (tester) async {
      Finder portfolioHealthHint() =>
          find.text(_l10n.whereToFindPortfolioHealth, skipOffstage: false);

      await openHelp(tester, flag: true, portfolioHealthFlag: false);
      _expectSection(visible: true);
      expect(portfolioHealthHint(), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await openHelp(tester, flag: false, portfolioHealthFlag: true);
      _expectSection(visible: false);
      expect(portfolioHealthHint(), findsOneWidget);
    });
  });
}

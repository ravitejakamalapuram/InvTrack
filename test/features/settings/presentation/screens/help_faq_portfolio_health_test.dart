// #903 (A129): Help & FAQ used to tell every user to switch on Portfolio Health
// in Debug Settings, a menu release builds do not have. The entry now shows
// only while the feature is on, and says where the score is, not how to
// enable it. Opened from About, the screen follows the flag.
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

const _question = 'Where do I find my Portfolio Health Score?';
const _oldQuestion = 'How do I enable Portfolio Health Score?';

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

  testWidgets('flag on: the answer says where the score is', (tester) async {
    await tester.pumpWidget(
      _app(
        const HelpFaqScreen(
          showDeveloperFaq: false,
          showPortfolioHealthFaq: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_question, skipOffstage: false), findsOneWidget);
    expect(find.text(_oldQuestion, skipOffstage: false), findsNothing);
    expect(
      find.textContaining('Overview screen', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('flag on: no FAQ text mentions Debug Settings', (tester) async {
    await tester.pumpWidget(
      _app(
        const HelpFaqScreen(
          showDeveloperFaq: false,
          showPortfolioHealthFaq: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Debug Settings', skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('flag off, which is the default: no entry', (tester) async {
    await tester.pumpWidget(_app(const HelpFaqScreen(showDeveloperFaq: false)));
    await tester.pumpAndSettle();

    expect(find.text(_question, skipOffstage: false), findsNothing);
    expect(find.text(_oldQuestion, skipOffstage: false), findsNothing);
    expect(
      find.textContaining('Debug Settings', skipOffstage: false),
      findsNothing,
    );
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
            isPortfolioHealthEnabledProvider.overrideWithValue(flag),
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
      expect(
        find.textContaining('Debug Settings', skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('flag off: no entry and no Debug Settings advice', (
      tester,
    ) async {
      await openHelp(tester, flag: false);
      expect(find.text(_question, skipOffstage: false), findsNothing);
      expect(find.text(_oldQuestion, skipOffstage: false), findsNothing);
      expect(
        find.textContaining('Debug Settings', skipOffstage: false),
        findsNothing,
      );
    });
  });
}

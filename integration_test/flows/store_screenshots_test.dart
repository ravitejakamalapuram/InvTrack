/// Captures the Play Store screenshot set (POR-98) using curated,
/// all-positive demo data so no real/loss-showing data ever reaches
/// a screenshot. Screens: Overview, FIRE dashboard, Goals, Investments
/// list, Privacy Mode, Investment detail.
///
/// Run with:
/// ```
/// flutter drive --profile \
///   --driver=test_driver/store_screenshots_driver.dart \
///   --target=integration_test/flows/store_screenshots_test.dart
/// ```
/// To refresh the Play images without a device, see "Play Store screenshots
/// without an emulator" in `integration_test/README.md`.
///
/// `--profile` (not the default debug build) is required - a debug build
/// always renders Flutter's red "DEBUG" ribbon over the UI, which is not
/// something we want on a real store listing. Screenshots land in
/// `build/store_screenshots/` by default, or `$SCREENSHOT_OUTPUT_DIR` when
/// set (see `test_driver/store_screenshots_driver.dart`).
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:inv_tracker/core/widgets/privacy_toggle_button.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_dashboard_card.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/income_guardian_service_providers.dart';
import 'package:inv_tracker/firebase_options.dart';

import '../mocks/fake_fire_settings_repository.dart';
import '../mocks/store_demo_data.dart';
import '../robots/robots.dart';
import '../test_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('capture store screenshot set', (tester) async {
    // Register the Firebase app locally (no network needed for this) so
    // provider chains that call FirebaseFirestore.instance / FirebaseAuth.instance
    // don't throw "No Firebase App" during widget build. Real Firestore/Auth
    // reads triggered by those providers fail gracefully in the background
    // (same as the shipped app when offline) since they're not overridden.
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {
      // Already initialized or unavailable - the app tolerates this.
    }

    final testApp = await TestApp.create(tester);

    // Curated all-positive demo portfolio, shared with the emulator-free
    // generator in test/store_screenshots/.
    final demo = StoreDemoData.build(DateTime.now());
    testApp.seedInvestments(demo.investments, demo.cashFlows);
    testApp.seedGoals(demo.goals);

    await testApp.pumpApp(
      extraOverrides: [
        fireSettingsRepositoryProvider.overrideWithValue(
          FakeFireSettingsRepository(initialSettings: demo.fireSettings),
        ),
        flutterLocalNotificationsPluginProvider.overrideWithValue(
          FlutterLocalNotificationsPlugin(),
        ),
      ],
    );

    final nav = NavigationRobot(tester);
    final inv = InvestmentRobot(tester);
    final binding = IntegrationTestWidgetsFlutterBinding.instance;

    // Background currency-conversion calls fail/timeout in this offline test
    // environment (no live network), which can leave cards mid-loading-spinner
    // right after pumpApp. Give them time to settle into their final
    // (graceful, cached-rate) state before the very first screenshot.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pumpAndSettle();

    // convertFlutterSurfaceToImage() is a one-time, irreversible switch - call
    // it once up front rather than per-screenshot (nav.takeScreenshot does
    // the latter and silently no-ops on every screenshot after the first).
    await binding.convertFlutterSurfaceToImage();
    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    // 1. Overview dashboard
    nav.verifyOnOverview();
    await shot('store_01_overview');

    // 2. FIRE Number dashboard
    await nav.tap(find.byType(FireDashboardCard));
    await shot('store_02_fire_dashboard');
    await nav.goBack();

    // 3. Goals list
    await nav.goToGoals();
    nav.verifyOnGoals();
    await shot('store_03_goals');

    // 4. Investments list - shows the breadth of asset types at a glance
    await nav.goToInvestments();
    nav.verifyOnInvestments();
    await shot('store_04_investments_list');

    // 5. Privacy Mode - toggle on from Overview, mask amounts
    await nav.goToOverview();
    nav.verifyOnOverview();
    await nav.tap(find.byType(PrivacyToggleButton).first);
    await shot('store_05_privacy_mode');
    // Turn privacy mode back off so the detail screen below renders normally.
    await nav.tap(find.byType(PrivacyToggleButton).first);

    // 6. Investment detail - another strong feature screen (full cash flow
    // history for a closed, profitable real-estate investment).
    await nav.goToInvestments();
    nav.verifyOnInvestments();
    await inv.tapInvestment(StoreDemoData.detailInvestmentName);
    await shot('store_06_investment_detail');
  });
}

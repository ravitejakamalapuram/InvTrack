// Generates the Google Play phone screenshots with plain `flutter test`, so no
// emulator (and no /dev/kvm) is needed. It pumps the real app on the same demo
// data as integration_test/flows/store_screenshots_test.dart, renders the five
// scenes at 1080x1920 and checks them before writing anything.
//
// Without STORE_SCREENSHOTS_DIR the scenes are rendered and checked but no
// file is written, so the normal `flutter test --exclude-tags=golden` run
// keeps the generator from rotting. To refresh the Play images:
//
//   STORE_SCREENSHOTS_DIR=android/fastlane/metadata/android/en-US/images/phoneScreenshots \
//     flutter test test/store_screenshots/store_screenshots_test.dart
//
// Uploading to Play stays manual (listing.yml).
@Tags(['store-screenshots'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/privacy_toggle_button.dart';

import '../../integration_test/mocks/store_demo_data.dart';
import '../../integration_test/robots/robots.dart';
import 'store_screenshot_harness.dart';

void main() {
  testWidgets('renders the five Play phone screenshots from the demo data', (
    tester,
  ) async {
    final fonts = await loadStoreScreenshotFonts(tester);
    expect(
      fonts.testFontFamilies,
      isEmpty,
      reason: 'these families would render as solid test boxes',
    );
    if (storeScreenshotsDir != null) {
      // The files are about to be published, so a missing font is an error.
      expect(
        fonts.materialFontsFound,
        isTrue,
        reason: 'MaterialIcons not found under FLUTTER_ROOT/bin/cache',
      );
      expect(
        fonts.emojiFontPath,
        isNotNull,
        reason:
            'goal icons are emoji; install Noto Color Emoji or set '
            '$storeScreenshotsEmojiFontVar',
      );
    }

    final demo = StoreDemoData.build(DateTime.now());
    final nav = NavigationRobot(tester);
    final inv = InvestmentRobot(tester);
    SemanticsHandle? semantics;
    try {
      await pumpStoreApp(tester, demo);
      // Privacy mode must hide amounts from screen readers too, so the scan
      // reads the semantics tree. The handle has to be gone before the test
      // ends.
      semantics = tester.ensureSemantics();

      // 04 Overview, with amounts shown.
      nav.verifyOnOverview();
      await expectSceneReady(tester, 'play_04_overview');
      expect(
        amountsOnScreen(tester),
        isNotEmpty,
        reason: 'the control: the amount check must see amounts when they show',
      );
      expect(find.text('XIRR'), findsOneWidget);
      await captureScene(tester, 'play_04_overview');

      // 05 Privacy mode: the same screen with every amount hidden.
      await nav.tap(find.byType(PrivacyToggleButton).first);
      await expectSceneReady(tester, 'play_05_privacy_mode');
      expect(amountsOnScreen(tester), isEmpty);
      await captureScene(tester, 'play_05_privacy_mode');
      await nav.tap(find.byType(PrivacyToggleButton).first);

      // 03 Goals.
      await nav.goToGoals();
      await expectSceneReady(tester, 'play_03_goals');
      expect(find.text('Emergency Fund'), findsOneWidget);
      expect(find.text('0%'), findsNothing, reason: 'a goal shows no progress');
      expect(find.text('Not Started'), findsNothing);
      await captureScene(tester, 'play_03_goals');

      // 01 Investments list.
      await nav.goToInvestments();
      await expectSceneReady(tester, 'play_01_investments_list');
      // Open and closed positions both exist, and the first cards are loaded.
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('UTI Nifty 50 Index'), findsOneWidget);
      expect(find.text('HDFC Bank FD'), findsOneWidget);
      await captureScene(tester, 'play_01_investments_list');

      // 02 Investment detail.
      await inv.tapInvestment(StoreDemoData.detailInvestmentName);
      await expectSceneReady(tester, 'play_02_investment_detail');
      expect(find.text('MOIC'), findsOneWidget);
      await captureScene(tester, 'play_02_investment_detail');
    } finally {
      semantics?.dispose();
      releaseStoreApp();
    }
  });
}

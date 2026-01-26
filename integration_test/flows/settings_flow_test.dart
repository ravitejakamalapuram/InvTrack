/// Integration tests for settings flows.
///
/// Tests theme switching, currency settings, and other preferences.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../robots/robots.dart';
import '../test_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('Settings Screen', () {
    testWidgets('should display all settings sections', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final settings = SettingsRobot(tester);

      await testApp.pumpApp();
      await nav.goToSettings();

      settings.verifyOnSettingsScreen();
      settings.verifyAppearanceSection();
    });

    testWidgets('should show sign out option when logged in', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final settings = SettingsRobot(tester);

      await testApp.pumpApp();
      await nav.goToSettings();

      await settings.scrollUntilVisible(find.text('Sign Out'));
      settings.verifySignOutVisible();
    });
  });

  group('Theme Switching', () {
    testWidgets('should display theme options', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final settings = SettingsRobot(tester);

      await testApp.pumpApp();
      await nav.goToSettings();

      // Tap on appearance to open theme selector
      await settings.tapAppearance();

      // Verify theme options are available
      settings.verifyTextDisplayed('Light');
      settings.verifyTextDisplayed('Dark');
      settings.verifyTextDisplayed('System');
    });

    testWidgets('should switch to dark theme', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final settings = SettingsRobot(tester);

      await testApp.pumpApp();
      await nav.goToSettings();

      await settings.tapAppearance();
      await settings.selectDarkTheme();

      // Take screenshot to verify dark theme
      await settings.takeScreenshot('settings_dark_theme');
    });

    testWidgets('should switch to light theme', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final settings = SettingsRobot(tester);

      await testApp.pumpApp();
      await nav.goToSettings();

      await settings.tapAppearance();
      await settings.selectLightTheme();

      // Take screenshot to verify light theme
      await settings.takeScreenshot('settings_light_theme');
    });
  });

  group('Settings Screenshots', () {
    testWidgets('capture settings screen variations', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final settings = SettingsRobot(tester);

      await testApp.pumpApp();
      await nav.goToSettings();

      // Main settings screen
      await settings.takeScreenshot('settings_main');

      // Scroll to show more options
      await settings.scrollUntilVisible(find.text('Sign Out'));
      await settings.takeScreenshot('settings_scrolled');
    });
  });
}

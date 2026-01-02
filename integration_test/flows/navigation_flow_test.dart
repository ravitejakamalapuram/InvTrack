/// Integration tests for app navigation flows.
///
/// Tests navigation between all tabs and screens.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../robots/robots.dart';
import '../test_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('Bottom Navigation', () {
    testWidgets('should start on Overview tab', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);

      await testApp.pumpApp();

      nav.verifyOnOverview();
      nav.verifyTextDisplayed('Overview');
    });

    testWidgets('should navigate to all tabs', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);

      await testApp.pumpApp();

      // Navigate to Investments
      await nav.goToInvestments();
      nav.verifyOnInvestments();
      nav.verifyTextDisplayed('Investments');

      // Navigate to Goals
      await nav.goToGoals();
      nav.verifyOnGoals();
      nav.verifyTextDisplayed('Goals');

      // Navigate to Settings
      await nav.goToSettings();
      nav.verifyOnSettings();
      nav.verifyTextDisplayed('Settings');

      // Navigate back to Overview
      await nav.goToOverview();
      nav.verifyOnOverview();
    });

    testWidgets('should show FAB on Overview screen', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);

      await testApp.pumpApp();

      nav.verifyFabVisible();
    });

    testWidgets('should preserve tab state when switching', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);

      await testApp.pumpApp();

      // Go to settings and verify
      await nav.goToSettings();
      nav.verifyOnSettings();

      // Go to investments
      await nav.goToInvestments();
      nav.verifyOnInvestments();

      // Go back to settings - should still show settings
      await nav.goToSettings();
      nav.verifyOnSettings();
    });
  });

  group('Navigation Screenshots', () {
    testWidgets('capture all tab screens', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);

      await testApp.pumpApp();

      // Overview
      await nav.takeScreenshot('tab_overview');

      // Investments
      await nav.goToInvestments();
      await nav.takeScreenshot('tab_investments');

      // Goals
      await nav.goToGoals();
      await nav.takeScreenshot('tab_goals');

      // Settings
      await nav.goToSettings();
      await nav.takeScreenshot('tab_settings');
    });
  });
}


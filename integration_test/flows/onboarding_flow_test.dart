/// Integration tests for onboarding flow.
///
/// Tests the onboarding wizard for new users.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../robots/robots.dart';
import '../test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding Flow Tests', () {
    late TestApp testApp;
    late OnboardingRobot onboarding;
    late NavigationRobot navigation;

    setUp(() async {
      // Set up fresh for each test
    });

    testWidgets('should display first onboarding page', (tester) async {
      testApp = await TestApp.create(tester);
      await testApp.pumpApp(showOnboarding: true);

      onboarding = OnboardingRobot(tester);

      // Verify first page content
      onboarding.verifyOnFirstPage();
      onboarding.verifyTextDisplayed('Skip');
      onboarding.verifyTextDisplayed('Next');
    });

    testWidgets('should navigate through all pages with Next button', (
      tester,
    ) async {
      testApp = await TestApp.create(tester);
      await testApp.pumpApp(showOnboarding: true);

      onboarding = OnboardingRobot(tester);

      // Page 1
      onboarding.verifyOnFirstPage();
      await onboarding.goToNextPage();

      // Page 2
      onboarding.verifyOnSecondPage();
      await onboarding.goToNextPage();

      // Page 3
      onboarding.verifyOnThirdPage();
      await onboarding.goToNextPage();

      // Page 4 (last)
      onboarding.verifyOnLastPage();
    });

    testWidgets('should navigate through pages by swiping', (tester) async {
      testApp = await TestApp.create(tester);
      await testApp.pumpApp(showOnboarding: true);

      onboarding = OnboardingRobot(tester);

      // Swipe through all pages
      onboarding.verifyOnFirstPage();
      await onboarding.swipeToNextPage();

      onboarding.verifyOnSecondPage();
      await onboarding.swipeToNextPage();

      onboarding.verifyOnThirdPage();
      await onboarding.swipeToNextPage();

      onboarding.verifyOnLastPage();
    });

    testWidgets('should allow swiping back to previous pages', (tester) async {
      testApp = await TestApp.create(tester);
      await testApp.pumpApp(showOnboarding: true);

      onboarding = OnboardingRobot(tester);

      // Go to page 2
      await onboarding.goToNextPage();
      onboarding.verifyOnSecondPage();

      // Swipe back to page 1
      await onboarding.swipeToPreviousPage();
      onboarding.verifyOnFirstPage();
    });

    testWidgets('should skip onboarding and go to main app', (tester) async {
      testApp = await TestApp.create(tester);
      await testApp.pumpApp(showOnboarding: true);

      onboarding = OnboardingRobot(tester);
      navigation = NavigationRobot(tester);

      // Skip onboarding
      await onboarding.skipOnboarding();

      // Verify we're in the main app (Overview tab)
      navigation.verifyOnOverview();
    });

    testWidgets('should complete onboarding and go to main app', (
      tester,
    ) async {
      testApp = await TestApp.create(tester);
      await testApp.pumpApp(showOnboarding: true);

      onboarding = OnboardingRobot(tester);
      navigation = NavigationRobot(tester);

      // Complete full onboarding
      await onboarding.completeFullOnboarding();

      // Verify we're in the main app (Overview tab)
      navigation.verifyOnOverview();
    });
  });
}

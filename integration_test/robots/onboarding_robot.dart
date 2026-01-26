import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'base_robot.dart';

/// Robot for interacting with onboarding screen.
class OnboardingRobot extends BaseRobot {
  OnboardingRobot(super.tester);

  // ============ PAGE NAVIGATION ============

  /// Verify on first onboarding page
  void verifyOnFirstPage() {
    verifyTextDisplayed('Track Money In & Out');
  }

  /// Verify on second onboarding page
  void verifyOnSecondPage() {
    verifyTextDisplayed('Know Your Real Returns');
  }

  /// Verify on third onboarding page
  void verifyOnThirdPage() {
    verifyTextDisplayed('Set Goals & Get Reminders');
  }

  /// Verify on fourth/last onboarding page
  void verifyOnLastPage() {
    verifyTextDisplayed('Works Offline, Syncs Online');
    verifyTextDisplayed('Get Started');
  }

  /// Go to next page
  Future<void> goToNextPage() async {
    await tapText('Next');
  }

  /// Skip onboarding
  Future<void> skipOnboarding() async {
    await tapText('Skip');
  }

  /// Complete onboarding (tap Get Started on last page)
  Future<void> completeOnboarding() async {
    await tapText('Get Started');
  }

  /// Swipe to next page
  Future<void> swipeToNextPage() async {
    await tester.drag(
      find.byType(PageView),
      const Offset(-300, 0),
    );
    await pumpAndSettle();
  }

  /// Swipe to previous page
  Future<void> swipeToPreviousPage() async {
    await tester.drag(
      find.byType(PageView),
      const Offset(300, 0),
    );
    await pumpAndSettle();
  }

  // ============ PAGE INDICATORS ============

  /// Verify page indicators exist
  void verifyPageIndicators() {
    // Look for the row of dot indicators
    final dots = find.byType(AnimatedContainer);
    verifyExists(dots, reason: 'Page indicators should exist');
  }

  // ============ FULL FLOWS ============

  /// Complete full onboarding by going through all pages
  Future<void> completeFullOnboarding() async {
    verifyOnFirstPage();
    await goToNextPage();

    verifyOnSecondPage();
    await goToNextPage();

    verifyOnThirdPage();
    await goToNextPage();

    verifyOnLastPage();
    await completeOnboarding();
  }

  /// Complete onboarding by swiping through all pages
  Future<void> completeBySwipe() async {
    verifyOnFirstPage();
    await swipeToNextPage();

    verifyOnSecondPage();
    await swipeToNextPage();

    verifyOnThirdPage();
    await swipeToNextPage();

    verifyOnLastPage();
    await completeOnboarding();
  }
}

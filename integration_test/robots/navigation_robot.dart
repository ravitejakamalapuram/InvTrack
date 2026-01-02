import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'base_robot.dart';

/// Robot for navigating between app screens using bottom navigation.
class NavigationRobot extends BaseRobot {
  NavigationRobot(super.tester);

  /// Navigate to Overview tab
  Future<void> goToOverview() async {
    await tapIcon(Icons.pie_chart_outline);
  }

  /// Navigate to Investments tab
  Future<void> goToInvestments() async {
    await tapIcon(Icons.account_balance_wallet_outlined);
  }

  /// Navigate to Goals tab
  Future<void> goToGoals() async {
    await tapIcon(Icons.flag_outlined);
  }

  /// Navigate to Settings tab
  Future<void> goToSettings() async {
    await tapIcon(Icons.settings_outlined);
  }

  /// Verify Overview tab is active
  void verifyOnOverview() {
    verifyExists(
      find.byIcon(Icons.pie_chart),
      reason: 'Overview tab should be selected (filled icon)',
    );
  }

  /// Verify Investments tab is active
  void verifyOnInvestments() {
    verifyExists(
      find.byIcon(Icons.account_balance_wallet),
      reason: 'Investments tab should be selected (filled icon)',
    );
  }

  /// Verify Goals tab is active
  void verifyOnGoals() {
    verifyExists(
      find.byIcon(Icons.flag),
      reason: 'Goals tab should be selected (filled icon)',
    );
  }

  /// Verify Settings tab is active
  void verifyOnSettings() {
    verifyExists(
      find.byIcon(Icons.settings),
      reason: 'Settings tab should be selected (filled icon)',
    );
  }

  /// Navigate back using back button or gesture
  Future<void> goBack() async {
    // Try to find back button first
    final backButton = find.byIcon(Icons.arrow_back);
    if (tester.any(backButton)) {
      await tap(backButton);
    } else {
      // Use navigator pop
      final navigatorState = tester.state<NavigatorState>(find.byType(Navigator).first);
      navigatorState.pop();
      await pumpAndSettle();
    }
  }

  /// Tap the FAB (Floating Action Button)
  Future<void> tapFab() async {
    await tap(find.byType(FloatingActionButton));
  }

  /// Verify FAB is visible
  void verifyFabVisible() {
    verifyExistsOnce(
      find.byType(FloatingActionButton),
      reason: 'FAB should be visible',
    );
  }
}


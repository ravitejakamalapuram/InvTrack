import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'base_robot.dart';

/// Robot for interacting with goals screens.
class GoalsRobot extends BaseRobot {
  GoalsRobot(super.tester);

  // ============ GOALS LIST SCREEN ============

  /// Verify empty state is shown
  void verifyEmptyState() {
    // Check for empty state indicators
    verifyExists(
      find.byIcon(Icons.flag),
      reason: 'Goals screen should be visible',
    );
  }

  /// Verify a goal is displayed
  void verifyGoalDisplayed(String name) {
    verifyTextDisplayed(name, reason: 'Goal "$name" should be in the list');
  }

  /// Tap on a goal in the list
  Future<void> tapGoal(String name) async {
    await tapText(name);
  }

  /// Open create goal screen
  Future<void> openCreateGoal() async {
    // Look for FAB or add button
    final fab = find.byType(FloatingActionButton);
    if (tester.any(fab)) {
      await tap(fab);
    } else {
      // Try "Create Goal" button in empty state
      await tapText('Create Goal');
    }
  }

  // ============ CREATE GOAL SCREEN ============

  /// Enter goal name
  Future<void> enterName(String name) async {
    final nameField = find.byType(TextFormField).first;
    await tester.enterText(nameField, name);
    await pumpAndSettle();
  }

  /// Enter target amount
  Future<void> enterTargetAmount(String amount) async {
    final amountField = find.byType(TextFormField).at(1);
    await tester.enterText(amountField, amount);
    await pumpAndSettle();
  }

  /// Tap save goal
  Future<void> tapSave() async {
    final saveButton = find.text('Create Goal');
    if (tester.any(saveButton)) {
      await tapText('Create Goal');
    } else {
      await tapText('Save');
    }
  }

  /// Complete create goal flow
  Future<void> createGoal({
    required String name,
    required String targetAmount,
  }) async {
    await openCreateGoal();
    await enterName(name);
    await enterTargetAmount(targetAmount);
    await tapSave();
  }

  // ============ GOAL DETAIL SCREEN ============

  /// Verify on goal detail screen
  void verifyOnDetailScreen(String goalName) {
    verifyTextDisplayed(goalName);
  }

  /// Verify goal progress
  void verifyProgress(String progressText) {
    verifyTextDisplayed(progressText);
  }

  /// Open edit goal
  Future<void> openEdit() async {
    await tapIcon(Icons.edit_outlined);
  }

  /// Delete goal
  Future<void> deleteGoal() async {
    await tapIcon(Icons.delete_outline_rounded);
    await tapText('Delete');
  }
}


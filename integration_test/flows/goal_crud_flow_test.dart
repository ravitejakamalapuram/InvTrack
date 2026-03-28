/// Integration tests for goal CRUD operations.
///
/// Tests creating, reading, updating, and deleting goals.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';

import '../robots/robots.dart';
import '../test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Goal CRUD Flow Tests', () {
    late TestApp testApp;
    late NavigationRobot navigation;
    late GoalsRobot goals;

    testWidgets('should show empty state when no goals', (tester) async {
      testApp = await TestApp.create(tester);
      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      goals = GoalsRobot(tester);

      await navigation.goToGoals();

      // Verify empty state
      goals.verifyEmptyState();
    });

    testWidgets('should open create goal screen', (tester) async {
      testApp = await TestApp.create(tester);
      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      goals = GoalsRobot(tester);

      await navigation.goToGoals();
      await goals.openCreateGoal();

      // Verify we're on create goal screen
      expect(find.text('Goal Name'), findsOneWidget);
    });

    testWidgets('should display seeded goals', (tester) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedGoals([
        GoalEntity(
          id: 'goal_1',
          name: 'Emergency Fund',
          type: GoalType.targetAmount,
          targetAmount: 50000,
          trackingMode: GoalTrackingMode.all,
          icon: '🛡️',
          colorValue: GoalColors.defaultColor.toARGB32(),
          createdAt: now,
          updatedAt: now,
        ),
        GoalEntity(
          id: 'goal_2',
          name: 'House Down Payment',
          type: GoalType.targetDate,
          targetAmount: 500000,
          targetDate: DateTime(2027, 1, 1),
          trackingMode: GoalTrackingMode.all,
          icon: '🏠',
          colorValue: const Color(0xFF10B981).toARGB32(),
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      goals = GoalsRobot(tester);

      await navigation.goToGoals();

      // Verify goals are displayed
      goals.verifyGoalDisplayed('Emergency Fund');
      goals.verifyGoalDisplayed('House Down Payment');
    });

    testWidgets('should navigate to goal detail screen', (tester) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedGoals([
        GoalEntity(
          id: 'goal_1',
          name: 'Retirement Fund',
          type: GoalType.targetAmount,
          targetAmount: 1000000,
          trackingMode: GoalTrackingMode.all,
          icon: '🎯',
          colorValue: GoalColors.defaultColor.toARGB32(),
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      goals = GoalsRobot(tester);

      await navigation.goToGoals();
      await goals.tapGoal('Retirement Fund');

      // Verify on detail screen
      goals.verifyOnDetailScreen('Retirement Fund');
    });

    testWidgets('should delete goal from detail screen', (tester) async {
      testApp = await TestApp.create(tester);

      final now = DateTime.now();
      testApp.seedGoals([
        GoalEntity(
          id: 'goal_to_delete',
          name: 'Goal to Delete',
          type: GoalType.targetAmount,
          targetAmount: 10000,
          trackingMode: GoalTrackingMode.all,
          icon: '🎯',
          colorValue: GoalColors.defaultColor.toARGB32(),
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await testApp.pumpApp();

      navigation = NavigationRobot(tester);
      goals = GoalsRobot(tester);

      await navigation.goToGoals();
      await goals.tapGoal('Goal to Delete');
      await goals.deleteGoal();

      // Wait for navigation back to list
      await tester.pumpAndSettle();

      // Verify goal is no longer in the list
      expect(find.text('Goal to Delete'), findsNothing);
    });
  });
}

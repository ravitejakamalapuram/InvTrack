/// Integration tests for goals flows.
///
/// Tests goal creation, viewing, and management.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';

import '../robots/robots.dart';
import '../test_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  /// Helper to create a test goal with required fields
  GoalEntity createTestGoal({
    required String id,
    required String name,
    required double targetAmount,
  }) {
    return GoalEntity(
      id: id,
      name: name,
      type: GoalType.targetAmount,
      targetAmount: targetAmount,
      trackingMode: GoalTrackingMode.all,
      icon: GoalIcons.defaultIcon,
      colorValue: GoalColors.defaultColor.toARGB32(),
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
  }

  group('Goals Screen', () {
    testWidgets('should display empty state when no goals', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final goals = GoalsRobot(tester);

      await testApp.pumpApp();
      await nav.goToGoals();

      nav.verifyOnGoals();
      goals.verifyEmptyState();
    });

    testWidgets('should display seeded goals', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final goals = GoalsRobot(tester);

      // Seed test goals
      testApp.seedGoals([
        createTestGoal(
          id: 'goal-1',
          name: 'Emergency Fund',
          targetAmount: 100000,
        ),
        createTestGoal(
          id: 'goal-2',
          name: 'Vacation Fund',
          targetAmount: 50000,
        ),
      ]);

      await testApp.pumpApp();
      await nav.goToGoals();

      goals.verifyGoalDisplayed('Emergency Fund');
      goals.verifyGoalDisplayed('Vacation Fund');
    });

    testWidgets('should navigate to goal detail', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final goals = GoalsRobot(tester);

      testApp.seedGoals([
        createTestGoal(id: 'goal-1', name: 'Test Goal', targetAmount: 100000),
      ]);

      await testApp.pumpApp();
      await nav.goToGoals();

      await goals.tapGoal('Test Goal');
      goals.verifyOnDetailScreen('Test Goal');
    });
  });

  group('Goals Screenshots', () {
    testWidgets('capture goals screen states', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);
      final goals = GoalsRobot(tester);

      await testApp.pumpApp();
      await nav.goToGoals();

      // Empty state
      await goals.takeScreenshot('goals_empty');

      // With goals
      testApp.seedGoals([
        createTestGoal(
          id: 'goal-1',
          name: 'Retirement Fund',
          targetAmount: 1000000,
        ),
      ]);

      await nav.goToOverview();
      await nav.goToGoals();

      await goals.takeScreenshot('goals_with_data');
    });
  });
}

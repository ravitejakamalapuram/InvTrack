import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/handlers/goal_notification_handler.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mocks/mock_notification_service.dart';

/// Creates a [GoalEntity] for use in handler tests.
GoalEntity makeHandlerTestGoal({
  String id = 'handler-goal-1',
  String name = 'Handler Test Goal',
  double targetAmount = 100000,
  List<int> milestones = const [],
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
    notificationMilestonesSent: milestones,
  );
}

void main() {
  late FakeFlutterLocalNotificationsPlugin fakePlugin;
  late SharedPreferences prefs;
  late GoalNotificationHandler handler;
  bool permissionsGranted = true;

  setUp(() async {
    fakePlugin = FakeFlutterLocalNotificationsPlugin();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    permissionsGranted = true;

    handler = GoalNotificationHandler(
      plugin: fakePlugin,
      prefs: prefs,
      ensureInitialized: () async {
        // Initialize the fake plugin with minimal settings
        await fakePlugin.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
        );
      },
      ensurePermissionsForShow: () async => permissionsGranted,
      formatCurrency: (amount, currency) {
        // Simple formatter for tests
        return '₹${amount.toStringAsFixed(2)}';
      },
    );
  });

  tearDown(() {
    fakePlugin.reset();
  });

  group('GoalNotificationHandler.checkAndShowGoalMilestone - return value', () {
    test('returns updated goal with milestone when notification is shown', () async {
      final goal = makeHandlerTestGoal(milestones: []);

      final result = await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 25,
        currentValue: 25000,
        targetValue: 100000,
      );

      expect(result, isA<GoalEntity>());
      final updatedGoal = result as GoalEntity;
      expect(updatedGoal.notificationMilestonesSent, contains(25));
    });

    test('returns goal with 50% added when first reaching 50%', () async {
      final goal = makeHandlerTestGoal(milestones: []);

      final result = await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      final updatedGoal = result as GoalEntity;
      expect(updatedGoal.notificationMilestonesSent, contains(50));
      expect(updatedGoal.notificationMilestonesSent, hasLength(1));
    });

    test('returns goal unchanged when no new milestone reached', () async {
      // Goal already has all milestones sent
      final goal = makeHandlerTestGoal(milestones: [25, 50, 75, 100]);

      final result = await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 75,
        currentValue: 75000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications, isEmpty);
      expect(result, same(goal));
    });

    test('returns goal unchanged when disabled', () async {
      await prefs.setBool('notifications_goal_milestones', false);
      final goal = makeHandlerTestGoal();

      final result = await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      expect(result, same(goal));
      expect(fakePlugin.shownNotifications, isEmpty);
    });

    test('returns goal unchanged when targetValue is zero', () async {
      final goal = makeHandlerTestGoal();

      final result = await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 50,
        currentValue: 0,
        targetValue: 0,
      );

      expect(result, same(goal));
      expect(fakePlugin.shownNotifications, isEmpty);
    });

    test('returns goal unchanged when targetValue is negative', () async {
      final goal = makeHandlerTestGoal();

      final result = await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 50,
        currentValue: 50000,
        targetValue: -1,
      );

      expect(result, same(goal));
      expect(fakePlugin.shownNotifications, isEmpty);
    });

    test('returns goal unchanged when permissions denied', () async {
      permissionsGranted = false;
      final goal = makeHandlerTestGoal();

      final result = await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      expect(result, same(goal));
      expect(fakePlugin.shownNotifications, isEmpty);
    });
  });

  group('GoalNotificationHandler.checkAndShowGoalMilestone - Firestore-based deduplication', () {
    test('does not show milestone already present in goal.notificationMilestonesSent', () async {
      // Goal has [50] already in milestonesSent (Firestore-persisted)
      final goal = makeHandlerTestGoal(milestones: [50]);

      await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications, isEmpty);
    });

    test('shows next unshown milestone when highest is already sent', () async {
      // Goal has [50] in milestonesSent; at 50% progress, should show 25% (next in reverse)
      final goal = makeHandlerTestGoal(milestones: [50]);

      final result = await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 1);
      expect(fakePlugin.shownNotifications.first.title, contains('25%'));
      final updatedGoal = result as GoalEntity;
      expect(updatedGoal.notificationMilestonesSent, containsAll([25, 50]));
    });

    test('returned goal can be passed back in to prevent re-notification', () async {
      final goal = makeHandlerTestGoal(milestones: []);

      // First call at 50% - shows 50%
      final result1 = await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );
      expect(fakePlugin.shownNotifications.length, 1);

      // Use the returned goal (with [50]) for the next call
      final result2 = await handler.checkAndShowGoalMilestone(
        goal: result1 as GoalEntity,
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );
      // Should show 25% (50% already in milestonesSent)
      expect(fakePlugin.shownNotifications.length, 2);
      expect(fakePlugin.shownNotifications.last.title, contains('25%'));

      // Use the returned goal (with [50, 25]) for third call
      await handler.checkAndShowGoalMilestone(
        goal: result2 as GoalEntity,
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );
      // No more milestones at 50% - 25 and 50 already sent, 75 and 100 not reached
      expect(fakePlugin.shownNotifications.length, 2);
    });

    test('ignores SharedPreferences, relies on goal.notificationMilestonesSent', () async {
      // This verifies that a goal with EMPTY notificationMilestonesSent shows a notification
      // even if SharedPreferences was previously set (different goal, or app reinstall scenario)
      await prefs.setBool('goal_milestone_shown_handler-goal-1_50', true);

      final goal = makeHandlerTestGoal(milestones: []);

      // Should still show the notification since goal.notificationMilestonesSent is empty
      await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 1);
    });

    test('does not show 75% milestone when only 74% reached', () async {
      final goal = makeHandlerTestGoal(milestones: [25, 50]);

      final result = await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 74,
        currentValue: 74000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications, isEmpty);
      expect(result, same(goal));
    });
  });

  group('GoalNotificationHandler.checkAndShowGoalMilestone - milestone selection', () {
    test('shows highest unreached milestone at 100%', () async {
      // At 100%, with [25, 50, 75] already sent, shows 100%
      final goal = makeHandlerTestGoal(milestones: [25, 50, 75]);

      await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 100,
        currentValue: 100000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 1);
      expect(
        fakePlugin.shownNotifications.first.title,
        contains('Achieved'),
      );
    });

    test('shows 75% notification at exactly 75% progress', () async {
      final goal = makeHandlerTestGoal(milestones: [25, 50]);

      await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 75,
        currentValue: 75000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 1);
      expect(fakePlugin.shownNotifications.first.title, contains('75%'));
    });

    test('only shows one notification per call even at 100% with no prior milestones', () async {
      // At 100% with no milestones sent, should show 100% (highest first, then stop)
      final goal = makeHandlerTestGoal(milestones: []);

      await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 100,
        currentValue: 100000,
        targetValue: 100000,
      );

      // Only one notification per call
      expect(fakePlugin.shownNotifications.length, 1);
      expect(fakePlugin.shownNotifications.first.title, contains('Achieved'));
    });
  });

  group('GoalNotificationHandler.checkAndShowGoalMilestone - notification content', () {
    test('100% notification title says Goal Achieved', () async {
      final goal = makeHandlerTestGoal(
        id: 'goal-achieved',
        name: 'Vacation Fund',
        milestones: [],
      );

      await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 100,
        currentValue: 100000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 1);
      expect(fakePlugin.shownNotifications.first.title, contains('Achieved'));
    });

    test('100% notification body mentions goal name and target', () async {
      final goal = makeHandlerTestGoal(
        id: 'goal-achieved',
        name: 'Emergency Fund',
        milestones: [],
      );

      await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 100,
        currentValue: 50000,
        targetValue: 50000,
      );

      final body = fakePlugin.shownNotifications.first.body ?? '';
      expect(body, contains('Emergency Fund'));
    });

    test('25% notification title contains percentage', () async {
      final goal = makeHandlerTestGoal(name: 'Retirement Fund', milestones: []);

      await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 25,
        currentValue: 25000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.first.title, contains('25%'));
    });

    test('notification body contains goal name for non-100% milestones', () async {
      final goal = makeHandlerTestGoal(name: 'House Fund', milestones: []);

      await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      expect(
        fakePlugin.shownNotifications.first.body,
        contains('House Fund'),
      );
    });

    test('notification has a non-zero ID', () async {
      final goal = makeHandlerTestGoal(milestones: []);

      await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 25,
        currentValue: 25000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.first.id, isNot(0));
    });

    test('notification has a payload', () async {
      final goal = makeHandlerTestGoal(milestones: []);

      await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 25,
        currentValue: 25000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.first.payload, isNotNull);
    });
  });

  group('GoalNotificationHandler.checkAndShowGoalMilestone - boundary conditions', () {
    test('does not show notification when progress is exactly below 25%', () async {
      final goal = makeHandlerTestGoal(milestones: []);

      final result = await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 24.9,
        currentValue: 24900,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications, isEmpty);
      expect(result, same(goal));
    });

    test('shows 25% notification at exactly 25% progress', () async {
      final goal = makeHandlerTestGoal(milestones: []);

      await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 25.0,
        currentValue: 25000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 1);
      expect(fakePlugin.shownNotifications.first.title, contains('25%'));
    });

    test('shows 25% notification when progress exceeds 25% but is below 50%', () async {
      final goal = makeHandlerTestGoal(milestones: []);

      await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 30,
        currentValue: 30000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 1);
      expect(fakePlugin.shownNotifications.first.title, contains('25%'));
    });

    test('regression: goal with all milestones sent shows no notification', () async {
      final goal = makeHandlerTestGoal(milestones: [25, 50, 75, 100]);

      final result = await handler.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 100,
        currentValue: 100000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications, isEmpty);
      expect(result, same(goal));
    });
  });
}
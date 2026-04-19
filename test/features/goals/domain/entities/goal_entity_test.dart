import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';

void main() {
  group('GoalEntity', () {
    final testGoal = GoalEntity(
      id: 'goal-1',
      name: 'Test Goal',
      type: GoalType.targetAmount,
      targetAmount: 10000,
      trackingMode: GoalTrackingMode.all,
      icon: GoalIcons.defaultIcon,
      colorValue: GoalColors.defaultColor.toARGB32(),
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

    test('color getter returns correct Color from colorValue', () {
      final goal = testGoal.copyWith(colorValue: 0xFF3B82F6);

      expect(goal.color, const Color(0xFF3B82F6));
    });

    test('hasDeadline returns true when targetDate is set', () {
      final goalWithDeadline = testGoal.copyWith(
        targetDate: DateTime(2025, 12, 31),
      );

      expect(goalWithDeadline.hasDeadline, isTrue);
    });

    test('hasDeadline returns false when targetDate is null', () {
      expect(testGoal.hasDeadline, isFalse);
    });

    test('type can be incomeTarget', () {
      final incomeGoal = testGoal.copyWith(type: GoalType.incomeTarget);

      expect(incomeGoal.type, GoalType.incomeTarget);
    });

    test('type can be targetDate', () {
      final dateGoal = testGoal.copyWith(type: GoalType.targetDate);

      expect(dateGoal.type, GoalType.targetDate);
    });

    test('copyWith creates new instance with updated values', () {
      final updated = testGoal.copyWith(
        name: 'Updated Goal',
        targetAmount: 20000,
      );

      expect(updated.id, testGoal.id);
      expect(updated.name, 'Updated Goal');
      expect(updated.targetAmount, 20000);
      expect(updated.type, testGoal.type);
    });

    test('equality works correctly', () {
      final goal1 = testGoal;
      final goal2 = GoalEntity(
        id: 'goal-1',
        name: 'Test Goal',
        type: GoalType.targetAmount,
        targetAmount: 10000,
        trackingMode: GoalTrackingMode.all,
        icon: GoalIcons.defaultIcon,
        colorValue: GoalColors.defaultColor.toARGB32(),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(goal1, equals(goal2));
    });
  });

  group('GoalType', () {
    test('displayName returns correct names', () {
      expect(GoalType.targetAmount.displayName, 'Target Amount');
      expect(GoalType.incomeTarget.displayName, 'Income Target');
      expect(GoalType.targetDate.displayName, 'Target by Date');
    });

    test('icon returns correct icons', () {
      expect(GoalType.targetAmount.icon, Icons.savings_rounded);
      expect(GoalType.incomeTarget.icon, Icons.trending_up_rounded);
      expect(GoalType.targetDate.icon, Icons.event_rounded);
    });

    test('fromString returns correct enum value', () {
      expect(GoalType.fromString('targetAmount'), GoalType.targetAmount);
      expect(GoalType.fromString('incomeTarget'), GoalType.incomeTarget);
    });

    test('fromString returns default for unknown value', () {
      expect(GoalType.fromString('unknown'), GoalType.targetAmount);
    });
  });

  group('GoalTrackingMode', () {
    test('displayName returns correct names', () {
      expect(GoalTrackingMode.all.displayName, 'All Investments');
      expect(GoalTrackingMode.byType.displayName, 'By Investment Type');
      expect(GoalTrackingMode.selected.displayName, 'Selected Investments');
    });

    test('fromString returns correct enum value', () {
      expect(GoalTrackingMode.fromString('all'), GoalTrackingMode.all);
      expect(GoalTrackingMode.fromString('byType'), GoalTrackingMode.byType);
      expect(
        GoalTrackingMode.fromString('selected'),
        GoalTrackingMode.selected,
      );
    });
  });

  group('GoalStatus', () {
    test('displayName returns correct names', () {
      expect(GoalStatus.notStarted.displayName, 'Not Started');
      expect(GoalStatus.onTrack.displayName, 'On Track');
      expect(GoalStatus.ahead.displayName, 'Ahead');
      expect(GoalStatus.behind.displayName, 'Behind');
      expect(GoalStatus.achieved.displayName, 'Achieved');
      expect(GoalStatus.archived.displayName, 'Archived');
    });

    test('icon returns correct icons', () {
      expect(GoalStatus.achieved.icon, Icons.check_circle_rounded);
      expect(GoalStatus.behind.icon, Icons.trending_down_rounded);
    });
  });

  group('GoalColors', () {
    test('available contains expected colors', () {
      expect(GoalColors.available, isNotEmpty);
      expect(GoalColors.available.length, 8);
    });

    test('defaultColor returns first available color', () {
      expect(GoalColors.defaultColor, GoalColors.available[0]);
    });
  });

  group('GoalIcons', () {
    test('available contains expected icons', () {
      expect(GoalIcons.available, isNotEmpty);
    });

    test('defaultIcon is in available list', () {
      expect(GoalIcons.available, contains(GoalIcons.defaultIcon));
    });
  });

  group('GoalEntity - notificationMilestonesSent', () {
    final baseGoal = GoalEntity(
      id: 'goal-notif',
      name: 'Notification Test Goal',
      type: GoalType.targetAmount,
      targetAmount: 50000,
      trackingMode: GoalTrackingMode.all,
      icon: GoalIcons.defaultIcon,
      colorValue: GoalColors.defaultColor.toARGB32(),
      createdAt: DateTime(2024, 6, 1),
      updatedAt: DateTime(2024, 6, 1),
    );

    test('defaults to empty list when not provided', () {
      expect(baseGoal.notificationMilestonesSent, isEmpty);
    });

    test('accepts non-empty list on construction', () {
      final goal = GoalEntity(
        id: 'goal-milestones',
        name: 'Milestone Goal',
        type: GoalType.targetAmount,
        targetAmount: 100000,
        trackingMode: GoalTrackingMode.all,
        icon: GoalIcons.defaultIcon,
        colorValue: GoalColors.defaultColor.toARGB32(),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        notificationMilestonesSent: [25, 50],
      );

      expect(goal.notificationMilestonesSent, equals([25, 50]));
    });

    test('copyWith updates notificationMilestonesSent correctly', () {
      final updated = baseGoal.copyWith(
        notificationMilestonesSent: [25, 50, 75],
      );

      expect(updated.notificationMilestonesSent, equals([25, 50, 75]));
    });

    test('copyWith without notificationMilestonesSent preserves existing value', () {
      final goalWithMilestones = baseGoal.copyWith(
        notificationMilestonesSent: [25, 50],
      );
      final updated = goalWithMilestones.copyWith(name: 'Renamed Goal');

      expect(updated.notificationMilestonesSent, equals([25, 50]));
      expect(updated.name, 'Renamed Goal');
    });

    test('copyWith can set notificationMilestonesSent to empty list', () {
      final goalWithMilestones = baseGoal.copyWith(
        notificationMilestonesSent: [25, 50, 75, 100],
      );
      final cleared = goalWithMilestones.copyWith(
        notificationMilestonesSent: [],
      );

      expect(cleared.notificationMilestonesSent, isEmpty);
    });

    test('copyWith appending a milestone creates new list', () {
      final goalWith25 = baseGoal.copyWith(
        notificationMilestonesSent: [25],
      );
      final goalWith25and50 = goalWith25.copyWith(
        notificationMilestonesSent: [...goalWith25.notificationMilestonesSent, 50],
      );

      expect(goalWith25and50.notificationMilestonesSent, equals([25, 50]));
      // Original should be unchanged
      expect(goalWith25.notificationMilestonesSent, equals([25]));
    });

    test('notificationMilestonesSent stores all four standard milestones', () {
      final goal = baseGoal.copyWith(
        notificationMilestonesSent: [25, 50, 75, 100],
      );

      expect(goal.notificationMilestonesSent, containsAll([25, 50, 75, 100]));
      expect(goal.notificationMilestonesSent.length, 4);
    });

    test('equality is not affected by different notificationMilestonesSent values', () {
      // GoalEntity equality uses id, name, type, etc., NOT notificationMilestonesSent
      final goal1 = baseGoal.copyWith(notificationMilestonesSent: []);
      final goal2 = baseGoal.copyWith(notificationMilestonesSent: [25, 50]);

      expect(goal1, equals(goal2));
    });
  });
}
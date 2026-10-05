// A12 (#756) review: goal status labels and messages are user-facing text,
// so they come from the app strings through the presentation layer, not
// from English in the domain entities.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  // As main.dart does at start-up.
  setUpAll(initializeDateFormatting);

  GoalEntity goal({
    GoalType type = GoalType.targetAmount,
    DateTime? targetDate,
  }) => GoalEntity(
    id: 'goal-1',
    name: 'House',
    type: type,
    targetAmount: 1000000,
    targetMonthlyIncome: type == GoalType.incomeTarget ? 10000 : null,
    targetDate: targetDate,
    trackingMode: GoalTrackingMode.all,
    icon: '🏠',
    colorValue: 0xFF3B82F6,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    currency: 'INR',
  );

  String message(
    GoalStatus status, {
    GoalType type = GoalType.targetAmount,
    DateTime? targetDate,
    DateTime? projected,
  }) => GoalProgress(
    goal: goal(type: type, targetDate: targetDate),
    currentAmount: 200000,
    targetAmount: 1000000,
    progressPercent: 20,
    monthlyVelocity: 0,
    monthlyIncome: 0,
    projectedCompletionDate: projected,
    status: status,
    currentMilestone: GoalMilestone.start,
    achievedMilestones: const [],
    linkedInvestmentCount: 1,
    calculatedAt: DateTime(2026, 10, 4),
  ).statusMessage(l10n);

  group('goal status text from the app strings', () {
    test('every goal status has a label from the app strings', () {
      expect(GoalStatus.notStarted.label(l10n), 'Not Started');
      expect(GoalStatus.inProgress.label(l10n), 'In Progress');
      expect(GoalStatus.onTrack.label(l10n), 'On Track');
      expect(GoalStatus.ahead.label(l10n), 'Ahead');
      expect(GoalStatus.behind.label(l10n), 'Behind');
      expect(GoalStatus.achieved.label(l10n), 'Achieved');
      expect(GoalStatus.archived.label(l10n), 'Archived');
    });

    test('an unprojected goal says why it has no projection', () {
      expect(
        message(GoalStatus.inProgress, type: GoalType.incomeTarget),
        'Income goals are not projected',
      );
      expect(
        message(GoalStatus.inProgress, targetDate: DateTime(2029, 10, 4)),
        'Not enough history to project yet',
      );
    });

    test('every other status has its message', () {
      expect(
        message(GoalStatus.notStarted),
        'Start investing to make progress',
      );
      expect(
        message(GoalStatus.onTrack, projected: DateTime(2027, 3, 15)),
        'On track for Mar 2027',
      );
      expect(message(GoalStatus.onTrack), 'Making steady progress');
      expect(message(GoalStatus.ahead), 'Ahead of schedule! Keep it up!');
      expect(
        message(GoalStatus.behind, targetDate: DateTime(2029, 10, 4)),
        'Behind schedule - needs attention',
      );
      expect(message(GoalStatus.behind), 'Consider increasing contributions');
      expect(message(GoalStatus.achieved), 'Goal achieved!');
      expect(message(GoalStatus.archived), 'Goal archived');
    });
  });
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/notifications/notification_constants.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';
import 'package:inv_tracker/core/notifications/notification_preferences.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handler for goal-related notifications.
///
/// Manages:
/// - Goal milestone notifications (25%, 50%, 75%, 100%)
/// - Goal at-risk notifications
/// - Goal stale notifications
class GoalNotificationHandler with NotificationPreferencesMixin {
  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences _prefs;
  final Future<void> Function() ensureInitialized;
  final Future<bool> Function() ensurePermissionsForShow;
  final String Function(double amount, String currency) formatCurrency;

  /// Standard goal progress milestones to celebrate (percentages)
  static const List<int> goalMilestones = [25, 50, 75, 100];

  GoalNotificationHandler({
    required FlutterLocalNotificationsPlugin plugin,
    required SharedPreferences prefs,
    required this.ensureInitialized,
    required this.ensurePermissionsForShow,
    required this.formatCurrency,
  }) : _plugin = plugin,
       _prefs = prefs;

  @override
  SharedPreferences get prefs => _prefs;

  // ============ Goal Milestone Notifications ============

  /// Check if goal has reached a new milestone and show notification.
  ///
  /// Announces only the highest milestone reached and records every lower
  /// one as shown, so milestones are never announced backwards (GAP3-07).
  /// On the [firstCheck] of a goal with no milestone recorded yet, the
  /// milestones it has already passed are recorded without a notification:
  /// they were reached before, not now.
  Future<void> checkAndShowGoalMilestone({
    required String goalId,
    required String goalName,
    required double progressPercent,
    required double currentValue,
    required double targetValue,
    String currency = 'INR',
    bool firstCheck = false,
  }) async {
    await ensureInitialized();
    if (!goalMilestonesEnabled) return;
    if (targetValue <= 0) return;

    final reached = [
      for (final milestone in goalMilestones)
        if (progressPercent >= milestone) milestone,
    ];
    if (reached.isEmpty) return;
    final reachedMilestone = reached.last;
    if (isGoalMilestoneShown(goalId, reachedMilestone)) return;

    final baseline =
        firstCheck &&
        !goalMilestones.any((m) => isGoalMilestoneShown(goalId, m));
    if (!baseline && !await ensurePermissionsForShow()) return;

    for (final milestone in reached) {
      await markGoalMilestoneShown(goalId, milestone);
    }
    if (baseline) return;

    final formattedCurrent = formatCurrency(currentValue, currency);
    final formattedTarget = formatCurrency(targetValue, currency);

    String title;
    String body;

    if (reachedMilestone == 100) {
      title = '🎉 Goal Achieved!';
      body =
          'Congratulations! You\'ve reached your "$goalName" goal of $formattedTarget!';
    } else {
      title = '🎯 $reachedMilestone% Progress!';
      body =
          'You\'re $reachedMilestone% of the way to your "$goalName" goal! '
          'Current: $formattedCurrent of $formattedTarget.';
    }

    final androidDetails = AndroidNotificationDetails(
      NotificationChannels.goalMilestones,
      'Goal Milestones',
      channelDescription:
          'Celebration notifications for goal progress milestones',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.private,
      groupKey: NotificationGroups.goalMilestones,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: NotificationGroups.goalMilestones,
    );

    await _plugin.show(
      id: NotificationIds.goalMilestone(goalId, reachedMilestone),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: NotificationPayload.goalMilestone(goalId, reachedMilestone),
    );

    LoggerService.info(
      'Goal milestone notification shown',
      metadata: {
        'goalId': goalId,
        'goalName': goalName,
        'milestone': reachedMilestone,
      },
    );
  }

  // ============ Goal At-Risk Notifications ============

  /// Show goal at-risk notification when goal is behind schedule.
  ///
  /// Rate-limited to once per week per goal.
  Future<void> showGoalAtRiskNotification({
    required String goalId,
    required String goalName,
    required double progressPercent,
    required DateTime? targetDate,
    required DateTime? projectedDate,
  }) async {
    await ensureInitialized();
    if (!goalAtRiskEnabled) return;
    if (targetDate == null || projectedDate == null) return;

    final lastShown = getGoalAtRiskLastShown(goalId);
    if (lastShown != null) {
      final daysSinceShown = DateTime.now().difference(lastShown).inDays;
      if (daysSinceShown < 7) return;
    }

    if (!await ensurePermissionsForShow()) return;

    await markGoalAtRiskShown(goalId);

    final daysOver = projectedDate.difference(targetDate).inDays;
    const title = '⚠️ Goal At Risk';
    final body =
        '"$goalName" is ${GoalProgress.wholePercent(progressPercent)}% complete but '
        'projected to miss deadline by $daysOver days. Consider increasing contributions.';

    final androidDetails = AndroidNotificationDetails(
      NotificationChannels.goalMilestones,
      'Goal Alerts',
      channelDescription: 'Alerts when goals need attention',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.private,
      groupKey: NotificationGroups.goalMilestones,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: NotificationGroups.goalMilestones,
    );

    await _plugin.show(
      id: NotificationIds.goalAtRisk(goalId),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: NotificationPayload.goalAtRisk(goalId),
    );

    LoggerService.info(
      'Goal at-risk notification shown',
      metadata: {'goalId': goalId, 'goalName': goalName},
    );
  }

  // ============ Goal Stale Notifications ============

  /// Show goal stale notification when goal has no activity for X days.
  ///
  /// Rate-limited to once per month per goal.
  Future<void> showGoalStaleNotification({
    required String goalId,
    required String goalName,
    required DateTime? lastActivityDate,
  }) async {
    await ensureInitialized();
    if (!goalStaleEnabled) return;

    final now = DateTime.now();
    final threshold = now.subtract(Duration(days: goalStaleDays));

    if (lastActivityDate != null && lastActivityDate.isAfter(threshold)) {
      return;
    }

    final lastShown = getGoalStaleLastShown(goalId);
    if (lastShown != null) {
      final daysSinceShown = now.difference(lastShown).inDays;
      if (daysSinceShown < 30) return;
    }

    if (!await ensurePermissionsForShow()) return;

    await markGoalStaleShown(goalId);

    final daysSinceActivity = lastActivityDate != null
        ? now.difference(lastActivityDate).inDays
        : goalStaleDays;
    const title = '💤 Goal Needs Attention';
    final body =
        '"$goalName" has had no activity for $daysSinceActivity days. '
        'Add investments to make progress!';

    final androidDetails = AndroidNotificationDetails(
      NotificationChannels.goalMilestones,
      'Goal Alerts',
      channelDescription: 'Alerts when goals need attention',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      visibility: NotificationVisibility.private,
      groupKey: NotificationGroups.goalMilestones,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: NotificationGroups.goalMilestones,
    );

    await _plugin.show(
      id: NotificationIds.goalStale(goalId),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: NotificationPayload.goalStale(goalId),
    );

    LoggerService.info(
      'Goal stale notification shown',
      metadata: {'goalId': goalId, 'goalName': goalName},
    );
  }
}

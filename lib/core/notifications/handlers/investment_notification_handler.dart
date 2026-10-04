import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/notifications/notification_constants.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';
import 'package:inv_tracker/core/notifications/notification_preferences.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Handler for investment-related notifications.
///
/// Manages:
/// - Income reminders
/// - Maturity reminders
/// - Investment milestones
/// - Multi-device sync (reschedule all)
/// - Summary notifications
class InvestmentNotificationHandler with NotificationPreferencesMixin {
  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences _prefs;
  final Future<void> Function() ensureInitialized;
  final Future<bool> Function() ensurePermissionsForShow;
  final Future<void> Function() scheduleWeeklySummary;
  final Future<void> Function() scheduleMonthlySummary;
  final DateTime Function() _clock;

  InvestmentNotificationHandler({
    required FlutterLocalNotificationsPlugin plugin,
    required SharedPreferences prefs,
    required this.ensureInitialized,
    required this.ensurePermissionsForShow,
    required this.scheduleWeeklySummary,
    required this.scheduleMonthlySummary,
    DateTime Function()? clock,
  }) : _plugin = plugin,
       _prefs = prefs,
       _clock = clock ?? DateTime.now;

  @override
  SharedPreferences get prefs => _prefs;

  /// Standard MOIC milestones for investment notifications
  static const List<double> standardMilestones = [1.5, 2.0, 3.0, 5.0, 10.0];

  // ============ Income Reminders ============

  /// Schedule income reminder notification for an investment.
  ///
  /// [lastIncomeDate] anchors the payout schedule (pass the start date when
  /// there is no income yet): the reminder fires on the first
  /// `anchor + k * monthsBetweenPayments` (k >= 1) that is not in the past.
  /// The same inputs always give the same date, so calling this on every
  /// launch does not push the reminder out.
  Future<void> scheduleIncomeReminder({
    required String investmentId,
    required String investmentName,
    required int monthsBetweenPayments,
    DateTime? lastIncomeDate,
  }) async {
    await ensureInitialized();
    // Cancel first so that a reminder scheduled before the type was turned
    // off does not keep firing.
    await _plugin.cancel(id: NotificationIds.incomeReminder(investmentId));
    if (!incomeRemindersEnabled) return;

    final now = _clock();
    DateTime nextIncomeDate;

    if (lastIncomeDate != null) {
      // Step from the anchor each time so a month-end anchor (Jan 31) does
      // not drift to an earlier day (Feb 28, Mar 28, ...).
      var periods = 1;
      nextIncomeDate = _addMonthsSafely(
        lastIncomeDate,
        monthsBetweenPayments,
        hour: 9,
      );
      while (nextIncomeDate.isBefore(now)) {
        periods++;
        nextIncomeDate = _addMonthsSafely(
          lastIncomeDate,
          monthsBetweenPayments * periods,
          hour: 9,
        );
      }
    } else {
      nextIncomeDate = _addMonthsSafely(now, monthsBetweenPayments, hour: 9);
    }

    final androidDetails = AndroidNotificationDetails(
      NotificationChannels.incomeReminders,
      'Income Reminders',
      channelDescription: 'Reminders for expected investment income',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.private,
      groupKey: NotificationGroups.incomeReminders,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: NotificationGroups.incomeReminders,
    );

    await _plugin.zonedSchedule(
      id: NotificationIds.incomeReminder(investmentId),
      title: '💰 Income Expected',
      body: 'Income from $investmentName may be due today. Check your account!',
      scheduledDate: tz.TZDateTime.from(nextIncomeDate, tz.local),
      notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: NotificationPayload.incomeReminder(investmentId),
    );

    LoggerService.info(
      'Income reminder scheduled',
      metadata: {
        'investmentId': investmentId,
        'investmentName': investmentName,
        'nextIncomeDate': nextIncomeDate.toString(),
      },
    );
  }

  /// Cancel income reminder for a specific investment.
  Future<void> cancelIncomeReminder(String investmentId) async {
    await _plugin.cancel(id: NotificationIds.incomeReminder(investmentId));
    LoggerService.info(
      'Income reminder cancelled',
      metadata: {'investmentId': investmentId},
    );
  }

  // ============ Maturity Reminders ============

  /// Schedule maturity reminder notifications (7 days and 1 day before).
  ///
  /// Enhanced version includes financial context:
  /// - [investmentType] - Type of investment (FD, MF, etc.)
  /// - [investedAmount] - Original invested amount
  /// - [currentValue] - Current/maturity value
  /// - [currency] - Currency for formatting
  Future<void> scheduleMaturityReminders({
    required String investmentId,
    required String investmentName,
    required DateTime maturityDate,
    String? investmentType,
    double? investedAmount,
    double? currentValue,
    String currency = 'INR',
  }) async {
    await ensureInitialized();
    // Cancel first so that reminders scheduled before the type was turned
    // off do not keep firing.
    await cancelMaturityReminders(investmentId);
    if (!maturityRemindersEnabled) return;

    final now = _clock();
    // Count back calendar days, not 24-hour periods: across a DST change,
    // a local midnight minus 7 x 24 hours is 23:00 on the day before.
    final sevenDaysBefore = DateTime(
      maturityDate.year,
      maturityDate.month,
      maturityDate.day - 7,
    );
    final oneDayBefore = DateTime(
      maturityDate.year,
      maturityDate.month,
      maturityDate.day - 1,
    );

    // Calculate returns if both values are provided
    double? returnPercent;
    if (investedAmount != null && investedAmount > 0 && currentValue != null) {
      returnPercent = ((currentValue - investedAmount) / investedAmount) * 100;
    }

    final androidDetails = AndroidNotificationDetails(
      NotificationChannels.maturityReminders,
      'Maturity Reminders',
      channelDescription: 'Reminders before investments mature',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.private,
      groupKey: NotificationGroups.maturityReminders,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: NotificationGroups.maturityReminders,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Each reminder fires at 09:00 on its day. Guard on that fire time, not
    // on the maturity date's time of day, or a maturity read as late evening
    // (saved in a timezone east of this device) passes the guard after
    // 09:00 has gone and the plugin rejects the past date.
    final sevenDayFireTime = DateTime(
      sevenDaysBefore.year,
      sevenDaysBefore.month,
      sevenDaysBefore.day,
      9,
    );
    final oneDayFireTime = DateTime(
      oneDayBefore.year,
      oneDayBefore.month,
      oneDayBefore.day,
      9,
    );

    // Schedule 7-day reminder
    if (sevenDayFireTime.isAfter(now)) {
      final scheduledDate = sevenDayFireTime;

      await _plugin.zonedSchedule(
        id: NotificationIds.maturityReminder7Days(investmentId),
        title: '📅 Investment Maturing Soon',
        body: _buildMaturityNotificationBody(
          investmentName: investmentName,
          maturityDate: maturityDate,
          daysRemaining: 7,
          investmentType: investmentType,
          currentValue: currentValue,
          returnPercent: returnPercent,
          currency: currency,
        ),
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: NotificationPayload.maturityReminder(investmentId, 7),
      );

      LoggerService.info(
        '7-day maturity reminder scheduled',
        metadata: {
          'investmentId': investmentId,
          'investmentName': investmentName,
          'scheduledDate': scheduledDate.toString(),
        },
      );
    }

    // Schedule 1-day reminder
    if (oneDayFireTime.isAfter(now)) {
      final scheduledDate = oneDayFireTime;

      await _plugin.zonedSchedule(
        id: NotificationIds.maturityReminder1Day(investmentId),
        title: '⏰ Maturity Tomorrow!',
        body: _buildMaturityNotificationBody(
          investmentName: investmentName,
          maturityDate: maturityDate,
          daysRemaining: 1,
          investmentType: investmentType,
          currentValue: currentValue,
          returnPercent: returnPercent,
          currency: currency,
        ),
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: NotificationPayload.maturityReminder(investmentId, 1),
      );

      LoggerService.info(
        '1-day maturity reminder scheduled',
        metadata: {
          'investmentId': investmentId,
          'investmentName': investmentName,
          'scheduledDate': scheduledDate.toString(),
        },
      );
    }
  }

  /// Cancel maturity reminders for a specific investment.
  Future<void> cancelMaturityReminders(String investmentId) async {
    await _plugin.cancel(id: NotificationIds.maturityReminder7Days(investmentId));
    await _plugin.cancel(id: NotificationIds.maturityReminder1Day(investmentId));
    LoggerService.info(
      'Maturity reminders cancelled',
      metadata: {'investmentId': investmentId},
    );
  }

  String _buildMaturityNotificationBody({
    required String investmentName,
    required DateTime maturityDate,
    required int daysRemaining,
    String? investmentType,
    double? currentValue,
    double? returnPercent,
    String currency = 'INR',
  }) {
    final formattedDate = DateFormat('MMM d, yyyy').format(maturityDate);
    final buffer = StringBuffer();

    // Build base message
    buffer.write(investmentName);
    if (investmentType != null) {
      buffer.write(' ($investmentType)');
    }

    if (daysRemaining == 1) {
      buffer.write(' matures tomorrow.');
    } else {
      buffer.write(' matures in $daysRemaining days ($formattedDate).');
    }

    // Add financial context if available
    if (currentValue != null) {
      final currencySymbol = currency == 'INR' ? '₹' : '\$';
      buffer.write(' Value: $currencySymbol${currentValue.toInt()}');
      if (returnPercent != null) {
        buffer.write(' (${returnPercent.toStringAsFixed(1)}% return)');
      }
      buffer.write('.');
    }

    return buffer.toString();
  }

  // ============ Multi-Device Sync Support ============

  /// Re-schedule all notifications for the given investments.
  ///
  /// Call when app launches or investments sync from another device.
  /// [lastIncomeDates] maps investment id to its latest INCOME cash-flow
  /// date; investments without one are anchored on their start date. Pending
  /// income and maturity reminders for investments that are closed or no
  /// longer present are cancelled.
  ///
  /// One investment that fails to schedule is logged and skipped, so it
  /// cannot block the others or the stale-reminder sweep. When [isCancelled]
  /// returns true (the account changed), the remaining work is dropped.
  Future<void> rescheduleAllNotifications(
    List<InvestmentEntity> investments, {
    required Map<String, DateTime> lastIncomeDates,
    bool Function()? isCancelled,
  }) async {
    bool cancelled() => isCancelled?.call() ?? false;

    LoggerService.info(
      'Re-scheduling notifications',
      metadata: {'investmentCount': investments.length},
    );

    try {
      await scheduleWeeklySummary();
      await scheduleMonthlySummary();
    } catch (e) {
      LoggerService.warn('Error scheduling summary notifications', error: e);
    }

    final wantedIds = <int>{};
    for (final investment in investments) {
      if (cancelled()) return;
      if (!investment.isOpen) continue;

      if (investment.maturityDate != null) {
        wantedIds
          ..add(NotificationIds.maturityReminder7Days(investment.id))
          ..add(NotificationIds.maturityReminder1Day(investment.id));
      }
      if (investment.incomeFrequency != null) {
        wantedIds.add(NotificationIds.incomeReminder(investment.id));
      }

      try {
        if (investment.maturityDate != null) {
          await scheduleMaturityReminders(
            investmentId: investment.id,
            investmentName: investment.name,
            maturityDate: investment.maturityDate!,
          );
        }

        if (investment.incomeFrequency != null) {
          await scheduleIncomeReminder(
            investmentId: investment.id,
            investmentName: investment.name,
            monthsBetweenPayments:
                investment.incomeFrequency!.monthsBetweenPayments,
            lastIncomeDate:
                lastIncomeDates[investment.id] ??
                investment.startDate ??
                investment.createdAt,
          );
        }
      } catch (e) {
        LoggerService.warn('Error scheduling investment reminders', error: e);
      }
    }

    if (cancelled()) return;

    // Drop reminders for investments closed, deleted or archived elsewhere.
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      final isInvestmentReminder =
          NotificationIds.isIncomeReminderId(request.id) ||
          NotificationIds.isMaturityReminderId(request.id);
      if (isInvestmentReminder && !wantedIds.contains(request.id)) {
        await _plugin.cancel(id: request.id);
      }
    }

    LoggerService.info('Finished re-scheduling all notifications');
  }

  // ============ Summary Notifications ============

  /// Show grouped summary notification for income reminders.
  Future<void> showIncomeRemindersSummary(List<String> investmentNames) async {
    if (investmentNames.isEmpty) return;
    await ensureInitialized();
    if (!await ensurePermissionsForShow()) return;

    final count = investmentNames.length;
    final title = '💰 $count Income Payments Expected';
    final body =
        investmentNames.take(3).join(', ') +
        (count > 3 ? ' and ${count - 3} more' : '');

    final androidDetails = AndroidNotificationDetails(
      NotificationChannels.incomeReminders,
      'Income Reminders',
      channelDescription: 'Reminders for expected investment income',
      importance: Importance.max,
      priority: Priority.max,
      groupKey: NotificationGroups.incomeReminders,
      setAsGroupSummary: true,
      visibility: NotificationVisibility.private,
      styleInformation: InboxStyleInformation(
        investmentNames.take(5).toList(),
        contentTitle: title,
        summaryText: '$count income payments',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: NotificationGroups.incomeReminders,
    );

    await _plugin.show(
      id: NotificationIds.incomeRemindersSummary,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  /// Show grouped summary notification for maturity reminders.
  Future<void> showMaturityRemindersSummary(
    List<String> investmentNames,
  ) async {
    if (investmentNames.isEmpty) return;
    await ensureInitialized();
    if (!await ensurePermissionsForShow()) return;

    final count = investmentNames.length;
    final title = '📅 $count Investments Maturing Soon';
    final body =
        investmentNames.take(3).join(', ') +
        (count > 3 ? ' and ${count - 3} more' : '');

    final androidDetails = AndroidNotificationDetails(
      NotificationChannels.maturityReminders,
      'Maturity Reminders',
      channelDescription: 'Reminders before investments mature',
      importance: Importance.max,
      priority: Priority.max,
      groupKey: NotificationGroups.maturityReminders,
      setAsGroupSummary: true,
      visibility: NotificationVisibility.private,
      styleInformation: InboxStyleInformation(
        investmentNames.take(5).toList(),
        contentTitle: title,
        summaryText: '$count investments maturing',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: NotificationGroups.maturityReminders,
    );

    await _plugin.show(
      id: NotificationIds.maturityRemindersSummary,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  // ============ Milestone Notifications ============

  /// Check if investment has reached a new milestone and show notification.
  Future<void> checkAndShowMilestone({
    required String investmentId,
    required String investmentName,
    required double totalInvested,
    required double totalReturned,
    required String Function(double, String) formatCurrency,
    String currency = 'INR',
  }) async {
    await ensureInitialized();
    if (!milestonesEnabled) return;
    if (totalInvested <= 0) return;

    if (!await ensurePermissionsForShow()) return;

    final moic = totalReturned / totalInvested;

    double? reachedMilestone;
    for (final milestone in standardMilestones.reversed) {
      if (moic >= milestone && !isMilestoneShown(investmentId, milestone)) {
        reachedMilestone = milestone;
        break;
      }
    }

    if (reachedMilestone == null) return;

    await markMilestoneShown(investmentId, reachedMilestone);

    final profit = totalReturned - totalInvested;
    final formattedProfit = formatCurrency(profit, currency);

    final title =
        '🎉 ${reachedMilestone.toStringAsFixed(1)}x Returns Achieved!';
    final body =
        '$investmentName has reached ${reachedMilestone.toStringAsFixed(1)}x returns! '
        'You\'ve earned $formattedProfit profit.';

    final androidDetails = AndroidNotificationDetails(
      NotificationChannels.milestones,
      'Milestones',
      channelDescription: 'Celebration notifications for investment milestones',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.private,
      groupKey: NotificationGroups.milestones,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: NotificationGroups.milestones,
    );

    await _plugin.show(
      id: NotificationIds.milestone(investmentId, reachedMilestone),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: NotificationPayload.milestone(investmentId, reachedMilestone),
    );

    LoggerService.info(
      'Milestone notification shown',
      metadata: {
        'investmentId': investmentId,
        'investmentName': investmentName,
        'milestone': reachedMilestone,
      },
    );
  }

  // ============ Helper Methods ============

  /// Safely add months to a date, handling day overflow.
  ///
  /// When adding months to a date like January 31 + 3 months, the naive
  /// DateTime(2026, 4, 31) would overflow to May 1 since April has only 30 days.
  /// This method clamps the day to the last valid day of the target month.
  ///
  /// Example:
  /// - Jan 31 + 3 months = Apr 30 (not May 1)
  /// - Jan 31 + 1 month = Feb 28/29 (not Mar 3)
  DateTime _addMonthsSafely(
    DateTime date,
    int months, {
    int hour = 0,
    int minute = 0,
  }) {
    final targetYear = date.year + (date.month + months - 1) ~/ 12;
    final targetMonth = (date.month + months - 1) % 12 + 1;

    // Get the last day of the target month
    final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;

    // Clamp the day to the last valid day of the target month
    final targetDay = date.day > lastDayOfTargetMonth
        ? lastDayOfTargetMonth
        : date.day;

    return DateTime(targetYear, targetMonth, targetDay, hour, minute);
  }
}

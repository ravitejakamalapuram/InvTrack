import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
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

  InvestmentNotificationHandler({
    required FlutterLocalNotificationsPlugin plugin,
    required SharedPreferences prefs,
    required this.ensureInitialized,
    required this.ensurePermissionsForShow,
    required this.scheduleWeeklySummary,
    required this.scheduleMonthlySummary,
  }) : _plugin = plugin,
       _prefs = prefs;

  @override
  SharedPreferences get prefs => _prefs;

  /// Standard MOIC milestones for investment notifications
  static const List<double> standardMilestones = [1.5, 2.0, 3.0, 5.0, 10.0];

  // ============ Income Reminders ============

  /// Schedule income reminder notification for an investment.
  Future<void> scheduleIncomeReminder({
    required String investmentId,
    required String investmentName,
    required int monthsBetweenPayments,
    DateTime? lastIncomeDate,
  }) async {
    await ensureInitialized();
    if (!incomeRemindersEnabled) return;

    await _plugin.cancel(NotificationIds.incomeReminder(investmentId));

    final now = DateTime.now();
    DateTime nextIncomeDate;

    if (lastIncomeDate != null) {
      nextIncomeDate = _addMonthsSafely(
        lastIncomeDate,
        monthsBetweenPayments,
        hour: 9,
      );
      while (nextIncomeDate.isBefore(now)) {
        nextIncomeDate = _addMonthsSafely(
          nextIncomeDate,
          monthsBetweenPayments,
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
      NotificationIds.incomeReminder(investmentId),
      '💰 Income Expected',
      'Income from $investmentName may be due today. Check your account!',
      tz.TZDateTime.from(nextIncomeDate, tz.local),
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: NotificationPayload.incomeReminder(investmentId),
    );

    if (kDebugMode) {
      debugPrint(
        '🔔 Income reminder scheduled for $investmentName on $nextIncomeDate',
      );
    }
  }

  /// Cancel income reminder for a specific investment.
  Future<void> cancelIncomeReminder(String investmentId) async {
    await _plugin.cancel(NotificationIds.incomeReminder(investmentId));
    if (kDebugMode) {
      debugPrint('🔔 Income reminder cancelled for investment $investmentId');
    }
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
    if (!maturityRemindersEnabled) return;

    await cancelMaturityReminders(investmentId);

    final now = DateTime.now();
    final sevenDaysBefore = maturityDate.subtract(const Duration(days: 7));
    final oneDayBefore = maturityDate.subtract(const Duration(days: 1));

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

    // Schedule 7-day reminder
    if (sevenDaysBefore.isAfter(now)) {
      final scheduledDate = DateTime(
        sevenDaysBefore.year,
        sevenDaysBefore.month,
        sevenDaysBefore.day,
        9,
        0,
      );

      await _plugin.zonedSchedule(
        NotificationIds.maturityReminder7Days(investmentId),
        '📅 Investment Maturing Soon',
        _buildMaturityNotificationBody(
          investmentName: investmentName,
          maturityDate: maturityDate,
          daysRemaining: 7,
          investmentType: investmentType,
          currentValue: currentValue,
          returnPercent: returnPercent,
          currency: currency,
        ),
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: NotificationPayload.maturityReminder(investmentId, 7),
      );

      if (kDebugMode) {
        debugPrint(
          '🔔 7-day maturity reminder scheduled for $investmentName on $scheduledDate',
        );
      }
    }

    // Schedule 1-day reminder
    if (oneDayBefore.isAfter(now)) {
      final scheduledDate = DateTime(
        oneDayBefore.year,
        oneDayBefore.month,
        oneDayBefore.day,
        9,
        0,
      );

      await _plugin.zonedSchedule(
        NotificationIds.maturityReminder1Day(investmentId),
        '⏰ Maturity Tomorrow!',
        _buildMaturityNotificationBody(
          investmentName: investmentName,
          maturityDate: maturityDate,
          daysRemaining: 1,
          investmentType: investmentType,
          currentValue: currentValue,
          returnPercent: returnPercent,
          currency: currency,
        ),
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: NotificationPayload.maturityReminder(investmentId, 1),
      );

      if (kDebugMode) {
        debugPrint(
          '🔔 1-day maturity reminder scheduled for $investmentName on $scheduledDate',
        );
      }
    }
  }

  /// Cancel maturity reminders for a specific investment.
  Future<void> cancelMaturityReminders(String investmentId) async {
    await _plugin.cancel(NotificationIds.maturityReminder7Days(investmentId));
    await _plugin.cancel(NotificationIds.maturityReminder1Day(investmentId));
    if (kDebugMode) {
      debugPrint(
        '🔔 Maturity reminders cancelled for investment $investmentId',
      );
    }
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
  Future<void> rescheduleAllNotifications(
    List<InvestmentEntity> investments,
  ) async {
    if (kDebugMode) {
      debugPrint(
        '🔔 Re-scheduling notifications for ${investments.length} investments',
      );
    }

    await scheduleWeeklySummary();
    await scheduleMonthlySummary();

    for (final investment in investments) {
      if (!investment.isOpen) continue;

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
        );
      }
    }

    if (kDebugMode) {
      debugPrint('🔔 Finished re-scheduling all notifications');
    }
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
      NotificationIds.incomeRemindersSummary,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
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
      NotificationIds.maturityRemindersSummary,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
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
      NotificationIds.milestone(investmentId, reachedMilestone),
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: NotificationPayload.milestone(investmentId, reachedMilestone),
    );

    if (kDebugMode) {
      debugPrint(
        '🔔 Milestone notification shown: ${reachedMilestone}x for $investmentName',
      );
    }
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

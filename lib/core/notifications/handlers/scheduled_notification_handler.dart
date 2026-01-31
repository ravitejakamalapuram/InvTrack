import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:inv_tracker/core/notifications/notification_constants.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';
import 'package:inv_tracker/core/notifications/notification_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Handler for scheduled summary notifications.
///
/// Manages:
/// - Weekly summary scheduling
/// - Monthly summary scheduling
/// - Tax reminder scheduling
/// - Weekly check-in scheduling
/// - Financial Year summary scheduling
class ScheduledNotificationHandler with NotificationPreferencesMixin {
  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences _prefs;
  final Future<void> Function() ensureInitialized;
  final Future<bool> Function() ensurePermissionsForShow;
  final String Function(double amount, String currency) formatCurrency;

  ScheduledNotificationHandler({
    required FlutterLocalNotificationsPlugin plugin,
    required SharedPreferences prefs,
    required this.ensureInitialized,
    required this.ensurePermissionsForShow,
    required this.formatCurrency,
  })  : _plugin = plugin,
        _prefs = prefs;

  @override
  SharedPreferences get prefs => _prefs;

  // ============ Weekly & Monthly Summaries ============

  /// Schedule weekly summary notification (every Sunday at 10 AM)
  Future<void> scheduleWeeklySummary() async {
    await ensureInitialized();
    if (!weeklySummaryEnabled) return;

    await _plugin.cancel(NotificationIds.weeklySummary);

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.weeklySummary,
      'Weekly Summary',
      channelDescription: 'Weekly investment activity summary',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.private,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 10, 0);

    while (scheduledDate.weekday != DateTime.sunday ||
        scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      NotificationIds.weeklySummary,
      '📊 Weekly Investment Summary',
      'Check your investment activity for this week',
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: NotificationPayload.weeklySummary,
    );

    if (kDebugMode) {
      debugPrint('🔔 Weekly summary scheduled for $scheduledDate');
    }
  }

  /// Schedule monthly income summary (last day of each month at 6 PM)
  Future<void> scheduleMonthlySummary() async {
    await ensureInitialized();
    if (!monthlySummaryEnabled) return;

    await _plugin.cancel(NotificationIds.monthlySummary);

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.monthlySummary,
      'Monthly Summary',
      channelDescription: 'Monthly investment income summary',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.private,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final now = DateTime.now();
    var lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 18, 0);

    if (lastDayOfMonth.isBefore(now) ||
        (lastDayOfMonth.day == now.day && now.hour >= 18)) {
      lastDayOfMonth = DateTime(now.year, now.month + 2, 0, 18, 0);
    }

    await _plugin.zonedSchedule(
      NotificationIds.monthlySummary,
      '📈 Monthly Income Summary',
      'Review your investment income for this month',
      tz.TZDateTime.from(lastDayOfMonth, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      payload: NotificationPayload.monthlySummary,
    );

    if (kDebugMode) {
      debugPrint('🔔 Monthly summary scheduled for $lastDayOfMonth');
    }
  }

  // ============ Tax Reminder Notifications ============

  /// Schedule all tax-related reminders for the financial year.
  Future<void> scheduleTaxReminders() async {
    await ensureInitialized();
    if (!taxRemindersEnabled) return;

    await cancelTaxReminders();

    final now = DateTime.now();
    final currentYear = now.year;
    final nextYear = currentYear + 1;
    final fyYear = now.month >= 4 ? currentYear : currentYear - 1;

    final reminders = <_TaxReminder>[
      _TaxReminder(
        id: NotificationIds.taxReminder80C,
        title: '📋 80C Investment Deadline',
        body: 'March 31 is the deadline for 80C tax-saving investments.',
        date: DateTime(fyYear + 1, 3, 24, 9, 0),
      ),
      _TaxReminder(
        id: NotificationIds.taxReminderAdvanceQ1,
        title: '💰 Advance Tax Due (Q1)',
        body: 'First installment of advance tax (15%) is due by June 15.',
        date: DateTime(now.month >= 6 ? nextYear : currentYear, 6, 10, 9, 0),
      ),
      _TaxReminder(
        id: NotificationIds.taxReminderAdvanceQ2,
        title: '💰 Advance Tax Due (Q2)',
        body: 'Second installment of advance tax (45%) is due by September 15.',
        date: DateTime(now.month >= 9 ? nextYear : currentYear, 9, 10, 9, 0),
      ),
      _TaxReminder(
        id: NotificationIds.taxReminderAdvanceQ3,
        title: '💰 Advance Tax Due (Q3)',
        body: 'Third installment of advance tax (75%) is due by December 15.',
        date: DateTime(now.month >= 12 ? nextYear : currentYear, 12, 10, 9, 0),
      ),
      _TaxReminder(
        id: NotificationIds.taxReminderAdvanceQ4,
        title: '💰 Advance Tax Due (Q4)',
        body: 'Final installment of advance tax (100%) is due by March 15.',
        date: DateTime(
          now.month >= 3 && now.day > 15 ? nextYear : currentYear,
          3, 10, 9, 0,
        ),
      ),
      _TaxReminder(
        id: NotificationIds.taxReminderITR,
        title: '📝 ITR Filing Deadline',
        body: 'July 31 is the deadline for filing Income Tax Returns.',
        date: DateTime(
          now.month >= 7 && now.day > 25 ? nextYear : currentYear,
          7, 25, 9, 0,
        ),
      ),
    ];

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.taxReminders,
      'Tax Reminders',
      channelDescription: 'Important tax-related deadlines and reminders',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.private,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    for (final reminder in reminders) {
      if (reminder.date.isAfter(now)) {
        await _plugin.zonedSchedule(
          reminder.id,
          reminder.title,
          reminder.body,
          tz.TZDateTime.from(reminder.date, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: NotificationPayload.taxReminder(reminder.id.toString()),
        );

        if (kDebugMode) {
          debugPrint('🔔 Tax reminder scheduled: ${reminder.title}');
        }
      }
    }
  }

  /// Cancel all tax reminder notifications
  Future<void> cancelTaxReminders() async {
    await _plugin.cancel(NotificationIds.taxReminder80C);
    await _plugin.cancel(NotificationIds.taxReminderAdvanceQ1);
    await _plugin.cancel(NotificationIds.taxReminderAdvanceQ2);
    await _plugin.cancel(NotificationIds.taxReminderAdvanceQ3);
    await _plugin.cancel(NotificationIds.taxReminderAdvanceQ4);
    await _plugin.cancel(NotificationIds.taxReminderITR);
  }

  // ============ Weekly Check-In Notifications ============

  /// Schedule weekly check-in prompt for Sunday at 6 PM.
  Future<void> scheduleWeeklyCheckIn() async {
    await ensureInitialized();
    if (!weeklyCheckInEnabled) return;

    await _plugin.cancel(NotificationIds.weeklyCheckIn);

    var nextSunday = DateTime.now();
    while (nextSunday.weekday != DateTime.sunday) {
      nextSunday = nextSunday.add(const Duration(days: 1));
    }
    nextSunday = DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 18, 0);

    if (nextSunday.isBefore(DateTime.now())) {
      nextSunday = nextSunday.add(const Duration(days: 7));
    }

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.weeklyCheckIn,
      'Weekly Check-In',
      channelDescription: 'Weekly prompts to log investment income',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      visibility: NotificationVisibility.private,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      NotificationIds.weeklyCheckIn,
      '📊 Weekly Check-In',
      'Did you receive any investment income this week? Tap to log it now.',
      tz.TZDateTime.from(nextSunday, tz.local),
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: NotificationPayload.weeklyCheckIn,
    );

    if (kDebugMode) {
      debugPrint('🔔 Weekly check-in scheduled for $nextSunday');
    }
  }

  // ============ Financial Year Summary ============

  /// Schedule FY summary notification for April 1st at 10 AM.
  Future<void> scheduleFYSummary() async {
    await ensureInitialized();
    if (!fySummaryEnabled) return;

    await _plugin.cancel(NotificationIds.fySummary);

    final now = DateTime.now();
    var nextApril1 = DateTime(now.year, 4, 1, 10, 0);

    if (nextApril1.isBefore(now)) {
      nextApril1 = DateTime(now.year + 1, 4, 1, 10, 0);
    }

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.fySummary,
      'FY Summary',
      channelDescription: 'Annual financial year summary',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      visibility: NotificationVisibility.private,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      NotificationIds.fySummary,
      '📅 FY Summary Ready',
      'Your financial year summary is ready!',
      tz.TZDateTime.from(nextApril1, tz.local),
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: NotificationPayload.fySummary,
    );

    if (kDebugMode) {
      debugPrint('🔔 FY summary scheduled for $nextApril1');
    }
  }

  /// Show immediate FY summary notification with custom data.
  Future<void> showFYSummary({
    required int previousFY,
    required double totalIncome,
    required double totalTDS,
    required String? topPerformer,
    String currency = 'INR',
  }) async {
    await ensureInitialized();
    if (!await ensurePermissionsForShow()) return;

    final formattedIncome = formatCurrency(totalIncome, currency);
    final formattedTDS = formatCurrency(totalTDS, currency);

    final buffer = StringBuffer();
    final nextFY = previousFY + 1;
    buffer.write('FY$previousFY-$nextFY: Income: $formattedIncome');
    if (totalTDS > 0) buffer.write(', TDS: $formattedTDS');
    if (topPerformer != null) buffer.write('. Top: $topPerformer');

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.fySummary,
      'FY Summary',
      channelDescription: 'Annual financial year summary',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      visibility: NotificationVisibility.private,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      NotificationIds.fySummary,
      '📊 FY$previousFY-$nextFY Summary',
      buffer.toString(),
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: NotificationPayload.fySummary,
    );

    if (kDebugMode) {
      debugPrint('🔔 FY summary shown');
    }
  }
}

/// Helper class for tax reminders
class _TaxReminder {
  final int id;
  final String title;
  final String body;
  final DateTime date;

  const _TaxReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
  });
}

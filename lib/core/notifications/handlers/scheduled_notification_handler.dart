import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
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
  final DateTime Function() _clock;

  ScheduledNotificationHandler({
    required FlutterLocalNotificationsPlugin plugin,
    required SharedPreferences prefs,
    required this.ensureInitialized,
    required this.ensurePermissionsForShow,
    required this.formatCurrency,
    DateTime Function()? clock,
  }) : _plugin = plugin,
       _prefs = prefs,
       _clock = clock ?? DateTime.now;

  @override
  SharedPreferences get prefs => _prefs;

  /// The weekly, monthly and FY summaries open a report; with Reports off the
  /// tap would land on Overview with nothing to show, so they are not
  /// scheduled (and any pending one is cancelled).
  bool reportsRouteEnabled = false;

  /// Base currency of the signed-in user; the India tax deadlines apply only
  /// to INR. Null until known, so nothing is scheduled before then.
  String? baseCurrency;

  Future<bool> _reportsOff(int id) async {
    if (reportsRouteEnabled) return false;
    await _plugin.cancel(id: id);
    return true;
  }

  // ============ Weekly & Monthly Summaries ============

  /// Schedule weekly summary notification (every Sunday at 10 AM)
  Future<void> scheduleWeeklySummary() async {
    await ensureInitialized();
    if (!weeklySummaryEnabled) return;
    if (await _reportsOff(NotificationIds.weeklySummary)) return;

    await _plugin.cancel(id: NotificationIds.weeklySummary);

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.weeklySummary,
      'Weekly Summary',
      channelDescription: 'Weekly investment activity summary',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
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
      id: NotificationIds.weeklySummary,
      title: '📊 Weekly Investment Summary',
      body: 'Check your investment activity for this week',
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: NotificationPayload.weeklySummary,
    );

    LoggerService.info(
      'Weekly summary scheduled',
      metadata: {'scheduledDate': scheduledDate.toString()},
    );
  }

  /// Schedule monthly income summary (last day of each month at 6 PM)
  Future<void> scheduleMonthlySummary() async {
    await ensureInitialized();
    if (!monthlySummaryEnabled) return;
    if (await _reportsOff(NotificationIds.monthlySummary)) return;

    await _plugin.cancel(id: NotificationIds.monthlySummary);

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.monthlySummary,
      'Monthly Summary',
      channelDescription: 'Monthly investment income summary',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
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
      id: NotificationIds.monthlySummary,
      title: '📈 Monthly Income Summary',
      body: 'Review your investment income for this month',
      scheduledDate: tz.TZDateTime.from(lastDayOfMonth, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      payload: NotificationPayload.monthlySummary,
    );

    LoggerService.info(
      'Monthly summary scheduled',
      metadata: {'scheduledDate': lastDayOfMonth.toString()},
    );
  }

  /// The title and body of the recap for [month]. Counts only, never an
  /// amount or a name (rules 7 and 8): [maturingNextMonth] is how many
  /// investments mature in the month after, [needingValue] how many open ones
  /// wait on a current value.
  static ({String title, String body}) monthlyRecapText({
    required DateTime month,
    required int maturingNextMonth,
    required int needingValue,
  }) {
    final monthName = DateFormat('MMMM').format(month);
    final nextName = DateFormat(
      'MMMM',
    ).format(DateTime(month.year, month.month + 1));
    final facts = [
      if (maturingNextMonth == 1) '1 investment matures in $nextName.',
      if (maturingNextMonth > 1)
        '$maturingNextMonth investments mature in $nextName.',
      if (needingValue == 1) '1 needs a current value.',
      if (needingValue > 1) '$needingValue need a current value.',
    ];
    return (
      title: 'Your $monthName recap is ready',
      body: facts.isEmpty ? 'See what came in last month.' : facts.join(' '),
    );
  }

  /// Schedule the recap of [now]'s month for 10 AM on the 1st of the next.
  /// It takes the monthly summary's slot and toggle, and is rescheduled with
  /// fresh counts whenever investments change.
  Future<void> scheduleMonthlyRecap({
    required DateTime now,
    required int maturingNextMonth,
    required int needingValue,
  }) async {
    await ensureInitialized();
    if (monthlySummaryEnabled &&
        shouldKeepDueRecap(now, await _plugin.pendingNotificationRequests())) {
      return;
    }
    await _plugin.cancel(id: NotificationIds.monthlySummary);
    if (!monthlySummaryEnabled) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        NotificationChannels.monthlyRecap,
        'Monthly Recap',
        channelDescription: 'What came in last month and what needs you next',
        visibility: NotificationVisibility.private,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true),
    );
    final month = DateTime(now.year, now.month);
    final text = monthlyRecapText(
      month: month,
      maturingNextMonth: maturingNextMonth,
      needingValue: needingValue,
    );

    await _plugin.zonedSchedule(
      id: NotificationIds.monthlySummary,
      title: text.title,
      body: text.body,
      scheduledDate: tz.TZDateTime.from(
        DateTime(now.year, now.month + 1, 1, 10),
        tz.local,
      ),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: NotificationPayload.monthlyRecap(
        DateFormat('yyyy-MM').format(month),
      ),
    );
  }

  /// On the 1st, a still-pending recap of last month is the one due today
  /// (the alarm is inexact, so it can fire after 10:00). Opening the app must
  /// not replace it.
  static bool shouldKeepDueRecap(
    DateTime now,
    List<PendingNotificationRequest> pending,
  ) {
    if (now.day != 1) return false;
    final due = NotificationPayload.monthlyRecap(
      DateFormat('yyyy-MM').format(DateTime(now.year, now.month - 1)),
    );
    return pending.any(
      (r) => r.id == NotificationIds.monthlySummary && r.payload == due,
    );
  }

  // ============ Tax Reminder Notifications ============

  /// Schedule all tax-related reminders for the financial year.
  Future<void> scheduleTaxReminders() async {
    await ensureInitialized();
    if (!taxRemindersEnabled) return;

    await cancelTaxReminders();
    if (baseCurrency != 'INR') return;

    final now = _clock();

    // Each deadline reminder fires at 09:00 on its next occurrence, so the
    // date does not depend on which day the app was opened.
    DateTime next(int month, int day) {
      final thisYear = DateTime(now.year, month, day, 9);
      return thisYear.isAfter(now)
          ? thisYear
          : DateTime(now.year + 1, month, day, 9);
    }

    final reminders = <_TaxReminder>[
      _TaxReminder(
        id: NotificationIds.taxReminder80C,
        title: '📋 80C Investment Deadline',
        body: 'March 31 is the deadline for 80C tax-saving investments.',
        date: next(3, 24),
      ),
      _TaxReminder(
        id: NotificationIds.taxReminderAdvanceQ1,
        title: '💰 Advance Tax Due (Q1)',
        body: 'First installment of advance tax (15%) is due by June 15.',
        date: next(6, 10),
      ),
      _TaxReminder(
        id: NotificationIds.taxReminderAdvanceQ2,
        title: '💰 Advance Tax Due (Q2)',
        body: 'Second installment of advance tax (45%) is due by September 15.',
        date: next(9, 10),
      ),
      _TaxReminder(
        id: NotificationIds.taxReminderAdvanceQ3,
        title: '💰 Advance Tax Due (Q3)',
        body: 'Third installment of advance tax (75%) is due by December 15.',
        date: next(12, 10),
      ),
      _TaxReminder(
        id: NotificationIds.taxReminderAdvanceQ4,
        title: '💰 Advance Tax Due (Q4)',
        body: 'Final installment of advance tax (100%) is due by March 15.',
        date: next(3, 10),
      ),
      _TaxReminder(
        id: NotificationIds.taxReminderITR,
        title: '📝 ITR Filing Deadline',
        body: 'July 31 is the deadline for filing Income Tax Returns.',
        date: next(7, 25),
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

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    for (final reminder in reminders) {
      if (reminder.date.isAfter(now)) {
        await _plugin.zonedSchedule(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: tz.TZDateTime.from(reminder.date, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: NotificationPayload.taxReminder(reminder.id.toString()),
        );

        LoggerService.info(
          'Tax reminder scheduled',
          metadata: {'title': reminder.title, 'date': reminder.date.toString()},
        );
      }
    }
  }

  /// Cancel all tax reminder notifications
  Future<void> cancelTaxReminders() async {
    await _plugin.cancel(id: NotificationIds.taxReminder80C);
    await _plugin.cancel(id: NotificationIds.taxReminderAdvanceQ1);
    await _plugin.cancel(id: NotificationIds.taxReminderAdvanceQ2);
    await _plugin.cancel(id: NotificationIds.taxReminderAdvanceQ3);
    await _plugin.cancel(id: NotificationIds.taxReminderAdvanceQ4);
    await _plugin.cancel(id: NotificationIds.taxReminderITR);
  }

  // ============ Weekly Check-In Notifications ============

  /// Schedule weekly check-in prompt for Sunday at 6 PM.
  Future<void> scheduleWeeklyCheckIn() async {
    await ensureInitialized();
    if (!weeklyCheckInEnabled) return;

    await _plugin.cancel(id: NotificationIds.weeklyCheckIn);

    var nextSunday = DateTime.now();
    while (nextSunday.weekday != DateTime.sunday) {
      nextSunday = nextSunday.add(const Duration(days: 1));
    }
    nextSunday = DateTime(
      nextSunday.year,
      nextSunday.month,
      nextSunday.day,
      18,
      0,
    );

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
      id: NotificationIds.weeklyCheckIn,
      title: '📊 Weekly Check-In',
      body: 'Did you receive any investment income this week? Tap to log it now.',
      scheduledDate: tz.TZDateTime.from(nextSunday, tz.local),
      notificationDetails: const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: NotificationPayload.weeklyCheckIn,
    );

    LoggerService.info(
      'Weekly check-in scheduled',
      metadata: {'scheduledDate': nextSunday.toString()},
    );
  }

  // ============ Financial Year Summary ============

  /// Schedule FY summary notification for April 1st at 10 AM.
  Future<void> scheduleFYSummary() async {
    await ensureInitialized();
    if (!fySummaryEnabled) return;
    if (await _reportsOff(NotificationIds.fySummary)) return;

    await _plugin.cancel(id: NotificationIds.fySummary);

    final now = DateTime.now();
    var nextApril1 = DateTime(now.year, 4, 1, 10, 0);

    if (nextApril1.isBefore(now)) {
      nextApril1 = DateTime(now.year + 1, 4, 1, 10, 0);
    }

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.fySummary,
      'FY Summary',
      channelDescription: 'Annual financial year summary',
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
      id: NotificationIds.fySummary,
      title: '📅 FY Summary Ready',
      body: 'Your financial year summary is ready!',
      scheduledDate: tz.TZDateTime.from(nextApril1, tz.local),
      notificationDetails: const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: NotificationPayload.fySummary,
    );

    LoggerService.info(
      'FY summary scheduled',
      metadata: {'scheduledDate': nextApril1.toString()},
    );
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

    await _plugin.show(
      id: NotificationIds.fySummary,
      title: '📊 FY$previousFY-$nextFY Summary',
      body: buffer.toString(),
      notificationDetails: const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: NotificationPayload.fySummary,
    );

    LoggerService.info('FY summary shown');
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

/// Notification service for local push notifications.
///
/// Handles scheduling and displaying notifications for:
/// - Income alerts (when income is recorded)
/// - Weekly investment summary
/// - Maturity reminders
/// - Income reminders
/// - Monthly income summary
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:inv_tracker/core/notifications/notification_navigator.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Provider for the notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError('Override in main.dart');
});

/// Notification channel IDs
class NotificationChannels {
  static const String weeklySummary = 'weekly_summary';
  static const String incomeReminders = 'income_reminders';
  static const String maturityReminders = 'maturity_reminders';
  static const String monthlySummary = 'monthly_summary';
  static const String milestones = 'milestones';
  static const String goalMilestones = 'goal_milestones';
  static const String taxReminders = 'tax_reminders';
  static const String riskAlerts = 'risk_alerts';
  static const String weeklyCheckIn = 'weekly_check_in';
  static const String idleAlerts = 'idle_alerts';
  static const String fySummary = 'fy_summary';
  static const String general = 'general'; // For test notifications
}

/// Notification group keys for Android grouping
class NotificationGroups {
  static const String incomeReminders = 'com.invtracker.INCOME_REMINDERS';
  static const String maturityReminders = 'com.invtracker.MATURITY_REMINDERS';
  static const String milestones = 'com.invtracker.MILESTONES';
  static const String goalMilestones = 'com.invtracker.GOAL_MILESTONES';
}

/// Notification IDs for scheduled notifications
class NotificationIds {
  static const int weeklySummary = 1000;
  static const int monthlySummary = 1001;

  /// Summary notification IDs for grouped notifications
  static const int incomeRemindersSummary = 1002;
  static const int maturityRemindersSummary = 1003;

  /// Tax reminder IDs (fixed dates throughout the year)
  static const int taxReminder80C = 1010;
  static const int taxReminderAdvanceQ1 = 1011;
  static const int taxReminderAdvanceQ2 = 1012;
  static const int taxReminderAdvanceQ3 = 1013;
  static const int taxReminderAdvanceQ4 = 1014;
  static const int taxReminderITR = 1015;

  /// Generate a unique notification ID for income reminders based on investment ID
  static int incomeReminder(String investmentId) =>
      (investmentId.hashCode.abs() % 50000) + 50000;

  /// Generate unique notification IDs for maturity reminders (7-day and 1-day before)
  static int maturityReminder7Days(String investmentId) =>
      (investmentId.hashCode.abs() % 25000) + 100000;
  static int maturityReminder1Day(String investmentId) =>
      (investmentId.hashCode.abs() % 25000) + 125000;

  /// Milestone notification ID based on investment ID and milestone type
  static int milestone(String investmentId, double moic) =>
      (investmentId.hashCode.abs() % 20000) + 150000 + (moic * 100).toInt();

  /// Risk alert notification ID
  static int riskAlert(String alertType) =>
      200000 + alertType.hashCode.abs() % 1000;

  /// Weekly check-in notification
  static const int weeklyCheckIn = 2000;

  /// Idle investment alert ID (per investment)
  static int idleAlert(String investmentId) =>
      210000 + investmentId.hashCode.abs() % 10000;

  /// FY summary notification
  static const int fySummary = 2001;

  /// Goal milestone notification ID based on goal ID and milestone percentage
  static int goalMilestone(String goalId, int milestonePercent) =>
      (goalId.hashCode.abs() % 20000) + 220000 + milestonePercent;
}

/// Settings keys for notification preferences
class NotificationPrefsKeys {
  static const String weeklySummaryEnabled = 'notifications_weekly_summary';
  static const String incomeRemindersEnabled = 'notifications_income_reminders';
  static const String maturityRemindersEnabled =
      'notifications_maturity_reminders';
  static const String monthlySummaryEnabled = 'notifications_monthly_summary';
  static const String milestonesEnabled = 'notifications_milestones';
  static const String goalMilestonesEnabled = 'notifications_goal_milestones';
  static const String taxRemindersEnabled = 'notifications_tax_reminders';
  static const String riskAlertsEnabled = 'notifications_risk_alerts';
  static const String weeklyCheckInEnabled = 'notifications_weekly_check_in';
  static const String idleAlertsEnabled = 'notifications_idle_alerts';
  static const String idleAlertDays = 'notifications_idle_alert_days';
  static const String fySummaryEnabled = 'notifications_fy_summary';

  /// Track which milestones have been shown (to avoid duplicates)
  static String milestoneShown(String investmentId, double moic) =>
      'milestone_shown_${investmentId}_${moic.toStringAsFixed(1)}';

  /// Track which goal milestones have been shown (to avoid duplicates)
  static String goalMilestoneShown(String goalId, int milestonePercent) =>
      'goal_milestone_shown_${goalId}_$milestonePercent';

  /// Track when idle alert was last shown for an investment
  static String idleAlertLastShown(String investmentId) =>
      'idle_alert_last_shown_$investmentId';
}

/// Notification service that wraps flutter_local_notifications
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences _prefs;
  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  NotificationService(this._plugin, this._prefs);

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // If already initializing, return the existing future
    if (_initializationFuture != null) {
      return _initializationFuture;
    }

    _initializationFuture = _doInitialize();
    return _initializationFuture;
  }

  Future<void> _doInitialize() async {
    // Initialize timezone database
    tz_data.initializeTimeZones();

    // Set the local timezone from the device
    await _configureLocalTimeZone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
    if (kDebugMode) {
      debugPrint('🔔 NotificationService initialized');
    }
  }

  /// Configure the local timezone from the device.
  /// This is required for scheduled notifications to work correctly.
  Future<void> _configureLocalTimeZone() async {
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final timeZoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      if (kDebugMode) {
        debugPrint('🔔 Local timezone set to: $timeZoneName');
      }
    } catch (e) {
      // Fallback to UTC if we can't get the local timezone
      if (kDebugMode) {
        debugPrint('🔔 Failed to get local timezone, using UTC: $e');
      }
      // tz.local defaults to UTC, which is fine as a fallback
    }
  }

  /// Ensure the service is initialized before performing operations.
  /// Call this at the start of any method that requires initialization.
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    await initialize();
  }

  /// Request notification permissions (call this when appropriate in UI)
  /// Check if notification permissions are currently granted (without prompting)
  ///
  /// Returns `true` if permissions are granted, `false` otherwise.
  /// This does NOT show a permission dialog - use [requestPermissions] for that.
  Future<bool> arePermissionsGranted() async {
    await _ensureInitialized();

    // Check Android permissions
    final androidEnabled = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.areNotificationsEnabled();

    // Check iOS permissions (for iOS, if we can check, otherwise assume granted)
    // iOS doesn't have a simple areNotificationsEnabled, but if initialized, we assume ok
    // The actual check happens when we try to show

    final granted = androidEnabled ?? true;
    if (kDebugMode) {
      debugPrint('🔔 Notification permissions status: $granted');
    }
    return granted;
  }

  /// Request notification permissions (call this when appropriate in UI)
  ///
  /// Shows a permission dialog if not already granted.
  /// Returns `true` if permissions are granted after the request.
  Future<bool> requestPermissions() async {
    await _ensureInitialized();

    // iOS permissions
    final iosResult = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Android 13+ permissions
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidResult = await androidPlugin?.requestNotificationsPermission();

    // Note: We intentionally do NOT request SCHEDULE_EXACT_ALARM permission
    // as it requires special Play Store approval for non-alarm apps.
    // We use inexact scheduling which is sufficient for reminder notifications.

    final granted = (iosResult ?? true) && (androidResult ?? true);
    if (kDebugMode) {
      debugPrint('🔔 Notification permissions granted: $granted');
    }
    return granted;
  }

  /// Ensure permissions are granted before showing a notification.
  ///
  /// This is a non-blocking check that returns `false` if permissions aren't granted.
  /// It does NOT prompt for permissions - that should be done proactively in the UI.
  ///
  /// All notification-showing methods should call this before attempting to show.
  Future<bool> _ensurePermissionsForShow() async {
    final granted = await arePermissionsGranted();
    if (!granted && kDebugMode) {
      debugPrint('🔔 Cannot show notification: permissions not granted');
    }
    return granted;
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint(
        '🔔 Notification response: type=${response.notificationResponseType}, '
        'actionId=${response.actionId}, payload=${response.payload}',
      );
    }

    final payload = response.payload;
    final actionId = response.actionId;

    // Handle action button taps
    if (actionId != null && actionId.isNotEmpty) {
      _handleNotificationAction(actionId, payload);
      return;
    }

    // Handle regular notification tap
    if (payload != null && payload.isNotEmpty) {
      queueNotificationNavigation(payload);
    }
  }

  /// Handle notification action button taps
  void _handleNotificationAction(String actionId, String? payload) {
    if (kDebugMode) {
      debugPrint('🔔 Handling action: $actionId with payload: $payload');
    }

    switch (actionId) {
      case NotificationActionIds.recordIncome:
        // Navigate to add cash flow screen
        if (payload != null) {
          queueNotificationNavigation(payload);
        }
        break;

      case NotificationActionIds.snoozeOneDay:
        // Reschedule notification for tomorrow
        if (payload != null) {
          _handleSnooze(payload, days: 1);
        }
        break;

      case NotificationActionIds.viewDetails:
      case NotificationActionIds.viewMaturity:
        // Navigate to investment detail
        if (payload != null) {
          // Use the original payload for navigation
          queueNotificationNavigation(payload);
        }
        break;

      case NotificationActionIds.markComplete:
        // Navigate to investment to mark as complete/closed
        if (payload != null) {
          queueNotificationNavigation(payload);
        }
        break;
    }
  }

  /// Handle snooze action - reschedule notification for later
  Future<void> _handleSnooze(String payload, {required int days}) async {
    final parsed = NotificationPayload.parse(payload);
    if (parsed.investmentId == null) return;

    // For now, we can't directly reschedule from here without investment details
    // The snooze will be handled by the notification navigator
    if (kDebugMode) {
      debugPrint(
        '🔔 Snoozed notification for ${parsed.investmentId} by $days days',
      );
    }
    // Note: Full snooze implementation would require storing investment details
    // or looking them up via repository. For MVP, the notification is dismissed.
  }

  // ============ Notification Preferences ============

  bool get weeklySummaryEnabled =>
      _prefs.getBool(NotificationPrefsKeys.weeklySummaryEnabled) ?? true;

  Future<void> setWeeklySummaryEnabled(bool enabled) async {
    await _prefs.setBool(NotificationPrefsKeys.weeklySummaryEnabled, enabled);
    if (enabled) {
      await scheduleWeeklySummary();
    } else {
      await _plugin.cancel(NotificationIds.weeklySummary);
    }
  }

  bool get incomeRemindersEnabled =>
      _prefs.getBool(NotificationPrefsKeys.incomeRemindersEnabled) ?? true;

  Future<void> setIncomeRemindersEnabled(bool enabled) async {
    await _prefs.setBool(NotificationPrefsKeys.incomeRemindersEnabled, enabled);
    // Note: When disabled, we don't cancel existing reminders here.
    // They will be filtered out in the schedule method.
    // To cancel all, call cancelAllIncomeReminders() separately.
  }

  bool get maturityRemindersEnabled =>
      _prefs.getBool(NotificationPrefsKeys.maturityRemindersEnabled) ?? true;

  Future<void> setMaturityRemindersEnabled(bool enabled) async {
    await _prefs.setBool(
      NotificationPrefsKeys.maturityRemindersEnabled,
      enabled,
    );
  }

  bool get monthlySummaryEnabled =>
      _prefs.getBool(NotificationPrefsKeys.monthlySummaryEnabled) ?? true;

  Future<void> setMonthlySummaryEnabled(bool enabled) async {
    await _prefs.setBool(NotificationPrefsKeys.monthlySummaryEnabled, enabled);
    if (enabled) {
      await scheduleMonthlySummary();
    } else {
      await _plugin.cancel(NotificationIds.monthlySummary);
    }
  }

  bool get milestonesEnabled =>
      _prefs.getBool(NotificationPrefsKeys.milestonesEnabled) ?? true;

  Future<void> setMilestonesEnabled(bool enabled) async {
    await _prefs.setBool(NotificationPrefsKeys.milestonesEnabled, enabled);
  }

  /// Goal progress milestone notifications enabled
  bool get goalMilestonesEnabled =>
      _prefs.getBool(NotificationPrefsKeys.goalMilestonesEnabled) ?? true;

  Future<void> setGoalMilestonesEnabled(bool enabled) async {
    await _prefs.setBool(NotificationPrefsKeys.goalMilestonesEnabled, enabled);
  }

  bool get taxRemindersEnabled =>
      _prefs.getBool(NotificationPrefsKeys.taxRemindersEnabled) ?? true;

  Future<void> setTaxRemindersEnabled(bool enabled) async {
    await _prefs.setBool(NotificationPrefsKeys.taxRemindersEnabled, enabled);
    if (enabled) {
      await scheduleTaxReminders();
    } else {
      await cancelTaxReminders();
    }
  }

  bool get riskAlertsEnabled =>
      _prefs.getBool(NotificationPrefsKeys.riskAlertsEnabled) ?? true;

  Future<void> setRiskAlertsEnabled(bool enabled) async {
    await _prefs.setBool(NotificationPrefsKeys.riskAlertsEnabled, enabled);
  }

  /// Weekly check-in (Sunday prompt) enabled
  bool get weeklyCheckInEnabled =>
      _prefs.getBool(NotificationPrefsKeys.weeklyCheckInEnabled) ?? true;

  Future<void> setWeeklyCheckInEnabled(bool enabled) async {
    await _prefs.setBool(NotificationPrefsKeys.weeklyCheckInEnabled, enabled);
    if (enabled) {
      await scheduleWeeklyCheckIn();
    } else {
      await _plugin.cancel(NotificationIds.weeklyCheckIn);
    }
  }

  /// Idle investment alerts enabled
  bool get idleAlertsEnabled =>
      _prefs.getBool(NotificationPrefsKeys.idleAlertsEnabled) ?? true;

  Future<void> setIdleAlertsEnabled(bool enabled) async {
    await _prefs.setBool(NotificationPrefsKeys.idleAlertsEnabled, enabled);
  }

  /// Number of days before an investment is considered "idle" (default: 90)
  int get idleAlertDays =>
      _prefs.getInt(NotificationPrefsKeys.idleAlertDays) ?? 90;

  Future<void> setIdleAlertDays(int days) async {
    await _prefs.setInt(NotificationPrefsKeys.idleAlertDays, days);
  }

  /// FY summary notification enabled
  bool get fySummaryEnabled =>
      _prefs.getBool(NotificationPrefsKeys.fySummaryEnabled) ?? true;

  Future<void> setFySummaryEnabled(bool enabled) async {
    await _prefs.setBool(NotificationPrefsKeys.fySummaryEnabled, enabled);
    if (enabled) {
      await scheduleFYSummary();
    } else {
      await _plugin.cancel(NotificationIds.fySummary);
    }
  }

  /// Check if a milestone has already been shown for an investment
  bool isMilestoneShown(String investmentId, double moic) =>
      _prefs.getBool(
        NotificationPrefsKeys.milestoneShown(investmentId, moic),
      ) ??
      false;

  /// Mark a milestone as shown
  Future<void> markMilestoneShown(String investmentId, double moic) async {
    await _prefs.setBool(
      NotificationPrefsKeys.milestoneShown(investmentId, moic),
      true,
    );
  }

  /// Check if a goal milestone has already been shown
  bool isGoalMilestoneShown(String goalId, int milestonePercent) =>
      _prefs.getBool(
        NotificationPrefsKeys.goalMilestoneShown(goalId, milestonePercent),
      ) ??
      false;

  /// Mark a goal milestone as shown
  Future<void> markGoalMilestoneShown(
    String goalId,
    int milestonePercent,
  ) async {
    await _prefs.setBool(
      NotificationPrefsKeys.goalMilestoneShown(goalId, milestonePercent),
      true,
    );
  }

  /// Get last time idle alert was shown for an investment (as ISO8601 string)
  DateTime? getIdleAlertLastShown(String investmentId) {
    final str = _prefs.getString(
      NotificationPrefsKeys.idleAlertLastShown(investmentId),
    );
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  /// Mark idle alert as shown for an investment
  Future<void> markIdleAlertShown(String investmentId) async {
    await _prefs.setString(
      NotificationPrefsKeys.idleAlertLastShown(investmentId),
      DateTime.now().toIso8601String(),
    );
  }

  // ============ Show Notifications ============

  /// Schedule weekly summary notification (every Sunday at 10 AM)
  Future<void> scheduleWeeklySummary() async {
    await _ensureInitialized();
    if (!weeklySummaryEnabled) return;

    // Cancel existing
    await _plugin.cancel(NotificationIds.weeklySummary);

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.weeklySummary,
      'Weekly Summary',
      channelDescription: 'Weekly investment activity summary',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
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

    // Schedule for next Sunday at 10 AM
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 10, 0);

    // Find next Sunday
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

  /// Schedule monthly income summary notification (last day of each month at 6 PM)
  Future<void> scheduleMonthlySummary() async {
    await _ensureInitialized();
    if (!monthlySummaryEnabled) return;

    // Cancel existing
    await _plugin.cancel(NotificationIds.monthlySummary);

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.monthlySummary,
      'Monthly Summary',
      channelDescription: 'Monthly investment income summary',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
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

    // Schedule for last day of current month at 6 PM
    final now = DateTime.now();

    // Get the last day of the current month
    var lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 18, 0);

    // If today is already past 6 PM on the last day, schedule for next month
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

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Show a test notification (for developer testing)
  Future<bool> showTestNotification() async {
    await _ensureInitialized();

    // Request permissions first
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      if (kDebugMode) {
        debugPrint('🔔 Test notification failed: no permission');
      }
      return false;
    }

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.general,
      'Test Notification',
      channelDescription: 'Test notification from developer options',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
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

    await _plugin.show(
      99999, // Fixed ID for test notification
      '🔔 Test Notification',
      'If you see this, notifications are working!',
      details,
      payload: 'test_notification',
    );

    if (kDebugMode) {
      debugPrint('🔔 Test notification sent successfully');
    }
    return true;
  }

  /// Schedule a test notification after a delay (for developer testing of scheduled notifications)
  ///
  /// [delaySeconds] - Number of seconds to wait before showing the notification (default: 5)
  Future<bool> scheduleTestNotification({int delaySeconds = 5}) async {
    await _ensureInitialized();

    // Request permissions first
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      if (kDebugMode) {
        debugPrint('🔔 Scheduled test notification failed: no permission');
      }
      return false;
    }

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.general,
      'Test Scheduled Notification',
      channelDescription: 'Test scheduled notification from developer options',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
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

    final scheduledTime = DateTime.now().add(Duration(seconds: delaySeconds));

    await _plugin.zonedSchedule(
      99998, // Fixed ID for scheduled test notification
      '⏰ Scheduled Test Notification',
      'This notification was scheduled $delaySeconds seconds ago!',
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'test_scheduled_notification',
    );

    if (kDebugMode) {
      debugPrint(
        '🔔 Test notification scheduled for $scheduledTime ($delaySeconds seconds from now)',
      );
    }
    return true;
  }

  // ============ Income Reminders ============

  /// Schedule an income reminder for an investment based on its income frequency.
  ///
  /// [investmentId] - Unique ID of the investment
  /// [investmentName] - Name to show in the notification
  /// [frequency] - How often income is expected (monthly, quarterly, etc.)
  /// [lastIncomeDate] - Date of last income received (used to calculate next expected date)
  ///
  /// If [lastIncomeDate] is null, schedules from today + frequency period.
  Future<void> scheduleIncomeReminder({
    required String investmentId,
    required String investmentName,
    required int monthsBetweenPayments,
    DateTime? lastIncomeDate,
  }) async {
    await _ensureInitialized();
    if (!incomeRemindersEnabled) return;

    // Cancel any existing reminder for this investment
    await cancelIncomeReminder(investmentId);

    // Calculate next expected income date
    final now = DateTime.now();
    DateTime nextIncomeDate;

    if (lastIncomeDate != null) {
      // Calculate next expected date based on last income
      nextIncomeDate = DateTime(
        lastIncomeDate.year,
        lastIncomeDate.month + monthsBetweenPayments,
        lastIncomeDate.day,
      );
      // If next date is in the past, keep adding frequency until it's in the future
      while (nextIncomeDate.isBefore(now)) {
        nextIncomeDate = DateTime(
          nextIncomeDate.year,
          nextIncomeDate.month + monthsBetweenPayments,
          nextIncomeDate.day,
        );
      }
    } else {
      // No last income, schedule from today + frequency
      nextIncomeDate = DateTime(
        now.year,
        now.month + monthsBetweenPayments,
        now.day,
      );
    }

    // Schedule at 9 AM on the expected date
    final scheduledDate = DateTime(
      nextIncomeDate.year,
      nextIncomeDate.month,
      nextIncomeDate.day,
      9, // 9 AM
      0,
    );

    final androidDetails = AndroidNotificationDetails(
      NotificationChannels.incomeReminders,
      'Income Reminders',
      channelDescription: 'Reminders for expected investment income',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      groupKey: NotificationGroups.incomeReminders,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          NotificationActionIds.recordIncome,
          '💰 Record Income',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          NotificationActionIds.snoozeOneDay,
          '⏰ Snooze 1 Day',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: NotificationGroups.incomeReminders,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      NotificationIds.incomeReminder(investmentId),
      '💰 Income Expected',
      'Check if $investmentName has paid income',
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: NotificationPayload.incomeReminder(investmentId),
    );

    if (kDebugMode) {
      debugPrint(
        '🔔 Income reminder scheduled for $investmentName on $scheduledDate',
      );
    }
  }

  /// Cancel income reminder for a specific investment
  Future<void> cancelIncomeReminder(String investmentId) async {
    await _plugin.cancel(NotificationIds.incomeReminder(investmentId));
    if (kDebugMode) {
      debugPrint('🔔 Income reminder cancelled for investment $investmentId');
    }
  }

  // ============ Maturity Reminders ============

  /// Schedule maturity reminders for an investment.
  ///
  /// Schedules two notifications:
  /// - 7 days before maturity
  /// - 1 day before maturity
  ///
  /// [investmentId] - Unique ID of the investment
  /// [investmentName] - Name to show in the notification
  /// [maturityDate] - The date the investment matures
  /// [investmentType] - Type of investment (e.g., "FD", "Bond") for context
  /// [investedAmount] - Original investment amount (optional, for enhanced notification)
  /// [currentValue] - Current/maturity value (optional, for enhanced notification)
  /// [currency] - Currency code (defaults to "INR")
  Future<void> scheduleMaturityReminders({
    required String investmentId,
    required String investmentName,
    required DateTime maturityDate,
    String? investmentType,
    double? investedAmount,
    double? currentValue,
    String currency = 'INR',
  }) async {
    await _ensureInitialized();
    if (!maturityRemindersEnabled) return;

    // Cancel any existing reminders for this investment
    await cancelMaturityReminders(investmentId);

    final now = DateTime.now();

    // Don't schedule if maturity date is in the past
    if (maturityDate.isBefore(now)) {
      if (kDebugMode) {
        debugPrint('🔔 Maturity date is in the past, not scheduling reminders');
      }
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      NotificationChannels.maturityReminders,
      'Maturity Reminders',
      channelDescription: 'Reminders before investments mature',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      groupKey: NotificationGroups.maturityReminders,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          NotificationActionIds.viewMaturity,
          '👁️ View Details',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          NotificationActionIds.markComplete,
          '✅ Mark Complete',
          showsUserInterface: true,
        ),
      ],
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

    // Build enhanced notification body with financial context
    final body7Days = _buildMaturityNotificationBody(
      investmentName: investmentName,
      daysRemaining: 7,
      investmentType: investmentType,
      investedAmount: investedAmount,
      currentValue: currentValue,
      currency: currency,
    );

    final body1Day = _buildMaturityNotificationBody(
      investmentName: investmentName,
      daysRemaining: 1,
      investmentType: investmentType,
      investedAmount: investedAmount,
      currentValue: currentValue,
      currency: currency,
    );

    // Schedule 7-day reminder
    final sevenDaysBefore = maturityDate.subtract(const Duration(days: 7));
    if (sevenDaysBefore.isAfter(now)) {
      final scheduledDate = DateTime(
        sevenDaysBefore.year,
        sevenDaysBefore.month,
        sevenDaysBefore.day,
        9, // 9 AM
        0,
      );

      await _plugin.zonedSchedule(
        NotificationIds.maturityReminder7Days(investmentId),
        '📅 Investment Maturing Soon',
        body7Days,
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
    final oneDayBefore = maturityDate.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(now)) {
      final scheduledDate = DateTime(
        oneDayBefore.year,
        oneDayBefore.month,
        oneDayBefore.day,
        9, // 9 AM
        0,
      );

      await _plugin.zonedSchedule(
        NotificationIds.maturityReminder1Day(investmentId),
        '⚠️ Investment Matures Tomorrow',
        body1Day,
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

  /// Cancel maturity reminders for a specific investment
  Future<void> cancelMaturityReminders(String investmentId) async {
    await _plugin.cancel(NotificationIds.maturityReminder7Days(investmentId));
    await _plugin.cancel(NotificationIds.maturityReminder1Day(investmentId));
    if (kDebugMode) {
      debugPrint(
        '🔔 Maturity reminders cancelled for investment $investmentId',
      );
    }
  }

  // ============ Multi-Device Sync Support ============

  /// Re-schedule all notifications for the given investments.
  ///
  /// This should be called when:
  /// - App launches and investments are loaded
  /// - Investments are synced from another device
  ///
  /// This ensures all devices have notifications scheduled, not just
  /// the device that originally created the investment.
  Future<void> rescheduleAllNotifications(
    List<InvestmentEntity> investments,
  ) async {
    if (kDebugMode) {
      debugPrint(
        '🔔 Re-scheduling notifications for ${investments.length} investments',
      );
    }

    // Schedule recurring summaries
    await scheduleWeeklySummary();
    await scheduleMonthlySummary();

    // Schedule per-investment notifications
    for (final investment in investments) {
      // Only schedule for open investments
      if (!investment.isOpen) continue;

      // Schedule maturity reminders if maturity date is set
      if (investment.maturityDate != null) {
        await scheduleMaturityReminders(
          investmentId: investment.id,
          investmentName: investment.name,
          maturityDate: investment.maturityDate!,
        );
      }

      // Schedule income reminders if income frequency is set
      if (investment.incomeFrequency != null) {
        await scheduleIncomeReminder(
          investmentId: investment.id,
          investmentName: investment.name,
          monthsBetweenPayments:
              investment.incomeFrequency!.monthsBetweenPayments,
          // Note: lastIncomeDate is null here - schedules from today.
          // Future enhancement: look up last income cash flow date from repository.
        );
      }
    }

    if (kDebugMode) {
      debugPrint('🔔 Finished re-scheduling all notifications');
    }
  }

  /// Show a grouped summary notification for income reminders.
  ///
  /// This creates an Android InboxStyle summary notification that groups
  /// multiple income reminders together. On iOS, notifications are grouped
  /// automatically using threadIdentifier.
  ///
  /// [investmentNames] - List of investment names with income due
  Future<void> showIncomeRemindersSummary(List<String> investmentNames) async {
    if (investmentNames.isEmpty) return;
    await _ensureInitialized();
    if (!await _ensurePermissionsForShow()) return;

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

  /// Show a grouped summary notification for maturity reminders.
  ///
  /// [investmentNames] - List of investment names maturing soon
  Future<void> showMaturityRemindersSummary(
    List<String> investmentNames,
  ) async {
    if (investmentNames.isEmpty) return;
    await _ensureInitialized();
    if (!await _ensurePermissionsForShow()) return;

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

  String _formatCurrency(double amount, String currency) {
    final symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'INR': '₹',
      'JPY': '¥',
    };
    final symbol = symbols[currency] ?? currency;
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Build enhanced notification body for maturity reminders
  String _buildMaturityNotificationBody({
    required String investmentName,
    required int daysRemaining,
    String? investmentType,
    double? investedAmount,
    double? currentValue,
    String currency = 'INR',
  }) {
    final timeText = daysRemaining == 1 ? 'tomorrow' : 'in $daysRemaining days';
    final buffer = StringBuffer('$investmentName matures $timeText');

    // Add investment type context
    if (investmentType != null && investmentType.isNotEmpty) {
      buffer.write(' ($investmentType)');
    }

    // Add financial summary if available
    if (investedAmount != null && currentValue != null) {
      final returns = currentValue - investedAmount;
      final returnPercent = (returns / investedAmount * 100);
      final formattedCurrent = _formatCurrency(currentValue, currency);
      final formattedReturns = _formatCurrency(returns.abs(), currency);

      if (returns >= 0) {
        buffer.write(
          '. Maturity value: $formattedCurrent (+$formattedReturns, ${returnPercent.toStringAsFixed(1)}%)',
        );
      } else {
        buffer.write(
          '. Maturity value: $formattedCurrent (-$formattedReturns, ${returnPercent.toStringAsFixed(1)}%)',
        );
      }
    } else if (currentValue != null) {
      final formattedCurrent = _formatCurrency(currentValue, currency);
      buffer.write('. Expected: $formattedCurrent');
    }

    return buffer.toString();
  }

  // ============ Milestone Notifications ============

  /// Standard MOIC milestones to celebrate
  static const List<double> standardMilestones = [1.5, 2.0, 3.0, 5.0, 10.0];

  /// Check if investment has reached a new milestone and show notification.
  ///
  /// Call this after a cash flow is recorded to check for new milestones.
  /// [investmentId] - Unique ID of the investment
  /// [investmentName] - Name of the investment
  /// [totalInvested] - Total amount invested (outflows)
  /// [totalReturned] - Total returns received (inflows)
  /// [currency] - Currency code (defaults to "INR")
  Future<void> checkAndShowMilestone({
    required String investmentId,
    required String investmentName,
    required double totalInvested,
    required double totalReturned,
    String currency = 'INR',
  }) async {
    await _ensureInitialized();
    if (!milestonesEnabled) return;
    if (totalInvested <= 0) return;

    // Check permissions before attempting to show notification
    if (!await _ensurePermissionsForShow()) return;

    final moic = totalReturned / totalInvested;

    // Find the highest milestone reached
    double? reachedMilestone;
    for (final milestone in standardMilestones.reversed) {
      if (moic >= milestone && !isMilestoneShown(investmentId, milestone)) {
        reachedMilestone = milestone;
        break;
      }
    }

    if (reachedMilestone == null) return;

    // Mark as shown to prevent duplicate notifications
    await markMilestoneShown(investmentId, reachedMilestone);

    final profit = totalReturned - totalInvested;
    final formattedProfit = _formatCurrency(profit, currency);

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
      visibility: NotificationVisibility.public,
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

  // ============ Goal Milestone Notifications ============

  /// Standard goal progress milestones to celebrate (percentages)
  static const List<int> goalMilestones = [25, 50, 75, 100];

  /// Check if goal has reached a new milestone and show notification.
  ///
  /// Call this after goal progress changes to check for new milestones.
  /// [goalId] - Unique ID of the goal
  /// [goalName] - Name of the goal
  /// [progressPercent] - Current progress percentage (0-100+)
  /// [currentValue] - Current value towards the goal
  /// [targetValue] - Target value of the goal
  /// [currency] - Currency code (defaults to "INR")
  Future<void> checkAndShowGoalMilestone({
    required String goalId,
    required String goalName,
    required double progressPercent,
    required double currentValue,
    required double targetValue,
    String currency = 'INR',
  }) async {
    await _ensureInitialized();
    if (!goalMilestonesEnabled) return;
    if (targetValue <= 0) return;

    // Check permissions before attempting to show notification
    if (!await _ensurePermissionsForShow()) return;

    // Find the highest milestone reached that hasn't been shown
    int? reachedMilestone;
    for (final milestone in goalMilestones.reversed) {
      if (progressPercent >= milestone &&
          !isGoalMilestoneShown(goalId, milestone)) {
        reachedMilestone = milestone;
        break;
      }
    }

    if (reachedMilestone == null) return;

    // Mark as shown to prevent duplicate notifications
    await markGoalMilestoneShown(goalId, reachedMilestone);

    final formattedCurrent = _formatCurrency(currentValue, currency);
    final formattedTarget = _formatCurrency(targetValue, currency);

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
      visibility: NotificationVisibility.public,
      groupKey: NotificationGroups.goalMilestones,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: NotificationGroups.goalMilestones,
    );

    await _plugin.show(
      NotificationIds.goalMilestone(goalId, reachedMilestone),
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: NotificationPayload.goalMilestone(goalId, reachedMilestone),
    );

    if (kDebugMode) {
      debugPrint(
        '🔔 Goal milestone notification shown: $reachedMilestone% for $goalName',
      );
    }
  }

  // ============ Tax Reminder Notifications ============

  /// Schedule all tax-related reminders for the financial year.
  /// India-specific dates:
  /// - 80C deadline: March 31
  /// - Advance tax: June 15, September 15, December 15, March 15
  /// - ITR filing: July 31
  Future<void> scheduleTaxReminders() async {
    await _ensureInitialized();
    if (!taxRemindersEnabled) return;

    await cancelTaxReminders();

    final now = DateTime.now();
    final currentYear = now.year;
    final nextYear = currentYear + 1;

    // Determine financial year (April to March)
    final fyYear = now.month >= 4 ? currentYear : currentYear - 1;

    final reminders = <_TaxReminder>[
      // 80C deadline - March 31 (7 days before)
      _TaxReminder(
        id: NotificationIds.taxReminder80C,
        title: '📋 80C Investment Deadline',
        body:
            'March 31 is the deadline for 80C tax-saving investments. Review your ELSS, PPF, and insurance investments.',
        date: DateTime(fyYear + 1, 3, 24, 9, 0), // 7 days before March 31
      ),
      // Advance Tax Q1 - June 15
      _TaxReminder(
        id: NotificationIds.taxReminderAdvanceQ1,
        title: '💰 Advance Tax Due (Q1)',
        body: 'First installment of advance tax (15%) is due by June 15.',
        date: DateTime(now.month >= 6 ? nextYear : currentYear, 6, 10, 9, 0),
      ),
      // Advance Tax Q2 - September 15
      _TaxReminder(
        id: NotificationIds.taxReminderAdvanceQ2,
        title: '💰 Advance Tax Due (Q2)',
        body:
            'Second installment of advance tax (45% cumulative) is due by September 15.',
        date: DateTime(now.month >= 9 ? nextYear : currentYear, 9, 10, 9, 0),
      ),
      // Advance Tax Q3 - December 15
      _TaxReminder(
        id: NotificationIds.taxReminderAdvanceQ3,
        title: '💰 Advance Tax Due (Q3)',
        body:
            'Third installment of advance tax (75% cumulative) is due by December 15.',
        date: DateTime(now.month >= 12 ? nextYear : currentYear, 12, 10, 9, 0),
      ),
      // Advance Tax Q4 - March 15
      _TaxReminder(
        id: NotificationIds.taxReminderAdvanceQ4,
        title: '💰 Advance Tax Due (Q4)',
        body: 'Final installment of advance tax (100%) is due by March 15.',
        date: DateTime(
          now.month >= 3 && now.day > 15 ? nextYear : currentYear,
          3,
          10,
          9,
          0,
        ),
      ),
      // ITR filing - July 31
      _TaxReminder(
        id: NotificationIds.taxReminderITR,
        title: '📝 ITR Filing Deadline',
        body:
            'July 31 is the deadline for filing Income Tax Returns. Gather your Form 16, investment proofs, and capital gains statements.',
        date: DateTime(
          now.month >= 7 && now.day > 25 ? nextYear : currentYear,
          7,
          25,
          9,
          0,
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
      visibility: NotificationVisibility.public,
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
          reminder.id,
          reminder.title,
          reminder.body,
          tz.TZDateTime.from(reminder.date, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: NotificationPayload.taxReminder(reminder.id.toString()),
        );

        if (kDebugMode) {
          debugPrint(
            '🔔 Tax reminder scheduled: ${reminder.title} on ${reminder.date}',
          );
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

  // ============ Risk/Concentration Alert Notifications ============

  /// Show a concentration/risk alert notification.
  ///
  /// [alertType] - Type of alert (e.g., 'single_investment', 'platform', 'type')
  /// [title] - Alert title
  /// [body] - Alert message with details
  Future<void> showRiskAlert({
    required String alertType,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();
    if (!riskAlertsEnabled) return;
    if (!await _ensurePermissionsForShow()) return;

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.riskAlerts,
      'Risk Alerts',
      channelDescription: 'Portfolio concentration and risk alerts',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      NotificationIds.riskAlert(alertType),
      '⚠️ $title',
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: NotificationPayload.riskAlert(alertType),
    );

    if (kDebugMode) {
      debugPrint('🔔 Risk alert shown: $title');
    }
  }

  // ============ Weekly Check-In Notifications ============

  /// Schedule weekly check-in prompt for Sunday at 6 PM.
  ///
  /// This prompts users to log any income they may have received during the week.
  Future<void> scheduleWeeklyCheckIn() async {
    await _ensureInitialized();
    if (!weeklyCheckInEnabled) return;

    await _plugin.cancel(NotificationIds.weeklyCheckIn);

    // Find next Sunday at 6 PM
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

    // If it's already past 6 PM on Sunday, schedule for next Sunday
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
      debugPrint('🔔 Weekly check-in scheduled for $nextSunday (repeating)');
    }
  }

  // ============ Idle Investment Alerts ============

  /// Check for idle investments and show alerts.
  ///
  /// An investment is considered "idle" if it has no cash flow activity
  /// for [idleAlertDays] days. We only show one alert per investment per month
  /// to avoid notification fatigue.
  ///
  /// [investments] - List of (investmentId, investmentName, lastActivityDate, status)
  Future<void> checkIdleInvestments(
    List<IdleInvestmentInfo> investments,
  ) async {
    await _ensureInitialized();
    if (!idleAlertsEnabled) return;
    if (!await _ensurePermissionsForShow()) return;

    final now = DateTime.now();
    final threshold = now.subtract(Duration(days: idleAlertDays));
    final monthAgo = now.subtract(const Duration(days: 30));

    for (final inv in investments) {
      // Skip if investment is closed/matured
      if (inv.isClosed) continue;

      // Skip if activity is recent
      if (inv.lastActivityDate != null &&
          inv.lastActivityDate!.isAfter(threshold)) {
        continue;
      }

      // Skip if we showed an alert for this investment within the last month
      final lastShown = getIdleAlertLastShown(inv.id);
      if (lastShown != null && lastShown.isAfter(monthAgo)) {
        continue;
      }

      // Show idle alert
      await markIdleAlertShown(inv.id);

      final daysSinceActivity = inv.lastActivityDate != null
          ? now.difference(inv.lastActivityDate!).inDays
          : null;

      final body = daysSinceActivity != null
          ? '${inv.name} has had no activity for $daysSinceActivity days. Review this investment?'
          : '${inv.name} has no recorded activity. Consider adding cash flows.';

      const androidDetails = AndroidNotificationDetails(
        NotificationChannels.idleAlerts,
        'Idle Alerts',
        channelDescription: 'Alerts for investments with no recent activity',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _plugin.show(
        NotificationIds.idleAlert(inv.id),
        '💤 Investment Review Needed',
        body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: NotificationPayload.idleAlert(inv.id),
      );

      if (kDebugMode) {
        debugPrint('🔔 Idle alert shown for ${inv.name}');
      }
    }
  }

  // ============ Financial Year Summary ============

  /// Schedule FY summary notification for April 1st at 10 AM.
  Future<void> scheduleFYSummary() async {
    await _ensureInitialized();
    if (!fySummaryEnabled) return;

    await _plugin.cancel(NotificationIds.fySummary);

    final now = DateTime.now();
    var nextApril1 = DateTime(now.year, 4, 1, 10, 0);

    // If we're past April 1st, schedule for next year
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
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      NotificationIds.fySummary,
      '📅 FY Summary Ready',
      'Your financial year summary is ready! Review your total income, TDS, and top performers.',
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
  ///
  /// Call this when user explicitly requests FY summary or when you have
  /// the summary data calculated.
  Future<void> showFYSummary({
    required int previousFY,
    required double totalIncome,
    required double totalTDS,
    required String? topPerformer,
    String currency = 'INR',
  }) async {
    await _ensureInitialized();
    if (!await _ensurePermissionsForShow()) return;

    final formattedIncome = _formatCurrency(totalIncome, currency);
    final formattedTDS = _formatCurrency(totalTDS, currency);

    final buffer = StringBuffer();
    final nextFY = previousFY + 1;
    buffer.write('FY$previousFY-$nextFY: ');
    buffer.write('Income: $formattedIncome');
    if (totalTDS > 0) {
      buffer.write(', TDS: $formattedTDS');
    }
    if (topPerformer != null) {
      buffer.write('. Top: $topPerformer');
    }

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.fySummary,
      'FY Summary',
      channelDescription: 'Annual financial year summary',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
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

/// Info about an investment for idle checking
class IdleInvestmentInfo {
  final String id;
  final String name;
  final DateTime? lastActivityDate;
  final bool isClosed;

  const IdleInvestmentInfo({
    required this.id,
    required this.name,
    this.lastActivityDate,
    this.isClosed = false,
  });
}

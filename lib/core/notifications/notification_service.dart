/// Notification service for local push notifications.
///
/// Handles scheduling and displaying notifications for:
/// - Income alerts (when income is recorded)
/// - Weekly investment summary
/// - Maturity reminders
/// - Income reminders
/// - Monthly income summary
///
/// This is the main notification service that coordinates all notification
/// operations. The service delegates to specialized handlers:
/// - [ScheduledNotificationHandler]: Weekly, monthly, FY summaries & tax reminders
/// - [InvestmentNotificationHandler]: Income & maturity reminders, milestones
/// - [GoalNotificationHandler]: Goal milestones and alerts
/// - [AlertNotificationHandler]: Risk alerts, idle investment checks
///
/// Constants and preferences are extracted into separate files.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:inv_tracker/core/notifications/handlers/alert_notification_handler.dart';
import 'package:inv_tracker/core/notifications/handlers/goal_notification_handler.dart';
import 'package:inv_tracker/core/notifications/handlers/investment_notification_handler.dart';
import 'package:inv_tracker/core/notifications/handlers/scheduled_notification_handler.dart';
import 'package:inv_tracker/core/notifications/notification_constants.dart';
import 'package:inv_tracker/core/notifications/notification_navigator.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';
import 'package:inv_tracker/core/notifications/notification_preferences.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// Re-export constants for backward compatibility
export 'package:inv_tracker/core/notifications/notification_constants.dart';

/// Provider for the notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError('Override in main.dart');
});

/// Notification service that wraps flutter_local_notifications.
///
/// This service uses [NotificationPreferencesMixin] for preference management.
/// Constants are defined in [notification_constants.dart].
/// Domain-specific notification logic is delegated to handler classes.
class NotificationService with NotificationPreferencesMixin {
  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences _prefs;
  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  // Handler instances for domain-specific notifications
  late final ScheduledNotificationHandler _scheduledHandler;
  late final InvestmentNotificationHandler _investmentHandler;
  late final GoalNotificationHandler _goalHandler;
  late final AlertNotificationHandler _alertHandler;

  NotificationService(this._plugin, this._prefs) {
    // Initialize handlers with required dependencies
    _scheduledHandler = ScheduledNotificationHandler(
      plugin: _plugin,
      prefs: _prefs,
      ensureInitialized: _ensureInitialized,
      ensurePermissionsForShow: _ensurePermissionsForShow,
      formatCurrency: _formatCurrency,
    );

    _investmentHandler = InvestmentNotificationHandler(
      plugin: _plugin,
      prefs: _prefs,
      ensureInitialized: _ensureInitialized,
      ensurePermissionsForShow: _ensurePermissionsForShow,
      scheduleWeeklySummary: () => _scheduledHandler.scheduleWeeklySummary(),
      scheduleMonthlySummary: () => _scheduledHandler.scheduleMonthlySummary(),
    );

    _goalHandler = GoalNotificationHandler(
      plugin: _plugin,
      prefs: _prefs,
      ensureInitialized: _ensureInitialized,
      ensurePermissionsForShow: _ensurePermissionsForShow,
      formatCurrency: _formatCurrency,
    );

    _alertHandler = AlertNotificationHandler(
      plugin: _plugin,
      prefs: _prefs,
      ensureInitialized: _ensureInitialized,
      ensurePermissionsForShow: _ensurePermissionsForShow,
    );
  }

  /// Expose SharedPreferences for the mixin
  @override
  SharedPreferences get prefs => _prefs;

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
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
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

  // ============ Preference Overrides with Side Effects ============
  //
  // The base preference getters/setters are inherited from NotificationPreferencesMixin.
  // These overrides add scheduling/cancellation side effects when preferences change.

  /// Override to schedule/cancel weekly summary when preference changes
  @override
  Future<void> setWeeklySummaryEnabled(bool enabled) async {
    await super.setWeeklySummaryEnabled(enabled);
    if (enabled) {
      await scheduleWeeklySummary();
    } else {
      await _plugin.cancel(NotificationIds.weeklySummary);
    }
  }

  /// Override to schedule/cancel monthly summary when preference changes
  @override
  Future<void> setMonthlySummaryEnabled(bool enabled) async {
    await super.setMonthlySummaryEnabled(enabled);
    if (enabled) {
      await scheduleMonthlySummary();
    } else {
      await _plugin.cancel(NotificationIds.monthlySummary);
    }
  }

  /// Override to schedule/cancel tax reminders when preference changes
  @override
  Future<void> setTaxRemindersEnabled(bool enabled) async {
    await super.setTaxRemindersEnabled(enabled);
    if (enabled) {
      await scheduleTaxReminders();
    } else {
      await cancelTaxReminders();
    }
  }

  /// Override to schedule/cancel weekly check-in when preference changes
  @override
  Future<void> setWeeklyCheckInEnabled(bool enabled) async {
    await super.setWeeklyCheckInEnabled(enabled);
    if (enabled) {
      await scheduleWeeklyCheckIn();
    } else {
      await _plugin.cancel(NotificationIds.weeklyCheckIn);
    }
  }

  /// Override to schedule/cancel FY summary when preference changes
  @override
  Future<void> setFySummaryEnabled(bool enabled) async {
    await super.setFySummaryEnabled(enabled);
    if (enabled) {
      await scheduleFYSummary();
    } else {
      await _plugin.cancel(NotificationIds.fySummary);
    }
  }

  // ============ Delegated Notification Methods ============
  //
  // These methods delegate to specialized handler classes for better
  // separation of concerns and maintainability.

  // --- Scheduled Notifications ---

  /// Schedule weekly summary notification (every Sunday at 10 AM)
  Future<void> scheduleWeeklySummary() =>
      _scheduledHandler.scheduleWeeklySummary();

  /// Schedule monthly income summary notification (last day of each month)
  Future<void> scheduleMonthlySummary() =>
      _scheduledHandler.scheduleMonthlySummary();

  /// Schedule all tax-related reminders for the financial year
  Future<void> scheduleTaxReminders() =>
      _scheduledHandler.scheduleTaxReminders();

  /// Cancel all tax reminder notifications
  Future<void> cancelTaxReminders() => _scheduledHandler.cancelTaxReminders();

  /// Schedule weekly check-in prompt for Sunday at 6 PM
  Future<void> scheduleWeeklyCheckIn() =>
      _scheduledHandler.scheduleWeeklyCheckIn();

  /// Schedule FY summary notification for April 1st at 10 AM
  Future<void> scheduleFYSummary() => _scheduledHandler.scheduleFYSummary();

  /// Show immediate FY summary notification with custom data
  Future<void> showFYSummary({
    required int previousFY,
    required double totalIncome,
    required double totalTDS,
    required String? topPerformer,
    String currency = 'INR',
  }) => _scheduledHandler.showFYSummary(
    previousFY: previousFY,
    totalIncome: totalIncome,
    totalTDS: totalTDS,
    topPerformer: topPerformer,
    currency: currency,
  );

  // --- Utility Methods ---

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Format currency value for display
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

  // --- Investment Notifications ---

  /// Schedule an income reminder for an investment
  Future<void> scheduleIncomeReminder({
    required String investmentId,
    required String investmentName,
    required int monthsBetweenPayments,
    DateTime? lastIncomeDate,
  }) => _investmentHandler.scheduleIncomeReminder(
    investmentId: investmentId,
    investmentName: investmentName,
    monthsBetweenPayments: monthsBetweenPayments,
    lastIncomeDate: lastIncomeDate,
  );

  /// Cancel income reminder for a specific investment
  Future<void> cancelIncomeReminder(String investmentId) =>
      _investmentHandler.cancelIncomeReminder(investmentId);

  /// Schedule maturity reminder notifications (7 days and 1 day before)
  Future<void> scheduleMaturityReminders({
    required String investmentId,
    required String investmentName,
    required DateTime maturityDate,
    String? investmentType,
    double? investedAmount,
    double? currentValue,
    String currency = 'INR',
  }) => _investmentHandler.scheduleMaturityReminders(
    investmentId: investmentId,
    investmentName: investmentName,
    maturityDate: maturityDate,
    investmentType: investmentType,
    investedAmount: investedAmount,
    currentValue: currentValue,
    currency: currency,
  );

  /// Cancel maturity reminders for a specific investment
  Future<void> cancelMaturityReminders(String investmentId) =>
      _investmentHandler.cancelMaturityReminders(investmentId);

  /// Re-schedule all notifications for the given investments
  Future<void> rescheduleAllNotifications(List<InvestmentEntity> investments) =>
      _investmentHandler.rescheduleAllNotifications(investments);

  /// Show grouped summary notification for income reminders
  Future<void> showIncomeRemindersSummary(List<String> investmentNames) =>
      _investmentHandler.showIncomeRemindersSummary(investmentNames);

  /// Show grouped summary notification for maturity reminders
  Future<void> showMaturityRemindersSummary(List<String> investmentNames) =>
      _investmentHandler.showMaturityRemindersSummary(investmentNames);

  /// Check if investment has reached a new milestone and show notification
  Future<void> checkAndShowMilestone({
    required String investmentId,
    required String investmentName,
    required double totalInvested,
    required double totalReturned,
    String currency = 'INR',
  }) => _investmentHandler.checkAndShowMilestone(
    investmentId: investmentId,
    investmentName: investmentName,
    totalInvested: totalInvested,
    totalReturned: totalReturned,
    formatCurrency: _formatCurrency,
    currency: currency,
  );

  // --- Goal Notifications ---

  /// Check if goal has reached a new milestone and show notification
  Future<void> checkAndShowGoalMilestone({
    required String goalId,
    required String goalName,
    required double progressPercent,
    required double currentValue,
    required double targetValue,
    String currency = 'INR',
  }) => _goalHandler.checkAndShowGoalMilestone(
    goalId: goalId,
    goalName: goalName,
    progressPercent: progressPercent,
    currentValue: currentValue,
    targetValue: targetValue,
    currency: currency,
  );

  /// Show goal at-risk notification when goal is behind schedule
  Future<void> showGoalAtRiskNotification({
    required String goalId,
    required String goalName,
    required double progressPercent,
    required DateTime? targetDate,
    required DateTime? projectedDate,
  }) => _goalHandler.showGoalAtRiskNotification(
    goalId: goalId,
    goalName: goalName,
    progressPercent: progressPercent,
    targetDate: targetDate,
    projectedDate: projectedDate,
  );

  /// Show goal stale notification when goal has no activity
  Future<void> showGoalStaleNotification({
    required String goalId,
    required String goalName,
    required DateTime? lastActivityDate,
  }) => _goalHandler.showGoalStaleNotification(
    goalId: goalId,
    goalName: goalName,
    lastActivityDate: lastActivityDate,
  );

  // --- Alert Notifications ---

  /// Show a concentration/risk alert notification
  Future<void> showRiskAlert({
    required String alertType,
    required String title,
    required String body,
  }) => _alertHandler.showRiskAlert(
    alertType: alertType,
    title: title,
    body: body,
  );

  /// Check for idle investments and show alerts
  Future<void> checkIdleInvestments(List<IdleInvestmentInfo> investments) =>
      _alertHandler.checkIdleInvestments(investments);
}

/// Local push notification service for InvTrack.
///
/// This service provides a unified interface for scheduling and displaying
/// local notifications across the app. It wraps `flutter_local_notifications`
/// and delegates domain-specific logic to specialized handlers.
///
/// ## Key Features
///
/// - **Scheduled Notifications**: Weekly/monthly summaries, tax reminders
/// - **Investment Notifications**: Maturity reminders, income alerts, milestones
/// - **Goal Notifications**: Goal milestones and progress alerts
/// - **Alert Notifications**: Risk alerts, idle investment checks
/// - **Deep Linking**: Tap notifications to navigate to specific screens
/// - **Timezone Support**: Handles timezone conversions for accurate scheduling
///
/// ## Architecture
///
/// The service delegates to specialized handlers:
/// - [ScheduledNotificationHandler]: Weekly, monthly, FY summaries & tax reminders
/// - [InvestmentNotificationHandler]: Income & maturity reminders, milestones
/// - [GoalNotificationHandler]: Goal milestones and alerts
/// - [AlertNotificationHandler]: Risk alerts, idle investment checks
///
/// ## Notification Types
///
/// ### 1. Scheduled Notifications
/// - **Weekly Summary**: Every Sunday at 9 AM
/// - **Monthly Summary**: 1st of every month at 9 AM
/// - **FY Summary**: April 1st at 9 AM (India)
/// - **Tax Reminder**: March 15th at 9 AM (before FY end)
///
/// ### 2. Investment Notifications
/// - **Maturity Reminder**: 7 days before maturity date
/// - **Income Alert**: When income/dividend is recorded
/// - **Milestone**: When investment reaches 10%, 25%, 50%, 100% gain
///
/// ### 3. Goal Notifications
/// - **Goal Milestone**: When goal reaches 25%, 50%, 75%, 100%
/// - **Goal Alert**: Custom alerts for goal progress
///
/// ### 4. Alert Notifications
/// - **Risk Alert**: When investment underperforms
/// - **Idle Investment**: When no transactions for 90 days
///
/// ## Usage Example
///
/// ```dart
/// // Initialize service (in main.dart)
/// final notificationService = NotificationService(
///   FlutterLocalNotificationsPlugin(),
///   sharedPreferences,
/// );
/// await notificationService.initialize();
///
/// // Request permissions (in settings screen)
/// final granted = await notificationService.requestPermissions();
/// if (granted) {
///   print('Notifications enabled');
/// }
///
/// // Schedule maturity reminder
/// await notificationService.scheduleMaturityReminder(
///   investment: investment,
///   daysBeforeMaturity: 7,
/// );
///
/// // Show income alert
/// await notificationService.showIncomeAlert(
///   investmentName: 'FD - HDFC Bank',
///   amount: 5000,
///   incomeType: 'Interest',
/// );
///
/// // Schedule weekly summary
/// await notificationService.scheduleWeeklySummary();
/// ```
///
/// ## Deep Linking
///
/// Notifications include payloads for deep linking:
/// - **Investment notifications**: Navigate to investment detail screen
/// - **Goal notifications**: Navigate to goal detail screen
/// - **Summary notifications**: Navigate to dashboard
///
/// ## Preferences
///
/// User preferences are managed via [NotificationPreferencesMixin]:
/// - Enable/disable notifications
/// - Enable/disable specific notification types
/// - Customize notification times
///
/// ## Timezone Handling
///
/// The service automatically detects the device timezone and schedules
/// notifications accordingly. Fallback to UTC if timezone detection fails.
///
/// ## Testing
///
/// In tests, use a mock [FlutterLocalNotificationsPlugin] to avoid
/// platform-specific initialization.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
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

/// Provider for the notification service.
///
/// **Must be overridden in main.dart** with actual implementation.
///
/// ## Example
///
/// ```dart
/// // In main.dart
/// final sharedPrefs = await SharedPreferences.getInstance();
/// final notificationService = NotificationService(
///   FlutterLocalNotificationsPlugin(),
///   sharedPrefs,
/// );
/// await notificationService.initialize();
///
/// runApp(
///   ProviderScope(
///     overrides: [
///       notificationServiceProvider.overrideWithValue(notificationService),
///     ],
///     child: MyApp(),
///   ),
/// );
/// ```
final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError('Override in main.dart');
});

/// Notification service that wraps flutter_local_notifications.
///
/// See library documentation above for usage examples and notification types.
///
/// ## Key Responsibilities
///
/// 1. **Initialization**: Set up notification plugin and timezone
/// 2. **Permission Management**: Request and check notification permissions
/// 3. **Scheduling**: Schedule recurring and one-time notifications
/// 4. **Display**: Show immediate notifications
/// 5. **Deep Linking**: Handle notification taps and navigate to screens
/// 6. **Preference Management**: Enable/disable notification types
///
/// ## Handler Delegation
///
/// This service delegates domain-specific logic to specialized handlers:
/// - [_scheduledHandler]: Weekly/monthly summaries, tax reminders
/// - [_investmentHandler]: Maturity reminders, income alerts
/// - [_goalHandler]: Goal milestones and alerts
/// - [_alertHandler]: Risk alerts, idle investment checks
///
/// ## See Also
///
/// - [NotificationPreferencesMixin] for preference management
/// - [NotificationConstants] for notification IDs and channels
/// - [NotificationPayload] for deep linking payloads
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

  /// Expose SharedPreferences for the mixin.
  @override
  SharedPreferences get prefs => _prefs;

  /// Initialize the notification service.
  ///
  /// **Must be called before using any notification features.**
  /// Safe to call multiple times - subsequent calls return immediately.
  ///
  /// ## Initialization Steps
  ///
  /// 1. Initialize timezone database
  /// 2. Detect and set device timezone
  /// 3. Configure notification plugin (Android + iOS)
  /// 4. Set up notification tap handler
  ///
  /// ## Example
  ///
  /// ```dart
  /// // In main.dart
  /// final notificationService = NotificationService(
  ///   FlutterLocalNotificationsPlugin(),
  ///   sharedPreferences,
  /// );
  /// await notificationService.initialize();
  /// ```
  ///
  /// ## Timezone Handling
  ///
  /// The service automatically detects the device timezone using
  /// `flutter_timezone`. If detection fails, it falls back to UTC.
  ///
  /// ## Platform-Specific Behavior
  ///
  /// - **Android**: Uses `@mipmap/ic_launcher` as notification icon
  /// - **iOS**: Permissions requested separately (not during initialization)
  ///
  /// ## See Also
  ///
  /// - [requestPermissions] to request notification permissions
  /// - [arePermissionsGranted] to check permission status
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
    LoggerService.info('NotificationService initialized');
  }

  /// Configure the local timezone from the device.
  /// This is required for scheduled notifications to work correctly.
  Future<void> _configureLocalTimeZone() async {
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final timeZoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      LoggerService.debug(
        'Local timezone set',
        metadata: {'timezone': timeZoneName},
      );
    } catch (e) {
      // Fallback to UTC if we can't get the local timezone
      LoggerService.warn('Failed to get local timezone, using UTC', error: e);
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
    LoggerService.debug(
      'Notification permissions status',
      metadata: {'granted': granted},
    );
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
    LoggerService.info(
      'Notification permissions granted',
      metadata: {'granted': granted},
    );
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
    if (!granted) {
      LoggerService.warn('Cannot show notification: permissions not granted');
    }
    return granted;
  }

  void _onNotificationTapped(NotificationResponse response) {
    LoggerService.debug(
      'Notification response',
      metadata: {
        'type': response.notificationResponseType.toString(),
        'actionId': response.actionId ?? 'none',
        'payload': response.payload ?? 'none',
      },
    );

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
    LoggerService.debug(
      'Handling notification action',
      metadata: {'actionId': actionId, 'payload': payload ?? 'none'},
    );

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
    LoggerService.debug(
      'Snoozed notification',
      metadata: {'investmentId': parsed.investmentId, 'days': days},
    );
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
      LoggerService.warn('Test notification failed: no permission');
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

    await _plugin.show(
      99999, // Fixed ID for test notification
      '🔔 Test Notification',
      'If you see this, notifications are working!',
      details,
      payload: 'test_notification',
    );

    LoggerService.info('Test notification sent successfully');
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
      LoggerService.warn('Scheduled test notification failed: no permission');
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

    LoggerService.info(
      'Test notification scheduled',
      metadata: {
        'scheduledTime': scheduledTime.toString(),
        'delaySeconds': delaySeconds,
      },
    );
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

  // ============ New User Activation Sequence ============

  /// Whether activation notifications are enabled
  bool get activationNotificationsEnabled =>
      _prefs.getBool(NotificationPrefsKeys.activationNotificationsEnabled) ??
      true;

  Future<void> setActivationNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(
      NotificationPrefsKeys.activationNotificationsEnabled,
      enabled,
    );
    if (!enabled) {
      await cancelActivationSequence();
    }
  }

  /// Get user signup date (when they first registered)
  DateTime? get userSignupDate {
    final str = _prefs.getString(NotificationPrefsKeys.userSignupDate);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  /// Set user signup date (call when user first signs up)
  Future<void> setUserSignupDate(DateTime date) async {
    await _prefs.setString(
      NotificationPrefsKeys.userSignupDate,
      date.toIso8601String(),
    );
  }

  /// Check if activation day notification has been sent
  bool _isActivationDaySent(int day) {
    switch (day) {
      case 0:
        return _prefs.getBool(NotificationPrefsKeys.activationDay0Sent) ??
            false;
      case 1:
        return _prefs.getBool(NotificationPrefsKeys.activationDay1Sent) ??
            false;
      case 3:
        return _prefs.getBool(NotificationPrefsKeys.activationDay3Sent) ??
            false;
      case 7:
        return _prefs.getBool(NotificationPrefsKeys.activationDay7Sent) ??
            false;
      case 14:
        return _prefs.getBool(NotificationPrefsKeys.activationDay14Sent) ??
            false;
      default:
        return false;
    }
  }

  /// Mark activation day notification as sent
  Future<void> _markActivationDaySent(int day) async {
    switch (day) {
      case 0:
        await _prefs.setBool(NotificationPrefsKeys.activationDay0Sent, true);
      case 1:
        await _prefs.setBool(NotificationPrefsKeys.activationDay1Sent, true);
      case 3:
        await _prefs.setBool(NotificationPrefsKeys.activationDay3Sent, true);
      case 7:
        await _prefs.setBool(NotificationPrefsKeys.activationDay7Sent, true);
      case 14:
        await _prefs.setBool(NotificationPrefsKeys.activationDay14Sent, true);
    }
  }

  /// Schedule the new user activation notification sequence.
  ///
  /// This schedules notifications for Day 0 (1 hour), Day 1, Day 3, Day 7, Day 14
  /// after signup to encourage users to add their first investment.
  ///
  /// Call this when user first signs up AND has no investments.
  Future<void> scheduleActivationSequence() async {
    await _ensureInitialized();
    if (!activationNotificationsEnabled) return;

    final signupDate = userSignupDate ?? DateTime.now();
    final now = DateTime.now();

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.activation,
      'Activation',
      channelDescription: 'New user activation nudges',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
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

    // Day 0: Welcome (1 hour after signup)
    final day0Time = signupDate.add(const Duration(hours: 1));
    if (day0Time.isAfter(now) && !_isActivationDaySent(0)) {
      await _plugin.zonedSchedule(
        NotificationIds.activationDay0,
        '🎉 Welcome to InvTrack!',
        'Start tracking your investments and discover your real returns (XIRR). Add your first investment now!',
        tz.TZDateTime.from(day0Time, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: NotificationPayload.activationDay0,
      );
      await _markActivationDaySent(0);
      LoggerService.info(
        'Activation Day 0 scheduled',
        metadata: {'scheduledTime': day0Time.toString()},
      );
    }

    // Day 1: First investment nudge (24 hours after signup, at 10 AM)
    final day1Date = signupDate.add(const Duration(days: 1));
    final day1Time = DateTime(day1Date.year, day1Date.month, day1Date.day, 10);
    if (day1Time.isAfter(now) && !_isActivationDaySent(1)) {
      await _plugin.zonedSchedule(
        NotificationIds.activationDay1,
        '📊 Add Your First Investment',
        'Take 30 seconds to add an FD, mutual fund, or any investment. See how your returns really stack up!',
        tz.TZDateTime.from(day1Time, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: NotificationPayload.activationDay1,
      );
      await _markActivationDaySent(1);
      LoggerService.info(
        'Activation Day 1 scheduled',
        metadata: {'scheduledTime': day1Time.toString()},
      );
    }

    // Day 3: Import reminder (3 days after signup, at 6 PM)
    final day3Date = signupDate.add(const Duration(days: 3));
    final day3Time = DateTime(day3Date.year, day3Date.month, day3Date.day, 18);
    if (day3Time.isAfter(now) && !_isActivationDaySent(3)) {
      await _plugin.zonedSchedule(
        NotificationIds.activationDay3,
        '📥 Import Your Investments',
        'Have a spreadsheet? Import your investments from CSV in seconds. No manual entry needed!',
        tz.TZDateTime.from(day3Time, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: NotificationPayload.activationDay3,
      );
      await _markActivationDaySent(3);
      LoggerService.info(
        'Activation Day 3 scheduled',
        metadata: {'scheduledTime': day3Time.toString()},
      );
    }

    // Day 7: Tips & benefits (7 days after signup, at 11 AM)
    final day7Date = signupDate.add(const Duration(days: 7));
    final day7Time = DateTime(day7Date.year, day7Date.month, day7Date.day, 11);
    if (day7Time.isAfter(now) && !_isActivationDaySent(7)) {
      await _plugin.zonedSchedule(
        NotificationIds.activationDay7,
        '💡 Did You Know?',
        'InvTrack shows your real XIRR returns - often different from advertised rates. Start tracking to see the difference!',
        tz.TZDateTime.from(day7Time, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: NotificationPayload.activationDay7,
      );
      await _markActivationDaySent(7);
      LoggerService.info(
        'Activation Day 7 scheduled',
        metadata: {'scheduledTime': day7Time.toString()},
      );
    }

    // Day 14: Social proof / last chance (14 days after signup, at 10 AM)
    final day14Date = signupDate.add(const Duration(days: 14));
    final day14Time = DateTime(
      day14Date.year,
      day14Date.month,
      day14Date.day,
      10,
    );
    if (day14Time.isAfter(now) && !_isActivationDaySent(14)) {
      await _plugin.zonedSchedule(
        NotificationIds.activationDay14,
        '📈 Join Smart Investors',
        'Thousands of investors track their real returns with InvTrack. Add your first investment and join them!',
        tz.TZDateTime.from(day14Time, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: NotificationPayload.activationDay14,
      );
      await _markActivationDaySent(14);
      LoggerService.info(
        'Activation Day 14 scheduled',
        metadata: {'scheduledTime': day14Time.toString()},
      );
    }
  }

  /// Cancel all activation sequence notifications.
  ///
  /// Call this when user adds their first investment to stop sending nudges.
  Future<void> cancelActivationSequence() async {
    await _plugin.cancel(NotificationIds.activationDay0);
    await _plugin.cancel(NotificationIds.activationDay1);
    await _plugin.cancel(NotificationIds.activationDay3);
    await _plugin.cancel(NotificationIds.activationDay7);
    await _plugin.cancel(NotificationIds.activationDay14);

    LoggerService.info('Activation sequence cancelled');
  }

  /// Reset activation sequence state (for testing or re-onboarding).
  Future<void> resetActivationSequence() async {
    await _prefs.remove(NotificationPrefsKeys.userSignupDate);
    await _prefs.remove(NotificationPrefsKeys.activationDay0Sent);
    await _prefs.remove(NotificationPrefsKeys.activationDay1Sent);
    await _prefs.remove(NotificationPrefsKeys.activationDay3Sent);
    await _prefs.remove(NotificationPrefsKeys.activationDay7Sent);
    await _prefs.remove(NotificationPrefsKeys.activationDay14Sent);
    await cancelActivationSequence();
  }
}

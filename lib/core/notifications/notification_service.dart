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
  static const String incomeAlerts = 'income_alerts';
  static const String weeklySummary = 'weekly_summary';
  static const String incomeReminders = 'income_reminders';
  static const String maturityReminders = 'maturity_reminders';
  static const String monthlySummary = 'monthly_summary';
}

/// Notification IDs for scheduled notifications
class NotificationIds {
  static const int weeklySummary = 1000;
  static const int monthlySummary = 1001;
  static int incomeAlert(String cashFlowId) => cashFlowId.hashCode.abs() % 100000;
  /// Generate a unique notification ID for income reminders based on investment ID
  static int incomeReminder(String investmentId) => (investmentId.hashCode.abs() % 50000) + 50000;
  /// Generate unique notification IDs for maturity reminders (7-day and 1-day before)
  static int maturityReminder7Days(String investmentId) => (investmentId.hashCode.abs() % 25000) + 100000;
  static int maturityReminder1Day(String investmentId) => (investmentId.hashCode.abs() % 25000) + 125000;
}

/// Settings keys for notification preferences
class NotificationPrefsKeys {
  static const String incomeAlertsEnabled = 'notifications_income_alerts';
  static const String weeklySummaryEnabled = 'notifications_weekly_summary';
  static const String incomeRemindersEnabled = 'notifications_income_reminders';
  static const String maturityRemindersEnabled = 'notifications_maturity_reminders';
  static const String monthlySummaryEnabled = 'notifications_monthly_summary';
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
    // Initialize timezone
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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

  /// Ensure the service is initialized before performing operations.
  /// Call this at the start of any method that requires initialization.
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    await initialize();
  }

  /// Request notification permissions (call this when appropriate in UI)
  Future<bool> requestPermissions() async {
    // iOS permissions
    final iosResult = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Android 13+ permissions
    final androidResult = await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final granted = (iosResult ?? true) && (androidResult ?? true);
    if (kDebugMode) {
      debugPrint('🔔 Notification permissions granted: $granted');
    }
    return granted;
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('🔔 Notification tapped: ${response.payload}');
    }
    // TODO: Navigate to relevant screen based on payload
  }

  // ============ Notification Preferences ============

  bool get incomeAlertsEnabled => 
      _prefs.getBool(NotificationPrefsKeys.incomeAlertsEnabled) ?? true;

  Future<void> setIncomeAlertsEnabled(bool enabled) async {
    await _prefs.setBool(NotificationPrefsKeys.incomeAlertsEnabled, enabled);
  }

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
    await _prefs.setBool(NotificationPrefsKeys.maturityRemindersEnabled, enabled);
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

  // ============ Show Notifications ============

  /// Show an immediate notification for income received
  Future<void> showIncomeAlert({
    required String investmentName,
    required double amount,
    required String currency,
  }) async {
    await _ensureInitialized();
    if (!incomeAlertsEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.incomeAlerts,
      'Income Alerts',
      channelDescription: 'Notifications when income is recorded',
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

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final formattedAmount = _formatCurrency(amount, currency);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      '💰 Income Received',
      '$formattedAmount from $investmentName',
      details,
      payload: 'income_alert',
    );
  }

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

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // Schedule for next Sunday at 10 AM
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 10, 0);

    // Find next Sunday
    while (scheduledDate.weekday != DateTime.sunday || scheduledDate.isBefore(now)) {
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
      payload: 'weekly_summary',
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

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

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
      payload: 'monthly_summary',
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
      NotificationChannels.incomeAlerts,
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

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

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

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.incomeReminders,
      'Income Reminders',
      channelDescription: 'Reminders for expected investment income',
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

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      NotificationIds.incomeReminder(investmentId),
      '💰 Income Expected',
      'Check if $investmentName has paid income',
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'income_reminder:$investmentId',
    );

    if (kDebugMode) {
      debugPrint('🔔 Income reminder scheduled for $investmentName on $scheduledDate');
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
  Future<void> scheduleMaturityReminders({
    required String investmentId,
    required String investmentName,
    required DateTime maturityDate,
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

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.maturityReminders,
      'Maturity Reminders',
      channelDescription: 'Reminders before investments mature',
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

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

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
        '$investmentName matures in 7 days',
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'maturity_reminder:$investmentId:7',
      );

      if (kDebugMode) {
        debugPrint('🔔 7-day maturity reminder scheduled for $investmentName on $scheduledDate');
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
        '$investmentName matures tomorrow!',
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'maturity_reminder:$investmentId:1',
      );

      if (kDebugMode) {
        debugPrint('🔔 1-day maturity reminder scheduled for $investmentName on $scheduledDate');
      }
    }
  }

  /// Cancel maturity reminders for a specific investment
  Future<void> cancelMaturityReminders(String investmentId) async {
    await _plugin.cancel(NotificationIds.maturityReminder7Days(investmentId));
    await _plugin.cancel(NotificationIds.maturityReminder1Day(investmentId));
    if (kDebugMode) {
      debugPrint('🔔 Maturity reminders cancelled for investment $investmentId');
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
  Future<void> rescheduleAllNotifications(List<InvestmentEntity> investments) async {
    if (kDebugMode) {
      debugPrint('🔔 Re-scheduling notifications for ${investments.length} investments');
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
          monthsBetweenPayments: investment.incomeFrequency!.monthsBetweenPayments,
          // lastIncomeDate will be null - schedules from today
          // TODO: In future, could look up last income cash flow date
        );
      }
    }

    if (kDebugMode) {
      debugPrint('🔔 Finished re-scheduling all notifications');
    }
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
}


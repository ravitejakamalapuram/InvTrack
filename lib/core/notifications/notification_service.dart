/// Notification service for local push notifications.
///
/// Handles scheduling and displaying notifications for:
/// - Income alerts (when income is recorded)
/// - Weekly investment summary
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  static const String reminders = 'reminders';
}

/// Notification IDs for scheduled notifications
class NotificationIds {
  static const int weeklySummary = 1000;
  static int incomeAlert(String cashFlowId) => cashFlowId.hashCode.abs() % 100000;
}

/// Settings keys for notification preferences
class NotificationPrefsKeys {
  static const String incomeAlertsEnabled = 'notifications_income_alerts';
  static const String weeklySummaryEnabled = 'notifications_weekly_summary';
}

/// Notification service that wraps flutter_local_notifications
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences _prefs;
  bool _isInitialized = false;

  NotificationService(this._plugin, this._prefs);

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

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

  // ============ Show Notifications ============

  /// Show an immediate notification for income received
  Future<void> showIncomeAlert({
    required String investmentName,
    required double amount,
    required String currency,
  }) async {
    if (!incomeAlertsEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.incomeAlerts,
      'Income Alerts',
      channelDescription: 'Notifications when income is recorded',
      importance: Importance.high,
      priority: Priority.high,
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
    if (!weeklySummaryEnabled) return;

    // Cancel existing
    await _plugin.cancel(NotificationIds.weeklySummary);

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.weeklySummary,
      'Weekly Summary',
      channelDescription: 'Weekly investment activity summary',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
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

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
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


import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/notifications/notification_constants.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';
import 'package:inv_tracker/core/notifications/notification_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handler for alert-type notifications.
///
/// Manages:
/// - Risk/concentration alerts
/// - Idle investment alerts
class AlertNotificationHandler with NotificationPreferencesMixin {
  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences _prefs;
  final Future<void> Function() ensureInitialized;
  final Future<bool> Function() ensurePermissionsForShow;

  AlertNotificationHandler({
    required FlutterLocalNotificationsPlugin plugin,
    required SharedPreferences prefs,
    required this.ensureInitialized,
    required this.ensurePermissionsForShow,
  }) : _plugin = plugin,
       _prefs = prefs;

  @override
  SharedPreferences get prefs => _prefs;

  // ============ Risk/Concentration Alert Notifications ============

  /// Show a concentration/risk alert notification.
  Future<void> showRiskAlert({
    required String alertType,
    required String title,
    required String body,
  }) async {
    await ensureInitialized();
    if (!riskAlertsEnabled) return;
    if (!await ensurePermissionsForShow()) return;

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.riskAlerts,
      'Risk Alerts',
      channelDescription: 'Portfolio concentration and risk alerts',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.private,
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

    LoggerService.info(
      'Risk alert shown',
      metadata: {'title': title, 'body': body, 'alertType': alertType},
    );
  }

  // ============ Idle Investment Alerts ============

  /// Check for idle investments and show alerts.
  ///
  /// An investment is "idle" if it has no cash flow activity
  /// for [idleAlertDays] days. Limited to one alert per investment per month.
  Future<void> checkIdleInvestments(
    List<IdleInvestmentInfo> investments,
  ) async {
    await ensureInitialized();
    if (!idleAlertsEnabled) return;
    if (!await ensurePermissionsForShow()) return;

    final now = DateTime.now();
    final threshold = now.subtract(Duration(days: idleAlertDays));
    final monthAgo = now.subtract(const Duration(days: 30));

    for (final inv in investments) {
      if (inv.isClosed) continue;

      // Safe null handling: Use local variable to avoid multiple null assertions
      final activityDate = inv.lastActivityDate;
      if (activityDate != null && activityDate.isAfter(threshold)) {
        continue;
      }

      final lastShown = getIdleAlertLastShown(inv.id);
      if (lastShown != null && lastShown.isAfter(monthAgo)) {
        continue;
      }

      await markIdleAlertShown(inv.id);

      final daysSinceActivity = activityDate != null
          ? now.difference(activityDate).inDays
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
        visibility: NotificationVisibility.private,
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

      LoggerService.info(
        'Idle alert shown',
        metadata: {'investmentId': inv.id, 'investmentName': inv.name},
      );
    }
  }
}

/// Income Guardian notification handler for expected cash flow alerts.
///
/// This handler manages notifications for:
/// - Overdue expected payments
/// - Upcoming payment reminders (1 day before)
/// - Payment received confirmations
/// - Platform delay warnings
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/notifications/notification_constants.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';

/// Income Guardian notification handler
class IncomeGuardianNotificationHandler {
  final FlutterLocalNotificationsPlugin _plugin;
  final Future<void> Function() _ensureInitialized;
  final Future<bool> Function() _ensurePermissionsForShow;
  final String Function(double amount, String currency, String locale) _formatCurrency;

  IncomeGuardianNotificationHandler({
    required FlutterLocalNotificationsPlugin plugin,
    required Future<void> Function() ensureInitialized,
    required Future<bool> Function() ensurePermissionsForShow,
    required String Function(double, String, String) formatCurrency,
  })  : _plugin = plugin,
        _ensureInitialized = ensureInitialized,
        _ensurePermissionsForShow = ensurePermissionsForShow,
        _formatCurrency = formatCurrency;

  // ============ NOTIFICATION DISPLAY METHODS ============

  /// Show overdue payment notification
  Future<void> showOverduePaymentNotification({
    required ExpectedCashFlowEntity expectedCashFlow,
    required String investmentName,
    required String currency,
    required String locale,
  }) async {
    await _ensureInitialized();
    if (!await _ensurePermissionsForShow()) return;

    final formattedAmount = _formatCurrency(
      expectedCashFlow.expectedAmount,
      currency,
      locale,
    );
    final daysOverdue = expectedCashFlow.daysOverdue;

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.incomeGuardian,
      'Income Guardian',
      channelDescription: 'Expected payment alerts and reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      id: NotificationIds.incomeGuardianOverdue(expectedCashFlow.investmentId),
      title: '⚠️ Payment Overdue',
      body: '$formattedAmount expected from $investmentName is $daysOverdue days late',
      notificationDetails: details,
      payload: NotificationPayload.incomeGuardianOverdue(
        expectedCashFlow.investmentId,
        expectedCashFlow.id,
      ),
    );

    LoggerService.info(
      'Overdue payment notification shown',
      metadata: {
        'investmentId': expectedCashFlow.investmentId,
        'expectedCashFlowId': expectedCashFlow.id,
        'daysOverdue': daysOverdue,
      },
    );
  }

  /// Show upcoming payment reminder (1 day before)
  Future<void> showUpcomingPaymentReminder({
    required ExpectedCashFlowEntity expectedCashFlow,
    required String investmentName,
    required String currency,
    required String locale,
  }) async {
    await _ensureInitialized();
    if (!await _ensurePermissionsForShow()) return;

    final formattedAmount = _formatCurrency(
      expectedCashFlow.expectedAmount,
      currency,
      locale,
    );

    const androidDetails = AndroidNotificationDetails(
      NotificationChannels.incomeGuardian,
      'Income Guardian',
      channelDescription: 'Expected payment alerts and reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      id: NotificationIds.incomeGuardianUpcoming(expectedCashFlow.investmentId),
      title: '📅 Payment Due Tomorrow',
      body: 'Expecting $formattedAmount from $investmentName',
      notificationDetails: details,
      payload: NotificationPayload.incomeGuardianUpcoming(
        expectedCashFlow.investmentId,
        expectedCashFlow.id,
      ),
    );

    LoggerService.info(
      'Upcoming payment reminder shown',
      metadata: {
        'investmentId': expectedCashFlow.investmentId,
        'expectedCashFlowId': expectedCashFlow.id,
      },
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/notification_navigator.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

void main() {
  group('NotificationNavigator - Add Cash Flow from a notification (A08)', () {
    test('income reminder tap opens Add Cash Flow with INCOME preselected', () {
      final payload = NotificationPayload.parse(
        NotificationPayload.incomeReminder('inv-1'),
      );

      final screen = NotificationNavigator.addCashFlowScreen(
        payload.investmentId!,
        payload.params,
      );

      expect(screen.investmentId, 'inv-1');
      expect(screen.initialType, CashFlowType.income);
    });

    test('unknown flow type leaves the screen default', () {
      final screen = NotificationNavigator.addCashFlowScreen('inv-1', const {
        'flowType': 'not-a-type',
      });

      expect(screen.initialType, isNull);
    });
  });
}

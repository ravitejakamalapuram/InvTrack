import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/income_guardian_service_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../../../../mocks/mock_notification_service.dart';

/// Income Guardian notifications passed the ISO code as the symbol, so they
/// read 'INR2.5L' or 'USD1.5K' (UX-V02). The amount must use the currency's
/// own symbol and the shared compact format.
void main() {
  late FakeFlutterLocalNotificationsPlugin plugin;
  late ProviderContainer container;

  setUp(() async {
    tz_data.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    plugin = FakeFlutterLocalNotificationsPlugin();
    container = ProviderContainer(
      overrides: [
        flutterLocalNotificationsPluginProvider.overrideWithValue(plugin),
        notificationServiceProvider.overrideWithValue(
          NotificationService(plugin, prefs),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  ExpectedCashFlowEntity expected(double amount, String currency) =>
      ExpectedCashFlowEntity(
        id: 'ecf-1',
        investmentId: 'inv-1',
        expectedDate: DateTime.now().subtract(const Duration(days: 5)),
        expectedAmount: amount,
        currency: currency,
        predictionSource: PredictionSource.fixed,
        status: ExpectedCashFlowStatus.overdue,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  test('an INR payment reads in lakh with the rupee symbol', () async {
    await container
        .read(incomeGuardianNotificationHandlerProvider)
        .showOverduePaymentNotification(
          expectedCashFlow: expected(250000, 'INR'),
          investmentName: 'P2P loan',
          currency: 'INR',
          locale: 'en_IN',
        );

    final body = plugin.shownNotifications.single.body!;
    expect(body, startsWith('₹2.5 L expected from P2P loan'));
    expect(body, isNot(contains('INR')));
  });

  test('a USD payment uses the dollar symbol, not the code', () async {
    await container
        .read(incomeGuardianNotificationHandlerProvider)
        .showUpcomingPaymentReminder(
          expectedCashFlow: expected(1500, 'USD'),
          investmentName: 'US bond',
          currency: 'USD',
          locale: 'en_IN',
        );

    final body = plugin.shownNotifications.single.body!;
    expect(body, contains('\$1.5K'));
    expect(body, isNot(contains('USD')));
  });
}

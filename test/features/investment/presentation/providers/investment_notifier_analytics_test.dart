// A41 (#784): creating an investment is the first step of the activation
// funnel. investment_created says the type and whether notes and an amount
// were entered, as 1/0 flags: never the name, the notes or an amount.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

import '../../../../helpers/analytics_privacy.dart';
import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_notification_service.dart';
import '../../data/repositories/mock_investment_repository.dart';

void main() {
  late FakeAnalyticsService analytics;
  late ProviderContainer container;

  setUp(() {
    analytics = FakeAnalyticsService();
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(
          FakeInvestmentRepository(),
        ),
        analyticsServiceProvider.overrideWithValue(analytics),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        isAuthenticatedProvider.overrideWithValue(true),
        currencyCodeProvider.overrideWithValue('INR'),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> add({String? notes}) => container
      .read(investmentNotifierProvider.notifier)
      .addInvestment(
        name: 'Ravi Kumar P2P',
        type: InvestmentType.p2pLending,
        notes: notes,
      );

  Iterable<({String name, Map<String, Object>? parameters})> created() =>
      analytics.loggedEvents.where((e) => e.name == 'investment_created');

  test('is logged once, with no notes and no amount', () async {
    await add();

    expect(created(), hasLength(1));
    expect(created().single.parameters, {
      'investment_type': 'p2pLending',
      'has_notes': 0,
      'has_amount': 0,
    });
    expectPrivacySafe(
      created().single,
      allowedStrings: {
        'investment_type': {'p2pLending'},
      },
    );
  });

  test('says when notes were entered, without sending them', () async {
    await add(notes: 'Lent to my cousin Ravi');

    expect(created().single.parameters, {
      'investment_type': 'p2pLending',
      'has_notes': 1,
      'has_amount': 0,
    });
  });

  test('blank notes count as no notes', () async {
    await add(notes: '   ');

    expect(created().single.parameters!['has_notes'], 0);
  });
}

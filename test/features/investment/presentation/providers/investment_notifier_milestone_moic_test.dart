import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_currency_conversion_service.dart';
import '../../../../mocks/mock_notification_service.dart';
import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../data/repositories/mock_investment_repository.dart';
import '../../valuation/in_memory_valuation_repository.dart';
import '../../valuation/valuation_fixtures.dart';

/// Milestone notifications must show the same MOIC as the screens (money
/// rule 3): the shared paid-in MOIC from `calculateStats`, on cash flows
/// converted to the base currency (rule 2) and with the current value of an
/// open investment (rule 4). These tests run the real notification service
/// against a fake plugin, so they check what the user is shown.
void main() {
  late FakeInvestmentRepository repo;
  late FakeGoalRepository goals;
  late FakeFlutterLocalNotificationsPlugin plugin;
  late NotificationService notifications;

  setUp(() async {
    tz_data.initializeTimeZones();
    repo = FakeInvestmentRepository();
    goals = FakeGoalRepository();
    plugin = FakeFlutterLocalNotificationsPlugin();
    SharedPreferences.setMockInitialValues({});
    notifications = NotificationService(
      plugin,
      await SharedPreferences.getInstance(),
    );
  });

  ProviderContainer containerFor(
    String baseCurrency, {
    InMemoryValuationRepository? valuations,
  }) {
    final container = ProviderContainer(
      overrides: [
        if (valuations != null) ...[
          valuationRepositoryProvider.overrideWithValue(valuations),
          valuationSnapshotsActiveProvider.overrideWithValue(true),
        ],
        investmentRepositoryProvider.overrideWithValue(repo),
        goalRepositoryProvider.overrideWithValue(goals),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        notificationServiceProvider.overrideWithValue(notifications),
        currencyConversionServiceProvider.overrideWithValue(
          MockCurrencyConversionService(),
        ),
        isAuthenticatedProvider.overrideWithValue(true),
        currencyCodeProvider.overrideWithValue(baseCurrency),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  InvestmentEntity investment(
    String id, {
    InvestmentType type = InvestmentType.p2pLending,
    InvestmentStatus status = InvestmentStatus.open,
    String currency = 'INR',
    double? currentValue,
    DateTime? currentValueDate,
  }) => InvestmentEntity(
    id: id,
    name: 'Holding $id',
    type: type,
    status: status,
    createdAt: DateTime(2023, 1, 1),
    updatedAt: DateTime(2023, 1, 1),
    currency: currency,
    currentValue: currentValue,
    currentValueDate: currentValueDate,
  );

  CashFlowEntity flow(
    String id,
    String investmentId,
    CashFlowType type,
    double amount,
    DateTime date, {
    String currency = 'INR',
  }) => CashFlowEntity(
    id: id,
    investmentId: investmentId,
    type: type,
    amount: amount,
    date: date,
    createdAt: date,
    currency: currency,
  );

  Future<void> addReturn(
    ProviderContainer container,
    String investmentId,
    double amount,
    DateTime date, {
    CashFlowType type = CashFlowType.returnFlow,
    String currency = 'INR',
  }) => container
      .read(investmentNotifierProvider.notifier)
      .addCashFlow(
        investmentId: investmentId,
        type: type,
        amount: amount,
        date: date,
        currency: currency,
      );

  group('milestone MOIC is the shared paid-in MOIC', () {
    test('a re-lent P2P payout counts once, so 1.5x fires', () async {
      // -1,00,000; +50,000; -50,000 re-lent; +1,50,000. Paid in: 1,00,000.
      // MOIC = (2,00,000 - 50,000 re-lent) / 1,00,000 = 1.5, as on screen.
      // The old gross sum gave 2,00,000 / 1,50,000 = 1.33x: no notification.
      repo.seed(
        investments: [investment('p2p')],
        cashFlows: [
          flow('a', 'p2p', CashFlowType.invest, 100000, DateTime(2025, 1, 1)),
          flow(
            'b',
            'p2p',
            CashFlowType.returnFlow,
            50000,
            DateTime(2025, 3, 1),
          ),
          flow('c', 'p2p', CashFlowType.invest, 50000, DateTime(2025, 3, 1)),
        ],
      );

      await addReturn(containerFor('INR'), 'p2p', 150000, DateTime(2025, 9, 1));

      final shown = plugin.shownNotifications.single;
      expect(shown.title, contains('1.5x'));
      // The gain is unchanged by the re-lending: 2,00,000 back for 1,50,000
      // out.
      expect(shown.body, contains('₹50,000.00'));
    });

    test('a renewed FD shows the 2.0x it reached, not 1.5x', () async {
      // -10L; +15L back and -15L renewed on one day; +22.5L at the end.
      // Paid in: 10L. MOIC = (37.5L - 15L renewed) / 10L = 2.25. The old
      // gross sum gave 37.5L / 25L = 1.5x.
      repo.seed(
        investments: [investment('fd', type: InvestmentType.fixedDeposit)],
        cashFlows: [
          flow('a', 'fd', CashFlowType.invest, 1000000, DateTime(2023, 1, 1)),
          flow(
            'b',
            'fd',
            CashFlowType.returnFlow,
            1500000,
            DateTime(2024, 1, 1),
          ),
          flow('c', 'fd', CashFlowType.invest, 1500000, DateTime(2024, 1, 1)),
        ],
      );

      await addReturn(containerFor('INR'), 'fd', 2250000, DateTime(2025, 1, 1));

      final shown = plugin.shownNotifications.single;
      expect(shown.title, contains('2.0x'));
      expect(shown.body, contains('₹12,50,000.00'));
    });

    test('a USD loan for an INR user uses converted amounts', () async {
      // $1,000 out, $500 back and re-lent, $1,500 at the end, at 83 INR:
      // paid in ₹83,000, MOIC = ₹1,24,500 / ₹83,000 = 1.5.
      repo.seed(
        investments: [investment('usd', currency: 'USD')],
        cashFlows: [
          flow(
            'a',
            'usd',
            CashFlowType.invest,
            1000,
            DateTime(2025, 1, 1),
            currency: 'USD',
          ),
          flow(
            'b',
            'usd',
            CashFlowType.returnFlow,
            500,
            DateTime(2025, 3, 1),
            currency: 'USD',
          ),
          flow(
            'c',
            'usd',
            CashFlowType.invest,
            500,
            DateTime(2025, 3, 1),
            currency: 'USD',
          ),
        ],
      );

      await addReturn(
        containerFor('INR'),
        'usd',
        1500,
        DateTime(2025, 9, 1),
        currency: 'USD',
      );

      final shown = plugin.shownNotifications.single;
      expect(shown.title, contains('1.5x'));
      // $500 of gain at 83 INR, in the base currency.
      expect(shown.body, contains('₹41,500.00'));
    });

    test('a closed investment with mixed currencies is converted', () async {
      // $10,000 out; ₹12,45,000 back = $15,000 at 83: 1.5x.
      repo.seed(
        investments: [
          investment(
            'closed',
            currency: 'USD',
            status: InvestmentStatus.closed,
          ),
        ],
        cashFlows: [
          flow(
            'a',
            'closed',
            CashFlowType.invest,
            10000,
            DateTime(2025, 1, 1),
            currency: 'USD',
          ),
        ],
      );

      await addReturn(
        containerFor('USD'),
        'closed',
        1245000,
        DateTime(2025, 9, 1),
      );

      final shown = plugin.shownNotifications.single;
      expect(shown.title, contains('1.5x'));
      expect(shown.body, contains('\$5,000.00'));
    });
  });

  group('milestone MOIC needs a current value for an open investment', () {
    test('the current value of an open investment counts', () async {
      // ₹1,00,000 in; ₹30,000 income; the user values it at ₹1,30,000.
      // MOIC = (30,000 + 1,30,000) / 1,00,000 = 1.6. The cash alone is 0.3x.
      repo.seed(
        investments: [
          investment(
            'valued',
            currentValue: 130000,
            currentValueDate: DateTime(2025, 6, 1),
          ),
        ],
        cashFlows: [
          flow(
            'a',
            'valued',
            CashFlowType.invest,
            100000,
            DateTime(2025, 1, 1),
          ),
        ],
      );

      await addReturn(
        containerFor('INR'),
        'valued',
        30000,
        DateTime(2025, 7, 1),
        type: CashFlowType.income,
      );

      final shown = plugin.shownNotifications.single;
      expect(shown.title, contains('1.5x'));
      // Gain: 30,000 income + 1,30,000 value - 1,00,000 invested.
      expect(shown.body, contains('₹60,000.00'));
    });

    test('a dated valuation counts, and only its own are read', () async {
      // Gold bought for ₹1,00,000, valued at ₹1,20,000 on 2025-06-01; ₹40,000
      // of income after that does not move a market value. MOIC =
      // (40,000 + 1,20,000) / 1,00,000 = 1.6. Without the valuation the gold
      // has no value, so no MOIC.
      final valuations = InMemoryValuationRepository();
      addTearDown(valuations.dispose);
      valuations.docs['v1'] = testSnapshot(
        'v1',
        investmentId: 'gold',
        amount: 120000,
        date: DateTime(2025, 6, 1),
        kind: ValuationKind.marketValue,
      );
      valuations.docs['v2'] = testSnapshot(
        'v2',
        investmentId: 'other',
        amount: 5,
        date: DateTime(2025, 6, 1),
      );
      repo.seed(
        investments: [investment('gold', type: InvestmentType.gold)],
        cashFlows: [
          flow('a', 'gold', CashFlowType.invest, 100000, DateTime(2025, 1, 1)),
        ],
      );

      await addReturn(
        containerFor('INR', valuations: valuations),
        'gold',
        40000,
        DateTime(2025, 7, 1),
        type: CashFlowType.income,
      );

      final shown = plugin.shownNotifications.single;
      expect(shown.title, contains('1.5x'));
      // Gain: 40,000 income + 1,20,000 value - 1,00,000 invested.
      expect(shown.body, contains('₹60,000.00'));
      expect(valuations.readByInvestment, ['gold']);
      expect(valuations.getAllCount, 0);
    });

    test('an open holding with no value yet has no MOIC', () async {
      // Gold bought for ₹1,00,000 with ₹40,000 back is still out of pocket,
      // and nothing says what it is worth: the screens show "—".
      repo.seed(
        investments: [investment('gold', type: InvestmentType.gold)],
        cashFlows: [
          flow('a', 'gold', CashFlowType.invest, 100000, DateTime(2025, 1, 1)),
        ],
      );

      await addReturn(
        containerFor('INR'),
        'gold',
        40000,
        DateTime(2025, 7, 1),
        type: CashFlowType.income,
      );

      expect(plugin.shownNotifications, isEmpty);
    });

    test(
      'an open loan whose flows are in two currencies has no MOIC',
      () async {
        // $10,000 out and ₹12,45,000 ($15,000) back would be 1.5x, but its
        // value cannot be worked out across two currencies, so the screens show
        // "—" (money rule 4). No milestone is announced either.
        repo.seed(
          investments: [investment('mixed', currency: 'USD')],
          cashFlows: [
            flow(
              'a',
              'mixed',
              CashFlowType.invest,
              10000,
              DateTime(2025, 1, 1),
              currency: 'USD',
            ),
          ],
        );

        await addReturn(
          containerFor('USD'),
          'mixed',
          1245000,
          DateTime(2025, 9, 1),
        );

        expect(plugin.shownNotifications, isEmpty);
      },
    );
  });
}

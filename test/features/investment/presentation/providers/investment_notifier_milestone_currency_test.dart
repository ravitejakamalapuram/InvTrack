import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_currency_conversion_service.dart';
import '../../../../mocks/mock_notification_service.dart';
import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../data/repositories/mock_investment_repository.dart';

/// Records what the notifier asks the notification service to show.
class _RecordingNotificationService extends FakeNotificationService {
  final milestones = <Map<String, Object>>[];
  final goalMilestones = <Map<String, Object>>[];

  @override
  Future<void> checkAndShowMilestone({
    required String investmentId,
    required String investmentName,
    required double totalInvested,
    required double totalReturned,
    String currency = 'INR',
  }) async {
    milestones.add({
      'invested': totalInvested,
      'returned': totalReturned,
      'currency': currency,
    });
  }

  @override
  Future<void> checkAndShowGoalMilestone({
    required String goalId,
    required String goalName,
    required double progressPercent,
    required double currentValue,
    required double targetValue,
    String currency = 'INR',
    bool firstCheck = false,
  }) async {
    goalMilestones.add({
      'percent': progressPercent,
      'current': currentValue,
      'target': targetValue,
      'currency': currency,
    });
  }
}

/// A converter that is offline and has no cached rate to fall back on.
class _OfflineNoCacheConversionService extends MockCurrencyConversionService {
  @override
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async {
    if (from == to) return amount;
    throw Exception('offline');
  }

  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async => throw Exception('offline');

  @override
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async => from == to ? 1.0 : null;
}

/// Milestone notifications summed raw amounts in mixed currencies and showed
/// them under '₹' whatever the base currency (GAP2-03). They must use the
/// base currency and amounts converted to it (rate here: 1 USD = 83 INR).
void main() {
  late FakeInvestmentRepository repo;
  late FakeGoalRepository goals;
  late _RecordingNotificationService notifications;

  setUp(() {
    repo = FakeInvestmentRepository();
    goals = FakeGoalRepository();
    notifications = _RecordingNotificationService();
  });

  ProviderContainer containerFor(
    String baseCurrency, {
    CurrencyConversionService? conversion,
  }) {
    final container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(repo),
        goalRepositoryProvider.overrideWithValue(goals),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        notificationServiceProvider.overrideWithValue(notifications),
        currencyConversionServiceProvider.overrideWithValue(
          conversion ?? MockCurrencyConversionService(),
        ),
        isAuthenticatedProvider.overrideWithValue(true),
        currencyCodeProvider.overrideWithValue(baseCurrency),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  InvestmentEntity investment(String id, String currency) => InvestmentEntity(
    id: id,
    name: 'Fund $id',
    type: InvestmentType.p2pLending,
    status: InvestmentStatus.open,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
    currency: currency,
  );

  CashFlowEntity flow(
    String investmentId,
    CashFlowType type,
    double amount,
    String currency,
  ) => CashFlowEntity(
    id: 'cf-$investmentId-${type.name}-$amount',
    investmentId: investmentId,
    type: type,
    amount: amount,
    date: DateTime(2025, 2, 1),
    createdAt: DateTime(2025, 2, 1),
    currency: currency,
  );

  group('investment milestone', () {
    test('a USD user is notified in USD', () async {
      repo.seed(
        investments: [investment('inv-1', 'USD')],
        cashFlows: [flow('inv-1', CashFlowType.invest, 10000, 'USD')],
      );
      final container = containerFor('USD');

      await container
          .read(investmentNotifierProvider.notifier)
          .addCashFlow(
            investmentId: 'inv-1',
            type: CashFlowType.returnFlow,
            amount: 15000,
            date: DateTime(2026, 1, 1),
            currency: 'USD',
          );

      expect(notifications.milestones, [
        {'invested': 10000.0, 'returned': 15000.0, 'currency': 'USD'},
      ]);
    });

    test('mixed currencies are converted before the MOIC check', () async {
      // $10,000 in, ₹8,30,000 back = $10,000 at 83: 1.0x, not 83x.
      repo.seed(
        investments: [investment('inv-2', 'USD')],
        cashFlows: [flow('inv-2', CashFlowType.invest, 10000, 'USD')],
      );
      final container = containerFor('USD');

      await container
          .read(investmentNotifierProvider.notifier)
          .addCashFlow(
            investmentId: 'inv-2',
            type: CashFlowType.returnFlow,
            amount: 830000,
            date: DateTime(2026, 1, 1),
            currency: 'INR',
          );

      expect(notifications.milestones, hasLength(1));
      expect(notifications.milestones.single['currency'], 'USD');
      expect(
        notifications.milestones.single['invested'] as double,
        closeTo(10000, 0.005),
      );
      expect(
        notifications.milestones.single['returned'] as double,
        closeTo(10000, 0.005),
      );
    });

    test('no milestone when a rate is unavailable offline', () async {
      // Without a rate the ₹8,30,000 would be counted as $830,000 (83x).
      repo.seed(
        investments: [investment('inv-5', 'USD')],
        cashFlows: [flow('inv-5', CashFlowType.invest, 10000, 'USD')],
      );
      final container = containerFor(
        'USD',
        conversion: _OfflineNoCacheConversionService(),
      );

      await container
          .read(investmentNotifierProvider.notifier)
          .addCashFlow(
            investmentId: 'inv-5',
            type: CashFlowType.returnFlow,
            amount: 830000,
            date: DateTime(2026, 1, 1),
            currency: 'INR',
          );

      expect(notifications.milestones, isEmpty);
    });
  });

  group('goal milestone', () {
    GoalEntity goal({
      String id = 'goal-1',
      GoalType type = GoalType.targetAmount,
      double targetAmount = 50000,
      double? targetMonthlyIncome,
      List<String> linkedInvestmentIds = const [],
    }) => GoalEntity(
      id: id,
      name: 'Retire',
      type: type,
      targetAmount: targetAmount,
      targetMonthlyIncome: targetMonthlyIncome,
      trackingMode: linkedInvestmentIds.isEmpty
          ? GoalTrackingMode.all
          : GoalTrackingMode.selected,
      linkedInvestmentIds: linkedInvestmentIds,
      icon: 'flag',
      colorValue: 0,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      currency: 'USD',
    );

    test('a USD goal against INR flows notifies 50%, not 100%', () async {
      // $50,000 target; ₹20,75,000 still invested = $25,000 at 83. A goal
      // counts what its open investments are worth today (A12), here the
      // principal still invested as no value is entered.
      goals.seed(goals: [goal()]);
      repo.seed(
        investments: [investment('inv-3', 'INR')],
        cashFlows: [flow('inv-3', CashFlowType.invest, 2000000, 'INR')],
      );
      final container = containerFor('USD');

      await container
          .read(investmentNotifierProvider.notifier)
          .addCashFlow(
            investmentId: 'inv-3',
            type: CashFlowType.invest,
            amount: 75000,
            date: DateTime(2026, 1, 1),
            currency: 'INR',
          );

      expect(notifications.goalMilestones, hasLength(1));
      final shown = notifications.goalMilestones.single;
      expect(shown['percent'] as double, closeTo(50, 1e-6));
      expect(shown['current'] as double, closeTo(25000, 0.005));
      expect(shown['target'], 50000.0);
      expect(shown['currency'], 'USD');
    });

    test(
      'an income goal shows its monthly target in the base currency',
      () async {
        // $1,000 a month = ₹83,000 for an INR user; ₹20,750 a month is 25%.
        // Income counts over the last 12 months (A12), so a single payout of
        // ₹2,49,000 today is ₹20,750 a month.
        final now = DateTime.now();
        goals.seed(
          goals: [
            goal(
              type: GoalType.incomeTarget,
              targetAmount: 12000,
              targetMonthlyIncome: 1000,
            ),
          ],
        );
        repo.seed(investments: [investment('inv-4', 'INR')]);
        final container = containerFor('INR');

        await container
            .read(investmentNotifierProvider.notifier)
            .addCashFlow(
              investmentId: 'inv-4',
              type: CashFlowType.income,
              amount: 249000,
              date: DateTime(now.year, now.month, now.day),
              currency: 'INR',
            );

        expect(notifications.goalMilestones, hasLength(1));
        final shown = notifications.goalMilestones.single;
        expect(shown['target'], 83000.0);
        expect(shown['currency'], 'INR');
      },
    );

    test('no goal milestone when a rate is unavailable offline', () async {
      // Without a rate ₹8,30,000 would count as $830,000 of a $50,000 goal.
      goals.seed(goals: [goal()]);
      repo.seed(investments: [investment('inv-6', 'INR')]);
      final container = containerFor(
        'USD',
        conversion: _OfflineNoCacheConversionService(),
      );

      await container
          .read(investmentNotifierProvider.notifier)
          .addCashFlow(
            investmentId: 'inv-6',
            type: CashFlowType.invest,
            amount: 830000,
            date: DateTime(2026, 1, 1),
            currency: 'INR',
          );

      expect(notifications.goalMilestones, isEmpty);
    });

    test('a missing rate for one goal does not skip the other goals', () async {
      // goal-1 tracks everything, including an INR flow with no rate.
      // goal-2 tracks only a USD investment: $10,000 invested of $20,000
      // is 50%.
      goals.seed(
        goals: [
          goal(),
          goal(
            id: 'goal-2',
            targetAmount: 20000,
            linkedInvestmentIds: ['inv-8'],
          ),
        ],
      );
      repo.seed(
        investments: [investment('inv-7', 'INR'), investment('inv-8', 'USD')],
        cashFlows: [flow('inv-7', CashFlowType.invest, 100000, 'INR')],
      );
      final container = containerFor(
        'USD',
        conversion: _OfflineNoCacheConversionService(),
      );

      await container
          .read(investmentNotifierProvider.notifier)
          .addCashFlow(
            investmentId: 'inv-8',
            type: CashFlowType.invest,
            amount: 10000,
            date: DateTime(2026, 1, 1),
            currency: 'USD',
          );

      expect(notifications.goalMilestones, hasLength(1));
      final shown = notifications.goalMilestones.single;
      expect(shown['percent'] as double, closeTo(50, 1e-6));
      expect(shown['target'], 20000.0);
      expect(shown['currency'], 'USD');
      // The stale-goal check needs no amounts, so it runs for both goals.
      expect(
        notifications.shownGoalStaleNotifications,
        containsAll(<String>['goal-1', 'goal-2']),
      );
    });
  });
}

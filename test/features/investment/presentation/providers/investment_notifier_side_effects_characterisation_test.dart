// A40 (#783) PR A1, characterisation. The A1 refactor moves the side effects of
// addCashFlow into one funnel and the post-save work of addInvestment into its
// own guarded step. With the first-investment flow off, a user must see exactly
// the events and notifications that main produces today. These tests pin them
// and were written against the code BEFORE the refactor: green before, green
// after. They are not red-first tests.
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

/// Records the notification calls a save makes.
class _RecordingNotifications extends FakeNotificationService {
  int activationCancelled = 0;
  final milestones = <String>[];
  final goalMilestones = <Map<String, Object>>[];

  @override
  Future<void> cancelActivationSequence() async => activationCancelled++;

  @override
  Future<void> checkAndShowMilestone({
    required String investmentId,
    required String investmentName,
    required double moic,
    required double gain,
    String currency = 'INR',
  }) async {
    milestones.add('$investmentId $currency ${moic.toStringAsFixed(2)}');
  }

  @override
  Future<void> checkAndShowGoalMilestone({
    required String goalId,
    required String goalName,
    required double progressPercent,
    required double currentValue,
    required double targetValue,
    String currency = 'INR',
    bool announce = true,
  }) async {
    goalMilestones.add({
      'goal': goalId,
      'percent': progressPercent,
      'announce': announce,
    });
  }
}

void main() {
  late FakeAnalyticsService analytics;
  late _RecordingNotifications notifications;
  late FakeInvestmentRepository repo;
  late FakeGoalRepository goals;
  late ProviderContainer container;

  setUp(() {
    analytics = FakeAnalyticsService();
    notifications = _RecordingNotifications();
    repo = FakeInvestmentRepository();
    goals = FakeGoalRepository();
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(repo),
        goalRepositoryProvider.overrideWithValue(goals),
        analyticsServiceProvider.overrideWithValue(analytics),
        notificationServiceProvider.overrideWithValue(notifications),
        currencyConversionServiceProvider.overrideWithValue(
          MockCurrencyConversionService(),
        ),
        isAuthenticatedProvider.overrideWithValue(true),
        currencyCodeProvider.overrideWithValue('INR'),
      ],
    );
    addTearDown(container.dispose);
  });

  InvestmentNotifier notifier() =>
      container.read(investmentNotifierProvider.notifier);

  /// Every event logged so far, as its name and parameters in one map.
  List<Map<String, Object?>> events() => [
    for (final e in analytics.loggedEvents) {'event': e.name, ...?e.parameters},
  ];

  group('addInvestment without an amount', () {
    test('fires investment_created and nothing else', () async {
      await notifier().addInvestment(
        name: 'HDFC FD',
        type: InvestmentType.fixedDeposit,
        notes: 'for the house',
      );
      await pumpEventQueue();

      expect(events(), [
        {
          'event': 'investment_created',
          'investment_type': 'fixedDeposit',
          'has_notes': 1,
          'has_amount': 0,
        },
      ]);
      expect(repo.investments, hasLength(1));
      expect(repo.cashFlows, isEmpty);
    });

    test('cancels the activation nudges once', () async {
      await notifier().addInvestment(
        name: 'HDFC FD',
        type: InvestmentType.fixedDeposit,
      );
      await pumpEventQueue();

      expect(notifications.activationCancelled, 1);
    });

    test('schedules the income and maturity reminders it was given', () async {
      final created = await notifier().addInvestment(
        name: 'HDFC FD',
        type: InvestmentType.fixedDeposit,
        incomeFrequency: IncomeFrequency.quarterly,
        maturityDate: DateTime(2027, 10, 11),
      );
      await pumpEventQueue();

      expect(notifications.scheduledIncomeReminders, [created.id]);
      expect(notifications.scheduledMaturityReminders, [created.id]);
    });

    test('schedules no reminder when it was given neither', () async {
      await notifier().addInvestment(
        name: 'HDFC FD',
        type: InvestmentType.fixedDeposit,
      );
      await pumpEventQueue();

      expect(notifications.scheduledIncomeReminders, isEmpty);
      expect(notifications.scheduledMaturityReminders, isEmpty);
    });

    test('a failing write fires nothing', () async {
      container.dispose();
      final failing = ProviderContainer(
        overrides: [
          investmentRepositoryProvider.overrideWithValue(_FailingRepository()),
          analyticsServiceProvider.overrideWithValue(analytics),
          notificationServiceProvider.overrideWithValue(notifications),
          isAuthenticatedProvider.overrideWithValue(true),
          currencyCodeProvider.overrideWithValue('INR'),
        ],
      );
      addTearDown(failing.dispose);

      await expectLater(
        failing
            .read(investmentNotifierProvider.notifier)
            .addInvestment(name: 'HDFC FD', type: InvestmentType.fixedDeposit),
        throwsA(isA<StateError>()),
      );
      await pumpEventQueue();

      expect(events(), isEmpty);
      expect(notifications.activationCancelled, 0);
      expect(failing.read(investmentNotifierProvider).hasError, isTrue);
    });
  });

  group('addCashFlow', () {
    final investment = InvestmentEntity(
      id: 'inv-1',
      name: 'Fund',
      type: InvestmentType.p2pLending,
      status: InvestmentStatus.closed,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      currency: 'INR',
    );
    final invested = CashFlowEntity(
      id: 'cf-0',
      investmentId: 'inv-1',
      type: CashFlowType.invest,
      amount: 10000,
      date: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      currency: 'INR',
    );

    GoalEntity goal() => GoalEntity(
      id: 'goal-1',
      name: 'House',
      type: GoalType.targetAmount,
      targetAmount: 100000,
      trackingMode: GoalTrackingMode.all,
      linkedInvestmentIds: const [],
      icon: 'flag',
      colorValue: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      currency: 'INR',
    );

    Future<void> add(CashFlowType type, double amount) =>
        notifier().addCashFlow(
          investmentId: 'inv-1',
          type: type,
          amount: amount,
          date: DateTime(2026, 6, 1),
          currency: 'INR',
        );

    for (final type in CashFlowType.values) {
      test('${type.name}: fires one cashflow_added and nothing else', () async {
        repo.seed(investments: [investment], cashFlows: [invested]);

        await add(type, 2500);
        await pumpEventQueue();

        expect(events(), [
          {
            'event': 'cashflow_added',
            'flow_type': type.name,
            'amount_range': '1k_10k',
          },
        ]);
      });
    }

    for (final type in CashFlowType.values) {
      final announced =
          type == CashFlowType.income || type == CashFlowType.returnFlow;
      test('${type.name}: the investment milestone is '
          '${announced ? 'checked' : 'not checked'}', () async {
        repo.seed(investments: [investment], cashFlows: [invested]);

        await add(type, 15000);

        // 1.5x on 10,000 paid in; only income and returns can announce it.
        expect(notifications.milestones, announced ? ['inv-1 INR 1.50'] : []);
      });
    }

    for (final type in CashFlowType.values) {
      test('${type.name}: the goal check runs', () async {
        repo.seed(investments: [investment], cashFlows: [invested]);
        goals.seed(goals: [goal()]);

        await add(type, 2500);

        expect(notifications.shownGoalStaleNotifications, ['goal-1']);
      });
    }

    test('a flow that crosses a goal milestone announces it', () async {
      final open = investment.copyWith(status: InvestmentStatus.open);
      repo.seed(investments: [open], cashFlows: [invested]);
      goals.seed(goals: [goal()]);

      // 10,000 of 1,00,000 is 10%; 60,000 more makes 70%.
      await add(CashFlowType.invest, 60000);

      expect(notifications.goalMilestones, [
        {'goal': 'goal-1', 'percent': closeTo(70, 1e-6), 'announce': true},
      ]);
    });

    test('a failing write fires nothing', () async {
      repo.seed(investments: [investment]);
      container.dispose();
      final failing = ProviderContainer(
        overrides: [
          investmentRepositoryProvider.overrideWithValue(_FailingRepository()),
          goalRepositoryProvider.overrideWithValue(goals),
          analyticsServiceProvider.overrideWithValue(analytics),
          notificationServiceProvider.overrideWithValue(notifications),
          isAuthenticatedProvider.overrideWithValue(true),
          currencyCodeProvider.overrideWithValue('INR'),
        ],
      );
      addTearDown(failing.dispose);

      await expectLater(
        failing
            .read(investmentNotifierProvider.notifier)
            .addCashFlow(
              investmentId: 'inv-1',
              type: CashFlowType.invest,
              amount: 2500,
              date: DateTime(2026, 6, 1),
              currency: 'INR',
            ),
        throwsA(isA<StateError>()),
      );
      await pumpEventQueue();

      expect(events(), isEmpty);
      expect(failing.read(investmentNotifierProvider).hasError, isTrue);
    });
  });
}

/// A repository whose writes fail.
class _FailingRepository extends FakeInvestmentRepository {
  @override
  Future<void> createInvestment(InvestmentEntity investment) =>
      Future.error(StateError('write failed'));

  @override
  Future<void> addCashFlow(CashFlowEntity cashFlow) =>
      Future.error(StateError('write failed'));
}

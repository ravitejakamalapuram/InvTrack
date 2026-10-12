// A40 (#783) PR-2, decision d-a40-date: editing an investment's start date
// never moves its first cash flow. CHARACTERISATION: this holds today (an
// edit rewrites the investment only) and passes before this PR's form exists;
// it pins the decision, so a later "keep them in step" change must come with a
// new decision. The cash flow keeps the date it was paid on.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_currency_conversion_service.dart';
import '../../../../mocks/mock_notification_service.dart';
import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../data/repositories/mock_investment_repository.dart';

void main() {
  late FakeInvestmentRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeInvestmentRepository();
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(repo),
        goalRepositoryProvider.overrideWithValue(FakeGoalRepository()),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        currencyConversionServiceProvider.overrideWithValue(
          MockCurrencyConversionService(),
        ),
        isAuthenticatedProvider.overrideWithValue(true),
        currencyCodeProvider.overrideWithValue('INR'),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'moving the start date leaves the first INVEST flow where it was',
    () async {
      final notifier = container.read(investmentNotifierProvider.notifier);
      final added = await notifier.addInvestment(
        name: 'Grip FD',
        type: InvestmentType.fixedDeposit,
        startDate: DateTime(2026, 10, 11),
        initialAmount: 100000,
      );
      expect(repo.cashFlows.single.date, DateTime(2026, 10, 11));

      await notifier.updateInvestment(
        id: added.id,
        name: 'Grip FD',
        type: InvestmentType.fixedDeposit,
        startDate: DateTime(2026, 10, 5),
      );

      expect(repo.investments.single.startDate, DateTime(2026, 10, 5));
      final flow = repo.cashFlows.single;
      expect(flow.type, CashFlowType.invest);
      expect(flow.date, DateTime(2026, 10, 11));
      expect(flow.amount, 100000.0);
    },
  );

  test(
    'clearing the start date leaves the first flow dated as saved',
    () async {
      final notifier = container.read(investmentNotifierProvider.notifier);
      final added = await notifier.addInvestment(
        name: 'Grip FD',
        type: InvestmentType.fixedDeposit,
        startDate: DateTime(2026, 10, 11),
        initialAmount: 100000,
      );

      await notifier.updateInvestment(
        id: added.id,
        name: 'Grip FD',
        type: InvestmentType.fixedDeposit,
      );

      expect(repo.investments.single.startDate, isNull);
      expect(repo.cashFlows.single.date, DateTime(2026, 10, 11));
    },
  );
}

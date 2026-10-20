// A26 / ARCH-V02: after a cash flow was saved, the goal milestone check
// pulled every investment and cash flow from the server and the save waited
// for it. The save no longer waits, and the check reads what the app already
// holds (the streams the screens use), not a fresh download.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_currency_conversion_service.dart';
import '../../../../mocks/mock_notification_service.dart';
import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../data/repositories/mock_investment_repository.dart';

/// Counts the whole-collection reads, which are server reads online.
class _CountingRepository extends FakeInvestmentRepository {
  int allInvestmentsReads = 0;
  int allCashFlowsReads = 0;

  @override
  Future<List<InvestmentEntity>> getAllInvestments() {
    allInvestmentsReads++;
    return super.getAllInvestments();
  }

  @override
  Future<List<CashFlowEntity>> getAllCashFlows() {
    allCashFlowsReads++;
    return super.getAllCashFlows();
  }
}

/// A goals source that never answers, like a stalled network read.
class _StalledGoalRepository extends FakeGoalRepository {
  @override
  Stream<List<GoalEntity>> watchActiveGoals() =>
      StreamController<List<GoalEntity>>().stream;
}

GoalEntity _goal() => GoalEntity(
  currency: 'INR',
  id: 'goal-1',
  name: 'Corpus',
  type: GoalType.targetAmount,
  targetAmount: 100000,
  trackingMode: GoalTrackingMode.all,
  icon: GoalIcons.defaultIcon,
  colorValue: GoalColors.defaultColor.toARGB32(),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

ProviderContainer _container(
  _CountingRepository investments,
  FakeGoalRepository goals,
) {
  final container = ProviderContainer(
    overrides: [
      investmentRepositoryProvider.overrideWithValue(investments),
      goalRepositoryProvider.overrideWithValue(goals),
      analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      currencyConversionServiceProvider.overrideWithValue(
        MockCurrencyConversionService(),
      ),
      isAuthenticatedProvider.overrideWithValue(true),
      currencyCodeProvider.overrideWithValue('INR'),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _add(ProviderContainer container) => container
    .read(investmentNotifierProvider.notifier)
    .addCashFlow(
      investmentId: 'inv-1',
      type: CashFlowType.invest,
      amount: 1000,
      date: DateTime(2026, 1, 1),
      currency: 'INR',
    );

void main() {
  test(
    'the save completes while the goal milestone check is stalled',
    () async {
      final container = _container(
        _CountingRepository(),
        _StalledGoalRepository(),
      );

      await _add(container).timeout(const Duration(seconds: 2));

      expect(container.read(investmentNotifierProvider).hasError, isFalse);
    },
  );

  test('the milestone check does not download the collections again', () async {
    final investments = _CountingRepository();
    final goals = FakeGoalRepository()..seed(goals: [_goal()]);
    final container = _container(investments, goals);

    await _add(container);
    await pumpEventQueue();

    expect(investments.cashFlows, hasLength(1));
    expect(investments.allInvestmentsReads, 0);
    expect(investments.allCashFlowsReads, 0);
  });
}

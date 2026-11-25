// The weight of metal bought, typed on the add investment form, is saved on
// the first cash flow with the amount (the same fields the Add transaction
// weight row uses), in the one atomic write.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';
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
        valuationSnapshotsActiveProvider.overrideWithValue(false),
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

  Future<InvestmentEntity> add({
    double? initialAmount,
    double? initialQuantity,
    QuantityUnit? initialQuantityUnit,
  }) => container
      .read(investmentNotifierProvider.notifier)
      .addInvestment(
        name: 'Coins',
        type: InvestmentType.gold,
        initialAmount: initialAmount,
        initialQuantity: initialQuantity,
        initialQuantityUnit: initialQuantityUnit,
      );

  test('the weight and its unit are kept on the first flow', () async {
    await add(
      initialAmount: 300000,
      initialQuantity: 50,
      initialQuantityUnit: QuantityUnit.gram,
    );

    final flow = repo.cashFlows.single;
    expect(flow.amount, 300000);
    expect(flow.quantity, 50);
    expect(flow.quantityUnit, QuantityUnit.gram);
  });

  test('a first flow without a weight has none', () async {
    await add(initialAmount: 300000);

    final flow = repo.cashFlows.single;
    expect(flow.quantity, isNull);
    expect(flow.quantityUnit, isNull);
  });

  test('a weight without an amount is refused and nothing is saved', () async {
    await expectLater(
      add(initialQuantity: 50, initialQuantityUnit: QuantityUnit.gram),
      throwsA(isA<ValidationException>()),
    );

    expect(repo.cashFlows, isEmpty);
    expect(repo.investments, isEmpty);
  });

  for (final bad in <double>[0, -1, double.nan, double.infinity]) {
    test('a weight of $bad is refused and nothing is saved', () async {
      await expectLater(
        add(
          initialAmount: 300000,
          initialQuantity: bad,
          initialQuantityUnit: QuantityUnit.gram,
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(repo.cashFlows, isEmpty);
      expect(repo.investments, isEmpty);
    });
  }

  test('a weight without a unit is refused', () async {
    await expectLater(
      add(initialAmount: 300000, initialQuantity: 50),
      throwsA(isA<ValidationException>()),
    );

    expect(repo.cashFlows, isEmpty);
  });
}

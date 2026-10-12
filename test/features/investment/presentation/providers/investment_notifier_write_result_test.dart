// A40 (#783) PR-2: the repository tells addInvestment whether the server
// confirmed the first write in time (false = only saved on this device,
// pending). The form shows "Saved on this device" on false, so addInvestment
// passes the answer on through onWriteResult instead of dropping it.
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

/// A repository whose atomic write answers [confirmed], or throws [failure].
class _Repository extends FakeInvestmentRepository {
  bool confirmed = true;
  Object? failure;

  @override
  Future<bool> createInvestmentWithFirstCashFlow(
    InvestmentEntity investment,
    CashFlowEntity? firstFlow,
  ) async {
    final error = failure;
    if (error != null) throw error;
    await super.createInvestmentWithFirstCashFlow(investment, firstFlow);
    return confirmed;
  }

  @override
  Future<void> createInvestment(InvestmentEntity investment) async {
    final error = failure;
    if (error != null) throw error;
    await super.createInvestment(investment);
  }
}

void main() {
  late _Repository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _Repository();
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

  Future<InvestmentEntity> add({
    double? initialAmount,
    void Function(bool confirmed)? onWriteResult,
  }) => container
      .read(investmentNotifierProvider.notifier)
      .addInvestment(
        name: 'HDFC FD',
        type: InvestmentType.fixedDeposit,
        initialAmount: initialAmount,
        onWriteResult: onWriteResult,
      );

  test('an unconfirmed atomic write reports false', () async {
    repo.confirmed = false;
    final results = <bool>[];

    await add(initialAmount: 100000, onWriteResult: results.add);

    expect(results, [false]);
  });

  test('a confirmed atomic write reports true', () async {
    final results = <bool>[];

    await add(initialAmount: 100000, onWriteResult: results.add);

    expect(results, [true]);
  });

  test('no amount reports true: the plain write has no signal', () async {
    repo.confirmed = false;
    final results = <bool>[];

    await add(onWriteResult: results.add);

    expect(results, [true]);
    expect(repo.investments, hasLength(1));
    expect(repo.cashFlows, isEmpty);
  });

  test('the report comes after the write and before add returns', () async {
    var recordsWhenReported = -1;
    var returned = false;

    final pending = add(
      initialAmount: 100000,
      onWriteResult: (_) {
        recordsWhenReported = repo.investments.length + repo.cashFlows.length;
        expect(returned, isFalse);
      },
    );
    await pending;
    returned = true;

    expect(recordsWhenReported, 2);
  });

  test('a callback that throws cannot fail a saved record', () async {
    final investment = await add(
      initialAmount: 100000,
      onWriteResult: (_) => throw StateError('the form went away'),
    );

    expect(repo.investments.single.id, investment.id);
    expect(repo.cashFlows, hasLength(1));
  });

  test('a failed write never reports', () async {
    repo.failure = StateError('permission denied');
    final results = <bool>[];

    await expectLater(
      add(initialAmount: 100000, onWriteResult: results.add),
      throwsStateError,
    );
    await expectLater(add(onWriteResult: results.add), throwsStateError);

    expect(results, isEmpty);
    expect(repo.investments, isEmpty);
  });

  test('without a callback nothing changes', () async {
    repo.confirmed = false;

    final investment = await add(initialAmount: 100000);

    expect(repo.investments.single.id, investment.id);
    expect(repo.cashFlows, hasLength(1));
  });
}

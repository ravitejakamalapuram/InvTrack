/// A28 / ARCH-05, UX-V01, ADOPT-11: the Overview stats providers must keep
/// the real loading and error states of their sources. Turning them into an
/// empty list made Overview show the new-user empty state (and offer sample
/// data) to existing users on cold start and on Firestore errors.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/multi_currency_providers.dart';

final _loadError = Exception('permission-denied');

final _statsProviders =
    <String, ProviderListenable<AsyncValue<InvestmentStats>>>{
      'multiCurrencyGlobalStatsProvider': multiCurrencyGlobalStatsProvider,
      'multiCurrencyOpenStatsProvider': multiCurrencyOpenStatsProvider,
      'multiCurrencyClosedStatsProvider': multiCurrencyClosedStatsProvider,
    };

final _openInvestment = InvestmentEntity(
  id: 'inv-1',
  name: 'FD',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final _closedInvestment = InvestmentEntity(
  id: 'inv-2',
  name: 'Bond',
  type: InvestmentType.bonds,
  status: InvestmentStatus.closed,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

ProviderContainer _container({
  required Stream<List<InvestmentEntity>> Function() investments,
  required Stream<List<CashFlowEntity>> Function() cashFlows,
}) {
  final container = ProviderContainer(
    overrides: [
      allInvestmentsProvider.overrideWith((ref) => investments()),
      allCashFlowsStreamProvider.overrideWith((ref) => cashFlows()),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  for (final entry in _statsProviders.entries) {
    group(entry.key, () {
      test('stays loading while investments are loading', () async {
        final investments = StreamController<List<InvestmentEntity>>();
        addTearDown(() => unawaited(investments.close()));
        final container = _container(
          investments: () => investments.stream,
          cashFlows: () => Stream.value(const []),
        );

        final sub = container.listen(entry.value, (_, _) {});
        await pumpEventQueue();

        expect(sub.read().isLoading, isTrue);
        expect(sub.read().hasValue, isFalse);
      });

      test('stays loading while cash flows are loading', () async {
        final cashFlows = StreamController<List<CashFlowEntity>>();
        addTearDown(() => unawaited(cashFlows.close()));
        final container = _container(
          investments: () => Stream.value([_openInvestment, _closedInvestment]),
          cashFlows: () => cashFlows.stream,
        );

        final sub = container.listen(entry.value, (_, _) {});
        await pumpEventQueue();

        expect(sub.read().isLoading, isTrue);
        expect(sub.read().hasValue, isFalse);
      });

      test('reports the error when cash flows fail to load', () async {
        final container = _container(
          investments: () => Stream.value([_openInvestment, _closedInvestment]),
          cashFlows: () => Stream.error(_loadError),
        );

        final sub = container.listen(entry.value, (_, _) {});
        await pumpEventQueue();

        expect(sub.read().hasError, isTrue);
        expect(sub.read().hasValue, isFalse);
        expect(sub.read().error.toString(), contains('permission-denied'));
      });

      test('reports the error when investments fail to load', () async {
        final container = _container(
          investments: () => Stream.error(_loadError),
          cashFlows: () => Stream.value(const []),
        );

        final sub = container.listen(entry.value, (_, _) {});
        await pumpEventQueue();

        expect(sub.read().hasError, isTrue);
        expect(sub.read().hasValue, isFalse);
      });

      test('resolves to empty stats when the account has no data', () async {
        final container = _container(
          investments: () => Stream.value(const []),
          cashFlows: () => Stream.value(const []),
        );

        final sub = container.listen(entry.value, (_, _) {});
        await pumpEventQueue();

        expect(sub.read().hasValue, isTrue);
        expect(sub.read().requireValue.hasData, isFalse);
        expect(sub.read().requireValue.totalInvested, 0);
      });
    });
  }
}

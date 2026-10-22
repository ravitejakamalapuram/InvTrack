import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_notification_service.dart';
import '../../data/repositories/mock_investment_repository.dart';
import '../../valuation/in_memory_valuation_repository.dart';

/// Merging deletes the sources and everything under them, so their dated
/// valuations must be rolled into the merged investment first.
void main() {
  late FakeInvestmentRepository repo;
  late InMemoryValuationRepository valuations;
  late ProviderContainer container;

  ProviderContainer buildContainer({bool snapshotsActive = true}) =>
      ProviderContainer(
        overrides: [
          investmentRepositoryProvider.overrideWithValue(repo),
          valuationRepositoryProvider.overrideWithValue(valuations),
          valuationSnapshotsActiveProvider.overrideWithValue(snapshotsActive),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          isAuthenticatedProvider.overrideWithValue(true),
          currencyCodeProvider.overrideWithValue('INR'),
        ],
      );

  setUp(() {
    repo = FakeInvestmentRepository();
    valuations = InMemoryValuationRepository();
    container = buildContainer();
  });

  tearDown(() {
    container.dispose();
    repo.reset();
  });

  Future<void> seed(String id) => repo.createInvestment(
    InvestmentEntity(
      id: id,
      name: id,
      type: InvestmentType.stocks,
      status: InvestmentStatus.open,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      currency: 'INR',
    ),
  );

  InvestmentValuationSnapshot snap(String id, String inv, double amount) =>
      InvestmentValuationSnapshot(
        id: id,
        investmentId: inv,
        amount: amount,
        currency: 'INR',
        effectiveDate: DateTime(2024, 6, 1),
        kind: ValuationKind.marketValue,
        provenance: ValuationProvenance.manual,
        createdAt: DateTime(2024, 6, 1),
        updatedAt: DateTime(2024, 6, 1),
      );

  test(
    'the merged investment carries the sum of the source valuations',
    () async {
      await seed('a');
      await seed('b');
      valuations.docs['s1'] = snap('s1', 'a', 1000);
      valuations.docs['s2'] = snap('s2', 'b', 500);
      container.listen(allInvestmentsProvider, (_, _) {});

      await container
          .read(investmentNotifierProvider.notifier)
          .mergeInvestments(['a', 'b'], 'Both');

      final merged = repo.investments.single;
      final carried = valuations.docs.values
          .where((s) => s.investmentId == merged.id)
          .toList();
      expect(carried.single.amount, 1500);
      expect(carried.single.currency, 'INR');
      expect(merged.currentValue, 1500);
      expect(merged.currentValueDate, DateTime(2024, 6, 1));
    },
  );

  test(
    'a failed valuation import leaves the sources and no merged copy',
    () async {
      await seed('a');
      await seed('b');
      valuations.docs['s1'] = snap('s1', 'a', 1000);
      valuations.docs['s2'] = snap('s2', 'b', 500);
      valuations.failNextWrite = StateError('boom');
      container.listen(allInvestmentsProvider, (_, _) {});

      await expectLater(
        container.read(investmentNotifierProvider.notifier).mergeInvestments([
          'a',
          'b',
        ], 'Both'),
        throwsStateError,
      );

      expect(repo.investments.map((i) => i.id), unorderedEquals(['a', 'b']));
    },
  );

  test(
    'with dated valuations off, snapshots are carried but not mirrored',
    () async {
      container.dispose();
      container = buildContainer(snapshotsActive: false);
      await seed('a');
      await seed('b');
      valuations.docs['s1'] = snap('s1', 'a', 1000);
      valuations.docs['s2'] = snap('s2', 'b', 500);
      container.listen(allInvestmentsProvider, (_, _) {});

      await container
          .read(investmentNotifierProvider.notifier)
          .mergeInvestments(['a', 'b'], 'Both');

      final merged = repo.investments.single;
      expect(
        valuations.docs.values.where((s) => s.investmentId == merged.id),
        hasLength(1),
      );
      expect(merged.currentValue, isNull);
      expect(merged.currentValueDate, isNull);
    },
  );
}

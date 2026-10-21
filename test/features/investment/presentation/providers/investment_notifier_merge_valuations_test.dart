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

  setUp(() {
    repo = FakeInvestmentRepository();
    valuations = InMemoryValuationRepository();
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(repo),
        valuationRepositoryProvider.overrideWithValue(valuations),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        isAuthenticatedProvider.overrideWithValue(true),
        currencyCodeProvider.overrideWithValue('INR'),
      ],
    );
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
}

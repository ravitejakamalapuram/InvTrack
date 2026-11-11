import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

import '../../../../mocks/fake_documents.dart';
import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_notification_service.dart';
import '../../data/repositories/mock_investment_repository.dart';
import '../../valuation/in_memory_valuation_repository.dart';

/// Merging copies each cash flow into the merged investment (#946): the
/// weight must come along, because the sources are deleted afterwards.
void main() {
  late FakeInvestmentRepository repo;
  late InMemoryValuationRepository valuations;
  late ProviderContainer container;

  ProviderContainer buildContainer({
    bool snapshotsActive = true,
  }) => ProviderContainer(
    overrides: [
      investmentRepositoryProvider.overrideWithValue(repo),
      valuationRepositoryProvider.overrideWithValue(valuations),
      documentRepositoryProvider.overrideWithValue(FakeDocumentRepository()),
      documentStorageServiceProvider.overrideWithValue(
        FakeDocumentStorageService(),
      ),
      valuationSnapshotsActiveProvider.overrideWithValue(snapshotsActive),
      analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
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
      type: InvestmentType.gold,
      status: InvestmentStatus.open,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      currency: 'INR',
    ),
  );

  test('merged cash flows keep their weight and unit', () async {
    await seed('a');
    await seed('b');
    await repo.addCashFlow(
      CashFlowEntity(
        id: 'c1',
        investmentId: 'a',
        date: DateTime(2024, 5, 1),
        type: CashFlowType.invest,
        amount: 1000,
        createdAt: DateTime(2024, 5, 1),
        currency: 'INR',
        quantity: 2,
        quantityUnit: QuantityUnit.tola,
      ),
    );
    await repo.addCashFlow(
      CashFlowEntity(
        id: 'c2',
        investmentId: 'b',
        date: DateTime(2024, 5, 2),
        type: CashFlowType.invest,
        amount: 500,
        createdAt: DateTime(2024, 5, 2),
        currency: 'INR',
      ),
    );
    container.listen(allInvestmentsProvider, (_, _) {});

    await container
        .read(investmentNotifierProvider.notifier)
        .mergeInvestments(['a', 'b'], 'Both');

    final merged = repo.investments.single;
    final flows = await repo.getCashFlowsByInvestment(merged.id);
    final weighed = flows.where((f) => f.quantity != null).single;
    expect(weighed.quantity, 2);
    expect(weighed.quantityUnit, QuantityUnit.tola);
    expect(flows.where((f) => f.quantity == null), hasLength(1));
  });
}

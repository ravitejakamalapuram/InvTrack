import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/metal.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

import '../../../../mocks/fake_documents.dart';
import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_notification_service.dart';
import '../../data/repositories/mock_investment_repository.dart';
import '../../valuation/in_memory_valuation_repository.dart';

/// The metal (#946) through the notifier: stored for precious metals, cleared
/// when the type changes away, carried by a merge and by a value update.
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
        documentRepositoryProvider.overrideWithValue(FakeDocumentRepository()),
        documentStorageServiceProvider.overrideWithValue(
          FakeDocumentStorageService(),
        ),
        valuationSnapshotsActiveProvider.overrideWithValue(true),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        isAuthenticatedProvider.overrideWithValue(true),
        currencyCodeProvider.overrideWithValue('INR'),
      ],
    );
    container.listen(allInvestmentsProvider, (_, _) {});
  });

  tearDown(() {
    container.dispose();
    repo.reset();
  });

  InvestmentNotifier notifier() =>
      container.read(investmentNotifierProvider.notifier);

  Future<InvestmentEntity> add(InvestmentType type, Metal? metal) =>
      notifier().addInvestment(
        name: 'Holding',
        type: type,
        currency: 'INR',
        metal: metal,
      );

  test('a new precious-metals investment keeps its metal', () async {
    await add(InvestmentType.gold, Metal.silver);
    expect(repo.investments.single.metal, Metal.silver);
  });

  test('another type drops a metal it was given', () async {
    await add(InvestmentType.stocks, Metal.silver);
    expect(repo.investments.single.metal, isNull);
  });

  test('an edit can change the metal', () async {
    final created = await add(InvestmentType.gold, Metal.gold);
    await notifier().updateInvestment(
      id: created.id,
      name: 'Holding',
      type: InvestmentType.gold,
      metal: Metal.silver,
    );
    expect(repo.investments.single.metal, Metal.silver);
  });

  test(
    'changing the type away from precious metals clears the metal',
    () async {
      final created = await add(InvestmentType.gold, Metal.silver);
      await notifier().updateInvestment(
        id: created.id,
        name: 'Holding',
        type: InvestmentType.other,
        metal: Metal.silver,
      );
      expect(repo.investments.single.metal, isNull);
    },
  );

  test('setting a current value keeps the metal', () async {
    final created = await add(InvestmentType.gold, Metal.silver);
    await notifier().setCurrentValue(
      id: created.id,
      value: 5000,
      date: DateTime(2026, 11, 1),
    );
    expect(repo.investments.single.metal, Metal.silver);
  });

  test('a merge keeps the metal of its sources', () async {
    final a = await add(InvestmentType.gold, Metal.silver);
    final b = await add(InvestmentType.gold, Metal.silver);
    await notifier().mergeInvestments([a.id, b.id], 'Both');
    expect(repo.investments.single.metal, Metal.silver);
  });

  test('a merge takes the metal of the first source, a record without one '
      'counting as gold', () async {
    final old = await add(InvestmentType.gold, null);
    final silver = await add(InvestmentType.gold, Metal.silver);
    await notifier().mergeInvestments([old.id, silver.id], 'Both');
    expect(repo.investments.single.metal, Metal.gold);
  });

  test('a merge into another type carries no metal', () async {
    final a = await add(InvestmentType.gold, Metal.silver);
    final b = await add(InvestmentType.gold, Metal.silver);
    await notifier().mergeInvestments(
      [a.id, b.id],
      'Both',
      type: InvestmentType.other,
    );
    expect(repo.investments.single.metal, isNull);
  });
}

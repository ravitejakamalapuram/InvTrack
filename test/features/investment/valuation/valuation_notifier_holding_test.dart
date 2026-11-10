// #946: setting a valuation by weight stores the holding with the snapshot and
// derives the amount (and the mirror) from weight x price; a later amount-only
// edit of the same day drops the weight claim.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_providers.dart';

import '../../../mocks/mock_analytics_service.dart';
import '../../../mocks/mock_notification_service.dart';
import '../data/repositories/mock_investment_repository.dart';
import 'in_memory_valuation_repository.dart';
import 'valuation_fixtures.dart';

void main() {
  late FakeInvestmentRepository investments;
  late InMemoryValuationRepository valuations;
  late ProviderContainer container;

  ValuationNotifier notifier() =>
      container.read(valuationNotifierProvider.notifier);

  setUp(() {
    investments = FakeInvestmentRepository();
    valuations = InMemoryValuationRepository();
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(investments),
        valuationRepositoryProvider.overrideWithValue(valuations),
        valuationSnapshotsActiveProvider.overrideWithValue(true),
        isAuthenticatedProvider.overrideWithValue(true),
        valuationAccountIdProvider.overrideWith((ref) => 'u1'),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        currencyCodeProvider.overrideWithValue('INR'),
      ],
    );
    investments.seed(investments: [testInvestment('gold')]);
  });

  tearDown(() {
    container.dispose();
    valuations.dispose();
    investments.reset();
  });

  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  const holding = UnitHolding(
    quantity: 10,
    unit: QuantityUnit.gram,
    unitPrice: 6000,
  );

  test(
    'a weighed valuation keeps its holding and derives the amount',
    () async {
      final saved = await notifier().setValuation(
        investmentId: 'gold',
        amount: 60000,
        date: day,
        holding: holding,
      );
      expect(saved.holding, holding);
      expect(saved.amount, 60000.00);
      expect(valuations.docs[saved.id]!.holding, holding);
      expect(valuations.mirrors['gold']!.value, 60000.00);
    },
  );

  test('an amount that disagrees with weight x price is refused', () async {
    await expectLater(
      notifier().setValuation(
        investmentId: 'gold',
        amount: 59999,
        date: day,
        holding: holding,
      ),
      throwsA(anything),
    );
    expect(valuations.docs, isEmpty);
  });

  test('the same day typed as a plain total drops the weight', () async {
    await notifier().setValuation(
      investmentId: 'gold',
      amount: 60000,
      date: day,
      holding: holding,
      replaceSameDay: true,
    );
    final again = await notifier().setValuation(
      investmentId: 'gold',
      amount: 61000,
      date: day,
      replaceSameDay: true,
    );
    expect(again.amount, 61000);
    expect(again.holding, isNull);
    expect(valuations.docs.values.where((s) => s.isLive), hasLength(1));
  });

  test(
    'a new price on a later day keeps the earlier snapshot intact',
    () async {
      final first = await notifier().setValuation(
        investmentId: 'gold',
        amount: 60000,
        date: DateTime(day.year, day.month, day.day - 5),
        holding: holding,
      );
      await notifier().setValuation(
        investmentId: 'gold',
        amount: 62000,
        date: day,
        holding: const UnitHolding(
          quantity: 10,
          unit: QuantityUnit.gram,
          unitPrice: 6200,
        ),
      );
      expect(valuations.docs[first.id]!.holding!.unitPrice, 6000);
      expect(valuations.docs[first.id]!.amount, 60000);
    },
  );

  test('editing a value by weight and price stores the holding', () async {
    final first = await notifier().setValuation(
      investmentId: 'gold',
      amount: 50000,
      date: day,
    );
    final edited = await notifier().editValuation(
      snapshotId: first.id,
      amount: 60000,
      holding: holding,
    );
    expect(edited.holding, holding);
    expect(valuations.docs[first.id]!.amount, 60000);
    expect(valuations.mirrors['gold']!.value, 60000);
  });

  test('editing a weighed value to a plain total drops the weight', () async {
    final first = await notifier().setValuation(
      investmentId: 'gold',
      amount: 60000,
      date: day,
      holding: holding,
    );
    final edited = await notifier().editValuation(
      snapshotId: first.id,
      amount: 61000,
    );
    expect(edited.holding, isNull);
    expect(valuations.docs[first.id]!.amount, 61000);
  });

  test(
    'editing with a weight that disagrees with the value is refused',
    () async {
      final first = await notifier().setValuation(
        investmentId: 'gold',
        amount: 50000,
        date: day,
      );
      await expectLater(
        notifier().editValuation(
          snapshotId: first.id,
          amount: 59999,
          holding: holding,
        ),
        throwsA(anything),
      );
      expect(valuations.docs[first.id]!.amount, 50000);
    },
  );
}

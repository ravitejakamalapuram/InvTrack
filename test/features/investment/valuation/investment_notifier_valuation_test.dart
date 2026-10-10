// #941: with dated valuations on, the old "current value" entry points write
// snapshots, and the edit form no longer re-sends a stale copy of the
// currentValue mirror. With them off nothing changes.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_providers.dart';

import '../../../mocks/mock_analytics_service.dart';
import '../../../mocks/mock_notification_service.dart';
import '../data/repositories/mock_investment_repository.dart';
import 'in_memory_valuation_repository.dart';
import 'valuation_fixtures.dart';

/// Records how the edit form's update reached the repository.
class _SpyRepository extends FakeInvestmentRepository {
  final List<bool> preserved = [];

  @override
  Future<void> updateInvestment(
    InvestmentEntity investment, {
    bool preserveCurrentValue = false,
  }) {
    preserved.add(preserveCurrentValue);
    return super.updateInvestment(
      investment,
      preserveCurrentValue: preserveCurrentValue,
    );
  }
}

void main() {
  late _SpyRepository investments;
  late InMemoryValuationRepository valuations;
  late ProviderContainer container;

  ProviderContainer build({required bool enabled}) => ProviderContainer(
    overrides: [
      investmentRepositoryProvider.overrideWithValue(investments),
      valuationRepositoryProvider.overrideWithValue(valuations),
      valuationSnapshotsActiveProvider.overrideWithValue(enabled),
      isAuthenticatedProvider.overrideWithValue(true),
      valuationAccountIdProvider.overrideWithValue('u1'),
      analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      currencyCodeProvider.overrideWithValue('INR'),
    ],
  );

  InvestmentNotifier notifier() =>
      container.read(investmentNotifierProvider.notifier);

  setUp(() {
    investments = _SpyRepository();
    valuations = InMemoryValuationRepository();
  });

  tearDown(() {
    container.dispose();
    valuations.dispose();
  });

  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);

  group('the flag on', () {
    setUp(() => container = build(enabled: true));

    test('setCurrentValue records a snapshot instead of the pair', () async {
      investments.seed(investments: [testInvestment('gold')]);

      await notifier().setCurrentValue(id: 'gold', value: 125000, date: day);

      expect(valuations.docs, hasLength(1));
      final saved = valuations.docs.values.single;
      expect(saved.amount, 125000);
      expect(saved.effectiveDate, day);
      expect(valuations.mirrors['gold']!.value, 125000);
      // The mirror is written with the snapshot, not by the legacy update.
      expect(investments.preserved, isEmpty);
      expect(investments.cashFlows, isEmpty);
    });

    test('setting a value twice on one day replaces it', () async {
      investments.seed(investments: [testInvestment('gold')]);
      await notifier().setCurrentValue(id: 'gold', value: 1, date: day);
      await notifier().setCurrentValue(id: 'gold', value: 2, date: day);

      expect(valuations.docs, hasLength(1));
      expect(valuations.docs.values.single.amount, 2);
    });

    test('setCurrentValue keeps its validation', () async {
      investments.seed(
        investments: [
          testInvestment('closed', status: InvestmentStatus.closed),
        ],
      );
      final tomorrow = day.add(const Duration(days: 1));
      for (final args in [
        ('closed', 1.0, day),
        ('closed', -1.0, day),
        ('closed', 1.0, tomorrow),
      ]) {
        await expectLater(
          notifier().setCurrentValue(
            id: args.$1,
            value: args.$2,
            date: args.$3,
          ),
          throwsA(isA<ValidationException>()),
        );
      }
      expect(valuations.docs, isEmpty);
    });

    test('clearCurrentValue clears the latest snapshot', () async {
      investments.seed(investments: [testInvestment('gold')]);
      await notifier().setCurrentValue(
        id: 'gold',
        value: 1,
        date: day.subtract(const Duration(days: 30)),
      );
      await notifier().setCurrentValue(id: 'gold', value: 2, date: day);

      await notifier().clearCurrentValue('gold');

      final liveAmounts = [
        for (final s in valuations.docs.values)
          if (s.isLive) s.amount,
      ];
      expect(liveAmounts, [1]);
      expect(valuations.mirrors['gold']!.value, 1);
    });

    test(
      'clearCurrentValue still clears a value only the pair holds',
      () async {
        investments.seed(
          investments: [
            testInvestment('gold', compatValue: 9, compatDate: day),
          ],
        );
        await notifier().clearCurrentValue('gold');

        final saved = (await investments.getInvestmentById('gold'))!;
        expect(saved.currentValue, isNull);
        expect(valuations.docs, isEmpty);
      },
    );

    test('the edit form leaves the pair as it is stored', () async {
      investments.seed(
        investments: [testInvestment('gold', compatValue: 9, compatDate: day)],
      );
      await notifier().updateInvestment(
        id: 'gold',
        name: 'Renamed',
        type: InvestmentType.gold,
      );
      expect(investments.preserved, [true]);
    });

    test('a currency change still clears the pair', () async {
      investments.seed(
        investments: [testInvestment('gold', compatValue: 9, compatDate: day)],
      );
      await notifier().updateInvestment(
        id: 'gold',
        name: 'gold',
        type: InvestmentType.gold,
        currency: 'USD',
      );
      expect(investments.preserved, [false]);
      final saved = (await investments.getInvestmentById('gold'))!;
      expect(saved.currentValue, isNull);
    });
  });

  group('the flag off', () {
    setUp(() => container = build(enabled: false));

    test('setCurrentValue writes the pair exactly as before', () async {
      investments.seed(investments: [testInvestment('gold')]);

      await notifier().setCurrentValue(id: 'gold', value: 125000, date: day);

      expect(valuations.docs, isEmpty);
      final saved = (await investments.getInvestmentById('gold'))!;
      expect(saved.currentValue, 125000);
      expect(saved.currentValueDate, day);
    });

    test('the edit form re-sends the pair, as before', () async {
      investments.seed(
        investments: [testInvestment('gold', compatValue: 9, compatDate: day)],
      );
      await notifier().updateInvestment(
        id: 'gold',
        name: 'Renamed',
        type: InvestmentType.gold,
      );
      expect(investments.preserved, [false]);
    });
  });
}

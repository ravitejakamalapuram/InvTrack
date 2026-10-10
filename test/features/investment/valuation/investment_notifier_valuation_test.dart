// #941: with dated valuations on, the old "current value" entry points write
// snapshots, and the edit form no longer re-sends a stale copy of the
// currentValue mirror. With them off nothing changes.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/calculations/valuation_snapshot_selector.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
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

  group('a currency round trip (flag on)', () {
    setUp(() => container = build(enabled: true));

    final snapshotDay = day.subtract(const Duration(days: 30));

    Future<void> changeCurrency(String currency) => notifier().updateInvestment(
      id: 'gold',
      name: 'gold',
      type: InvestmentType.gold,
      currency: currency,
    );

    ValuationCandidate? shown(InvestmentEntity investment) =>
        ValuationSnapshotSelector.select(
          investment: investment,
          snapshots: valuations.docs.values,
          asOf: day,
        );

    test('changing back shows the snapshot in that currency again', () async {
      investments.seed(
        investments: [
          testInvestment('gold', compatValue: 500000, compatDate: snapshotDay),
        ],
      );
      valuations.docs['s1'] = testSnapshot(
        's1',
        investmentId: 'gold',
        amount: 500000,
        date: snapshotDay,
        kind: ValuationKind.marketValue,
      );

      await changeCurrency('USD');
      final inUsd = (await investments.getInvestmentById('gold'))!;
      expect(inUsd.currentValue, isNull);
      expect(shown(inUsd), isNull);

      await changeCurrency('INR');
      final back = (await investments.getInvestmentById('gold'))!;
      expect(back.currency, 'INR');
      // The pair mirrors the snapshot that applies again.
      expect(back.currentValue, 500000);
      expect(back.currentValueDate, snapshotDay);
      final candidate = shown(back);
      expect(candidate?.snapshotId, 's1');
      expect(candidate?.amount, 500000);
      expect(candidate?.kind, ValuationKind.marketValue);
    });

    test('the pair mirrors the latest snapshot in the new currency', () async {
      investments.seed(
        investments: [
          testInvestment('gold', compatValue: 500000, compatDate: snapshotDay),
        ],
      );
      valuations.docs['inr'] = testSnapshot(
        'inr',
        investmentId: 'gold',
        amount: 500000,
        date: snapshotDay,
      );
      valuations.docs['usd-old'] = testSnapshot(
        'usd-old',
        investmentId: 'gold',
        amount: 5000,
        currency: 'USD',
        date: snapshotDay.subtract(const Duration(days: 60)),
      );
      valuations.docs['usd-new'] = testSnapshot(
        'usd-new',
        investmentId: 'gold',
        amount: 6000,
        currency: 'USD',
        date: snapshotDay.subtract(const Duration(days: 10)),
      );

      await changeCurrency('USD');

      final saved = (await investments.getInvestmentById('gold'))!;
      expect(saved.currentValue, 6000);
      expect(
        saved.currentValueDate,
        snapshotDay.subtract(const Duration(days: 10)),
      );
      expect(shown(saved)?.snapshotId, 'usd-new');
      // Snapshots of the old currency are kept as history.
      expect(valuations.docs.keys, containsAll(['inr', 'usd-old', 'usd-new']));
    });

    test('a currency change reads only that investment\'s snapshots', () async {
      investments.seed(
        investments: [
          testInvestment('gold', compatValue: 9, compatDate: snapshotDay),
        ],
      );
      valuations.docs['usd'] = testSnapshot(
        'usd',
        investmentId: 'gold',
        amount: 6000,
        currency: 'USD',
        date: snapshotDay,
      );
      valuations.docs['other'] = testSnapshot(
        'other',
        investmentId: 'silver',
        amount: 777,
        currency: 'USD',
        date: snapshotDay,
      );

      await changeCurrency('USD');

      expect(valuations.getAllCount, 0);
      expect(valuations.readByInvestment, ['gold']);
      expect((await investments.getInvestmentById('gold'))!.currentValue, 6000);
    });

    test('another investment\'s snapshots are not mirrored', () async {
      investments.seed(
        investments: [
          testInvestment('gold', compatValue: 9, compatDate: snapshotDay),
        ],
      );
      valuations.docs['other'] = testSnapshot(
        'other',
        investmentId: 'silver',
        amount: 777,
        currency: 'USD',
        date: snapshotDay,
      );

      await changeCurrency('USD');

      expect(
        (await investments.getInvestmentById('gold'))!.currentValue,
        isNull,
      );
    });
  });

  group('the flag off', () {
    setUp(() => container = build(enabled: false));

    test('a currency change clears the pair and reads no snapshots', () async {
      investments.seed(
        investments: [testInvestment('gold', compatValue: 9, compatDate: day)],
      );
      valuations.docs['usd'] = testSnapshot(
        'usd',
        investmentId: 'gold',
        amount: 5,
        currency: 'USD',
        date: day,
      );
      await notifier().updateInvestment(
        id: 'gold',
        name: 'gold',
        type: InvestmentType.gold,
        currency: 'USD',
      );
      expect(
        (await investments.getInvestmentById('gold'))!.currentValue,
        isNull,
      );
    });

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

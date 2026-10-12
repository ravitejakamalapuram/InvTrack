// #996: an amount has at most 15 digits (invtrack_rules 19.1). The limit holds
// for every write of a cash flow or a current value, not only the first
// payment of a new investment: addCashFlow, updateCashFlow, setCurrentValue
// (dated valuations off and on) and the valuation notifier. A refused amount
// writes nothing and logs nothing.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_providers.dart';

import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_notification_service.dart';
import '../../data/repositories/mock_investment_repository.dart';
import '../../valuation/in_memory_valuation_repository.dart';
import '../../valuation/valuation_fixtures.dart';

/// 16 and 21 digits, and the first amount with 16 digits.
const _tooLarge = <double>[1e15, 1e20];

/// The largest amount with 15 digits.
const _largest = 999999999999999.0;

/// 15 digits as typed; JPY has no minor units, so it rounds to 1e15.
const _roundsUp = 999999999999999.5;

void main() {
  late FakeInvestmentRepository repo;
  late InMemoryValuationRepository valuations;
  late FakeAnalyticsService analytics;

  ProviderContainer containerFor({required bool datedValuations}) {
    final container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(repo),
        valuationRepositoryProvider.overrideWithValue(valuations),
        valuationSnapshotsActiveProvider.overrideWithValue(datedValuations),
        isAuthenticatedProvider.overrideWithValue(true),
        valuationAccountIdProvider.overrideWith((ref) => 'u1'),
        analyticsServiceProvider.overrideWithValue(analytics),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        currencyCodeProvider.overrideWithValue('INR'),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    repo = FakeInvestmentRepository();
    valuations = InMemoryValuationRepository();
    analytics = FakeAnalyticsService();
    repo.seed(
      investments: [
        testInvestment('inr', type: InvestmentType.p2pLending),
        testInvestment('jpy', type: InvestmentType.p2pLending, currency: 'JPY'),
      ],
    );
  });

  tearDown(() {
    valuations.dispose();
    repo.reset();
  });

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  group('addCashFlow', () {
    Future<void> add(double amount, {String id = 'inr', String? currency}) =>
        containerFor(datedValuations: false)
            .read(investmentNotifierProvider.notifier)
            .addCashFlow(
              investmentId: id,
              type: CashFlowType.invest,
              amount: amount,
              date: DateTime(2026, 1, 5),
              currency: currency,
            );

    for (final bad in _tooLarge) {
      test('$bad is refused, and nothing is written or logged', () async {
        await expectLater(add(bad), throwsA(isA<ValidationException>()));

        expect(repo.cashFlows, isEmpty);
        expect(analytics.loggedEvents, isEmpty);
      });
    }

    test('an amount that rounds up to 16 digits is refused', () async {
      await expectLater(
        add(_roundsUp, id: 'jpy', currency: 'JPY'),
        throwsA(isA<ValidationException>()),
      );

      expect(repo.cashFlows, isEmpty);
    });

    test('the largest 15-digit amount is accepted', () async {
      await add(_largest);

      expect(repo.cashFlows.single.amount, _largest);
    });
  });

  group('updateCashFlow', () {
    CashFlowEntity existing() => CashFlowEntity(
      id: 'flow',
      investmentId: 'inr',
      type: CashFlowType.invest,
      amount: 5000,
      date: DateTime(2026, 1, 5),
      createdAt: DateTime(2026, 1, 5),
      currency: 'INR',
    );

    Future<void> update(double amount, {String? currency}) =>
        containerFor(datedValuations: false)
            .read(investmentNotifierProvider.notifier)
            .updateCashFlow(
              id: 'flow',
              investmentId: 'inr',
              type: CashFlowType.invest,
              amount: amount,
              date: DateTime(2026, 1, 5),
              createdAt: DateTime(2026, 1, 5),
              currency: currency ?? 'INR',
            );

    setUp(() => repo.seed(cashFlows: [existing()]));

    for (final bad in _tooLarge) {
      test('$bad is refused, and the saved flow is untouched', () async {
        await expectLater(update(bad), throwsA(isA<ValidationException>()));

        expect(repo.cashFlows.single.amount, 5000);
        expect(analytics.loggedEvents, isEmpty);
      });
    }

    test('an amount that rounds up to 16 digits is refused', () async {
      await expectLater(
        update(_roundsUp, currency: 'JPY'),
        throwsA(isA<ValidationException>()),
      );

      expect(repo.cashFlows.single.amount, 5000);
    });

    test('the largest 15-digit amount is accepted', () async {
      await update(_largest);

      expect(repo.cashFlows.single.amount, _largest);
    });
  });

  for (final datedValuations in [false, true]) {
    group('setCurrentValue (dated valuations: $datedValuations)', () {
      Future<void> set(double value, {String id = 'inr'}) =>
          containerFor(datedValuations: datedValuations)
              .read(investmentNotifierProvider.notifier)
              .setCurrentValue(id: id, value: value, date: today);

      Future<void> expectNothingSaved(String id) async {
        expect((await repo.getInvestmentById(id))!.currentValue, isNull);
        expect(valuations.docs, isEmpty);
        expect(valuations.mirrors, isEmpty);
        expect(analytics.loggedEvents, isEmpty);
      }

      for (final bad in _tooLarge) {
        test('$bad is refused, and nothing is written or logged', () async {
          await expectLater(set(bad), throwsA(isA<ValidationException>()));

          await expectNothingSaved('inr');
        });
      }

      test('an amount that rounds up to 16 digits is refused', () async {
        await expectLater(
          set(_roundsUp, id: 'jpy'),
          throwsA(isA<ValidationException>()),
        );

        await expectNothingSaved('jpy');
      });

      test('the largest 15-digit amount is accepted', () async {
        await set(_largest);

        // With dated valuations the value lives in the mirror the valuation
        // write updates; without them it is the investment's own field.
        final saved = datedValuations
            ? valuations.mirrors['inr']!.value
            : (await repo.getInvestmentById('inr'))!.currentValue;
        expect(saved, _largest);
      });
    });
  }

  group('ValuationNotifier', () {
    ValuationNotifier notifier() => containerFor(
      datedValuations: true,
    ).read(valuationNotifierProvider.notifier);

    for (final bad in _tooLarge) {
      test('setValuation refuses $bad and writes nothing', () async {
        await expectLater(
          notifier().setValuation(
            investmentId: 'inr',
            amount: bad,
            date: today,
          ),
          throwsA(isA<ValidationException>()),
        );

        expect(valuations.docs, isEmpty);
      });
    }

    test(
      'setValuation refuses an amount that rounds up to 16 digits',
      () async {
        await expectLater(
          notifier().setValuation(
            investmentId: 'jpy',
            amount: _roundsUp,
            date: today,
          ),
          throwsA(isA<ValidationException>()),
        );

        expect(valuations.docs, isEmpty);
      },
    );

    test('setValuation accepts the largest 15-digit amount', () async {
      final saved = await notifier().setValuation(
        investmentId: 'inr',
        amount: _largest,
        date: today,
      );

      expect(saved.amount, _largest);
    });

    for (final bad in _tooLarge) {
      test('editValuation refuses $bad and keeps the saved amount', () async {
        final n = notifier();
        final saved = await n.setValuation(
          investmentId: 'inr',
          amount: 1000,
          date: today,
        );

        await expectLater(
          n.editValuation(snapshotId: saved.id, amount: bad),
          throwsA(isA<ValidationException>()),
        );

        expect(valuations.docs[saved.id]!.amount, 1000);
      });
    }

    test(
      'editValuation refuses an amount that rounds up to 16 digits',
      () async {
        final n = notifier();
        final saved = await n.setValuation(
          investmentId: 'jpy',
          amount: 1000,
          date: today,
        );

        await expectLater(
          n.editValuation(snapshotId: saved.id, amount: _roundsUp),
          throwsA(isA<ValidationException>()),
        );

        expect(valuations.docs[saved.id]!.amount, 1000);
      },
    );

    test('editValuation accepts the largest 15-digit amount', () async {
      final n = notifier();
      final saved = await n.setValuation(
        investmentId: 'inr',
        amount: 1000,
        date: today,
      );

      final edited = await n.editValuation(
        snapshotId: saved.id,
        amount: _largest,
      );

      expect(edited.amount, _largest);
    });
  });
}

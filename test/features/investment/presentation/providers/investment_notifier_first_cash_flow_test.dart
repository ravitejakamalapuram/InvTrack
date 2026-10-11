// A40 (#783) PR A1: addInvestment can save the investment together with its
// first cash flow (an INVEST of the amount the user typed, dated the start
// date). The write is atomic and retry-safe through ids the caller owns; only
// that write can fail the save; the first flow goes through the same funnel as
// every other cash flow (one cashflow_added, the same goal checks).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

import '../../../../helpers/analytics_privacy.dart';
import '../../../../mocks/crashlytics_recorder.dart';
import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_currency_conversion_service.dart';
import '../../../../mocks/mock_notification_service.dart';
import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../data/repositories/mock_investment_repository.dart';

/// Remembers which write the notifier chose, and can fail the atomic one.
class _SpyRepository extends FakeInvestmentRepository {
  final plainCreates = <String>[];
  final atomicCreates = <({String investmentId, String? flowId})>[];

  /// Thrown (once) by the next atomic create, before anything is stored.
  Object? failNextAtomic;

  @override
  Future<void> createInvestment(InvestmentEntity investment) {
    plainCreates.add(investment.id);
    return super.createInvestment(investment);
  }

  @override
  Future<bool> createInvestmentWithFirstCashFlow(
    InvestmentEntity investment,
    CashFlowEntity? firstFlow,
  ) {
    atomicCreates.add((investmentId: investment.id, flowId: firstFlow?.id));
    final error = failNextAtomic;
    if (error != null) {
      failNextAtomic = null;
      return Future.error(error);
    }
    return super.createInvestmentWithFirstCashFlow(investment, firstFlow);
  }
}

class _RecordingNotifications extends FakeNotificationService {
  int activationCancelled = 0;

  @override
  Future<void> cancelActivationSequence() async => activationCancelled++;
}

/// A notification service whose platform calls never return.
class _HangingNotifications extends _RecordingNotifications {
  @override
  Future<void> scheduleIncomeReminder({
    required String investmentId,
    required String investmentName,
    required int monthsBetweenPayments,
    DateTime? lastIncomeDate,
  }) => Completer<void>().future;

  @override
  Future<void> scheduleMaturityReminders({
    required String investmentId,
    required String investmentName,
    required DateTime maturityDate,
    String? investmentType,
    double? investedAmount,
    double? currentValue,
    String currency = 'INR',
  }) => Completer<void>().future;
}

/// Activation nudges whose cancel (a platform call) never returns.
class _HangingActivationCancel extends _RecordingNotifications {
  @override
  Future<void> cancelActivationSequence() => Completer<void>().future;
}

/// Goals whose read never delivers, like a Firestore read that never answers.
class _HangingGoalRepository extends FakeGoalRepository {
  /// Never emits and never closes, so `first` waits for ever.
  @override
  Stream<List<GoalEntity>> watchActiveGoals() =>
      StreamController<List<GoalEntity>>().stream;
}

/// Analytics that fails with a message holding what must never be logged: a
/// name, an amount and an id.
class _LeakyAnalytics extends FakeAnalyticsService {
  static const leak = 'Ravi-Kumar-P2P 123456.78 inv-secret-42';

  @override
  Future<void> logInvestmentCreated({
    required String investmentType,
    bool hasNotes = false,
    bool hasAmount = false,
  }) => throw StateError(leak);

  @override
  Future<void> logCashFlowAdded({
    required String flowType,
    required String amountRange,
  }) => Future.error(StateError(leak));
}

class _FailingActivationCancel extends _RecordingNotifications {
  @override
  Future<void> cancelActivationSequence() =>
      Future.error(StateError('platform channel failed'));
}

/// Analytics that fails: one call throws at once, the other fails later.
class _FailingAnalytics extends FakeAnalyticsService {
  @override
  Future<void> logInvestmentCreated({
    required String investmentType,
    bool hasNotes = false,
    bool hasAmount = false,
  }) => throw StateError('analytics is down');

  @override
  Future<void> logCashFlowAdded({
    required String flowType,
    required String amountRange,
  }) => Future.error(StateError('analytics is down'));
}

/// The server of a currency conversion that is offline with no cached rate.
class _NoRateService extends MockCurrencyConversionService {
  @override
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async {
    if (from == to) return amount;
    throw Exception('offline');
  }

  @override
  Future<Map<String, double>> batchConvertHistorical({
    required Map<String, ConversionRequest> requests,
    required String to,
  }) async => throw Exception('offline');

  @override
  Future<double?> getLastKnownRate({
    required String from,
    required String to,
  }) async => from == to ? 1.0 : null;
}

void main() {
  late _SpyRepository repo;
  late FakeAnalyticsService analytics;
  late _RecordingNotifications notifications;
  late FakeGoalRepository goals;

  setUp(() {
    repo = _SpyRepository();
    analytics = FakeAnalyticsService();
    notifications = _RecordingNotifications();
    goals = FakeGoalRepository();
  });

  ProviderContainer containerFor({
    String base = 'INR',
    CurrencyConversionService? conversion,
    FakeAnalyticsService? analyticsService,
    FakeNotificationService? notificationService,
    FakeGoalRepository? goalRepository,
  }) {
    final container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(repo),
        goalRepositoryProvider.overrideWithValue(goalRepository ?? goals),
        analyticsServiceProvider.overrideWithValue(
          analyticsService ?? analytics,
        ),
        notificationServiceProvider.overrideWithValue(
          notificationService ?? notifications,
        ),
        currencyConversionServiceProvider.overrideWithValue(conversion),
        isAuthenticatedProvider.overrideWithValue(true),
        currencyCodeProvider.overrideWithValue(base),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  late ProviderContainer container;

  setUp(() {
    container = containerFor(conversion: MockCurrencyConversionService());
  });

  Future<InvestmentEntity> add({
    double? initialAmount,
    String? currency,
    DateTime? startDate,
    String? id,
    String name = 'HDFC FD',
    String? notes,
    IncomeFrequency? incomeFrequency,
    DateTime? maturityDate,
    ProviderContainer? on,
  }) => (on ?? container)
      .read(investmentNotifierProvider.notifier)
      .addInvestment(
        name: name,
        type: InvestmentType.fixedDeposit,
        notes: notes,
        currency: currency,
        startDate: startDate,
        initialAmount: initialAmount,
        id: id,
        incomeFrequency: incomeFrequency,
        maturityDate: maturityDate,
      );

  Iterable<({String name, Map<String, Object>? parameters})> logged(
    String name,
  ) => analytics.loggedEvents.where((e) => e.name == name);

  group('the amount', () {
    test('1234.567 in an INR account is stored as 1234.57', () async {
      await add(initialAmount: 1234.567, startDate: DateTime(2026, 10, 11));

      expect(repo.cashFlows.single.amount, 1234.57);
    });

    test('is rounded to the minor unit of the investment currency', () async {
      await add(initialAmount: 1234.567, currency: 'JPY');
      await add(initialAmount: 1.2346, currency: 'KWD');

      expect(repo.cashFlows.map((f) => f.amount), [1235.0, 1.235]);
    });

    for (final bad in <double>[0, -1, double.nan, double.infinity, 0.004]) {
      test('$bad is refused, and nothing is written or logged', () async {
        await expectLater(
          add(initialAmount: bad),
          throwsA(isA<ValidationException>()),
        );
        await pumpEventQueue();

        expect(repo.investments, isEmpty);
        expect(repo.cashFlows, isEmpty);
        expect(repo.plainCreates, isEmpty);
        expect(repo.atomicCreates, isEmpty);
        expect(analytics.loggedEvents, isEmpty);
        expect(notifications.activationCancelled, 0);
      });
    }

    test('a blank currency is refused, never defaulted', () async {
      await expectLater(
        add(initialAmount: 500, currency: ' '),
        throwsA(isA<ValidationException>()),
      );

      expect(repo.investments, isEmpty);
      expect(repo.cashFlows, isEmpty);
    });

    test('no amount writes the investment only, exactly as before', () async {
      final created = await add();

      expect(repo.plainCreates, [created.id]);
      expect(repo.atomicCreates, isEmpty);
      expect(repo.investments.single.id, created.id);
      expect(repo.cashFlows, isEmpty);
    });

    test('with an amount it makes one atomic write, not two', () async {
      final created = await add(initialAmount: 100000);

      expect(repo.plainCreates, isEmpty);
      expect(repo.atomicCreates.single.investmentId, created.id);
      expect(repo.cashFlows.single.investmentId, created.id);
    });
  });

  group('the first flow', () {
    test('is an INVEST dated the start date, date-only', () async {
      final created = await add(
        initialAmount: 100000,
        startDate: DateTime(2026, 10, 11, 23, 30),
      );

      final flow = repo.cashFlows.single;
      expect(flow.type, CashFlowType.invest);
      expect(flow.date, DateTime(2026, 10, 11));
      expect(created.startDate, DateTime(2026, 10, 11));
      expect(repo.investments.single.startDate, DateTime(2026, 10, 11));
    });

    // Local values whose UTC date differs from the local date in some zones
    // (23:30 in Los Angeles is already the next UTC day; 01:00 in Kolkata is
    // still the previous one). The day kept must be the local calendar day. A
    // test cannot change the process zone, so under a UTC runner the two dates
    // agree; run with TZ=America/Los_Angeles to exercise the difference.
    for (final (:local, :day) in [
      (local: DateTime(2026, 10, 11, 23, 30), day: DateTime(2026, 10, 11)),
      (local: DateTime(2026, 10, 12, 1, 0), day: DateTime(2026, 10, 12)),
    ]) {
      test('a start date of $local is the local day $day on both records, '
          'whatever its UTC date', () async {
        final created = await add(initialAmount: 100000, startDate: local);

        expect(repo.cashFlows.single.date, day);
        expect(created.startDate, day);
        expect(repo.investments.single.startDate, day);
      });
    }

    test('with no start date it is dated today on both records', () async {
      final before = DateTime.now();
      await add(initialAmount: 100000);
      final after = DateTime.now();

      final today = {
        DateTime(before.year, before.month, before.day),
        DateTime(after.year, after.month, after.day),
      };
      expect(today, contains(repo.cashFlows.single.date));
      expect(repo.investments.single.startDate, repo.cashFlows.single.date);
    });

    test('keeps the currency it was given, on both records', () async {
      await add(initialAmount: 100, currency: 'EUR');

      expect(repo.investments.single.currency, 'EUR');
      expect(repo.cashFlows.single.currency, 'EUR');
    });

    test('takes the base currency when none was given, never USD', () async {
      final gbp = containerFor(
        base: 'GBP',
        conversion: MockCurrencyConversionService(),
      );
      await add(initialAmount: 100, on: gbp);

      expect(repo.investments.single.currency, 'GBP');
      expect(repo.cashFlows.single.currency, 'GBP');
      expect([
        ...repo.investments.map((i) => i.currency),
        ...repo.cashFlows.map((f) => f.currency),
      ], isNot(contains('USD')));
    });
  });

  group('ids', () {
    test('given ids are used on both records', () async {
      final created = await add(initialAmount: 100, id: 'inv-given');

      expect(created.id, 'inv-given');
      expect(repo.investments.single.id, 'inv-given');
      expect(repo.cashFlows.single.id, 'inv-given-first-flow');
      expect(repo.cashFlows.single.investmentId, 'inv-given');
    });

    test('a second call with the same ids creates no duplicate', () async {
      await add(initialAmount: 100, id: 'inv-given');
      await add(initialAmount: 100, id: 'inv-given');

      expect(repo.investments, hasLength(1));
      expect(repo.cashFlows, hasLength(1));
    });

    test('a retry with the same ids after a failed write leaves one of '
        'each', () async {
      repo.failNextAtomic = StateError('network error');
      await expectLater(
        add(initialAmount: 100, id: 'inv-given'),
        throwsA(isA<StateError>()),
      );
      expect(repo.investments, isEmpty);
      expect(repo.cashFlows, isEmpty);

      await add(initialAmount: 100, id: 'inv-given');

      expect(repo.atomicCreates.map((c) => c.investmentId), [
        'inv-given',
        'inv-given',
      ]);
      expect(repo.investments, hasLength(1));
      expect(repo.cashFlows, hasLength(1));
    });

    test('a retry with only the investment id leaves one investment and one '
        'flow of 100000.00', () async {
      await add(initialAmount: 100000, id: 'inv-1');
      await add(initialAmount: 100000, id: 'inv-1');

      expect(repo.investments, hasLength(1));
      expect(repo.cashFlows, hasLength(1));
      expect(repo.cashFlows.single.amount, 100000.00);
      expect(repo.cashFlows.single.investmentId, 'inv-1');
    });

    test('a retry with only the investment id after a failed write leaves '
        'one of each', () async {
      repo.failNextAtomic = StateError('network error');
      await expectLater(
        add(initialAmount: 100000, id: 'inv-1'),
        throwsA(isA<StateError>()),
      );
      expect(repo.cashFlows, isEmpty);

      await add(initialAmount: 100000, id: 'inv-1');
      await add(initialAmount: 100000, id: 'inv-1');

      expect(repo.investments, hasLength(1));
      expect(repo.cashFlows, hasLength(1));
      expect(repo.cashFlows.single.amount, 100000.00);
    });

    test('the first flow id derived from the investment id is stable: the '
        'same on every call, so it survives a restart', () async {
      await add(initialAmount: 100, id: 'inv-1');

      expect(repo.cashFlows.single.id, 'inv-1-first-flow');
    });

    test('two different investment ids and no flow ids make two distinct '
        'flows', () async {
      await add(initialAmount: 100, id: 'inv-a');
      await add(initialAmount: 200, id: 'inv-b');

      expect(
        repo.investments.map((i) => i.id),
        unorderedEquals(['inv-a', 'inv-b']),
      );
      expect(repo.cashFlows, hasLength(2));
      expect(repo.cashFlows.map((f) => f.id).toSet(), hasLength(2));
      final byInvestment = {for (final f in repo.cashFlows) f.investmentId: f};
      expect(byInvestment['inv-a']!.amount, 100);
      expect(byInvestment['inv-b']!.amount, 200);
    });

    test(
      'the flow id is always derived from the investment id, minted or given',
      () async {
        final created = await add(initialAmount: 100);

        expect(repo.cashFlows.single.id, '${created.id}-first-flow');
      },
    );

    test('an id that already ends in the suffix stays distinct and a retry '
        'of it adds nothing', () async {
      await add(initialAmount: 100, id: 'x');
      await add(initialAmount: 200, id: 'x-first-flow');
      await add(initialAmount: 200, id: 'x-first-flow');

      expect(repo.investments.map((i) => i.id), ['x', 'x-first-flow']);
      expect(repo.cashFlows.map((f) => f.id), [
        'x-first-flow',
        'x-first-flow-first-flow',
      ]);
    });

    test('without ids each call mints its own', () async {
      await add(initialAmount: 100);
      await add(initialAmount: 100);

      expect(repo.investments.map((i) => i.id).toSet(), hasLength(2));
      expect(repo.cashFlows.map((f) => f.id).toSet(), hasLength(2));
      expect(repo.cashFlows.every((f) => f.id.isNotEmpty), isTrue);
    });
  });

  group('only the write can fail the save', () {
    for (final withAmount in [false, true]) {
      final amount = withAmount ? 100000.0 : null;
      final path = withAmount ? 'with an amount' : 'without an amount';

      test('analytics that fails does not fail the save, $path', () async {
        final failing = containerFor(
          conversion: MockCurrencyConversionService(),
          analyticsService: _FailingAnalytics(),
        );

        final created = await add(initialAmount: amount, on: failing);
        await pumpEventQueue();

        expect(repo.investments.single.id, created.id);
        expect(repo.cashFlows, hasLength(withAmount ? 1 : 0));
        expect(failing.read(investmentNotifierProvider).hasError, isFalse);
      });

      test(
        'a failing activation cancel does not fail the save, $path',
        () async {
          final failing = containerFor(
            conversion: MockCurrencyConversionService(),
            notificationService: _FailingActivationCancel(),
          );

          final created = await add(initialAmount: amount, on: failing);
          await pumpEventQueue();

          expect(repo.investments.single.id, created.id);
          expect(failing.read(investmentNotifierProvider).hasError, isFalse);
        },
      );

      test(
        'reminders that never complete do not block the call, $path',
        () async {
          final hanging = containerFor(
            conversion: MockCurrencyConversionService(),
            notificationService: _HangingNotifications(),
          );

          await expectLater(
            add(
              initialAmount: amount,
              incomeFrequency: IncomeFrequency.quarterly,
              maturityDate: DateTime(2027, 10, 11),
              on: hanging,
            ),
            completes,
          ).timeout(const Duration(seconds: 2));

          expect(repo.investments, hasLength(1));
        },
      );

      test('an activation cancel that never completes does not block the call, '
          '$path', () async {
        final hanging = containerFor(
          conversion: MockCurrencyConversionService(),
          notificationService: _HangingActivationCancel(),
        );

        await expectLater(
          add(initialAmount: amount, on: hanging),
          completes,
        ).timeout(const Duration(seconds: 2));

        expect(repo.investments, hasLength(1));
      });

      test('a failing write is the failure, and nothing after it runs, '
          '$path', () async {
        // The plain path fails in createInvestment; the atomic one in its own.
        final failing = _FailingWriteRepository();
        final failingContainer = ProviderContainer(
          overrides: [
            investmentRepositoryProvider.overrideWithValue(failing),
            goalRepositoryProvider.overrideWithValue(goals),
            analyticsServiceProvider.overrideWithValue(analytics),
            notificationServiceProvider.overrideWithValue(notifications),
            currencyCodeProvider.overrideWithValue('INR'),
          ],
        );
        addTearDown(failingContainer.dispose);

        await expectLater(
          add(initialAmount: amount, on: failingContainer),
          throwsA(isA<StateError>()),
        );
        await pumpEventQueue();

        expect(
          failingContainer.read(investmentNotifierProvider).hasError,
          isTrue,
        );
        expect(analytics.loggedEvents, isEmpty);
        expect(notifications.activationCancelled, 0);
      });
    }
  });

  group('what follows the save never delays it', () {
    test('a goal check that never completes does not block the call', () async {
      final hanging = containerFor(
        conversion: MockCurrencyConversionService(),
        goalRepository: _HangingGoalRepository(),
      );

      await expectLater(
        add(initialAmount: 100000, on: hanging),
        completes,
      ).timeout(const Duration(seconds: 2));

      expect(repo.investments, hasLength(1));
      expect(repo.cashFlows, hasLength(1));
    });
  });

  group('the log of a failed step after the save', () {
    test('is the constant message and the error type only: no name, amount, '
        'id or error text', () async {
      final reports = recordCrashReports();
      final leaky = containerFor(
        conversion: MockCurrencyConversionService(),
        analyticsService: _LeakyAnalytics(),
      );

      await add(
        name: 'Ravi-Kumar-P2P',
        initialAmount: 123456.78,
        id: 'inv-secret-42',
        on: leaky,
      );
      await pumpEventQueue();

      // investment_created and cashflow_added each failed once.
      expect(reports, hasLength(2));
      for (final report in reports) {
        expect(report.exception, 'A step after saving failed');
        expect(
          report.reason,
          'A step after saving failed | Metadata: errorType=StateError',
        );
        expect(report.fatal, isFalse);
      }
      final text = reports.map((r) => '${r.exception} ${r.reason}').join(' ');
      for (final secret in [
        'Ravi',
        'Kumar',
        '123456',
        '12345',
        'inv-secret',
        'secret',
        _LeakyAnalytics.leak,
      ]) {
        expect(text, isNot(contains(secret)));
      }
      // The save itself went through.
      expect(repo.investments.single.id, 'inv-secret-42');
    });
  });

  group('analytics', () {
    test('investment_created says has_amount 1 with an amount', () async {
      await add(initialAmount: 100000);
      await pumpEventQueue();

      expect(logged('investment_created').single.parameters, {
        'investment_type': 'fixedDeposit',
        'has_notes': 0,
        'has_amount': 1,
      });
    });

    test('investment_created says has_amount 0 without one', () async {
      await add();
      await pumpEventQueue();

      expect(logged('investment_created').single.parameters!['has_amount'], 0);
      expect(logged('cashflow_added'), isEmpty);
    });

    test('the first flow fires exactly one cashflow_added, bucketed in the '
        'base currency', () async {
      await add(initialAmount: 100000);
      await pumpEventQueue();

      expect(logged('cashflow_added').map((e) => e.parameters), [
        {'flow_type': 'invest', 'amount_range': '1L_5L'},
      ]);
      expect(analytics.loggedEvents.map((e) => e.name), [
        'investment_created',
        'cashflow_added',
      ]);
    });

    test('a USD flow under an INR base is bucketed after conversion', () async {
      await add(initialAmount: 1000, currency: 'USD');
      await pumpEventQueue();

      // USD 1,000 is INR 83,000 at the mock rate.
      expect(
        logged('cashflow_added').single.parameters!['amount_range'],
        '50k_1L',
      );
    });

    test('a USD flow under an INR base with no rate is unknown, never the '
        'native bucket', () async {
      for (final conversion in <CurrencyConversionService?>[
        null,
        _NoRateService(),
      ]) {
        analytics.reset();
        final offline = containerFor(conversion: conversion);

        await add(initialAmount: 1000, currency: 'USD', on: offline);
        await pumpEventQueue();

        expect(logged('cashflow_added').single.parameters, {
          'flow_type': 'invest',
          'amount_range': 'unknown',
        });
      }
    });

    test('no parameter carries the name or the amount', () async {
      await add(
        name: 'Ravi Kumar P2P',
        initialAmount: 123456.78,
        notes: 'Lent to my cousin Ravi',
      );
      await pumpEventQueue();

      expect(analytics.loggedEvents, hasLength(2));
      for (final event in analytics.loggedEvents) {
        expectPrivacySafe(
          event,
          allowedStrings: {
            'investment_type': {'fixedDeposit'},
            'flow_type': {'invest'},
            'amount_range': allowedAmountRanges,
          },
        );
        final text = '${event.parameters}';
        expect(text, isNot(contains('Ravi')));
        expect(text, isNot(contains('123456')));
        expect(text, isNot(contains('12345')));
        expect(text, isNot(contains('cousin')));
      }
    });
  });

  group('the funnel', () {
    GoalEntity goal() => GoalEntity(
      id: 'goal-1',
      name: 'House',
      type: GoalType.targetAmount,
      targetAmount: 1000000,
      trackingMode: GoalTrackingMode.all,
      linkedInvestmentIds: const [],
      icon: 'flag',
      colorValue: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      currency: 'INR',
    );

    test('the first flow gets the same goal check as any cash flow', () async {
      goals.seed(goals: [goal()]);

      await add(initialAmount: 100000);
      await pumpEventQueue();

      expect(notifications.shownGoalStaleNotifications, ['goal-1']);
    });

    test('an investment with no amount runs no goal check', () async {
      goals.seed(goals: [goal()]);

      await add();
      await pumpEventQueue();

      expect(notifications.shownGoalStaleNotifications, isEmpty);
    });

    test('the activation nudges are cancelled once', () async {
      await add(initialAmount: 100000);
      await pumpEventQueue();

      expect(notifications.activationCancelled, 1);
    });

    test('a first flow that crosses a goal milestone announces it', () async {
      // 3,00,000 of a 10,00,000 goal is 30%, from 0%: the 25% milestone.
      goals.seed(goals: [goal()]);
      await add(initialAmount: 300000);
      await pumpEventQueue();

      expect(notifications.shownGoalMilestones, ['goal-1']);
    });
  });
}

/// A repository whose writes fail.
class _FailingWriteRepository extends FakeInvestmentRepository {
  @override
  Future<void> createInvestment(InvestmentEntity investment) =>
      Future.error(StateError('write failed'));

  @override
  Future<bool> createInvestmentWithFirstCashFlow(
    InvestmentEntity investment,
    CashFlowEntity? firstFlow,
  ) => Future.error(StateError('write failed'));
}

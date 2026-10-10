// #941: users set, edit, clear (with Undo) and rebase dated valuations. Every
// write changes the snapshot and the investment's currentValue mirror
// together, never creates a cash flow, and carries nothing but kind and
// provenance to analytics.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_providers.dart';

import '../../../mocks/mock_analytics_service.dart';
import '../../../mocks/mock_notification_service.dart';
import '../data/repositories/mock_investment_repository.dart';
import 'in_memory_valuation_repository.dart';
import 'valuation_fixtures.dart';

/// The signed-in user, switchable from a test.
class _Account extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void switchTo(String? id) => state = id;
}

final _accountProvider = NotifierProvider<_Account, String?>(_Account.new);

void main() {
  late FakeInvestmentRepository investments;
  late InMemoryValuationRepository valuations;
  late FakeAnalyticsService analytics;
  late ProviderContainer container;

  ValuationNotifier notifier() =>
      container.read(valuationNotifierProvider.notifier);

  Future<void> expectRejected(
    Future<Object?> Function() action, {
    String? because,
  }) async {
    await expectLater(
      action,
      throwsA(isA<ValidationException>()),
      reason: because,
    );
  }

  /// Snapshots written for [investmentId], live ones only, newest first.
  List<InvestmentValuationSnapshot> live([String investmentId = 'gold']) => [
    for (final s in valuations.docs.values)
      if (s.investmentId == investmentId && s.isLive) s,
  ]..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));

  setUp(() {
    investments = FakeInvestmentRepository();
    valuations = InMemoryValuationRepository();
    analytics = FakeAnalyticsService();
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(investments),
        valuationRepositoryProvider.overrideWithValue(valuations),
        valuationSnapshotsActiveProvider.overrideWithValue(true),
        isAuthenticatedProvider.overrideWithValue(true),
        valuationAccountIdProvider.overrideWith(
          (ref) => ref.watch(_accountProvider),
        ),
        analyticsServiceProvider.overrideWithValue(analytics),
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

  final today = DateTime.now();
  final day = DateTime(today.year, today.month, today.day);

  group('set (plan test 1)', () {
    test('an opening baseline needs no cash flow and writes none', () async {
      final saved = await notifier().setValuation(
        investmentId: 'gold',
        amount: 500000,
        date: day,
        openingBaseline: true,
      );

      expect(saved.amount, 500000.00);
      expect(saved.currency, 'INR');
      expect(saved.provenance, ValuationProvenance.openingBaseline);
      expect(saved.effectiveDate, day);
      expect(saved.investmentId, 'gold');
      expect(valuations.docs, hasLength(1));
      // A valuation is never a cash flow.
      expect(investments.cashFlows, isEmpty);
      expect(investments.archivedCashFlows, isEmpty);
      // The mirror changed in the same write.
      expect(valuations.mirrors['gold']!.value, 500000.00);
      expect(valuations.mirrors['gold']!.date, day);
      expect(valuations.log, ['save:${saved.id}']);
    });

    test('the kind defaults by type and can be chosen', () async {
      investments.seed(
        investments: [testInvestment('fd', type: InvestmentType.fixedDeposit)],
      );
      final gold = await notifier().setValuation(
        investmentId: 'gold',
        amount: 1,
        date: day,
      );
      final fd = await notifier().setValuation(
        investmentId: 'fd',
        amount: 1,
        date: day,
      );
      final chosen = await notifier().setValuation(
        investmentId: 'gold',
        amount: 2,
        date: day.subtract(const Duration(days: 1)),
        kind: ValuationKind.principalOutstanding,
      );
      expect(gold.kind, ValuationKind.marketValue);
      expect(fd.kind, ValuationKind.carryingValue);
      expect(chosen.kind, ValuationKind.principalOutstanding);
      expect(gold.provenance, ValuationProvenance.manual);
    });

    test('the amount is rounded to the currency of the investment', () async {
      investments.seed(investments: [testInvestment('jp', currency: 'JPY')]);
      final saved = await notifier().setValuation(
        investmentId: 'jp',
        amount: 125.6,
        date: day,
      );
      expect(saved.amount, 126);
      expect(saved.currency, 'JPY');
    });

    test('the date is date-only', () async {
      final saved = await notifier().setValuation(
        investmentId: 'gold',
        amount: 1,
        date: DateTime(day.year, day.month, day.day, 18, 45),
      );
      expect(saved.effectiveDate, day);
    });

    test('rejects what cannot be a valuation', () async {
      final n = notifier();
      await expectRejected(
        () => n.setValuation(investmentId: 'gold', amount: -1, date: day),
        because: 'negative',
      );
      await expectRejected(
        () =>
            n.setValuation(investmentId: 'gold', amount: double.nan, date: day),
        because: 'not finite',
      );
      await expectRejected(
        () => n.setValuation(
          investmentId: 'gold',
          amount: 1,
          date: day.add(const Duration(days: 1)),
        ),
        because: 'future',
      );
      expect(valuations.docs, isEmpty);
    });

    test('rejects an investment that is closed, archived or unknown', () async {
      investments.seed(
        investments: [
          testInvestment('closed', status: InvestmentStatus.closed),
        ],
        archivedInvestments: [testInvestment('old', isArchived: true)],
      );
      final n = notifier();
      await expectRejected(
        () => n.setValuation(investmentId: 'closed', amount: 1, date: day),
        because: 'closed',
      );
      await expectRejected(
        () => n.setValuation(investmentId: 'old', amount: 1, date: day),
        because: 'archived',
      );
      await expectLater(
        () => n.setValuation(investmentId: 'nope', amount: 1, date: day),
        throwsA(isA<DataException>()),
      );
      expect(valuations.docs, isEmpty);
    });

    test('rejects a second opening baseline', () async {
      final n = notifier();
      await n.setValuation(
        investmentId: 'gold',
        amount: 1,
        date: day,
        openingBaseline: true,
      );
      await expectRejected(
        () => n.setValuation(
          investmentId: 'gold',
          amount: 2,
          date: day,
          openingBaseline: true,
        ),
      );
      expect(valuations.docs, hasLength(1));
    });

    test('rejects the 101st live snapshot', () async {
      for (var i = 0; i < 100; i++) {
        valuations.docs['s$i'] = testSnapshot(
          's$i',
          investmentId: 'gold',
          amount: 1,
          date: DateTime(2020).add(Duration(days: i)),
        );
      }
      await expectRejected(
        () =>
            notifier().setValuation(investmentId: 'gold', amount: 1, date: day),
      );
      expect(valuations.docs, hasLength(100));
    });

    test('cleared snapshots do not count towards the limit', () async {
      for (var i = 0; i < 100; i++) {
        valuations.docs['s$i'] = testSnapshot(
          's$i',
          investmentId: 'gold',
          amount: 1,
          date: DateTime(2020).add(Duration(days: i)),
          deletedAt: DateTime.utc(2021),
        );
      }
      await notifier().setValuation(investmentId: 'gold', amount: 1, date: day);
      expect(live(), hasLength(1));
    });

    test(
      'a write that fails leaves neither the snapshot nor the mirror',
      () async {
        valuations.failNextWrite = StateError('offline');
        await expectLater(
          () => notifier().setValuation(
            investmentId: 'gold',
            amount: 1,
            date: day,
          ),
          throwsStateError,
        );
        expect(valuations.docs, isEmpty);
        expect(valuations.mirrors, isEmpty);
      },
    );
  });

  group('adopting a legacy value', () {
    test('the value an older version stored is kept as a snapshot', () async {
      final legacyDate = day.subtract(const Duration(days: 100));
      investments.seed(
        investments: [
          testInvestment('legacy', compatValue: 125000, compatDate: legacyDate),
        ],
      );
      final saved = await notifier().setValuation(
        investmentId: 'legacy',
        amount: 90000,
        date: day.subtract(const Duration(days: 300)),
        openingBaseline: true,
      );

      final all = live('legacy');
      expect(all, hasLength(2));
      final adopted = all.singleWhere((s) => s.id != saved.id);
      expect(adopted.amount, 125000);
      expect(adopted.effectiveDate, legacyDate);
      expect(adopted.kind, ValuationKind.carryingValue);
      expect(adopted.provenance, ValuationProvenance.manual);
      // The latest of the two is what the mirror reads.
      expect(valuations.mirrors['legacy']!.value, 125000);
    });
  });

  group('edit (plan test 6)', () {
    late InvestmentValuationSnapshot saved;

    setUp(() async {
      saved = await notifier().setValuation(
        investmentId: 'gold',
        amount: 100,
        date: DateTime(day.year, day.month, 1),
      );
    });

    test('the amount, then the date, of one snapshot', () async {
      final edited = await notifier().editValuation(
        snapshotId: saved.id,
        amount: 200.555,
      );
      expect(edited.amount, 200.56);
      expect(valuations.mirrors['gold']!.value, 200.56);

      final moved = await notifier().editValuation(
        snapshotId: saved.id,
        date: DateTime(day.year, day.month, 1, 23),
      );
      expect(moved.effectiveDate, DateTime(day.year, day.month, 1));
      expect(valuations.docs, hasLength(1));
      expect(investments.cashFlows, isEmpty);
      expect(moved.id, saved.id);
      expect(moved.createdAt, saved.createdAt);
    });

    test('keeps its kind and its provenance', () async {
      final edited = await notifier().editValuation(
        snapshotId: saved.id,
        amount: 5,
      );
      expect(edited.kind, saved.kind);
      expect(edited.provenance, saved.provenance);
    });

    test('rejects a future date and an unknown snapshot', () async {
      await expectRejected(
        () => notifier().editValuation(
          snapshotId: saved.id,
          date: day.add(const Duration(days: 1)),
        ),
      );
      await expectLater(
        () => notifier().editValuation(snapshotId: 'nope', amount: 1),
        throwsA(isA<DataException>()),
      );
    });

    test('rejects editing once the investment is archived', () async {
      investments
        ..reset()
        ..seed(archivedInvestments: [testInvestment('gold', isArchived: true)]);
      await expectRejected(
        () => notifier().editValuation(snapshotId: saved.id, amount: 1),
      );
    });
  });

  group('clear and undo (plan test 7)', () {
    test(
      'the only snapshot: deleted, the mirror clears, Undo restores both',
      () async {
        final saved = await notifier().setValuation(
          investmentId: 'gold',
          amount: 100,
          date: day,
        );
        await notifier().clearValuation(saved.id);

        expect(valuations.docs[saved.id]!.isLive, isFalse);
        expect(valuations.mirrors['gold']!.value, isNull);
        expect(valuations.mirrors['gold']!.date, isNull);

        expect(await notifier().undoClear(), isTrue);
        expect(valuations.docs[saved.id]!.isLive, isTrue);
        expect(valuations.mirrors['gold']!.value, 100);
        // Nothing left to undo.
        expect(await notifier().undoClear(), isFalse);
      },
    );

    test('with an earlier snapshot the mirror falls back to it', () async {
      await notifier().setValuation(
        investmentId: 'gold',
        amount: 100,
        date: day.subtract(const Duration(days: 40)),
      );
      final latest = await notifier().setValuation(
        investmentId: 'gold',
        amount: 200,
        date: day,
      );
      expect(valuations.mirrors['gold']!.value, 200);

      await notifier().clearValuation(latest.id);
      expect(valuations.mirrors['gold']!.value, 100);
      expect(
        valuations.mirrors['gold']!.date,
        day.subtract(const Duration(days: 40)),
      );

      expect(await notifier().undoClear(), isTrue);
      expect(valuations.mirrors['gold']!.value, 200);
    });

    test('a snapshot is not deleted for good', () async {
      final saved = await notifier().setValuation(
        investmentId: 'gold',
        amount: 100,
        date: day,
      );
      await notifier().clearValuation(saved.id);
      expect(valuations.docs, contains(saved.id));
    });

    test('Undo cannot bring back a second opening baseline', () async {
      final first = await notifier().setValuation(
        investmentId: 'gold',
        amount: 100,
        date: day.subtract(const Duration(days: 30)),
        openingBaseline: true,
      );
      await notifier().clearValuation(first.id);
      await notifier().setValuation(
        investmentId: 'gold',
        amount: 200,
        date: day,
        openingBaseline: true,
      );
      await expectRejected(() => notifier().undoClear());
      expect(valuations.docs[first.id]!.isLive, isFalse);
    });

    test('Undo cannot go past the limit of 100 live snapshots', () async {
      final saved = await notifier().setValuation(
        investmentId: 'gold',
        amount: 1,
        date: day,
      );
      await notifier().clearValuation(saved.id);
      for (var i = 0; i < 100; i++) {
        valuations.docs['s$i'] = testSnapshot(
          's$i',
          investmentId: 'gold',
          amount: 1,
          date: DateTime(2020).add(Duration(days: i)),
        );
      }
      await expectRejected(() => notifier().undoClear());
      expect(live(), hasLength(100));
    });

    test('rejects clearing on a closed or archived investment', () async {
      final saved = await notifier().setValuation(
        investmentId: 'gold',
        amount: 100,
        date: day,
      );
      investments
        ..reset()
        ..seed(
          investments: [
            testInvestment('gold', status: InvestmentStatus.closed),
          ],
        );
      await expectRejected(() => notifier().clearValuation(saved.id));
    });
  });

  group('rebase (plan test 9)', () {
    test(
      'confirming the full history relabels the baseline as manual',
      () async {
        final baseline = await notifier().setValuation(
          investmentId: 'gold',
          amount: 500000,
          date: DateTime(day.year, 1, 1),
          openingBaseline: true,
        );
        final rebased = await notifier().rebase(baseline.id);

        expect(rebased.provenance, ValuationProvenance.manual);
        expect(rebased.id, baseline.id);
        expect(rebased.amount, 500000);
        expect(rebased.effectiveDate, baseline.effectiveDate);
        expect(valuations.docs, hasLength(1));
        expect(investments.cashFlows, isEmpty);
      },
    );

    test('only a baseline can be rebased', () async {
      final manual = await notifier().setValuation(
        investmentId: 'gold',
        amount: 1,
        date: day,
      );
      await expectRejected(() => notifier().rebase(manual.id));
    });
  });

  group('nothing built for a calculation is stored (AC11)', () {
    test('no write holds a current-value: or tracking-start: id, or a cash '
        'flow', () async {
      final baseline = await notifier().setValuation(
        investmentId: 'gold',
        amount: 500000,
        date: day.subtract(const Duration(days: 200)),
        openingBaseline: true,
      );
      final later = await notifier().setValuation(
        investmentId: 'gold',
        amount: 530000,
        date: day,
      );
      await notifier().editValuation(snapshotId: later.id, amount: 540000);
      await notifier().rebase(baseline.id);
      await notifier().clearValuation(later.id);
      await notifier().undoClear();

      for (final id in valuations.docs.keys) {
        expect(TerminalValues.isEphemeralId(id), isFalse, reason: id);
      }
      expect(investments.cashFlows, isEmpty);
      expect(investments.archivedCashFlows, isEmpty);
    });
  });

  group('telemetry (plan test 18)', () {
    test('events carry kind and provenance only', () async {
      final saved = await notifier().setValuation(
        investmentId: 'gold',
        amount: 123456,
        date: day,
        openingBaseline: true,
      );
      await notifier().clearValuation(saved.id);

      final events = analytics.loggedEvents;
      expect(events.map((e) => e.name), ['valuation_set', 'valuation_cleared']);
      for (final event in events) {
        expect(event.parameters, {
          'kind': 'marketValue',
          'provenance': 'openingBaseline',
        });
        final text = event.parameters.toString();
        expect(text, isNot(contains('123456')));
        expect(text, isNot(contains(saved.id)));
        expect(text, isNot(contains('gold')));
      }
    });

    test('a rejected write logs nothing', () async {
      await expectRejected(
        () => notifier().setValuation(
          investmentId: 'gold',
          amount: -1,
          date: day,
        ),
      );
      expect(analytics.loggedEvents, isEmpty);
    });
  });

  group('another account', () {
    test('clears the Undo of the previous one', () async {
      final saved = await notifier().setValuation(
        investmentId: 'gold',
        amount: 1,
        date: day,
      );
      await notifier().clearValuation(saved.id);

      container.read(_accountProvider.notifier).switchTo('u2');
      expect(await notifier().undoClear(), isFalse);
      expect(valuations.docs[saved.id]!.isLive, isFalse);
    });
  });

  group('offline conflicts (plan test 13)', () {
    test('a server value that differs from what this device wrote is reported '
        'once', () async {
      final sub = container.listen(valuationConflictsProvider, (_, _) {});
      addTearDown(sub.close);
      final saved = await notifier().setValuation(
        investmentId: 'gold',
        amount: 100,
        date: day,
      );
      expect(container.read(valuationConflictsProvider), isEmpty);

      // The server confirms what this device wrote: no notice.
      valuations.emitServer([saved]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(valuationConflictsProvider), isEmpty);

      // Another device wrote later and won: this device is told.
      valuations.emitServer([saved.copyWith(amount: 150)]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(valuationConflictsProvider), {saved.id});

      container.read(valuationConflictsProvider.notifier).dismiss();
      valuations.emitServer([saved.copyWith(amount: 175)]);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(valuationConflictsProvider),
        isEmpty,
        reason: 'one notice per overwrite, not a repeat of the same one',
      );
    });

    test('a snapshot this session did not write is never reported', () async {
      final sub = container.listen(valuationConflictsProvider, (_, _) {});
      addTearDown(sub.close);
      notifier();
      valuations.emitServer([
        testSnapshot('other', investmentId: 'gold', amount: 1, date: day),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(valuationConflictsProvider), isEmpty);
    });
  });
}

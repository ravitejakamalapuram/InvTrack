// #941: users set, edit, clear (with Undo) and rebase dated valuations. Every
// write changes the snapshot and the investment's currentValue mirror
// together, never creates a cash flow, and carries nothing but kind and
// provenance to analytics.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/valuation_snapshot_selector.dart';
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

    test('clearing the latest value reports a failure in the state', () async {
      // CodeRabbit on PR 961: the lookup ran outside the guarded action.
      await expectLater(
        () => notifier().clearLatestValuation('nope'),
        throwsA(isA<DataException>()),
      );
      expect(container.read(valuationNotifierProvider).hasError, isTrue);
    });

    test('clearing the latest value of an investment with none is false and '
        'no error', () async {
      expect(await notifier().clearLatestValuation('gold'), isFalse);
      final state = container.read(valuationNotifierProvider);
      expect(state.hasError, isFalse);
      expect(state.isLoading, isFalse);
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
    final baselineDay = DateTime(day.year, 1, 1);

    Future<InvestmentValuationSnapshot> baselineOn(DateTime on) =>
        notifier().setValuation(
          investmentId: 'gold',
          amount: 500000,
          date: on,
          openingBaseline: true,
        );

    test(
      'confirming the full history relabels the baseline as manual',
      () async {
        // The history was entered after the baseline: a flow before it.
        final history = testFlow(
          'gold',
          CashFlowType.invest,
          400000,
          DateTime(day.year - 1, 5, 1),
        );
        investments.seed(cashFlows: [history]);
        final baseline = await baselineOn(baselineDay);
        final rebased = await notifier().rebase(baseline.id);

        expect(rebased.provenance, ValuationProvenance.manual);
        expect(rebased.id, baseline.id);
        expect(rebased.amount, 500000);
        expect(rebased.effectiveDate, baseline.effectiveDate);
        expect(valuations.docs, hasLength(1));
        // No cash flow is written or removed.
        expect(investments.cashFlows, [history]);
      },
    );

    test('a flow on the baseline day is history too', () async {
      investments.seed(
        cashFlows: [testFlow('gold', CashFlowType.invest, 400000, baselineDay)],
      );
      final baseline = await baselineOn(baselineDay);
      final rebased = await notifier().rebase(baseline.id);
      expect(rebased.provenance, ValuationProvenance.manual);
    });

    test('with no cash flows there is no history to confirm', () async {
      // Rebasing would turn a value with an unknown cost into pure gain.
      final baseline = await baselineOn(baselineDay);
      await expectRejected(() => notifier().rebase(baseline.id));
      expect(
        valuations.docs[baseline.id]!.provenance,
        ValuationProvenance.openingBaseline,
      );
    });

    test('flows dated only after the baseline are not its history', () async {
      investments.seed(
        cashFlows: [
          testFlow(
            'gold',
            CashFlowType.income,
            100,
            baselineDay.add(const Duration(days: 1)),
          ),
        ],
      );
      final baseline = await baselineOn(baselineDay);
      await expectRejected(() => notifier().rebase(baseline.id));
      expect(
        valuations.docs[baseline.id]!.provenance,
        ValuationProvenance.openingBaseline,
      );
    });

    test('only a baseline can be rebased', () async {
      final manual = await notifier().setValuation(
        investmentId: 'gold',
        amount: 1,
        date: day,
      );
      await expectRejected(() => notifier().rebase(manual.id));
    });
  });

  // CodeRabbit on PR 961: a write gives its snapshot the server's update time,
  // which makes it the newest of its day. The mirror must name the snapshot a
  // reader will select after the write, not the one selected before it.
  group('the mirror follows the server time of the write', () {
    final older = DateTime.utc(2026, 3, 1);
    final newer = DateTime.utc(2026, 4, 1);

    // Two values on one day: 'b' is the newest now, 'a' the older.
    InvestmentValuationSnapshot twin(
      String id,
      double amount,
      DateTime updatedAt, {
      ValuationProvenance provenance = ValuationProvenance.manual,
    }) => testSnapshot(
      id,
      investmentId: 'gold',
      amount: amount,
      date: day,
      updatedAt: updatedAt,
      provenance: provenance,
    );

    /// What a reader selects from the documents as stored after the write.
    void expectMirrorIsStoredLatest(double amount) {
      final stored = ValuationSnapshotSelector.mirrorOf(
        live(),
        investmentId: 'gold',
        currency: 'INR',
      );
      expect(stored?.amount, amount, reason: 'the stored latest');
      expect(valuations.mirrors['gold']!.value, amount);
      expect(valuations.mirrors['gold']!.date, day);
    }

    setUp(() {
      valuations.serverTime = DateTime.utc(2026, 9, 1);
      valuations.docs['b'] = twin('b', 200, newer);
    });

    test('editing the older of two same-day values', () async {
      valuations.docs['a'] = twin('a', 100, older);
      await notifier().editValuation(snapshotId: 'a', amount: 150);
      expectMirrorIsStoredLatest(150);
    });

    test('replacing a same-day value', () async {
      valuations.docs
        ..clear()
        ..['a'] = twin('a', 100, older)
        ..['b'] = twin('b', 200, newer);
      await notifier().setValuation(
        investmentId: 'gold',
        amount: 175,
        date: day,
        replaceSameDay: true,
      );
      expect(valuations.docs, hasLength(2));
      expectMirrorIsStoredLatest(175);
    });

    test(
      'confirming a baseline that shares its day with a newer value',
      () async {
        valuations.docs['a'] = twin(
          'a',
          100,
          older,
          provenance: ValuationProvenance.openingBaseline,
        );
        investments.seed(
          cashFlows: [
            testFlow(
              'gold',
              CashFlowType.invest,
              90,
              DateTime(day.year - 1, 5, 1),
            ),
          ],
        );
        await notifier().rebase('a');
        expectMirrorIsStoredLatest(100);
      },
    );

    test('Undo of a clear brings back the value the server will rank '
        'newest', () async {
      valuations.docs['a'] = twin('a', 100, older);
      await notifier().clearValuation('a');
      expect(valuations.mirrors['gold']!.value, 200);

      expect(await notifier().undoClear(), isTrue);
      expectMirrorIsStoredLatest(100);
    });
  });

  // Follow-up to the CodeRabbit finding on the mirror: when the snapshots
  // ranked for the mirror hold more than one with no update time, the tie was
  // broken by id, while the server orders them by when they were written. The
  // write of the action is always the last.
  group('the mirror ranks the write after earlier unconfirmed ones', () {
    final older = DateTime.utc(2026, 3, 1);

    setUp(() => valuations.serverTime = DateTime.utc(2026, 9, 1));

    test('a legacy value adopted by the same action is older than the new '
        'value', () async {
      // Both ids are random: over many rounds the adopted one outranks the
      // new one by id about half the time, so a wrong tie-break shows.
      for (var i = 0; i < 64; i++) {
        final id = 'legacy$i';
        investments.seed(
          investments: [
            testInvestment(id, compatValue: 125000, compatDate: day),
          ],
        );
        await notifier().setValuation(
          investmentId: id,
          amount: 130000,
          date: day,
        );
        // The adopted value reaches the server first, then the new one.
        expect(
          valuations.mirrors[id]!.value,
          130000,
          reason: 'round $i, adopted legacy value vs the new one',
        );
        final stored = ValuationSnapshotSelector.mirrorOf(
          live(id),
          investmentId: id,
          currency: 'INR',
        );
        expect(stored?.amount, 130000, reason: 'round $i, as stored');
      }
    });

    test('a new value is newer than an earlier same-day write that has not '
        'reached the server', () async {
      // 'zzz' outranks any generated id, so an id tie-break picks it.
      valuations.docs['zzz'] = testSnapshot(
        'zzz',
        investmentId: 'gold',
        amount: 100,
        date: day,
        pending: true,
      );
      await notifier().setValuation(
        investmentId: 'gold',
        amount: 200,
        date: day,
      );
      expect(valuations.mirrors['gold']!.value, 200);
    });

    test('an edit is newer than an unconfirmed same-day write', () async {
      valuations.docs['aaa'] = testSnapshot(
        'aaa',
        investmentId: 'gold',
        amount: 100,
        date: day,
        updatedAt: older,
      );
      valuations.docs['zzz'] = testSnapshot(
        'zzz',
        investmentId: 'gold',
        amount: 300,
        date: day,
        pending: true,
      );
      await notifier().editValuation(snapshotId: 'aaa', amount: 150);
      expect(valuations.mirrors['gold']!.value, 150);
    });

    test('Undo is newer than an unconfirmed same-day write', () async {
      valuations.docs['aaa'] = testSnapshot(
        'aaa',
        investmentId: 'gold',
        amount: 100,
        date: day,
        updatedAt: older,
      );
      valuations.docs['zzz'] = testSnapshot(
        'zzz',
        investmentId: 'gold',
        amount: 300,
        date: day,
        pending: true,
      );
      await notifier().clearValuation('aaa');
      expect(valuations.mirrors['gold']!.value, 300);
      expect(await notifier().undoClear(), isTrue);
      expect(valuations.mirrors['gold']!.value, 100);
    });

    test('an unconfirmed write is still newer than a confirmed one of the same '
        'day', () async {
      valuations.docs['aaa'] = testSnapshot(
        'aaa',
        investmentId: 'gold',
        amount: 100,
        date: day,
        updatedAt: older,
      );
      valuations.docs['bbb'] = testSnapshot(
        'bbb',
        investmentId: 'gold',
        amount: 120,
        date: day,
        pending: true,
      );
      // A different day, so the write cannot decide the mirror: the newest
      // of the same day (bbb, unconfirmed) must.
      await notifier().setValuation(
        investmentId: 'gold',
        amount: 50,
        date: day.subtract(const Duration(days: 3)),
      );
      expect(valuations.mirrors['gold']!.value, 120);
    });
  });

  // CodeRabbit on PR 961: an action read the whole collection several times.
  // It reads what it needs once: one investment's snapshots where the
  // investment is known, the collection once where only a snapshot id is.
  group('what an action reads', () {
    late InvestmentValuationSnapshot first;

    setUp(() {
      first = testSnapshot(
        'a',
        investmentId: 'gold',
        amount: 100,
        date: day.subtract(const Duration(days: 5)),
      );
      valuations.docs['a'] = first;
      valuations.docs['b'] = testSnapshot(
        'b',
        investmentId: 'gold',
        amount: 200,
        date: day,
      );
      valuations.docs['other'] = testSnapshot(
        'other',
        investmentId: 'silver',
        amount: 999,
        date: day,
      );
    });

    void expectReadOnce({required bool byInvestment}) {
      expect(
        valuations.getAllCount,
        byInvestment ? 0 : 1,
        reason: 'whole-collection reads',
      );
      expect(valuations.readByInvestment, byInvestment ? ['gold'] : isEmpty);
    }

    test('setting a value reads that investment once', () async {
      await notifier().setValuation(
        investmentId: 'gold',
        amount: 300,
        date: day,
      );
      expectReadOnce(byInvestment: true);
    });

    test('editing a value reads the collection once', () async {
      await notifier().editValuation(snapshotId: 'a', amount: 150);
      expectReadOnce(byInvestment: false);
      expect(valuations.mirrors['gold']!.value, 200);
    });

    test('clearing a value reads the collection once', () async {
      await notifier().clearValuation('b');
      expectReadOnce(byInvestment: false);
      expect(valuations.mirrors['gold']!.value, 100);
    });

    test('clearing the latest value reads that investment once', () async {
      expect(await notifier().clearLatestValuation('gold'), isTrue);
      expectReadOnce(byInvestment: true);
      expect(valuations.docs['b']!.isLive, isFalse);
      expect(valuations.docs['a']!.isLive, isTrue);
      expect(valuations.mirrors['gold']!.value, 100);
    });

    test('undoing a clear reads that investment once', () async {
      await notifier().clearValuation('b');
      valuations
        ..getAllCount = 0
        ..readByInvestment.clear();
      expect(await notifier().undoClear(), isTrue);
      expectReadOnce(byInvestment: true);
      expect(valuations.mirrors['gold']!.value, 200);
    });

    test('confirming a baseline reads the collection once', () async {
      valuations.docs['a'] = first.copyWith(
        provenance: ValuationProvenance.openingBaseline,
      );
      investments.seed(
        cashFlows: [
          testFlow(
            'gold',
            CashFlowType.invest,
            90,
            day.subtract(const Duration(days: 400)),
          ),
        ],
      );
      await notifier().rebase('a');
      expectReadOnce(byInvestment: false);
    });

    test('a cleared value is still not found or counted', () async {
      await notifier().clearValuation('b');
      await expectLater(
        () => notifier().editValuation(snapshotId: 'b', amount: 1),
        throwsA(isA<DataException>()),
      );
      expect(await notifier().clearLatestValuation('gold'), isTrue);
      expect(valuations.docs['a']!.isLive, isFalse);
      expect(await notifier().clearLatestValuation('gold'), isFalse);
    });
  });

  group('nothing built for a calculation is stored (AC11)', () {
    test('no write holds a current-value: or tracking-start: id, or a cash '
        'flow', () async {
      final history = testFlow(
        'gold',
        CashFlowType.invest,
        400000,
        day.subtract(const Duration(days: 400)),
      );
      investments.seed(cashFlows: [history]);
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
      // Only the one flow seeded above: nothing was added.
      expect(investments.cashFlows, [history]);
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

    test('a snapshot this device cleared that the server still holds live is '
        'reported', () async {
      final sub = container.listen(valuationConflictsProvider, (_, _) {});
      addTearDown(sub.close);
      final saved = await notifier().setValuation(
        investmentId: 'gold',
        amount: 100,
        date: day,
      );
      await notifier().clearValuation(saved.id);

      // The server confirms the clear: no notice.
      valuations.emitServer([saved.copyWith(deletedAt: DateTime.now())]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(valuationConflictsProvider), isEmpty);

      // Another device edited it after the clear and won.
      valuations.emitServer([saved]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(valuationConflictsProvider), {saved.id});
    });

    test('a snapshot this device wrote that the server holds cleared is '
        'reported', () async {
      final sub = container.listen(valuationConflictsProvider, (_, _) {});
      addTearDown(sub.close);
      final saved = await notifier().setValuation(
        investmentId: 'gold',
        amount: 100,
        date: day,
      );

      // Another device cleared it and won.
      valuations.emitServer([saved.copyWith(deletedAt: DateTime.now())]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(valuationConflictsProvider), {saved.id});
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

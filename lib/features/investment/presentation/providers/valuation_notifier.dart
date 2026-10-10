/// State notifier for dated valuations: set, edit, clear (with Undo) and
/// rebase. Every write changes the snapshot and the investment's
/// currentValue mirror in one batch, and never creates a cash flow.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/valuation_snapshot_selector.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/utils/money_precision.dart';
import 'package:inv_tracker/core/utils/stored_date.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/repositories/valuation_repository.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_providers.dart';
import 'package:uuid/uuid.dart';

final valuationNotifierProvider =
    NotifierProvider<ValuationNotifier, AsyncValue<void>>(
      ValuationNotifier.new,
    );

/// A cleared snapshot Undo can bring back.
class _ClearedValuation {
  final InvestmentValuationSnapshot snapshot;

  const _ClearedValuation(this.snapshot);
}

class ValuationNotifier extends Notifier<AsyncValue<void>> {
  _ClearedValuation? _undo;

  @override
  AsyncValue<void> build() {
    // Another account starts clean: nothing of the previous one's Undo or
    // writes may reach it.
    ref.watch(valuationAccountIdProvider);
    _undo = null;
    return const AsyncValue.data(null);
  }

  ValuationRepository get _repository => ref.read(valuationRepositoryProvider);

  /// Records a new valuation of the open investment [investmentId], in the
  /// investment's own currency, as of [date] (date-only, not in the future).
  ///
  /// [openingBaseline] marks it as the value when tracking started, standing
  /// in for history that cannot be entered: it may precede every cash flow,
  /// there is at most one, and it keeps lifetime XIRR, MOIC and return
  /// unknown. [kind] defaults by the type of the investment. With
  /// [replaceSameDay] a plain value already recorded for that day is
  /// replaced instead of adding a second one.
  ///
  /// Throws [ValidationException] for a negative or non-finite amount, a
  /// future date, an investment that is not open or is archived, a second
  /// baseline, or an investment that already has 100 live valuations.
  Future<InvestmentValuationSnapshot> setValuation({
    required String investmentId,
    required double amount,
    required DateTime date,
    ValuationKind? kind,
    bool openingBaseline = false,
    bool replaceSameDay = false,
  }) async {
    _validateAmount(amount);
    final day = _validatedDay(date);
    return _run(() async {
      final investment = await _writableInvestment(investmentId);
      final currency = _requireCurrency(investment.currency);
      var existing = await _liveSnapshotsOf(investmentId);

      // A value an older app version stored is kept as a snapshot, so that
      // the first snapshot cannot replace it in the mirror and lose it.
      final adopted = await _adoptLegacyValue(investment, existing);
      if (adopted != null) existing = [...existing, adopted];

      if (openingBaseline &&
          ValuationSnapshotSelector.openingBaseline(
                existing,
                investmentId: investmentId,
                currency: currency,
              ) !=
              null) {
        throw _rejected(
          'This investment already has an opening value.',
          'second opening baseline',
        );
      }

      final sameDay = replaceSameDay && !openingBaseline
          ? existing
                .where(
                  (s) =>
                      s.currency == currency &&
                      !s.isOpeningBaseline &&
                      _dateOnly(s.effectiveDate) == day,
                )
                .firstOrNull
          : null;
      if (sameDay == null &&
          existing.length >= ValuationSnapshotSelector.maxLiveSnapshots) {
        throw _rejected(
          'This investment has the most dated values it can hold '
              '(${ValuationSnapshotSelector.maxLiveSnapshots}). Clear an old one '
              'first.',
          'live snapshot limit',
        );
      }

      final snapshot =
          sameDay?.copyWith(amount: _rounded(amount, currency)) ??
          InvestmentValuationSnapshot(
            id: const Uuid().v4(),
            investmentId: investmentId,
            amount: _rounded(amount, currency),
            currency: currency,
            effectiveDate: day,
            kind: kind ?? CurrentValueCalculator.defaultKind(investment.type),
            provenance: openingBaseline
                ? ValuationProvenance.openingBaseline
                : ValuationProvenance.manual,
            createdAt: DateTime.now(),
          );
      await _save(investment, snapshot, existing);
      ref
          .read(analyticsServiceProvider)
          .logValuationSet(
            kind: snapshot.kind.name,
            provenance: snapshot.provenance.storageName,
          );
      return snapshot;
    });
  }

  /// Changes the amount, the date or the kind of a live snapshot. The rest,
  /// its provenance included, stays.
  Future<InvestmentValuationSnapshot> editValuation({
    required String snapshotId,
    double? amount,
    DateTime? date,
    ValuationKind? kind,
  }) async {
    if (amount != null) _validateAmount(amount);
    final day = date == null ? null : _validatedDay(date);
    return _run(() async {
      final (snapshot: current, ofInvestment: own) =
          await _liveSnapshotWithSiblings(snapshotId);
      final investment = await _writableInvestment(current.investmentId);
      final edited = current.copyWith(
        amount: amount == null
            ? null
            : _rounded(amount, _requireCurrency(current.currency)),
        effectiveDate: day,
        kind: kind,
      );
      await _save(investment, edited, own);
      ref
          .read(analyticsServiceProvider)
          .logValuationSet(
            kind: edited.kind.name,
            provenance: edited.provenance.storageName,
          );
      return edited;
    });
  }

  /// Clears a snapshot. It is kept as a tombstone, so that [undoClear] can
  /// bring it back and a clear and an edit from two devices converge. The
  /// investment's mirror falls back to the latest snapshot that remains.
  Future<void> clearValuation(String snapshotId) async {
    await _run(() async {
      final (snapshot: current, ofInvestment: own) =
          await _liveSnapshotWithSiblings(snapshotId);
      await _clear(current, own);
    });
  }

  /// Clears [current], one of [own] (the live snapshots of its investment).
  Future<void> _clear(
    InvestmentValuationSnapshot current,
    List<InvestmentValuationSnapshot> own,
  ) async {
    final investment = await _writableInvestment(current.investmentId);
    final remaining = [
      for (final s in own)
        if (s.id != current.id) s,
    ];
    final cleared = current.copyWith(deletedAt: DateTime.now());
    await _repository.softDelete(
      cleared,
      mirror: _mirrorOf(investment, remaining),
    );
    _written(cleared);
    _undo = _ClearedValuation(current);
    ref
        .read(analyticsServiceProvider)
        .logValuationCleared(
          kind: current.kind.name,
          provenance: current.provenance.storageName,
        );
  }

  /// Clears the snapshot the investment's value comes from: its latest live
  /// one in its own currency. Returns false when it has none.
  Future<bool> clearLatestValuation(String investmentId) => _run(() async {
    final investment = await ref
        .read(investmentRepositoryProvider)
        .getInvestmentById(investmentId);
    if (investment == null) {
      throw DataException.notFound('Investment', investmentId);
    }
    final own = await _liveSnapshotsOf(investmentId);
    final latest = ValuationSnapshotSelector.mirrorOf(
      own,
      investmentId: investmentId,
      currency: investment.currency,
    );
    if (latest == null) return false;
    await _clear(latest, own);
    return true;
  });

  /// Brings back the snapshot cleared last, if the investment still takes
  /// it. Returns whether there was anything to bring back.
  Future<bool> undoClear() async {
    final undo = _undo;
    if (undo == null) return false;
    _undo = null;
    return _run(() async {
      final investment = await _writableInvestment(undo.snapshot.investmentId);
      final all = await _liveSnapshotsOf(investment.id);
      final restored = undo.snapshot;
      // What was cleared may have been replaced since: the limits still hold.
      if (restored.isOpeningBaseline &&
          ValuationSnapshotSelector.openingBaseline(
                all,
                investmentId: investment.id,
                currency: investment.currency,
              ) !=
              null) {
        throw _rejected(
          'This investment already has an opening value.',
          'undo would add a second opening baseline',
        );
      }
      if (all.length >= ValuationSnapshotSelector.maxLiveSnapshots) {
        throw _rejected(
          'This investment has the most dated values it can hold '
              '(${ValuationSnapshotSelector.maxLiveSnapshots}).',
          'undo would pass the live snapshot limit',
        );
      }
      await _repository.restore(
        restored,
        mirror: _mirrorOf(investment, _withWrite(all, restored)),
      );
      _written(restored);
      return true;
    });
  }

  /// Confirms that the full history is now entered: an opening baseline
  /// becomes a plain value. The snapshot is kept, no cash flow is written or
  /// removed, and lifetime metrics start. Needs at least one cash flow dated
  /// on or before the baseline day, otherwise there is no history to confirm
  /// and [ValidationException] is thrown.
  Future<InvestmentValuationSnapshot> rebase(String snapshotId) async {
    return _run(() async {
      final (snapshot: current, ofInvestment: own) =
          await _liveSnapshotWithSiblings(snapshotId);
      if (!current.isOpeningBaseline) {
        throw _rejected(
          'Only an opening value can be replaced by full history.',
          'rebase of a snapshot that is not a baseline',
        );
      }
      final investment = await _writableInvestment(current.investmentId);
      // Lifetime metrics start from the history, so there must be some: with
      // no cash flow on or before the baseline day, the value would read as
      // pure gain.
      final baselineDay = _dateOnly(current.effectiveDate);
      final flows = await ref
          .read(investmentRepositoryProvider)
          .getCashFlowsByInvestment(investment.id);
      if (!flows.any((cf) => !_dateOnly(cf.date).isAfter(baselineDay))) {
        throw _rejected(
          'Add the cash flows from before this opening value first.',
          'rebase with no cash flow on or before the baseline',
        );
      }
      final rebased = current.copyWith(provenance: ValuationProvenance.manual);
      await _save(investment, rebased, own);
      return rebased;
    });
  }

  // ============ HELPERS ============

  Future<T> _run<T>(Future<T> Function() action) async {
    state = const AsyncValue.loading();
    try {
      final result = await action();
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Writes [snapshot] with the mirror that [others] (the live snapshots of
  /// [investment]) and it make.
  Future<void> _save(
    InvestmentEntity investment,
    InvestmentValuationSnapshot snapshot,
    List<InvestmentValuationSnapshot> others,
  ) async {
    await _repository.save(
      snapshot,
      mirror: _mirrorOf(investment, _withWrite(others, snapshot)),
    );
    _written(snapshot);
  }

  /// [others] and [written] as the selector will rank them once the write has
  /// its server timestamp, for the mirror of that write. The write is the
  /// newest of its day, so it counts as pending (no update time), however old
  /// its in-memory copy is. A snapshot of [others] with no update time is an
  /// earlier write that has not reached the server, or the legacy value
  /// adopted a moment ago: it is older than [written], though both read as
  /// pending, and would otherwise be ranked by id. It stays newer than every
  /// confirmed snapshot.
  List<InvestmentValuationSnapshot> _withWrite(
    List<InvestmentValuationSnapshot> others,
    InvestmentValuationSnapshot written,
  ) {
    DateTime? latestConfirmed;
    for (final s in others) {
      final at = s.updatedAt;
      if (at != null &&
          (latestConfirmed == null || at.isAfter(latestConfirmed))) {
        latestConfirmed = at;
      }
    }
    final unconfirmed = (latestConfirmed ?? DateTime.utc(1970)).add(
      const Duration(milliseconds: 1),
    );
    return [
      for (final s in others)
        if (s.id != written.id)
          s.updatedAt == null ? s.copyWith(updatedAt: unconfirmed) : s,
      written.copyWith(clearUpdatedAt: true),
    ];
  }

  /// The mirror for an investment whose live snapshots are [snapshots].
  CompatMirror _mirrorOf(
    InvestmentEntity investment,
    List<InvestmentValuationSnapshot> snapshots,
  ) => CompatMirror.of(
    investment.id,
    ValuationSnapshotSelector.mirrorOf(
      snapshots,
      investmentId: investment.id,
      currency: investment.currency,
    ),
  );

  /// The open, active investment [id], or a [ValidationException] when it is
  /// closed or archived: neither takes a new value.
  Future<InvestmentEntity> _writableInvestment(String id) async {
    final investment = await ref
        .read(investmentRepositoryProvider)
        .getInvestmentById(id);
    if (investment == null) throw DataException.notFound('Investment', id);
    if (investment.isArchived) {
      throw _rejected(
        'Archived investments are not valued.',
        'valuation write on an archived investment',
      );
    }
    if (!investment.isOpen) {
      throw _rejected(
        'Only open investments have a current value.',
        'valuation write on a closed investment',
      );
    }
    return investment;
  }

  /// The live snapshots of [investmentId], from the repository (cache-first
  /// when offline, like the other reads of the notifiers). It reads that
  /// investment's snapshots only.
  Future<List<InvestmentValuationSnapshot>> _liveSnapshotsOf(
    String investmentId,
  ) async => [
    for (final s in await _repository.getByInvestment(investmentId))
      if (s.isLive) s,
  ];

  /// The live snapshot [id] and the live snapshots of its investment, itself
  /// included, from one read. Only the id is known here, so the collection is
  /// read, once.
  Future<
    ({
      InvestmentValuationSnapshot snapshot,
      List<InvestmentValuationSnapshot> ofInvestment,
    })
  >
  _liveSnapshotWithSiblings(String id) async {
    final live = [
      for (final s in await _repository.getAll())
        if (s.isLive) s,
    ];
    for (final s in live) {
      if (s.id != id) continue;
      return (
        snapshot: s,
        ofInvestment: [
          for (final o in live)
            if (o.investmentId == s.investmentId) o,
        ],
      );
    }
    throw DataException.notFound('Valuation', id);
  }

  /// The snapshot that keeps the value an older app version stored in the
  /// investment's own `currentValue`, written when it has no live snapshot
  /// and is about to get its first.
  Future<InvestmentValuationSnapshot?> _adoptLegacyValue(
    InvestmentEntity investment,
    List<InvestmentValuationSnapshot> live,
  ) async {
    final value = investment.currentValue;
    final date = investment.currentValueDate;
    if (value == null ||
        date == null ||
        !value.isFinite ||
        value < 0 ||
        ValuationSnapshotSelector.hasLive(
          live,
          investmentId: investment.id,
          currency: investment.currency,
        )) {
      return null;
    }
    final adopted = InvestmentValuationSnapshot(
      id: const Uuid().v4(),
      investmentId: investment.id,
      amount: _rounded(value, investment.currency),
      currency: investment.currency,
      effectiveDate: StoredDate.fromStorage(date),
      kind: ValuationKind.carryingValue,
      provenance: ValuationProvenance.manual,
      createdAt: DateTime.now(),
    );
    await _repository.save(
      adopted,
      mirror: CompatMirror(
        investmentId: investment.id,
        value: adopted.amount,
        date: adopted.effectiveDate,
      ),
    );
    return adopted;
  }

  /// Tells the conflict check what this device wrote.
  void _written(InvestmentValuationSnapshot snapshot) =>
      ref.read(valuationConflictsProvider.notifier).recordWrite(snapshot);

  void _validateAmount(double amount) {
    if (!amount.isFinite || amount < 0) {
      // No amount in the message: it may reach logs (money rule 7).
      throw _rejected('Enter a value of 0 or more.', 'amount is invalid');
    }
  }

  DateTime _validatedDay(DateTime date) {
    final day = _dateOnly(date);
    if (day.isAfter(_dateOnly(DateTime.now()))) {
      // No date in the message either.
      throw _rejected('Date cannot be in the future.', 'date is in the future');
    }
    return day;
  }

  String _requireCurrency(String currency) {
    if (currency.trim().isEmpty) {
      throw _rejected(
        'Choose a currency for this amount.',
        'currency is blank',
      );
    }
    return currency;
  }

  double _rounded(double amount, String currency) =>
      MoneyPrecision.round(amount, currencyCode: _requireCurrency(currency));

  ValidationException _rejected(String userMessage, String why) =>
      ValidationException(
        userMessage: userMessage,
        technicalMessage: 'Validation failed: $why',
      );

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

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
      final current = await _liveSnapshot(snapshotId);
      final investment = await _writableInvestment(current.investmentId);
      final edited = current.copyWith(
        amount: amount == null
            ? null
            : _rounded(amount, _requireCurrency(current.currency)),
        effectiveDate: day,
        kind: kind,
      );
      await _save(investment, edited, await _liveSnapshotsOf(investment.id));
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
      final current = await _liveSnapshot(snapshotId);
      final investment = await _writableInvestment(current.investmentId);
      final all = await _liveSnapshotsOf(investment.id);
      final remaining = [
        for (final s in all)
          if (s.id != snapshotId) s,
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
    });
  }

  /// Clears the snapshot the investment's value comes from: its latest live
  /// one in its own currency. Returns false when it has none.
  Future<bool> clearLatestValuation(String investmentId) async {
    final investment = await ref
        .read(investmentRepositoryProvider)
        .getInvestmentById(investmentId);
    if (investment == null) {
      throw DataException.notFound('Investment', investmentId);
    }
    final latest = ValuationSnapshotSelector.mirrorOf(
      await _liveSnapshotsOf(investmentId),
      investmentId: investmentId,
      currency: investment.currency,
    );
    if (latest == null) return false;
    await clearValuation(latest.id);
    return true;
  }

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
      await _repository.restore(
        restored,
        mirror: _mirrorOf(investment, [...all, restored]),
      );
      _written(restored);
      return true;
    });
  }

  /// Confirms that the full history is now entered: an opening baseline
  /// becomes a plain value. The snapshot is kept, no cash flow is written or
  /// removed, and lifetime metrics start.
  Future<InvestmentValuationSnapshot> rebase(String snapshotId) async {
    return _run(() async {
      final current = await _liveSnapshot(snapshotId);
      if (!current.isOpeningBaseline) {
        throw _rejected(
          'Only an opening value can be replaced by full history.',
          'rebase of a snapshot that is not a baseline',
        );
      }
      final investment = await _writableInvestment(current.investmentId);
      final rebased = current.copyWith(provenance: ValuationProvenance.manual);
      await _save(investment, rebased, await _liveSnapshotsOf(investment.id));
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
    final all = [
      for (final s in others)
        if (s.id != snapshot.id) s,
      snapshot,
    ];
    await _repository.save(snapshot, mirror: _mirrorOf(investment, all));
    _written(snapshot);
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
  /// when offline, like the other reads of the notifiers).
  Future<List<InvestmentValuationSnapshot>> _liveSnapshotsOf(
    String investmentId,
  ) async => [
    for (final s in await _repository.getAll())
      if (s.investmentId == investmentId && s.isLive) s,
  ];

  Future<InvestmentValuationSnapshot> _liveSnapshot(String id) async {
    for (final s in await _repository.getAll()) {
      if (s.id == id && s.isLive) return s;
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
      effectiveDate: _dateOnly(date),
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

import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';

/// What an investment's `currentValue` and `currentValueDate` must read after
/// a snapshot write: the latest live snapshot, or nothing. It is written in
/// the same batch as the snapshot, so older app versions and every reader of
/// the pair see one consistent value.
class CompatMirror {
  final String investmentId;

  /// Null clears the pair.
  final double? value;

  /// Date-only; null exactly when [value] is.
  final DateTime? date;

  const CompatMirror({required this.investmentId, this.value, this.date})
    : assert((value == null) == (date == null));

  /// The pair mirroring [latest], the latest live snapshot of the
  /// investment, or clearing it when there is none.
  factory CompatMirror.of(
    String investmentId,
    InvestmentValuationSnapshot? latest,
  ) => CompatMirror(
    investmentId: investmentId,
    value: latest?.amount,
    date: latest?.effectiveDate,
  );
}

/// Dated valuation snapshots of the user's investments, kept apart from cash
/// flows. A snapshot is never a cash flow and never money received.
///
/// Every write is a whole-document write, so that a document another device
/// deleted for good is not half re-created, and carries the [CompatMirror]
/// the investment document must read afterwards.
abstract class ValuationRepository {
  /// Every snapshot of the user, cleared ones included, as it changes.
  /// Documents that cannot be trusted (see the mapper) are left out.
  Stream<List<InvestmentValuationSnapshot>> watchAll();

  Future<List<InvestmentValuationSnapshot>> getAll();

  /// Writes [snapshot] (a new one or an edit) and [mirror] in one batch.
  Future<void> save(
    InvestmentValuationSnapshot snapshot, {
    required CompatMirror mirror,
  });

  /// Clears [snapshot] (kept as a tombstone, so a clear and an edit from two
  /// devices converge and Undo can restore it) and writes [mirror] in one
  /// batch.
  Future<void> softDelete(
    InvestmentValuationSnapshot snapshot, {
    required CompatMirror mirror,
  });

  /// Brings a cleared [snapshot] back and writes [mirror] in one batch.
  Future<void> restore(
    InvestmentValuationSnapshot snapshot, {
    required CompatMirror mirror,
  });

  /// Writes imported snapshots as given (their update time included, so that
  /// same-day ties survive) in chunks, and returns how many were written. The
  /// caller writes the investments' mirrors.
  Future<int> importAll(List<InvestmentValuationSnapshot> snapshots);
}

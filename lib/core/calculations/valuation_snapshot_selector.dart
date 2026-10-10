import 'package:inv_tracker/core/utils/stored_date.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';

/// The valuation that applies to an investment on a day.
class ValuationCandidate {
  final double amount;

  /// Date-only effective date.
  final DateTime date;
  final ValuationKind kind;
  final ValuationProvenance provenance;

  /// Null for the investment's `currentValue` pair (the compat candidate).
  final String? snapshotId;

  const ValuationCandidate({
    required this.amount,
    required this.date,
    required this.kind,
    required this.provenance,
    required this.snapshotId,
  });

  /// Whether this is the investment's `currentValue` pair, written by an
  /// older app version or by the dialog used while the feature was off.
  bool get isCompat => snapshotId == null;
}

/// Picks the valuation that applies to an investment on a day: the single
/// implementation of "which snapshot" (money rule 3). Pure; snapshots are
/// history and are never summed.
abstract final class ValuationSnapshotSelector {
  /// The most snapshots of one investment the app writes. Readers tolerate
  /// more.
  static const maxLiveSnapshots = 100;

  /// The valuation that applies to [investment] on the day [asOf]:
  ///
  /// 1. The latest live snapshot in the investment's currency dated on or
  ///    before [asOf]. Same-day snapshots are ordered by `updatedAt` (a
  ///    write still on its way counts as the newest), then by id.
  /// 2. The `currentValue` pair of the investment is one more candidate, so
  ///    that an older app version or the legacy dialog still works. A pair
  ///    equal to the latest snapshot is ignored. A different pair counts
  ///    only if the investment document was written after that snapshot,
  ///    which the batches of this app never do (they share one server
  ///    timestamp), and then it wins when it is dated later, when it has the
  ///    same date and another amount, or when it is null (a clear). A pair
  ///    dated earlier than the snapshot, or after [asOf], is ignored.
  ///
  /// Null when nothing applies: no snapshot is dated yet, or the value was
  /// cleared by an older app.
  static ValuationCandidate? select({
    required InvestmentEntity investment,
    required Iterable<InvestmentValuationSnapshot> snapshots,
    required DateTime asOf,
  }) {
    final today = _dateOnly(asOf);
    InvestmentValuationSnapshot? latest;
    for (final s in snapshots) {
      if (!applies(s, investment.id, investment.currency)) continue;
      if (_dateOnly(s.effectiveDate).isAfter(today)) continue;
      if (latest == null || compare(s, latest) > 0) latest = s;
    }

    final compat = _compat(investment);
    if (latest == null) {
      if (compat == null || compat.date.isAfter(today)) return null;
      return _compatCandidate(compat);
    }

    final latestDate = _dateOnly(latest.effectiveDate);
    final written = latest.updatedAt;
    // A write still on its way is the newest, so nothing overrules it.
    final compatWrittenAfter =
        written != null && investment.updatedAt.isAfter(written);
    if (compat == null) return compatWrittenAfter ? null : _candidate(latest);
    if (compat.amount == latest.amount && compat.date == latestDate) {
      return _candidate(latest);
    }
    if (!compatWrittenAfter || compat.date.isAfter(today)) {
      return _candidate(latest);
    }
    // Dated later, or the same day with another amount (equal pairs are
    // handled above); an earlier date is stale.
    return compat.date.isBefore(latestDate)
        ? _candidate(latest)
        : _compatCandidate(compat);
  }

  /// Whether [snapshot] is a live valuation of the investment [investmentId]
  /// in [currency]. A snapshot in another currency is kept as history but
  /// never used (money rule 2).
  static bool applies(
    InvestmentValuationSnapshot snapshot,
    String investmentId,
    String currency,
  ) =>
      snapshot.isLive &&
      snapshot.investmentId == investmentId &&
      snapshot.currency == currency &&
      snapshot.amount.isFinite &&
      snapshot.amount >= 0;

  /// Whether any live snapshot of the investment in its currency exists,
  /// whatever its date.
  static bool hasLive(
    Iterable<InvestmentValuationSnapshot> snapshots, {
    required String investmentId,
    required String currency,
  }) => snapshots.any((s) => applies(s, investmentId, currency));

  /// The live opening baseline of the investment in [currency], or null. A
  /// second one can only come from two devices writing at once; the newest
  /// is used.
  ///
  /// With [asOf], a baseline dated after that day has not started yet and is
  /// not returned, like [select] leaves out a snapshot dated after it. Readers
  /// that value or measure as of a day pass it; checks that only ask whether
  /// the investment already has a baseline (at most one) do not.
  static InvestmentValuationSnapshot? openingBaseline(
    Iterable<InvestmentValuationSnapshot> snapshots, {
    required String investmentId,
    required String currency,
    DateTime? asOf,
  }) {
    final today = asOf == null ? null : _dateOnly(asOf);
    return _latest(
      snapshots.where(
        (s) =>
            s.isOpeningBaseline &&
            applies(s, investmentId, currency) &&
            (today == null || !_dateOnly(s.effectiveDate).isAfter(today)),
      ),
    );
  }

  /// The snapshot the investment's `currentValue` pair must mirror: the
  /// latest live snapshot in [currency], whatever its date, or null.
  static InvestmentValuationSnapshot? mirrorOf(
    Iterable<InvestmentValuationSnapshot> snapshots, {
    required String investmentId,
    required String currency,
  }) => _latest(snapshots.where((s) => applies(s, investmentId, currency)));

  /// Orders snapshots: effective date, then `updatedAt` (null, a write that
  /// has not reached the server, is the newest), then id. Positive when [a]
  /// is the later one. Total and independent of input order.
  static int compare(
    InvestmentValuationSnapshot a,
    InvestmentValuationSnapshot b,
  ) {
    final byDate = _dateOnly(
      a.effectiveDate,
    ).compareTo(_dateOnly(b.effectiveDate));
    if (byDate != 0) return byDate;
    final au = a.updatedAt;
    final bu = b.updatedAt;
    if (au == null && bu != null) return 1;
    if (au != null && bu == null) return -1;
    if (au != null && bu != null) {
      final byWrite = au.compareTo(bu);
      if (byWrite != 0) return byWrite;
    }
    return a.id.compareTo(b.id);
  }

  static InvestmentValuationSnapshot? _latest(
    Iterable<InvestmentValuationSnapshot> snapshots,
  ) {
    InvestmentValuationSnapshot? latest;
    for (final s in snapshots) {
      if (latest == null || compare(s, latest) > 0) latest = s;
    }
    return latest;
  }

  static ValuationCandidate _candidate(InvestmentValuationSnapshot s) =>
      ValuationCandidate(
        amount: s.amount,
        date: _dateOnly(s.effectiveDate),
        kind: s.kind,
        provenance: s.provenance,
        snapshotId: s.id,
      );

  static ValuationCandidate _compatCandidate(
    ({double amount, DateTime date}) compat,
  ) => ValuationCandidate(
    amount: compat.amount,
    date: compat.date,
    // A legacy value is read as a carrying value, so that existing XIRR and
    // MOIC do not move.
    kind: ValuationKind.carryingValue,
    provenance: ValuationProvenance.manual,
    snapshotId: null,
  );

  /// The investment's `currentValue` pair, or null when it has none. Its date
  /// is read through [StoredDate], like the snapshot dates it competes with.
  static ({double amount, DateTime date})? _compat(
    InvestmentEntity investment,
  ) {
    final value = investment.currentValue;
    final date = investment.currentValueDate;
    if (value == null || date == null || !value.isFinite || value < 0) {
      return null;
    }
    return (amount: value, date: StoredDate.fromStorage(date));
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

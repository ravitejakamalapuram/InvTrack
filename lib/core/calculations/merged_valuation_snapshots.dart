import 'package:inv_tracker/core/calculations/valuation_snapshot_selector.dart';
import 'package:inv_tracker/core/utils/money_precision.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';

/// The dated valuations of an investment made by merging others. Snapshots
/// are history and are never summed in place, so a merge cannot just move
/// them: the merged investment is worth the sum of what each source was worth
/// on a day.
abstract final class MergedValuationSnapshots {
  /// One snapshot of the merged investment [mergedId] for every date on which
  /// every source has a live valuation: the sum of each source's latest live
  /// valuation on or before that date. A date on which a source has none yet
  /// gets no snapshot, because a partial total would understate the value.
  ///
  /// Empty when a source has no live valuation, or the sources' valuations
  /// are in more than one currency. Kinds that differ become a market value
  /// (which is never rolled forward); only the earliest total can be an
  /// opening baseline, and only when a source's valuation there is one.
  static List<InvestmentValuationSnapshot> combine({
    required Iterable<InvestmentValuationSnapshot> snapshots,
    required List<String> sourceIds,
    required String mergedId,
    required String Function() newId,
    required DateTime now,
  }) {
    final bySource = <String, List<InvestmentValuationSnapshot>>{
      for (final id in sourceIds) id: [],
    };
    for (final s in snapshots) {
      if (s.isLive && s.amount.isFinite && s.amount >= 0) {
        bySource[s.investmentId]?.add(s);
      }
    }
    if (bySource.values.any((l) => l.isEmpty)) return const [];
    final currencies = {
      for (final l in bySource.values)
        for (final s in l) s.currency,
    };
    if (currencies.length != 1) return const [];
    final currency = currencies.single;

    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final dates = {
      for (final l in bySource.values)
        for (final s in l) dateOnly(s.effectiveDate),
    }.toList()..sort();

    final merged = <InvestmentValuationSnapshot>[];
    for (final date in dates) {
      final latest = <InvestmentValuationSnapshot>[];
      for (final l in bySource.values) {
        InvestmentValuationSnapshot? best;
        for (final s in l) {
          if (dateOnly(s.effectiveDate).isAfter(date)) continue;
          if (best == null || ValuationSnapshotSelector.compare(s, best) > 0) {
            best = s;
          }
        }
        if (best == null) break;
        latest.add(best);
      }
      if (latest.length != bySource.length) continue;

      final kinds = {for (final s in latest) s.kind};
      final baseline = merged.isEmpty && latest.any((s) => s.isOpeningBaseline);
      merged.add(
        InvestmentValuationSnapshot(
          id: newId(),
          investmentId: mergedId,
          amount: MoneyPrecision.round(
            latest.fold<double>(0, (sum, s) => sum + s.amount),
            currencyCode: currency,
          ),
          currency: currency,
          effectiveDate: date,
          kind: kinds.length == 1 ? kinds.single : ValuationKind.marketValue,
          provenance: baseline
              ? ValuationProvenance.openingBaseline
              : ValuationProvenance.manual,
          createdAt: now,
        ),
      );
    }
    return merged;
  }
}

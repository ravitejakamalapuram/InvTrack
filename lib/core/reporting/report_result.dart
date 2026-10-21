/// The immutable output of the engine. Typed values only: formatting,
/// privacy masking and export happen in renderers.
library;

import 'package:inv_tracker/core/reporting/metric_value.dart';
import 'package:inv_tracker/core/reporting/report_definition.dart';
import 'package:inv_tracker/core/reporting/report_period.dart';

enum ReportNoteKind {
  /// Cash flows left out because they have no exchange rate to the base
  /// currency; [ReportNote.count] says how many.
  excludedFlows,

  /// Archived investments left out on purpose (money rule 9).
  archivedExcluded,
}

class ReportNote {
  final ReportNoteKind kind;
  final int count;
  const ReportNote(this.kind, this.count);

  @override
  bool operator ==(Object other) =>
      other is ReportNote && other.kind == kind && other.count == count;

  @override
  int get hashCode => Object.hash(kind, count);
}

class BreakdownRow {
  /// Investment type name, currency code, or the month as `yyyy-MM`.
  final String key;
  final Map<ReportMetric, MetricValue> values;
  BreakdownRow(this.key, Map<ReportMetric, MetricValue> values)
    : values = Map.unmodifiable(values);
}

class ReportResult {
  final String definitionId;
  final ReportPeriod period;
  final String baseCurrency;
  final DateTime generatedAt;
  final Map<ReportMetric, MetricValue> totals;

  /// Flow metrics of the previous period, or null when not compared.
  final Map<ReportMetric, MetricValue>? previous;
  final Map<Breakdown, List<BreakdownRow>> breakdowns;
  final List<ReportNote> notes;

  ReportResult({
    required this.definitionId,
    required this.period,
    required this.baseCurrency,
    required this.generatedAt,
    required Map<ReportMetric, MetricValue> totals,
    Map<ReportMetric, MetricValue>? previous,
    required Map<Breakdown, List<BreakdownRow>> breakdowns,
    required List<ReportNote> notes,
  }) : totals = Map.unmodifiable(totals),
       previous = previous == null ? null : Map.unmodifiable(previous),
       breakdowns = Map<Breakdown, List<BreakdownRow>>.unmodifiable({
         for (final e in breakdowns.entries)
           e.key: List<BreakdownRow>.unmodifiable(e.value),
       }),
       notes = List.unmodifiable(notes);

  /// Current minus previous, known only when both are known.
  MetricValue change(ReportMetric metric) {
    final now = totals[metric]?.valueOrNull;
    final before = previous?[metric]?.valueOrNull;
    if (now == null || before == null) {
      return const Unknown(UnknownReason.notApplicable);
    }
    return Known(now - before);
  }

  /// Percent change (20.0 = +20%), unknown when either side is unknown or the
  /// previous value is 0 (no base to compare against).
  MetricValue changePercent(ReportMetric metric) {
    final now = totals[metric]?.valueOrNull;
    final before = previous?[metric]?.valueOrNull;
    if (now == null || before == null || before == 0) {
      return const Unknown(UnknownReason.notApplicable);
    }
    return Known((now - before) / before.abs() * 100);
  }
}

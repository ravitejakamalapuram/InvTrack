/// The time window of a report: a half-open range [start, endExclusive) of
/// date-only local days (money rule 5). All arithmetic is calendar-based
/// (`DateTime(y, m, d + n)`), never `Duration(days:)`, so a DST change cannot
/// shift a boundary.
library;

import 'package:inv_tracker/core/utils/financial_year.dart';

enum ReportPeriodKind { week, month, quarter, fy, custom }

class ReportPeriod {
  final ReportPeriodKind kind;

  /// First day of the period, date-only.
  final DateTime start;

  /// First day after the period, date-only.
  final DateTime endExclusive;

  const ReportPeriod._(this.kind, this.start, this.endExclusive);

  /// The week containing [anchor], starting on [weekStart]
  /// (`DateTime.monday`..`DateTime.sunday`).
  factory ReportPeriod.week(
    DateTime anchor, {
    int weekStart = DateTime.monday,
  }) {
    if (weekStart < DateTime.monday || weekStart > DateTime.sunday) {
      throw ArgumentError.value(weekStart, 'weekStart', 'must be 1..7');
    }
    final day = _day(anchor);
    final back = (day.weekday - weekStart + 7) % 7;
    final start = DateTime(day.year, day.month, day.day - back);
    return ReportPeriod._(
      ReportPeriodKind.week,
      start,
      DateTime(start.year, start.month, start.day + 7),
    );
  }

  factory ReportPeriod.month(int year, int month) => ReportPeriod._(
    ReportPeriodKind.month,
    DateTime(year, month, 1),
    DateTime(year, month + 1, 1),
  );

  /// Calendar quarter [quarter] (1..4) of [year].
  factory ReportPeriod.quarter(int year, int quarter) {
    if (quarter < 1 || quarter > 4) {
      throw ArgumentError.value(quarter, 'quarter', 'must be 1..4');
    }
    final m = (quarter - 1) * 3 + 1;
    return ReportPeriod._(
      ReportPeriodKind.quarter,
      DateTime(year, m, 1),
      DateTime(year, m + 3, 1),
    );
  }

  /// The Indian financial year starting 1 April [startYear].
  factory ReportPeriod.fy(int startYear) => ReportPeriod._(
    ReportPeriodKind.fy,
    DateTime(startYear, DateTime.april, 1),
    DateTime(startYear + 1, DateTime.april, 1),
  );

  /// [start] to [endInclusive], both days included; time of day is dropped.
  factory ReportPeriod.custom(DateTime start, DateTime endInclusive) {
    final s = _day(start);
    final e = _day(endInclusive);
    if (e.isBefore(s)) {
      throw ArgumentError('end $e is before start $s');
    }
    return ReportPeriod._(
      ReportPeriodKind.custom,
      s,
      FinancialYear.dayAfter(e),
    );
  }

  /// The period of [kind] that contains [day]. Not for [ReportPeriodKind.custom].
  factory ReportPeriod.containing(
    ReportPeriodKind kind,
    DateTime day, {
    int weekStart = DateTime.monday,
  }) {
    final d = _day(day);
    switch (kind) {
      case ReportPeriodKind.week:
        return ReportPeriod.week(d, weekStart: weekStart);
      case ReportPeriodKind.month:
        return ReportPeriod.month(d.year, d.month);
      case ReportPeriodKind.quarter:
        return ReportPeriod.quarter(d.year, (d.month - 1) ~/ 3 + 1);
      case ReportPeriodKind.fy:
        return ReportPeriod.fy(FinancialYear.startOf(d).year);
      case ReportPeriodKind.custom:
        throw ArgumentError('A custom period has no containing period');
    }
  }

  /// Whether [date]'s calendar day is in [start, endExclusive).
  bool contains(DateTime date) =>
      FinancialYear.contains(start, endExclusive, date);

  /// Calendar days in the period (DST-proof).
  int get dayCount => DateTime.utc(
    endExclusive.year,
    endExclusive.month,
    endExclusive.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;

  /// Every day of the period, date-only.
  List<DateTime> days() => [
    for (var i = 0; i < dayCount; i++)
      DateTime(start.year, start.month, start.day + i),
  ];

  /// The first day of each calendar month the period touches.
  List<DateTime> months() {
    final out = <DateTime>[];
    var m = DateTime(start.year, start.month, 1);
    while (m.isBefore(endExclusive)) {
      out.add(m);
      m = DateTime(m.year, m.month + 1, 1);
    }
    return out;
  }

  /// The period of the same kind immediately before this one. A custom period
  /// is followed back by one of the same length.
  ReportPeriod previous() {
    switch (kind) {
      case ReportPeriodKind.week:
        return ReportPeriod._(
          kind,
          DateTime(start.year, start.month, start.day - 7),
          start,
        );
      case ReportPeriodKind.month:
        return ReportPeriod.month(start.year, start.month - 1);
      case ReportPeriodKind.quarter:
        return ReportPeriod._(
          kind,
          DateTime(start.year, start.month - 3, 1),
          start,
        );
      case ReportPeriodKind.fy:
        return ReportPeriod.fy(start.year - 1);
      case ReportPeriodKind.custom:
        return ReportPeriod._(
          kind,
          DateTime(start.year, start.month, start.day - dayCount),
          start,
        );
    }
  }

  /// "2023-24" for a financial year.
  String get fyLabel =>
      '${start.year}-${((start.year + 1) % 100).toString().padLeft(2, '0')}';

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  bool operator ==(Object other) =>
      other is ReportPeriod &&
      other.kind == kind &&
      other.start == start &&
      other.endExclusive == endExclusive;

  @override
  int get hashCode => Object.hash(kind, start, endExclusive);

  @override
  String toString() => 'ReportPeriod($kind, $start, $endExclusive)';
}

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/reporting/report_period.dart';

void main() {
  group('fy', () {
    test('is the half-open range 1 Apr to next 1 Apr', () {
      final p = ReportPeriod.fy(2023);
      expect(p.kind, ReportPeriodKind.fy);
      expect(p.start, DateTime(2023, 4, 1));
      expect(p.endExclusive, DateTime(2024, 4, 1));
    });
    test('31 Mar is inside, 1 Apr is outside', () {
      final p = ReportPeriod.fy(2023);
      expect(p.contains(DateTime(2024, 3, 31, 23, 59)), isTrue);
      expect(p.contains(DateTime(2024, 4, 1)), isFalse);
      expect(p.contains(DateTime(2023, 3, 31, 23, 59)), isFalse);
      expect(p.contains(DateTime(2023, 4, 1)), isTrue);
    });
    test('29 Feb is inside the FY that spans it', () {
      expect(ReportPeriod.fy(2023).contains(DateTime(2024, 2, 29)), isTrue);
      expect(ReportPeriod.fy(2023).dayCount, 366);
      expect(ReportPeriod.fy(2024).dayCount, 365);
    });
    test('containing picks the FY by month', () {
      expect(
        ReportPeriod.containing(ReportPeriodKind.fy, DateTime(2024, 3, 31)),
        ReportPeriod.fy(2023),
      );
      expect(
        ReportPeriod.containing(ReportPeriodKind.fy, DateTime(2024, 4, 1)),
        ReportPeriod.fy(2024),
      );
    });
    test('label is 2023-24', () {
      expect(ReportPeriod.fy(2023).fyLabel, '2023-24');
      expect(ReportPeriod.fy(1999).fyLabel, '1999-00');
    });
  });

  group('month', () {
    test('lengths including leap February', () {
      expect(ReportPeriod.month(2024, 2).dayCount, 29);
      expect(ReportPeriod.month(2023, 2).dayCount, 28);
      expect(ReportPeriod.month(2023, 12).endExclusive, DateTime(2024, 1, 1));
    });
    test('previous crosses the year boundary', () {
      expect(
        ReportPeriod.month(2024, 1).previous(),
        ReportPeriod.month(2023, 12),
      );
    });
  });

  group('quarter', () {
    test('calendar quarters', () {
      final q = ReportPeriod.quarter(2024, 4);
      expect(q.start, DateTime(2024, 10, 1));
      expect(q.endExclusive, DateTime(2025, 1, 1));
      expect(
        ReportPeriod.quarter(2024, 1).previous(),
        ReportPeriod.quarter(2023, 4),
      );
    });
  });

  group('week', () {
    test('Monday start by default', () {
      // Wed 2024-05-15
      final p = ReportPeriod.week(DateTime(2024, 5, 15));
      expect(p.start, DateTime(2024, 5, 13));
      expect(p.endExclusive, DateTime(2024, 5, 20));
      expect(p.dayCount, 7);
    });
    test('Sunday is the last day of a Monday week', () {
      final p = ReportPeriod.week(DateTime(2024, 5, 19));
      expect(p.start, DateTime(2024, 5, 13));
    });
    test('configurable week start', () {
      final p = ReportPeriod.week(
        DateTime(2024, 5, 15),
        weekStart: DateTime.sunday,
      );
      expect(p.start, DateTime(2024, 5, 12));
      final s = ReportPeriod.week(
        DateTime(2024, 5, 12),
        weekStart: DateTime.sunday,
      );
      expect(s.start, DateTime(2024, 5, 12));
    });
    test('week across new year', () {
      final p = ReportPeriod.week(DateTime(2025, 1, 1));
      expect(p.start, DateTime(2024, 12, 30));
      expect(p.endExclusive, DateTime(2025, 1, 6));
    });
    test('previous is exactly seven days earlier', () {
      final p = ReportPeriod.week(DateTime(2024, 3, 12));
      expect(p.previous().start, DateTime(2024, 3, 4));
      expect(p.previous().endExclusive, p.start);
    });
    test('stays 7 calendar days over DST changes in any zone', () {
      // US spring-forward (2024-03-10) and fall-back (2024-11-03) weeks.
      final spring = ReportPeriod.week(DateTime(2024, 3, 10));
      expect(spring.start, DateTime(2024, 3, 4));
      expect(spring.endExclusive, DateTime(2024, 3, 11));
      expect(spring.dayCount, 7);
      expect(spring.days().length, 7);
      final fall = ReportPeriod.week(DateTime(2024, 11, 3));
      expect(fall.start, DateTime(2024, 10, 28));
      expect(fall.endExclusive, DateTime(2024, 11, 4));
      expect(fall.dayCount, 7);
      expect(fall.days().length, 7);
      // EU autumn change.
      expect(ReportPeriod.week(DateTime(2024, 10, 27)).dayCount, 7);
    });
    test('rejects a bad week start', () {
      expect(
        () => ReportPeriod.week(DateTime(2024, 1, 1), weekStart: 0),
        throwsArgumentError,
      );
    });
  });

  group('custom', () {
    test('end is inclusive on input, exclusive in the value', () {
      final p = ReportPeriod.custom(
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 31),
      );
      expect(p.endExclusive, DateTime(2024, 2, 1));
      expect(p.dayCount, 31);
    });
    test('time of day is dropped', () {
      final p = ReportPeriod.custom(
        DateTime(2024, 1, 1, 23, 59),
        DateTime(2024, 1, 1, 0, 1),
      );
      expect(p.dayCount, 1);
    });
    test('end before start throws', () {
      expect(
        () => ReportPeriod.custom(DateTime(2024, 2, 1), DateTime(2024, 1, 1)),
        throwsArgumentError,
      );
    });
    test('previous is the same length immediately before', () {
      final p = ReportPeriod.custom(
        DateTime(2024, 3, 1),
        DateTime(2024, 3, 10),
      );
      final prev = p.previous();
      expect(prev.endExclusive, p.start);
      expect(prev.dayCount, 10);
    });
  });

  group('validation and remaining paths', () {
    test('month rejects values outside 1..12', () {
      expect(() => ReportPeriod.month(2024, 0), throwsArgumentError);
      expect(() => ReportPeriod.month(2024, 13), throwsArgumentError);
    });
    test('quarter rejects values outside 1..4', () {
      expect(() => ReportPeriod.quarter(2024, 0), throwsArgumentError);
      expect(() => ReportPeriod.quarter(2024, 5), throwsArgumentError);
    });
    test('fy previous is the prior financial year', () {
      expect(ReportPeriod.fy(2023).previous(), ReportPeriod.fy(2022));
    });
    test('containing week, month, quarter', () {
      expect(
        ReportPeriod.containing(ReportPeriodKind.week, DateTime(2024, 5, 15)),
        ReportPeriod.week(DateTime(2024, 5, 15)),
      );
      expect(
        ReportPeriod.containing(ReportPeriodKind.month, DateTime(2024, 5, 15)),
        ReportPeriod.month(2024, 5),
      );
      expect(
        ReportPeriod.containing(
          ReportPeriodKind.quarter,
          DateTime(2024, 5, 15),
        ),
        ReportPeriod.quarter(2024, 2),
      );
    });
    test('containing custom throws', () {
      expect(
        () => ReportPeriod.containing(
          ReportPeriodKind.custom,
          DateTime(2024, 5, 15),
        ),
        throwsArgumentError,
      );
    });
  });

  group('months()', () {
    test('lists each calendar month touched', () {
      expect(ReportPeriod.fy(2023).months(), [
        for (var m = 4; m <= 12; m++) DateTime(2023, m, 1),
        DateTime(2024, 1, 1),
        DateTime(2024, 2, 1),
        DateTime(2024, 3, 1),
      ]);
      expect(
        ReportPeriod.custom(
          DateTime(2024, 1, 31),
          DateTime(2024, 2, 1),
        ).months(),
        [DateTime(2024, 1, 1), DateTime(2024, 2, 1)],
      );
    });
  });

  test('equality and hashCode', () {
    expect(ReportPeriod.month(2024, 5), ReportPeriod.month(2024, 5));
    expect(
      ReportPeriod.month(2024, 5).hashCode,
      ReportPeriod.month(2024, 5).hashCode,
    );
    expect(ReportPeriod.month(2024, 5), isNot(ReportPeriod.month(2024, 6)));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';

void main() {
  group('AppDateUtils', () {
    group('formatRelative', () {
      test('returns "today" for current date', () {
        final now = DateTime.now();
        expect(AppDateUtils.formatRelative(now), 'today');
      });

      test('returns "yesterday" for yesterday', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        expect(AppDateUtils.formatRelative(yesterday), 'yesterday');
      });

      test('returns days ago for recent dates', () {
        final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
        expect(AppDateUtils.formatRelative(threeDaysAgo), '3 days ago');
      });

      test('returns weeks ago for dates within a month', () {
        final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
        expect(AppDateUtils.formatRelative(twoWeeksAgo), '2 weeks ago');
      });

      test('returns "1 week ago" singular', () {
        final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
        expect(AppDateUtils.formatRelative(oneWeekAgo), '1 week ago');
      });

      test('returns months ago for dates within a year', () {
        final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
        expect(AppDateUtils.formatRelative(threeMonthsAgo), '3 months ago');
      });

      test('returns "1 month ago" singular', () {
        final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
        expect(AppDateUtils.formatRelative(oneMonthAgo), '1 month ago');
      });

      test('returns years ago for old dates', () {
        final twoYearsAgo = DateTime.now().subtract(const Duration(days: 730));
        expect(AppDateUtils.formatRelative(twoYearsAgo), '2 years ago');
      });

      test('returns "1 year ago" singular', () {
        final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
        expect(AppDateUtils.formatRelative(oneYearAgo), '1 year ago');
      });
    });

    group('formatShort', () {
      test('formats date as "MMM d, y"', () {
        final date = DateTime(2024, 12, 25);
        expect(AppDateUtils.formatShort(date), 'Dec 25, 2024');
      });

      test('formats single digit day correctly', () {
        final date = DateTime(2024, 1, 5);
        expect(AppDateUtils.formatShort(date), 'Jan 5, 2024');
      });
    });

    group('formatLong', () {
      test('formats date as "MMMM d, yyyy"', () {
        final date = DateTime(2024, 12, 25);
        expect(AppDateUtils.formatLong(date), 'December 25, 2024');
      });

      test('formats all months correctly', () {
        expect(AppDateUtils.formatLong(DateTime(2024, 1, 1)), contains('January'));
        expect(AppDateUtils.formatLong(DateTime(2024, 6, 15)), contains('June'));
        expect(AppDateUtils.formatLong(DateTime(2024, 12, 31)), contains('December'));
      });
    });

    group('formatDayOfWeek', () {
      test('returns full day name', () {
        // December 25, 2024 is a Wednesday
        final date = DateTime(2024, 12, 25);
        expect(AppDateUtils.formatDayOfWeek(date), 'Wednesday');
      });

      test('returns correct day for different dates', () {
        // January 1, 2024 is a Monday
        final monday = DateTime(2024, 1, 1);
        expect(AppDateUtils.formatDayOfWeek(monday), 'Monday');

        // January 6, 2024 is a Saturday
        final saturday = DateTime(2024, 1, 6);
        expect(AppDateUtils.formatDayOfWeek(saturday), 'Saturday');
      });
    });

    group('formatMonthYear', () {
      test('formats as "MMM yyyy"', () {
        final date = DateTime(2024, 12, 25);
        expect(AppDateUtils.formatMonthYear(date), 'Dec 2024');
      });

      test('works for different months', () {
        expect(AppDateUtils.formatMonthYear(DateTime(2024, 1, 1)), 'Jan 2024');
        expect(AppDateUtils.formatMonthYear(DateTime(2024, 6, 15)), 'Jun 2024');
      });
    });

    group('formatMonth', () {
      test('returns abbreviated month name', () {
        final date = DateTime(2024, 12, 25);
        expect(AppDateUtils.formatMonth(date), 'Dec');
      });

      test('returns 3-letter abbreviation', () {
        expect(AppDateUtils.formatMonth(DateTime(2024, 1, 1)), 'Jan');
        expect(AppDateUtils.formatMonth(DateTime(2024, 9, 15)), 'Sep');
      });
    });
  });
}


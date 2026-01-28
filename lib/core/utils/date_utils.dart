import 'package:intl/intl.dart';

/// Utility class for date formatting and manipulation
class AppDateUtils {
  AppDateUtils._();

  /// Formats a date as a relative string (e.g., "today", "yesterday", "3 days ago")
  /// Falls back to "MMM d, y" format for dates older than a week
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      final years = (diff.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
  }

  // OPTIMIZATION: Cache DateFormat instances to avoid expensive parsing and allocation on every call.
  // Note: These static instances capture the locale at the time of first access.
  // If the app supports dynamic locale switching, these would need to be re-initialized.
  static final _shortFormat = DateFormat('MMM d, y');
  static final _longFormat = DateFormat('MMMM d, yyyy');
  static final _dayOfWeekFormat = DateFormat('EEEE');
  static final _monthYearFormat = DateFormat('MMM yyyy');
  static final _monthFormat = DateFormat('MMM');

  /// Formats a date as "MMM d, y" (e.g., "Dec 19, 2025")
  static String formatShort(DateTime date) {
    return _shortFormat.format(date);
  }

  /// Formats a date as "MMMM d, yyyy" (e.g., "December 19, 2025")
  static String formatLong(DateTime date) {
    return _longFormat.format(date);
  }

  /// Formats a date as "EEEE" (e.g., "Friday")
  static String formatDayOfWeek(DateTime date) {
    return _dayOfWeekFormat.format(date);
  }

  /// Formats a date as "MMM yyyy" (e.g., "Dec 2025") - useful for charts
  static String formatMonthYear(DateTime date) {
    return _monthYearFormat.format(date);
  }

  /// Formats a date as "MMM" (e.g., "Dec") - useful for compact charts
  static String formatMonth(DateTime date) {
    return _monthFormat.format(date);
  }
}

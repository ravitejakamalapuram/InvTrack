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

  /// Formats a date as "MMM d, y" (e.g., "Dec 19, 2025")
  static String formatShort(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  /// Formats a date as "MMMM d, yyyy" (e.g., "December 19, 2025")
  static String formatLong(DateTime date) {
    return DateFormat('MMMM d, yyyy').format(date);
  }

  /// Formats a date as "EEEE" (e.g., "Friday")
  static String formatDayOfWeek(DateTime date) {
    return DateFormat('EEEE').format(date);
  }

  /// Formats a date as "MMM yyyy" (e.g., "Dec 2025") - useful for charts
  static String formatMonthYear(DateTime date) {
    return DateFormat('MMM yyyy').format(date);
  }

  /// Formats a date as "MMM" (e.g., "Dec") - useful for compact charts
  static String formatMonth(DateTime date) {
    return DateFormat('MMM').format(date);
  }
}

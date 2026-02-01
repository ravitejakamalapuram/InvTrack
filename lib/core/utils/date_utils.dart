import 'package:intl/intl.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';

/// Utility class for date formatting and manipulation
class AppDateUtils {
  AppDateUtils._();

  /// Formats a date as a relative string (e.g., "today", "yesterday", "3 days ago")
  /// Falls back to locale-aware short format for dates older than a week
  static String formatRelative(DateTime date, {String? locale}) {
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
  /// Locale-aware: uses provided locale or defaults to system locale
  static String formatShort(DateTime date, {String? locale}) {
    final format = DateFormat('MMM d, y', locale);
    return format.format(date);
  }

  /// Formats a date as "MMMM d, yyyy" (e.g., "December 19, 2025")
  /// Locale-aware: uses provided locale or defaults to system locale
  static String formatLong(DateTime date, {String? locale}) {
    final format = DateFormat('MMMM d, yyyy', locale);
    return format.format(date);
  }

  /// Formats a date as "EEEE" (e.g., "Friday")
  /// Locale-aware: uses provided locale or defaults to system locale
  static String formatDayOfWeek(DateTime date, {String? locale}) {
    final format = DateFormat('EEEE', locale);
    return format.format(date);
  }

  /// Formats a date as "MMM yyyy" (e.g., "Dec 2025") - useful for charts
  /// Locale-aware: uses provided locale or defaults to system locale
  static String formatMonthYear(DateTime date, {String? locale}) {
    final format = DateFormat('MMM yyyy', locale);
    return format.format(date);
  }

  /// Formats a date as "MMM" (e.g., "Dec") - useful for compact charts
  /// Locale-aware: uses provided locale or defaults to system locale
  static String formatMonth(DateTime date, {String? locale}) {
    final format = DateFormat('MMM', locale);
    return format.format(date);
  }

  /// Format date based on user's preferred date format pattern
  /// Returns date in format based on DateFormatPattern (MDY, DMY, or YMD)
  static String formatByPattern(
    DateTime date,
    DateFormatPattern pattern, {
    String? locale,
  }) {
    switch (pattern) {
      case DateFormatPattern.mdy:
        // US format: MM/DD/YYYY
        final format = DateFormat('MM/dd/yyyy', locale);
        return format.format(date);
      case DateFormatPattern.dmy:
        // UK/India format: DD/MM/YYYY
        final format = DateFormat('dd/MM/yyyy', locale);
        return format.format(date);
      case DateFormatPattern.ymd:
        // ISO/Japan format: YYYY-MM-DD
        final format = DateFormat('yyyy-MM-dd', locale);
        return format.format(date);
    }
  }

  /// Format date for display in UI (short, readable format)
  /// Automatically uses the correct pattern based on user's locale
  static String formatForDisplay(
    DateTime date,
    DateFormatPattern pattern, {
    String? locale,
  }) {
    switch (pattern) {
      case DateFormatPattern.mdy:
        // US format: Dec 19, 2025
        return formatShort(date, locale: locale);
      case DateFormatPattern.dmy:
        // UK/India format: 19 Dec 2025
        final format = DateFormat('d MMM yyyy', locale);
        return format.format(date);
      case DateFormatPattern.ymd:
        // ISO/Japan format: 2025-12-19
        final format = DateFormat('yyyy-MM-dd', locale);
        return format.format(date);
    }
  }
}


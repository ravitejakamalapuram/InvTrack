/// Extension methods for DateTime.
/// 
/// Provides convenient methods for date manipulation
/// and formatting used throughout the app.
extension DateTimeExtensions on DateTime {
  /// Returns true if this date is the same day as [other].
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// Returns true if this date is before [other] (ignoring time).
  bool isBeforeDay(DateTime other) {
    return DateTime(year, month, day)
        .isBefore(DateTime(other.year, other.month, other.day));
  }

  /// Returns true if this date is after [other] (ignoring time).
  bool isAfterDay(DateTime other) {
    return DateTime(year, month, day)
        .isAfter(DateTime(other.year, other.month, other.day));
  }

  /// Returns the start of the day (midnight).
  DateTime get startOfDay => DateTime(year, month, day);

  /// Returns the end of the day (23:59:59.999).
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  /// Returns the number of days between this date and [other].
  int daysBetween(DateTime other) {
    return DateTime(year, month, day)
        .difference(DateTime(other.year, other.month, other.day))
        .inDays
        .abs();
  }

  /// Returns the number of years between this date and [other].
  double yearsBetween(DateTime other) {
    return daysBetween(other) / 365.25;
  }
}


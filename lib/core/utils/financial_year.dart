/// The Indian financial year: the half-open range [1 Apr, next 1 Apr)
/// (money rule 5). Dates are compared by calendar day.
abstract final class FinancialYear {
  /// 1 April of the financial year [day] falls in.
  static DateTime startOf(DateTime day) => DateTime(
    day.month >= DateTime.april ? day.year : day.year - 1,
    DateTime.april,
  );

  /// The same calendar day one year before [day], date-only. 29 February
  /// becomes 28 February.
  static DateTime sameDayLastYear(DateTime day) {
    final year = day.year - 1;
    final daysInMonth = DateTime(year, day.month + 1, 0).day;
    return DateTime(
      year,
      day.month,
      day.day < daysInMonth ? day.day : daysInMonth,
    );
  }

  /// The day after [day], date-only: the exclusive end of a range that
  /// includes [day].
  static DateTime dayAfter(DateTime day) =>
      DateTime(day.year, day.month, day.day + 1);

  /// Whether [date]'s calendar day is in the half-open range [start, end).
  static bool contains(DateTime start, DateTime end, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && day.isBefore(end);
  }
}

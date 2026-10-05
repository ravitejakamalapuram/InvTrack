/// The UTC offset of the reading device at [instant].
typedef UtcOffsetAt = Duration Function(DateTime instant);

/// Converts date-only fields (cash-flow date, start date, maturity date) to
/// and from their stored instant, so a date keeps its calendar day on every
/// device whatever its time zone (CLAUDE.md money and data rule 5).
///
/// **Stored format.** A date is stored as UTC midnight of its calendar day,
/// taken from the year, month and day fields of the value: 1 Apr 2026 is
/// stored as `2026-04-01T00:00:00Z`.
///
/// **Older documents.** Builds before this one stored the writer's local
/// midnight (or, for a few paths, the local time of day). [fromStorage] reads
/// them without rewriting anything:
/// 1. Exactly UTC midnight: that UTC day (the current format, and older saves
///    from a UTC+0 device).
/// 2. Midnight on the reading device's clock: that day. Same-device data
///    keeps its day in every zone, through DST changes too.
/// 3. Any other whole quarter hour: a midnight saved in another zone. Its day
///    is the UTC day of the instant plus 13 hours, which is right for writers
///    from UTC-10:59 to UTC+13 (India, Europe, the Americas, NZ summer time).
/// 4. Anything else (a time of day): the reading device's day, as before.
///
/// Instants such as `createdAt`, `updatedAt` and `closedAt` are not dates and
/// must not go through this class.
abstract final class StoredDate {
  /// Rule 3's shift: a midnight saved at UTC+13 or less, and later than
  /// UTC-11, lands on its own UTC day once shifted by this much.
  static const Duration _otherZoneShift = Duration(hours: 13);

  /// The value to store for [date]'s calendar day.
  static DateTime toStorage(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  /// The calendar day of a [stored] instant, as a local date-only value.
  ///
  /// [offsetAt] gives the reading device's UTC offset at an instant; it
  /// defaults to this device's zone. Tests inject other zones.
  static DateTime fromStorage(DateTime stored, {UtcOffsetAt? offsetAt}) {
    final utc = stored.toUtc();
    if (_isMidnight(utc)) return _day(utc);

    // The reading device's wall clock, held in a UTC value so that its
    // fields can be read without a second zone conversion.
    final wall = utc.add((offsetAt ?? _deviceOffset)(utc));
    if (_isMidnight(wall)) return _day(wall);

    if (_isWholeQuarterHour(utc)) return _day(utc.add(_otherZoneShift));
    return _day(wall);
  }

  /// The stored-instant window to query for cash flows dated from [firstDay]
  /// to [lastDay] (both included, compared by calendar day): every stored
  /// instant that [fromStorage] can read as one of those days lies in
  /// [from, until). Filter the results with [isWithinDays].
  static ({DateTime from, DateTime until}) queryWindow(
    DateTime firstDay,
    DateTime lastDay,
  ) => (
    from: toStorage(firstDay).subtract(const Duration(days: 1)),
    until: toStorage(lastDay).add(const Duration(days: 2)),
  );

  /// Whether [day]'s calendar day is from [firstDay] to [lastDay], both
  /// included. Only the year, month and day fields are compared.
  static bool isWithinDays(DateTime day, DateTime firstDay, DateTime lastDay) {
    final value = toStorage(day);
    return !value.isBefore(toStorage(firstDay)) &&
        !value.isAfter(toStorage(lastDay));
  }

  static Duration _deviceOffset(DateTime instant) =>
      instant.toLocal().timeZoneOffset;

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _isMidnight(DateTime value) =>
      value.hour == 0 && _isWholeQuarterHour(value) && value.minute == 0;

  static bool _isWholeQuarterHour(DateTime value) =>
      value.minute % 15 == 0 &&
      value.second == 0 &&
      value.millisecond == 0 &&
      value.microsecond == 0;
}

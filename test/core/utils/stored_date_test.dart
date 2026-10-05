// A70 (#835): date-only fields (cash-flow date, start date, maturity date)
// must keep their calendar day whatever the time zone of the device that
// reads them. Each test injects the reading device's zone, so the results do
// not depend on the zone of the machine running the tests.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/stored_date.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The UTC offset of [zone] at a given instant, as a device in [zone] sees it.
UtcOffsetAt zone(String zone) {
  final location = tz.getLocation(zone);
  return (instant) => location.timeZone(instant.millisecondsSinceEpoch).offset;
}

/// The instant an older build stored for a date picked on a device in [zone]:
/// that device's local midnight.
DateTime legacyMidnight(String zone, int year, int month, int day) =>
    tz.TZDateTime(tz.getLocation(zone), year, month, day).toUtc();

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('toStorage', () {
    test('stores UTC midnight of the calendar day', () {
      expect(
        StoredDate.toStorage(DateTime(2026, 4, 1)),
        DateTime.utc(2026, 4, 1),
      );
    });

    test('drops the time of day', () {
      expect(
        StoredDate.toStorage(DateTime(2026, 4, 1, 21, 30, 15, 123)),
        DateTime.utc(2026, 4, 1),
      );
    });

    test('takes the day from the fields of a UTC value too', () {
      expect(
        StoredDate.toStorage(DateTime.utc(2026, 4, 1, 23, 59)),
        DateTime.utc(2026, 4, 1),
      );
    });
  });

  group('fromStorage', () {
    test('returns a local date-only value', () {
      final day = StoredDate.fromStorage(
        DateTime.utc(2026, 4, 1),
        offsetAt: zone('America/New_York'),
      );
      expect(day, DateTime(2026, 4, 1));
      expect(day.isUtc, isFalse);
    });

    // Ticket test 3: save and read on the same device.
    for (final name in [
      'Asia/Kolkata',
      'Europe/London',
      'America/Los_Angeles',
    ]) {
      for (final day in [
        DateTime(2026, 1, 15),
        DateTime(2026, 3, 8), // US DST starts
        DateTime(2026, 3, 29), // UK DST starts
        DateTime(2026, 7, 1), // summer time
        DateTime(2026, 10, 25), // UK DST ends
        DateTime(2026, 11, 1), // US DST ends
      ]) {
        test('round-trips ${day.toIso8601String()} in $name', () {
          final stored = StoredDate.toStorage(day);
          expect(StoredDate.fromStorage(stored, offsetAt: zone(name)), day);
        });

        test('keeps the day of an older save of $day in $name', () {
          final stored = legacyMidnight(name, day.year, day.month, day.day);
          expect(StoredDate.fromStorage(stored, offsetAt: zone(name)), day);
        });
      }
    }

    // An older save read on a device in another zone.
    final crossZone = <(String, String)>[
      ('Asia/Kolkata', 'America/New_York'),
      ('America/New_York', 'Asia/Kolkata'),
      ('Europe/London', 'America/Los_Angeles'), // BST writer
      ('America/Los_Angeles', 'Asia/Kolkata'), // PDT writer
      ('Pacific/Auckland', 'America/Los_Angeles'), // NZDT, UTC+13
      ('Pacific/Honolulu', 'Asia/Kolkata'), // UTC-10
      ('Asia/Kolkata', 'Pacific/Auckland'),
      ('Asia/Kolkata', 'Etc/UTC'),
    ];
    for (final (writer, reader) in crossZone) {
      for (final day in [DateTime(2026, 1, 15), DateTime(2026, 4, 1)]) {
        test('an older save of $day in $writer reads the same in $reader', () {
          final stored = legacyMidnight(writer, day.year, day.month, day.day);
          expect(StoredDate.fromStorage(stored, offsetAt: zone(reader)), day);
        });
      }
    }

    test('keeps the day of an older same-device save in UTC+13 and UTC+14', () {
      for (final name in ['Pacific/Tongatapu', 'Pacific/Kiritimati']) {
        final stored = legacyMidnight(name, 2026, 4, 1);
        expect(
          StoredDate.fromStorage(stored, offsetAt: zone(name)),
          DateTime(2026, 4, 1),
          reason: name,
        );
      }
    });

    test('reads an older time-of-day save as the reading device day', () {
      // DateTime.now() at 21:30:15.123 IST on 1 Apr 2026 = 16:00:15.123Z.
      final stored = DateTime.utc(2026, 4, 1, 16, 0, 15, 123);
      expect(
        StoredDate.fromStorage(stored, offsetAt: zone('Asia/Kolkata')),
        DateTime(2026, 4, 1),
      );
    });
  });

  group('queryWindow', () {
    test('holds every stored instant that reads as a day in the range', () {
      final window = StoredDate.queryWindow(
        DateTime(2026, 4, 1),
        DateTime(2027, 3, 31, 23, 59, 59),
      );
      final inside = [
        DateTime.utc(2026, 4, 1),
        DateTime.utc(2027, 3, 31),
        legacyMidnight('Pacific/Kiritimati', 2026, 4, 1),
        legacyMidnight('Pacific/Pago_Pago', 2027, 3, 31),
      ];
      for (final instant in inside) {
        expect(instant.isBefore(window.from), isFalse, reason: '$instant');
        expect(instant.isBefore(window.until), isTrue, reason: '$instant');
      }
    });

    test('isWithinDays compares calendar days, both ends included', () {
      final first = DateTime(2026, 4, 1);
      final last = DateTime(2027, 3, 31, 23, 59, 59);
      expect(
        StoredDate.isWithinDays(DateTime(2026, 4, 1), first, last),
        isTrue,
      );
      expect(
        StoredDate.isWithinDays(DateTime(2027, 3, 31), first, last),
        isTrue,
      );
      expect(
        StoredDate.isWithinDays(DateTime(2026, 3, 31), first, last),
        isFalse,
      );
      expect(
        StoredDate.isWithinDays(DateTime(2027, 4, 1), first, last),
        isFalse,
      );
    });
  });
}

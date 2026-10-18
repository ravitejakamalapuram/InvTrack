import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/nightly_gate.dart';

/// The rule behind the gate job in `.github/workflows/auto-release.yml`: an
/// automatic release needs a successful nightly run (golden and emulator
/// integration tests) on main that started no more than 36 h ago.
void main() {
  final now = DateTime.utc(2026, 10, 3, 12);

  String runs(String conclusion, String createdAt) => jsonEncode([
    {'conclusion': conclusion, 'createdAt': createdAt},
  ]);

  String? check(String json) => nightlyBlockReason(
    latestRuns: nightlyRuns(json),
    now: now,
    maxAge: maxNightlyAge,
  );

  test('a failed nightly blocks', () {
    expect(check(runs('failure', '2026-10-03T01:37:00Z')), contains('failure'));
  });

  test('a cancelled nightly blocks', () {
    expect(check(runs('cancelled', '2026-10-03T01:37:00Z')), isNotNull);
  });

  test('a success 40 h old blocks as stale', () {
    expect(check(runs('success', '2026-10-01T20:00:00Z')), contains('36 h'));
  });

  test('a success 10 h old allows', () {
    expect(check(runs('success', '2026-10-03T02:00:00Z')), isNull);
  });

  test('a success exactly 36 h old allows, one minute older blocks', () {
    expect(check(runs('success', '2026-10-02T00:00:00Z')), isNull);
    expect(check(runs('success', '2026-10-01T23:59:00Z')), isNotNull);
  });

  test('a run dated in the future blocks', () {
    expect(check(runs('success', '2026-10-03T13:00:00Z')), isNotNull);
  });

  test('no nightly runs blocks', () {
    expect(check('[]'), contains('No completed nightly'));
  });

  test('an unreadable API response blocks', () {
    expect(nightlyRuns(''), isNull);
    expect(nightlyRuns('not json'), isNull);
    expect(nightlyRuns('{"message":"Not Found"}'), isNull);
    expect(check(''), contains('Cannot read'));
  });

  test('a run without a start time blocks', () {
    expect(
      check(
        jsonEncode([
          {'conclusion': 'success'},
        ]),
      ),
      isNotNull,
    );
  });

  test(
    'only the newest run counts: an older success does not hide a failure',
    () {
      final json = jsonEncode([
        {'conclusion': 'failure', 'createdAt': '2026-10-03T01:37:00Z'},
        {'conclusion': 'success', 'createdAt': '2026-10-02T01:37:00Z'},
      ]);
      expect(check(json), contains('failure'));
    },
  );
}

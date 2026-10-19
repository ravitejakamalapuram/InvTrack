import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/promotion_guard.dart';

/// The rule behind `.github/workflows/promote.yml`'s guard job: a new build
/// reaches production at no more than 5%, and goes above 5% only after 48 h
/// at a partial rollout that release-platform recorded when Play confirmed
/// it, and a Crashlytics crash-free-users figure of at least 99.5%.
void main() {
  final rolloutStart = DateTime.utc(2026, 10, 1, 10);

  RolloutRecord record({DateTime? at, List<String> codes = const ['121']}) =>
      RolloutRecord(startedAt: at ?? rolloutStart, versionCodes: codes);

  String? check({
    String action = 'complete',
    String toTrack = 'production',
    String userFraction = '',
    Duration soak = const Duration(hours: 48),
    String crashFree = '99.5',
    List<RolloutRecord>? records,
    bool unreadableRecords = false,
    String ref = 'refs/heads/main',
    String runAttempt = '1',
  }) {
    return promotionBlockReason(
      action: action,
      toTrack: toTrack,
      userFraction: userFraction,
      ref: ref,
      runAttempt: runAttempt,
      rolloutRecords: unreadableRecords ? null : (records ?? [record()]),
      now: rolloutStart.add(soak),
      crashFreeUsers: crashFree,
    );
  }

  test('the staged rollout fraction is 5%', () {
    expect(stagedRolloutFraction, 0.05);
  });

  group('A84: the 48 h count starts at the recorded Play rollout', () {
    test('47 h after the recorded start, rollout 0.2 is refused', () {
      final reason = check(
        action: 'rollout',
        userFraction: '0.2',
        soak: const Duration(hours: 47),
        crashFree: '99.9',
      );
      expect(reason, isNotNull);
      expect(reason, contains('48 h'));
    });

    test('48 h after the recorded start, rollout 0.2 is allowed', () {
      expect(
        check(action: 'rollout', userFraction: '0.2', crashFree: '99.9'),
        isNull,
      );
    });

    test('no record (the Play step failed, even though a no-op auto-release '
        'run succeeded later) refuses', () {
      final reason = check(
        action: 'rollout',
        userFraction: '0.2',
        soak: const Duration(hours: 72),
        crashFree: '99.9',
        records: const [],
      );
      expect(reason, isNotNull);
      expect(reason, contains('Cannot confirm'));
    });

    test('an unreadable record history refuses', () {
      expect(
        check(unreadableRecords: true, soak: const Duration(hours: 72)),
        isNotNull,
      );
    });

    test('the count starts at the latest record, so a newer rollout '
        'restarts it', () {
      final records = [
        record(
          at: rolloutStart.subtract(const Duration(days: 5)),
          codes: ['120'],
        ),
        record(at: rolloutStart, codes: ['121']),
      ];
      expect(
        check(records: records, soak: const Duration(hours: 47, minutes: 59)),
        isNotNull,
      );
      expect(check(records: records), isNull);
    });

    test('the version codes the soak was counted for are the latest '
        "record's", () {
      final records = [
        record(
          at: rolloutStart.subtract(const Duration(days: 5)),
          codes: ['120'],
        ),
        record(codes: ['121', '122']),
      ];
      expect(latestRolloutRecord(records)!.versionCodes, ['121', '122']);
      expect(latestRolloutRecord(const []), isNull);
    });

    test('only a widening above 5% needs the soak', () {
      expect(
        soakRequired(
          action: 'rollout',
          toTrack: 'production',
          userFraction: '0.2',
        ),
        isTrue,
      );
      expect(
        soakRequired(
          action: 'complete',
          toTrack: 'production',
          userFraction: '',
        ),
        isTrue,
      );
      expect(
        soakRequired(
          action: 'rollout',
          toTrack: 'production',
          userFraction: '0.05',
        ),
        isFalse,
      );
      expect(
        soakRequired(
          action: 'promote',
          toTrack: 'production',
          userFraction: '0.05',
        ),
        isFalse,
      );
      expect(
        soakRequired(action: 'rollout', toTrack: 'alpha', userFraction: '0.5'),
        isFalse,
      );
      expect(
        soakRequired(action: 'halt', toTrack: 'production', userFraction: ''),
        isFalse,
      );
    });
  });

  group('completing a production rollout (100%)', () {
    test('is blocked at 47 h 59 m after the recorded start', () {
      final reason = check(soak: const Duration(hours: 47, minutes: 59));
      expect(reason, isNotNull);
      expect(reason, contains('48 h'));
    });

    test('is allowed at exactly 48 h with 99.5% crash-free users', () {
      expect(check(), isNull);
    });

    test('is blocked when crash-free users are 99.49%', () {
      final reason = check(crashFree: '99.49');
      expect(reason, isNotNull);
      expect(reason, contains('99.5'));
    });

    test(
      'is blocked when the crash-free figure is missing or not a number',
      () {
        expect(check(crashFree: ''), isNotNull);
        expect(check(crashFree: 'n/a'), isNotNull);
        expect(check(crashFree: '101'), isNotNull);
      },
    );

    test('rollout to 1 or to an empty fraction counts as completing', () {
      const early = Duration(hours: 5);
      expect(
        check(action: 'rollout', userFraction: '1', soak: early),
        isNotNull,
      );
      expect(
        check(action: 'rollout', userFraction: '', soak: early),
        isNotNull,
      );
      expect(check(action: 'rollout', userFraction: '1'), isNull);
    });

    test('promote straight to production at 100% is blocked', () {
      expect(
        check(action: 'promote', userFraction: '', soak: Duration.zero),
        isNotNull,
      );
    });

    test('promote straight to production at 100% is blocked even after '
        '72 h', () {
      for (final fraction in ['', '1', '1.0']) {
        expect(
          check(
            action: 'promote',
            userFraction: fraction,
            soak: const Duration(hours: 72),
            crashFree: '99.9',
          ),
          isNotNull,
          reason: 'fraction "$fraction"',
        );
      }
    });
  });

  group('ci-release-1 / integration-3: nothing goes above 5% without the '
      '48 h soak', () {
    test('promote to production at 0.99 is blocked, with or without crash '
        'data', () {
      for (final crashFree in ['', '99.9']) {
        final reason = check(
          action: 'promote',
          userFraction: '0.99',
          soak: const Duration(hours: 1),
          crashFree: crashFree,
        );
        expect(reason, isNotNull, reason: 'crash-free "$crashFree"');
        expect(reason, contains('5%'));
      }
    });

    test('promote to production above 5% is blocked even after 72 h', () {
      for (final fraction in ['0.051', '0.06', '0.2', '0.5']) {
        expect(
          check(
            action: 'promote',
            userFraction: fraction,
            soak: const Duration(hours: 72),
            crashFree: '99.9',
          ),
          isNotNull,
          reason: 'fraction $fraction',
        );
      }
    });

    test('rollout to 0.999 at 47 h 59 m is blocked and at 48 h is allowed', () {
      String? at(Duration soak) => check(
        action: 'rollout',
        userFraction: '0.999',
        soak: soak,
        crashFree: '99.9',
      );
      expect(at(const Duration(hours: 47, minutes: 59)), isNotNull);
      expect(at(const Duration(hours: 48)), isNull);
    });
  });

  group('partial production rollouts', () {
    test('promote to production at 5% needs no soak or crash data', () {
      expect(
        check(
          action: 'promote',
          userFraction: '0.05',
          soak: Duration.zero,
          crashFree: '',
        ),
        isNull,
      );
    });

    test('promote to production below 5% is allowed', () {
      expect(
        check(
          action: 'promote',
          userFraction: '0.01',
          soak: Duration.zero,
          crashFree: '',
        ),
        isNull,
      );
    });

    // Policy change in A63-F1: widening above 5% now needs the same 48 h
    // soak as 100%, so 20% at 6 h is refused.
    test('widening 5% to 20% needs the 48 h soak and the crash-free gate', () {
      const early = Duration(hours: 6);
      final reason = check(
        action: 'rollout',
        userFraction: '0.2',
        soak: early,
        crashFree: '99.9',
      );
      expect(reason, isNotNull);
      expect(reason, contains('48 h'));
      expect(check(action: 'rollout', userFraction: '0.2'), isNull);
      expect(
        check(action: 'rollout', userFraction: '0.2', crashFree: '99.4'),
        isNotNull,
      );
    });

    test('resuming a halted rollout at 5% needs the crash-free gate but no '
        'soak', () {
      const early = Duration(hours: 1);
      expect(
        check(
          action: 'rollout',
          userFraction: '0.05',
          soak: early,
          crashFree: '99.9',
        ),
        isNull,
      );
      expect(
        check(
          action: 'rollout',
          userFraction: '0.05',
          soak: early,
          crashFree: '',
        ),
        isNotNull,
      );
    });

    test('rejects fractions outside (0, 1]', () {
      expect(check(action: 'rollout', userFraction: '0'), isNotNull);
      expect(check(action: 'rollout', userFraction: '1.5'), isNotNull);
      expect(check(action: 'rollout', userFraction: 'abc'), isNotNull);
      expect(check(action: 'rollout', userFraction: 'NaN'), isNotNull);
      expect(check(action: 'promote', userFraction: 'NaN'), isNotNull);
    });

    test('a crash-free figure of NaN or Infinity does not pass the gate', () {
      expect(
        check(action: 'rollout', userFraction: '0.2', crashFree: 'NaN'),
        isNotNull,
      );
      expect(check(crashFree: 'NaN'), isNotNull);
      expect(check(crashFree: 'Infinity'), isNotNull);
    });
  });

  group('ci-release-2 / ci-release-3: only a first run from main', () {
    test('a run from a ref other than main is blocked', () {
      for (final ref in ['refs/heads/review/x', 'refs/tags/v3.7.0', '']) {
        final reason = check(ref: ref);
        expect(reason, isNotNull, reason: 'ref "$ref"');
        expect(reason, contains('main'));
      }
      expect(
        check(
          action: 'promote',
          userFraction: '0.05',
          soak: Duration.zero,
          ref: 'refs/heads/review/x',
        ),
        isNotNull,
      );
    });

    test('a re-run is blocked, because it reuses old inputs', () {
      for (final attempt in ['2', '3', '', 'x']) {
        final reason = check(runAttempt: attempt);
        expect(reason, isNotNull, reason: 'attempt "$attempt"');
        expect(reason, contains('new promote run'));
      }
    });

    test('halt is allowed from any ref and on a re-run', () {
      expect(
        check(action: 'halt', ref: 'refs/heads/review/x', runAttempt: '2'),
        isNull,
      );
    });
  });

  group('other actions and tracks', () {
    test('halt is never blocked', () {
      expect(check(action: 'halt', soak: Duration.zero, crashFree: ''), isNull);
    });

    test('tracks other than production are not gated', () {
      expect(
        check(
          action: 'promote',
          toTrack: 'alpha',
          soak: Duration.zero,
          crashFree: '',
        ),
        isNull,
      );
    });

    test('production is gated whatever its letter case', () {
      expect(
        check(
          action: 'promote',
          toTrack: 'Production',
          userFraction: '',
          soak: Duration.zero,
        ),
        isNotNull,
      );
      expect(
        check(toTrack: ' PRODUCTION ', soak: const Duration(hours: 1)),
        isNotNull,
      );
    });

    test('unknown actions are blocked', () {
      expect(check(action: 'yolo'), isNotNull);
    });
  });

  group('reading the rollout records', () {
    Map<String, Object?> deployment(
      Object? payload, {
      String environment = 'play-production',
    }) => {'environment': environment, 'payload': payload};

    Map<String, Object?> payload({
      String track = 'production',
      String status = 'inProgress',
      Object? codes = const ['121'],
      Object? startedAt = '2026-10-01T10:00:00.000Z',
    }) => {
      'track': track,
      'status': status,
      'versionCodes': codes,
      'startedAt': startedAt,
    };

    test('reads the start time and version codes of each deployment', () {
      final records = rolloutRecords(
        jsonEncode([
          deployment(payload(codes: ['122', '121'])),
        ]),
      );
      expect(records, hasLength(1));
      expect(records!.single.startedAt, rolloutStart);
      expect(records.single.versionCodes, ['121', '122']);
    });

    test('ignores other environments and releases that are not a staged '
        'production rollout', () {
      final records = rolloutRecords(
        jsonEncode([
          deployment(payload(), environment: 'github-pages'),
          deployment(payload(track: 'internal')),
          deployment(payload(status: 'completed')),
          deployment(payload(codes: const [])),
          deployment(payload(startedAt: 'soon')),
          deployment('not a map'),
          deployment(null),
        ]),
      );
      expect(records, isEmpty);
    });

    test('an unreadable history is null', () {
      expect(rolloutRecords(''), isNull);
      expect(rolloutRecords('not json'), isNull);
      expect(rolloutRecords('{"a": 1}'), isNull);
      expect(rolloutRecords('[]'), isEmpty);
    });
  });
}

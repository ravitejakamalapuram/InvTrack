import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/promotion_guard.dart';

/// The rule behind `.github/workflows/promote.yml`'s guard job: no release
/// reaches 100% of production without 48 h at a partial rollout and a
/// Crashlytics crash-free-users figure of at least 99.5%.
void main() {
  final releasedAt = DateTime.utc(2026, 10, 1, 9);

  String? check({
    String action = 'complete',
    String toTrack = 'production',
    String userFraction = '',
    DateTime? released,
    Duration soak = const Duration(hours: 48),
    String crashFree = '99.5',
    bool noRelease = false,
    List<DateTime>? partialStarts = const [],
  }) {
    final from = noRelease ? null : (released ?? releasedAt);
    return promotionBlockReason(
      action: action,
      toTrack: toTrack,
      userFraction: userFraction,
      releasedAt: from,
      partialRolloutStarts: partialStarts,
      now: releasedAt.add(soak),
      crashFreeUsers: crashFree,
    );
  }

  group('completing a production rollout (100%)', () {
    test('is blocked at 47 h 59 m after the release', () {
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

    test('is blocked when no release time is known', () {
      expect(check(noRelease: true), isNotNull);
    });

    test('rollout to 1 or to an empty fraction counts as completing', () {
      final early = const Duration(hours: 5);
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

    test('promote straight to production at 100% is blocked even after the '
        'build has sat on internal for 72 h', () {
      const longAfter = Duration(hours: 72);
      for (final fraction in ['', '1', '1.0']) {
        expect(
          check(
            action: 'promote',
            userFraction: fraction,
            soak: longAfter,
            crashFree: '99.9',
          ),
          isNotNull,
          reason: 'fraction "$fraction"',
        );
      }
    });

    test('the 48 h count starts when the partial production rollout '
        'started, not when the build was released', () {
      // Built 72 h ago, kept on internal, promoted to 20% one minute ago.
      final partialStart = releasedAt.add(const Duration(hours: 72));
      String? completeAfter(Duration sincePartial) => check(
        soak: const Duration(hours: 72) + sincePartial,
        crashFree: '99.9',
        partialStarts: [partialStart],
      );
      final reason = completeAfter(const Duration(minutes: 1));
      expect(reason, isNotNull);
      expect(reason, contains('48 h'));
      expect(completeAfter(const Duration(hours: 47, minutes: 59)), isNotNull);
      expect(completeAfter(const Duration(hours: 48)), isNull);
    });

    test('an older partial rollout does not shorten the count for a newer '
        'release', () {
      final previousRelease = releasedAt.subtract(const Duration(days: 7));
      expect(
        check(soak: const Duration(hours: 5), partialStarts: [previousRelease]),
        isNotNull,
      );
    });

    test('is blocked when the promote history cannot be read', () {
      expect(check(partialStarts: null), isNotNull);
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

    test('widening 5% to 20% needs the crash-free gate but no 48 h soak', () {
      const early = Duration(hours: 6);
      expect(
        check(action: 'rollout', userFraction: '0.2', soak: early),
        isNull,
      );
      expect(
        check(
          action: 'rollout',
          userFraction: '0.2',
          soak: early,
          crashFree: '99.4',
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

  group('other actions and tracks', () {
    test('halt is never blocked', () {
      expect(
        check(
          action: 'halt',
          soak: Duration.zero,
          crashFree: '',
          noRelease: true,
        ),
        isNull,
      );
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

  group('reading the promote history', () {
    String runs(List<Map<String, String>> list) => jsonEncode(list);
    Map<String, String> run(String title, String createdAt) => {
      'displayTitle': title,
      'createdAt': createdAt,
    };

    test('keeps only promote runs that started a partial production '
        'rollout', () {
      final starts = partialRolloutStarts(
        runs([
          run(
            'promote action=promote to=production fraction=0.2',
            '2026-10-01T09:00:00Z',
          ),
          run(
            'promote action=promote to=Production fraction=0.05',
            '2026-09-20T09:00:00Z',
          ),
          run(
            'promote action=rollout to=production fraction=0.5',
            '2026-10-01T10:00:00Z',
          ),
          run(
            'promote action=complete to=production fraction=',
            '2026-10-01T11:00:00Z',
          ),
          run(
            'promote action=promote to=production fraction=',
            '2026-10-01T12:00:00Z',
          ),
          run(
            'promote action=promote to=production fraction=1',
            '2026-10-01T13:00:00Z',
          ),
          run(
            'promote action=promote to=alpha fraction=0.2',
            '2026-10-01T14:00:00Z',
          ),
          run('promote', '2026-10-01T15:00:00Z'),
        ]),
      );
      expect(starts, [
        DateTime.utc(2026, 10, 1, 9),
        DateTime.utc(2026, 9, 20, 9),
      ]);
    });

    test('an empty history is an empty list', () {
      expect(partialRolloutStarts('[]'), isEmpty);
    });

    test('an unreadable history is null', () {
      expect(partialRolloutStarts(''), isNull);
      expect(partialRolloutStarts('not json'), isNull);
      expect(partialRolloutStarts('{"a": 1}'), isNull);
    });
  });
}

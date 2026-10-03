import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/promotion_guard.dart';

/// The rule behind `.github/workflows/promote.yml`'s guard job: a new build
/// reaches production at no more than 5%, and goes above 5% only after 48 h
/// at a partial rollout and a Crashlytics crash-free-users figure of at least
/// 99.5%.
void main() {
  final releasedAt = DateTime.utc(2026, 10, 1, 9);

  /// Auto-release created the release and finished its 5% Play call at
  /// [releasedAt].
  final autoReleaseAtRelease = [
    WorkflowRun(
      createdAt: releasedAt.subtract(const Duration(minutes: 20)),
      finishedAt: releasedAt,
    ),
  ];

  String? check({
    String action = 'complete',
    String toTrack = 'production',
    String userFraction = '',
    DateTime? released,
    Duration soak = const Duration(hours: 48),
    String crashFree = '99.5',
    bool noRelease = false,
    List<DateTime>? partialStarts = const [],
    List<WorkflowRun>? autoRuns,
    bool noAutoRuns = false,
    String ref = 'refs/heads/main',
    String runAttempt = '1',
  }) {
    final from = noRelease ? null : (released ?? releasedAt);
    return promotionBlockReason(
      action: action,
      toTrack: toTrack,
      userFraction: userFraction,
      ref: ref,
      runAttempt: runAttempt,
      releasedAt: from,
      partialRolloutStarts: partialStarts,
      autoReleaseRuns: noAutoRuns ? null : (autoRuns ?? autoReleaseAtRelease),
      now: releasedAt.add(soak),
      crashFreeUsers: crashFree,
    );
  }

  test('the staged rollout fraction is 5%', () {
    expect(stagedRolloutFraction, 0.05);
  });

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
      // Built 72 h ago with release.yml, kept on internal, promoted to 5%
      // one minute ago.
      final partialStart = releasedAt.add(const Duration(hours: 72));
      String? completeAfter(Duration sincePartial) => check(
        soak: const Duration(hours: 72) + sincePartial,
        crashFree: '99.9',
        partialStarts: [partialStart],
        autoRuns: const [],
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

    test('rollout to 0.999 one hour after release is blocked', () {
      final reason = check(
        action: 'rollout',
        userFraction: '0.999',
        soak: const Duration(hours: 1),
        crashFree: '99.9',
      );
      expect(reason, isNotNull);
      expect(reason, contains('48 h'));
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

    test('rollout above 5% fails closed when no partial rollout of this '
        'release is on record', () {
      final reason = check(
        action: 'rollout',
        userFraction: '0.2',
        soak: const Duration(hours: 72),
        crashFree: '99.9',
        autoRuns: const [],
      );
      expect(reason, isNotNull);
      expect(reason, contains('Cannot confirm'));
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

  group('ci-release-4: the 48 h count starts when the Play call finished', () {
    test('an auto-release whose 5% step waited 30 h for approval needs 48 h '
        'from the end of that run', () {
      // Release created at 09:00; the production 5% job waited for approval
      // and its run finished 30 h later.
      final delayed = [
        WorkflowRun(
          createdAt: releasedAt.subtract(const Duration(minutes: 20)),
          finishedAt: releasedAt.add(const Duration(hours: 30)),
        ),
      ];
      final reason = check(crashFree: '99.9', autoRuns: delayed);
      expect(reason, isNotNull);
      expect(reason, contains('18.0 h'));
      expect(
        check(
          crashFree: '99.9',
          autoRuns: delayed,
          soak: const Duration(hours: 77, minutes: 59),
        ),
        isNotNull,
      );
      expect(
        check(
          crashFree: '99.9',
          autoRuns: delayed,
          soak: const Duration(hours: 78),
        ),
        isNull,
      );
    });

    test('auto-release runs that ended before the release or started after it '
        'are not this release', () {
      final unrelated = [
        WorkflowRun(
          createdAt: releasedAt.subtract(const Duration(hours: 2)),
          finishedAt: releasedAt.subtract(const Duration(hours: 1)),
        ),
        WorkflowRun(
          createdAt: releasedAt.add(const Duration(hours: 1)),
          finishedAt: releasedAt.add(const Duration(hours: 1, minutes: 5)),
        ),
      ];
      final reason = check(crashFree: '99.9', autoRuns: unrelated);
      expect(reason, isNotNull);
      expect(reason, contains('Cannot confirm'));
    });

    test('is blocked when the auto-release history cannot be read', () {
      expect(check(crashFree: '99.9', noAutoRuns: true), isNotNull);
    });

    test('the soak starts at the latest Play call for this release', () {
      final start = rolloutSoakStart(
        releasedAt: releasedAt,
        partialRolloutStarts: [
          releasedAt.subtract(const Duration(days: 3)),
          releasedAt.add(const Duration(hours: 2)),
        ],
        autoReleaseRuns: autoReleaseAtRelease,
      );
      expect(start, releasedAt.add(const Duration(hours: 2)));
      expect(
        rolloutSoakStart(
          releasedAt: releasedAt,
          partialRolloutStarts: const [],
          autoReleaseRuns: const [],
        ),
        isNull,
      );
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
        check(
          action: 'halt',
          ref: 'refs/heads/review/x',
          runAttempt: '2',
          noRelease: true,
        ),
        isNull,
      );
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
    // Each run finished, with its Play call done, an hour after dispatch.
    Map<String, String> run(String title, String createdAt) => {
      'displayTitle': title,
      'createdAt': createdAt,
      'updatedAt': DateTime.parse(
        createdAt,
      ).add(const Duration(hours: 1)).toIso8601String(),
    };

    test('keeps only promote runs that started a partial production '
        'rollout, timed by when the run finished', () {
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
        DateTime.utc(2026, 10, 1, 10),
        DateTime.utc(2026, 9, 20, 10),
      ]);
    });

    test('a partial production run without a finish time makes the history '
        'unreadable', () {
      expect(
        partialRolloutStarts(
          jsonEncode([
            {
              'displayTitle':
                  'promote action=promote to=production fraction=0.05',
              'createdAt': '2026-10-01T09:00:00Z',
            },
          ]),
        ),
        isNull,
      );
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

  group('reading the auto-release history', () {
    test('reads when each successful run was created and finished', () {
      final runs = autoReleaseRuns(
        jsonEncode([
          {
            'createdAt': '2026-10-01T08:40:00Z',
            'updatedAt': '2026-10-01T09:05:00Z',
          },
        ]),
      );
      expect(runs, hasLength(1));
      expect(runs!.single.createdAt, DateTime.utc(2026, 10, 1, 8, 40));
      expect(runs.single.finishedAt, DateTime.utc(2026, 10, 1, 9, 5));
    });

    test('an unreadable or incomplete history is null', () {
      expect(autoReleaseRuns(''), isNull);
      expect(autoReleaseRuns('{"a": 1}'), isNull);
      expect(
        autoReleaseRuns(
          jsonEncode([
            {'createdAt': '2026-10-01T08:40:00Z'},
          ]),
        ),
        isNull,
      );
      expect(autoReleaseRuns('[]'), isEmpty);
    });
  });
}

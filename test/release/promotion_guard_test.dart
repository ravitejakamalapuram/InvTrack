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
  }) {
    final from = noRelease ? null : (released ?? releasedAt);
    return promotionBlockReason(
      action: action,
      toTrack: toTrack,
      userFraction: userFraction,
      releasedAt: from,
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

    test('unknown actions are blocked', () {
      expect(check(action: 'yolo'), isNotNull);
    });
  });
}

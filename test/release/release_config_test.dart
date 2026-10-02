import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the release workflows (A63): automatic releases must start as a
/// staged rollout, manual promotion to 100% must go through the guard, and the
/// golden tests must run in CI.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('auto-release sends a new build to 5% of production, not 100%', () {
    final match = RegExp(
      r"^\s*rollout_fraction:\s*'([^']*)'",
      multiLine: true,
    ).firstMatch(read('.github/workflows/auto-release.yml'));
    expect(match, isNotNull, reason: 'rollout_fraction must be set');
    expect(double.parse(match!.group(1)!), 0.05);
  });

  test('promote.yml runs the promotion guard before touching Play', () {
    final promote = read('.github/workflows/promote.yml');
    expect(promote, contains('scripts/promotion_guard.dart'));
    expect(
      RegExp(
        r'^  promote:\n(?:    .*\n)*?    needs: guard$',
        multiLine: true,
      ).hasMatch(promote),
      isTrue,
      reason: 'the promote job must need the guard job',
    );
    expect(promote, contains('crash_free_users'));
  });

  test('a nightly workflow runs the golden tests', () {
    final nightly = read('.github/workflows/nightly.yml');
    expect(nightly, contains('schedule:'));
    expect(nightly, contains('flutter test --tags golden'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/promotion_guard.dart';

/// Guards the release workflows (A63): automatic releases must start as a
/// staged rollout, manual promotion to 100% must go through the guard, and the
/// golden and integration tests must run in CI.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('auto-release sends a new build to 5% of production, not 100%', () {
    final match = RegExp(
      r"^\s*rollout_fraction:\s*'([^']*)'",
      multiLine: true,
    ).firstMatch(read('.github/workflows/auto-release.yml'));
    expect(match, isNotNull, reason: 'rollout_fraction must be set');
    expect(double.parse(match!.group(1)!), 0.05);
    expect(
      double.parse(match.group(1)!),
      stagedRolloutFraction,
      reason: 'the guard caps promote at the auto-release fraction',
    );
  });

  test('promote.yml defaults to a fraction the guard lets promote use', () {
    final match = RegExp(
      r"^      user_fraction:\n(?:        .*\n)*?        default: '([^']*)'",
      multiLine: true,
    ).firstMatch(read('.github/workflows/promote.yml'));
    expect(match, isNotNull, reason: 'user_fraction needs a default');
    expect(double.parse(match!.group(1)!), stagedRolloutFraction);
  });

  // ci-release-2 and ci-release-3: the promote job reuses the guard job's
  // result, so it must only run on a first attempt from main (halt excepted).
  test('the promote job runs only on the first attempt from main', () {
    final promote = read('.github/workflows/promote.yml');
    final job = RegExp(
      r'^  promote:\n((?:    .*\n)+)',
      multiLine: true,
    ).firstMatch(promote)?.group(1);
    expect(job, isNotNull);
    final condition = RegExp(
      r'^    if: (.+)$',
      multiLine: true,
    ).firstMatch(job!)?.group(1);
    expect(condition, isNotNull, reason: 'the promote job needs an if');
    expect(condition, contains("github.ref == 'refs/heads/main'"));
    expect(condition, contains("github.run_attempt == '1'"));
    expect(condition, contains("inputs.action == 'halt'"));
  });

  // A84: the 48 h count comes from the rollout record that release-platform
  // writes after Play confirmed the rollout, never from a run-finish proxy.
  test('the guard reads the rollout records and not the run history', () {
    final promote = read('.github/workflows/promote.yml');
    expect(promote, contains('environment=play-production'));
    expect(promote, contains('ROLLOUT_RECORDS'));
    expect(promote, isNot(contains('AUTO_RELEASE_RUNS')));
    expect(promote, isNot(contains('PROMOTE_RUNS')));
    expect(promote, isNot(contains('gh release view')));
  });

  test('the promote job confirms the soaked release on Play and may record '
      'the next rollout', () {
    final promote = read('.github/workflows/promote.yml');
    expect(
      promote,
      contains(
        'expect_in_progress_version_codes: '
        r'${{ needs.guard.outputs.soak_version_codes }}',
      ),
    );
    expect(promote, contains('soak_version_codes:'));
    expect(promote, contains('deployments: write'));
    expect(
      read('.github/workflows/auto-release.yml'),
      contains('deployments: write'),
    );
  });

  // ci-release-8: third-party actions in the release guard and nightly
  // workflows are pinned to a commit, and checkout keeps no token.
  test('promote.yml and nightly.yml pin actions and drop checkout '
      'credentials', () {
    for (final path in [
      '.github/workflows/promote.yml',
      '.github/workflows/nightly.yml',
      '.github/workflows/auto-release.yml',
    ]) {
      final text = read(path);
      final uses = RegExp(
        r'uses:\s*(\S+)',
      ).allMatches(text).map((m) => m.group(1)!);
      for (final ref in uses) {
        // The owner's own reusable workflows are versioned by tag on purpose.
        if (ref.startsWith('ravitejakamalapuram/release-platform/')) continue;
        expect(
          ref,
          matches(RegExp(r'@[0-9a-f]{40}$')),
          reason: '$path: $ref must be pinned to a commit',
        );
      }
      final checkouts = RegExp(r'actions/checkout@').allMatches(text).length;
      final noCredentials = RegExp(
        r'persist-credentials: false',
      ).allMatches(text).length;
      expect(noCredentials, checkouts, reason: path);
    }
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

  test('the guard job may read deployments', () {
    final promote = read('.github/workflows/promote.yml');
    final guard = promote.substring(
      promote.indexOf('  guard:'),
      promote.indexOf('  promote:'),
    );
    expect(guard, contains('deployments: read'));
    expect(guard, contains('gh api'));
  });

  test('a nightly workflow runs the integration tests on an emulator', () {
    final nightly = read('.github/workflows/nightly.yml');
    expect(nightly, contains('reactivecircus/android-emulator-runner'));
    for (final flow in [
      'integration_test/app_test.dart',
      'integration_test/flows/investment_form_flow_test.dart',
      'integration_test/flows/cash_flow_crud_test.dart',
    ]) {
      expect(nightly, contains(flow));
      expect(File(flow).existsSync(), isTrue, reason: '$flow must exist');
    }
  });

  // A85: a red or stale nightly stops automatic releases.
  test('auto-release waits for a gate job that reads the nightly runs', () {
    final auto = read('.github/workflows/auto-release.yml');
    expect(
      RegExp(
        r'^  auto:\n(?:    .*\n)*?    needs: gate$',
        multiLine: true,
      ).hasMatch(auto),
      isTrue,
      reason: 'the auto job must need the gate job',
    );
    expect(auto, contains('--workflow nightly.yml'));
    expect(auto, contains('scripts/nightly_gate.dart'));
    final gate = auto.substring(
      auto.indexOf('  gate:'),
      auto.indexOf('  auto:'),
    );
    expect(gate, contains('actions: read'));
    expect(gate, isNot(contains('write')));
  });
}

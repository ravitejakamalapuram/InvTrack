import 'dart:convert';
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

  test('promote.yml names each run so the guard can find when a partial '
      'production rollout started', () {
    final promote = read('.github/workflows/promote.yml');
    final runName = RegExp(
      r'^run-name:\s*(.+)$',
      multiLine: true,
    ).firstMatch(promote)?.group(1)?.trim();
    expect(runName, isNotNull, reason: 'promote.yml needs a run-name');

    String title(String action, String toTrack, String fraction) => runName!
        .replaceAll(RegExp(r'\$\{\{\s*inputs\.action\s*\}\}'), action)
        .replaceAll(RegExp(r'\$\{\{\s*inputs\.to_track\s*\}\}'), toTrack)
        .replaceAll(RegExp(r'\$\{\{\s*inputs\.user_fraction\s*\}\}'), fraction);

    final starts = partialRolloutStarts(
      jsonEncode([
        {
          'displayTitle': title('promote', 'production', '0.05'),
          'createdAt': '2026-10-01T09:00:00Z',
        },
        {
          'displayTitle': title('rollout', 'production', '0.2'),
          'createdAt': '2026-10-01T10:00:00Z',
        },
      ]),
    );
    expect(starts, [DateTime.utc(2026, 10, 1, 9)]);

    // The guard reads that history, and it needs permission to.
    expect(promote, contains('gh run list'));
    expect(promote, contains('PROMOTE_RUNS'));
    expect(promote, contains('actions: read'));
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
}

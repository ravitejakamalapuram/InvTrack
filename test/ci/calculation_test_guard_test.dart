@TestOn('linux || mac-os')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _script = 'scripts/ci/check_calculation_tests.sh';

/// Runs the guard with [diff] (`git diff --name-status` output) on stdin.
Future<ProcessResult> _runGuard(String diff) async {
  final process = await Process.start('bash', [_script]);
  process.stdin.write(diff);
  await process.stdin.close();
  final stdout = await process.stdout.transform(utf8.decoder).join();
  final stderr = await process.stderr.transform(utf8.decoder).join();
  return ProcessResult(process.pid, await process.exitCode, stdout, stderr);
}

void main() {
  test('the guard script exists', () {
    expect(File(_script).existsSync(), isTrue);
  });

  group('money-code test guard', () {
    test(
      'fails when a calculation file changes without a test change',
      () async {
        final result = await _runGuard(
          'M\tlib/core/calculations/xirr_solver.dart\n'
          'M\tCHANGELOG.md\n',
        );
        expect(result.exitCode, 1);
        expect(
          result.stdout,
          contains('lib/core/calculations/xirr_solver.dart'),
        );
      },
    );

    test(
      'passes when a calculation change comes with a changed test',
      () async {
        final result = await _runGuard(
          'M\tlib/core/calculations/xirr_solver.dart\n'
          'M\ttest/core/calculations/xirr_solver_test.dart\n',
        );
        expect(result.exitCode, 0, reason: '${result.stdout}');
      },
    );

    test('passes when a calculation change comes with a new test', () async {
      final result = await _runGuard(
        'M\tlib/core/calculations/financial_calculator.dart\n'
        'A\ttest/core/calculations/new_case_test.dart\n',
      );
      expect(result.exitCode, 0, reason: '${result.stdout}');
    });

    for (final path in [
      'lib/features/goals/domain/services/goal_progress_calculator.dart',
      'lib/features/fire_number/domain/services/fire_calculation_service.dart',
      'lib/features/reports/data/services/fy_report_service.dart',
    ]) {
      test('fails for $path without a test change', () async {
        final result = await _runGuard('M\t$path\n');
        expect(result.exitCode, 1);
        expect(result.stdout, contains(path));
      });
    }

    test('a newly added calculation file also needs a test', () async {
      final result = await _runGuard(
        'A\tlib/core/calculations/new_metric.dart\n',
      );
      expect(result.exitCode, 1);
    });

    test('a file renamed into a guarded path needs a test', () async {
      final result = await _runGuard(
        'R100\tlib/core/utils/old.dart\tlib/core/calculations/new.dart\n',
      );
      expect(result.exitCode, 1);
      expect(result.stdout, contains('lib/core/calculations/new.dart'));
    });

    test('deleting a calculation file needs a test change', () async {
      final result = await _runGuard(
        'D\tlib/core/calculations/xirr_solver.dart\n',
      );
      expect(result.exitCode, 1);
      expect(result.stdout, contains('lib/core/calculations/xirr_solver.dart'));
    });

    test('a file renamed out of a guarded path needs a test', () async {
      final result = await _runGuard(
        'R100\tlib/core/calculations/old.dart\tlib/core/utils/old.dart\n',
      );
      expect(result.exitCode, 1);
      expect(result.stdout, contains('lib/core/calculations/old.dart'));
    });

    test(
      'a content-identical test rename does not count as a test change',
      () async {
        final result = await _runGuard(
          'M\tlib/core/calculations/xirr_solver.dart\n'
          'R100\ttest/core/calculations/old_test.dart\t'
          'test/core/calculations/new_test.dart\n',
        );
        expect(result.exitCode, 1);
      },
    );

    test('a test renamed with edits counts as a test change', () async {
      final result = await _runGuard(
        'M\tlib/core/calculations/xirr_solver.dart\n'
        'R087\ttest/core/calculations/old_test.dart\t'
        'test/core/calculations/new_test.dart\n',
      );
      expect(result.exitCode, 0, reason: '${result.stdout}');
    });

    test('deleting a test does not count as a test change', () async {
      final result = await _runGuard(
        'M\tlib/core/calculations/xirr_solver.dart\n'
        'D\ttest/core/calculations/xirr_solver_test.dart\n',
      );
      expect(result.exitCode, 1);
    });

    test(
      'a test helper that is not a *_test.dart file does not count',
      () async {
        final result = await _runGuard(
          'M\tlib/core/calculations/xirr_solver.dart\n'
          'M\ttest/helpers/fixtures.dart\n',
        );
        expect(result.exitCode, 1);
      },
    );

    test('generated files alone do not need a test', () async {
      final result = await _runGuard(
        'M\tlib/core/calculations/calculation_engine_provider.g.dart\n'
        'M\tlib/features/goals/presentation/providers/goals_provider.freezed.dart\n',
      );
      expect(result.exitCode, 0, reason: '${result.stdout}');
    });

    test('changes outside the guarded paths pass', () async {
      final result = await _runGuard(
        'M\tlib/features/settings/presentation/screens/settings_screen.dart\n'
        'M\tlib/core/calculations_helpers.dart\n'
        'M\tdocs/README.md\n',
      );
      expect(result.exitCode, 0, reason: '${result.stdout}');
    });

    test('an empty diff passes', () async {
      final result = await _runGuard('');
      expect(result.exitCode, 0, reason: '${result.stdout}');
    });
  });
}

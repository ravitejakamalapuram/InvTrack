// The Telegram daily tip job: the post is the app's tip plus the Play link, a
// dry run sends nothing, and the workflow cannot post by accident.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<ProcessResult> _dryRun(String date) => Process.run('node', [
  'scripts/telegram-tip/post-tip.mjs',
  '--dry-run',
  '--date',
  date,
]);

void main() {
  final tips =
      (jsonDecode(File('assets/tips/tips.json').readAsStringSync()) as List);
  final workflow = File(
    '.github/workflows/telegram-daily-tip.yml',
  ).readAsStringSync();

  test('dry run prints the tip, the disclaimer and the Play link', () async {
    final r = await _dryRun('2026-11-10');
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final out = r.stdout as String;
    final day = DateTime.utc(2026, 11, 10).millisecondsSinceEpoch ~/ 86400000;
    final tip = tips[day % tips.length] as Map<String, dynamic>;
    expect(out, contains(tip['title'] as String));
    expect(out, contains(tip['body'] as String));
    expect(out, contains('Education, not investment advice.'));
    expect(
      out,
      contains(
        'https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker',
      ),
    );
  });

  test('the next day shows the next tip, and the list wraps around', () async {
    final a = (await _dryRun('2026-11-10')).stdout as String;
    final b = (await _dryRun('2026-11-11')).stdout as String;
    expect(a, isNot(b));
    final wrap =
        (await _dryRun(
              DateTime.utc(2026, 11, 10)
                  .add(Duration(days: tips.length))
                  .toIso8601String()
                  .substring(0, 10),
            )).stdout
            as String;
    expect(wrap, a);
  });

  test('a bad date fails instead of posting', () async {
    final r = await _dryRun('tomorrow');
    expect(r.exitCode, isNot(0));
  });

  test('sending needs both secrets and never prints them', () async {
    final r = await Process.run(
      'node',
      ['scripts/telegram-tip/post-tip.mjs'],
      environment: {'TELEGRAM_BOT_TOKEN': 'secret-token-123'},
    );
    expect(r.exitCode, isNot(0));
    expect('${r.stdout}${r.stderr}', isNot(contains('secret-token-123')));
  });

  test('the workflow posts on a schedule only when the switch is on', () {
    expect(workflow, contains("vars.TELEGRAM_POSTING_ENABLED"));
    expect(workflow, contains(r'[ "$POSTING_ENABLED" = "true" ]'));
    expect(workflow, contains('default: false'));
    expect(workflow, contains("if: github.ref == 'refs/heads/main'"));
    expect(
      workflow,
      matches(RegExp(r'^permissions:\s*\{\s*\}\s*$', multiLine: true)),
    );
  });

  test('secrets reach the job only through env, never inside run', () {
    final run = workflow.split('run: |').last;
    expect(run, isNot(contains(r'${{')));
    expect(workflow, contains('persist-credentials: false'));
  });
}

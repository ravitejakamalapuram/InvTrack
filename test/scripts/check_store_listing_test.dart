// Tests for scripts/check_store_listing.sh, the CI guard that keeps false
// data-handling and compliance claims out of the Play listing and README,
// and keeps the listing text within Play's length limits.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _script = 'scripts/check_store_listing.sh';
const _listing = 'android/fastlane/metadata/android/en-US';

const _cleanFull = 'Track what you invested and what came back.\n';

/// Builds a minimal repo tree with a valid listing and README, then applies
/// [files] (relative path -> content) on top of it.
Directory _fixture(Map<String, String> files) {
  final root = Directory.systemTemp.createTempSync('listing_check_');
  addTearDown(() => root.deleteSync(recursive: true));
  final all = <String, String>{
    '$_listing/title.txt': 'InvTrack - Investment Tracker\n',
    '$_listing/short_description.txt': 'Track investments with XIRR.\n',
    '$_listing/full_description.txt': _cleanFull,
    'README.md': '# InvTrack\n',
    ...files,
  };
  all.forEach((rel, content) {
    File('${root.path}/$rel')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  });
  return root;
}

Future<ProcessResult> _check(String root) =>
    Process.run('bash', [_script, root]);

String _output(ProcessResult r) => '${r.stdout}${r.stderr}';

void main() {
  test('clean fixture passes', () async {
    final r = await _check(_fixture({}).path);
    expect(r.exitCode, 0, reason: _output(r));
  });

  group('banned claims', () {
    const claims = {
      "straight apostrophe don't store":
          "We don't store your financial data on our servers.",
      'curly apostrophe don’t store':
          'We don’t store your financial data on our servers.',
      'do not store': 'We do not store your data anywhere.',
      'stays with you': 'It stays with you.',
      'OWASP MASVS Compliant': 'OWASP MASVS Compliant - security standard',
      'OWASP compliant': 'Fully OWASP compliant.',
      'MASVS compliant': 'MASVS compliant app.',
      'WCAG compliant': 'Accessibility - WCAG compliant',
      'WCAG 2.1 AA compliant': 'WCAG 2.1 AA compliant screens',
    };

    claims.forEach((name, text) {
      test('fails on "$name" in the full description', () async {
        final r = await _check(
          _fixture({
            '$_listing/full_description.txt': '$_cleanFull$text\n',
          }).path,
        );
        expect(r.exitCode, 1, reason: _output(r));
        expect(_output(r), contains('full_description.txt'));
      });

      test('fails on "$name" in README.md', () async {
        final r = await _check(
          _fixture({'README.md': '# InvTrack\n$text\n'}).path,
        );
        expect(r.exitCode, 1, reason: _output(r));
        expect(_output(r), contains('README.md'));
      });
    });

    test('fails on a banned claim in a changelog', () async {
      final r = await _check(
        _fixture({
          '$_listing/changelogs/300.txt': 'Your data stays with you.\n',
        }).path,
      );
      expect(r.exitCode, 1, reason: _output(r));
      expect(_output(r), contains('changelogs/300.txt'));
    });
  });

  group('stale version header', () {
    test('fails on "NEW IN VERSION 3.6.0" in the full description', () async {
      final r = await _check(
        _fixture({
          '$_listing/full_description.txt':
              '$_cleanFull\n🆕 NEW IN VERSION 3.6.0\n',
        }).path,
      );
      expect(r.exitCode, 1, reason: _output(r));
      expect(_output(r), contains('full_description.txt'));
    });

    test('allows a version number in a changelog', () async {
      final r = await _check(
        _fixture({
          '$_listing/changelogs/300.txt': 'New in version 3.80.0: goals.\n',
        }).path,
      );
      expect(r.exitCode, 0, reason: _output(r));
    });
  });

  group('length limits', () {
    // Each case: file, limit. Text of exactly `limit` characters passes and
    // one more fails. The trailing newline is not counted.
    const limits = {
      'title.txt': 30,
      'short_description.txt': 80,
      'full_description.txt': 4000,
    };

    limits.forEach((file, limit) {
      test('$file passes at $limit characters', () async {
        final r = await _check(
          _fixture({'$_listing/$file': '${'a' * limit}\n'}).path,
        );
        expect(r.exitCode, 0, reason: _output(r));
      });

      test('$file fails at ${limit + 1} characters', () async {
        final r = await _check(
          _fixture({'$_listing/$file': '${'a' * (limit + 1)}\n'}).path,
        );
        expect(r.exitCode, 1, reason: _output(r));
        expect(_output(r), contains(file));
        expect(_output(r), contains('${limit + 1}'));
      });
    });

    test('counts characters, not bytes', () async {
      // 28 ASCII characters + ₹ (3 bytes) + 📊 (4 bytes) = 30 characters,
      // 35 bytes.
      final title = '${'a' * 28}₹📊';
      final r = await _check(
        _fixture({'$_listing/title.txt': '$title\n'}).path,
      );
      expect(r.exitCode, 0, reason: _output(r));
    });

    test('fails when a required listing file is missing', () async {
      final root = _fixture({});
      File('${root.path}/$_listing/title.txt').deleteSync();
      final r = await _check(root.path);
      expect(r.exitCode, 1, reason: _output(r));
      expect(_output(r), contains('title.txt'));
    });
  });

  group('this repository', () {
    test('listing and README pass the check', () async {
      final r = await _check('.');
      expect(r.exitCode, 0, reason: _output(r));
    });

    test('full description makes no stale or unqualified claims', () {
      final text = File('$_listing/full_description.txt').readAsStringSync();
      expect(text, isNot(contains('NEW IN VERSION')));
      expect(text, isNot(contains('Use the app without internet')));
      expect(text.toLowerCase(), contains('after first sign-in'));
      expect(text, contains('Google Firebase'));
    });
  });
}

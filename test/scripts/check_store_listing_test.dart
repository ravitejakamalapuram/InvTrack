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
      // Variants of the same claims (re-audit finding ci-release-6).
      "doesn't store": "InvTrack doesn't store your data on any server.",
      'does not store': 'InvTrack does not store your data.',
      'never store': 'We never store your financial data.',
      'never leaves': 'Your data never leaves your phone.',
      "don't<NBSP>store": "We don't\u00a0store your data.",
      "don't store split across a line break": "We don't\nstore your data.",
      'OWASP-compliant': 'OWASP-compliant security.',
      'MASVS-compliant': 'MASVS-compliant app.',
      'WCAG 2.1 AA-compliant': 'WCAG 2.1 AA-compliant screens',
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

  test('allows the accurate data-handling wording', () async {
    // The wording that replaced the banned claims must keep passing.
    final r = await _check(
      _fixture({
        '$_listing/full_description.txt':
            '${_cleanFull}Your data is stored in your InvTrack account on '
            'Google Firebase. It is private to your account and never sold. '
            'Attached documents stay on your phone.\n',
        'README.md':
            '# InvTrack\nAttach documents (files stay on your device; only '
            'metadata syncs to Firestore).\n',
      }).path,
    );
    expect(r.exitCode, 0, reason: _output(r));
  });

  group('files the check cannot skip', () {
    // Re-audit finding ci-release-5: a missing README.md made grep exit 2,
    // which the script read as "no match" for the listing too.
    test('fails when README.md is missing', () async {
      final root = _fixture({});
      File('${root.path}/README.md').deleteSync();
      final r = await _check(root.path);
      expect(r.exitCode, 1, reason: _output(r));
      expect(_output(r), contains('README.md'));
    });

    test('still reports a listing claim when README.md is missing', () async {
      final root = _fixture({
        '$_listing/full_description.txt':
            "${_cleanFull}We don't store your data. It stays with you.\n",
      });
      File('${root.path}/README.md').deleteSync();
      final r = await _check(root.path);
      expect(r.exitCode, 1, reason: _output(r));
      expect(_output(r), contains('full_description.txt'));
    });

    // Re-audit finding integration-5: grep -r skipped symlinks, while the
    // length check and the Play upload follow them.
    test('fails when a listing file is a symlink', () async {
      final root = _fixture({
        'docs/listing_full.txt':
            "We don't store your data on any server. Your data stays with "
            'you.\n',
      });
      final file = File('${root.path}/$_listing/full_description.txt')
        ..deleteSync();
      Link(file.path).createSync('${root.path}/docs/listing_full.txt');
      final r = await _check(root.path);
      expect(r.exitCode, 1, reason: _output(r));
      expect(_output(r), contains('full_description.txt'));
    });

    test('fails when a locale folder is a symlink', () async {
      final root = _fixture({
        'docs/listing/title.txt': 'InvTrack - Investment Tracker\n',
        'docs/listing/short_description.txt': 'Track investments.\n',
        'docs/listing/full_description.txt': 'Your data stays with you.\n',
      });
      Link(
        '${root.path}/android/fastlane/metadata/android/hi-IN',
      ).createSync('${root.path}/docs/listing');
      final r = await _check(root.path);
      expect(r.exitCode, 1, reason: _output(r));
      expect(_output(r), contains('hi-IN'));
    });

    // Guard: the script runs grep with -I, which skips binary files. A text
    // file with one invalid UTF-8 byte must still be checked, not skipped.
    test('fails on a claim in a listing file with invalid UTF-8', () async {
      final root = _fixture({});
      File('${root.path}/$_listing/full_description.txt').writeAsBytesSync([
        ...'${_cleanFull}We don\'t store your data.'.codeUnits,
        0xff,
        0x0a,
      ]);
      final r = await _check(root.path);
      expect(r.exitCode, 1, reason: _output(r));
      expect(_output(r), contains('Banned claim'));
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

/// A Google OAuth client download (named like `client_secret_ID.apps.
/// googleusercontent.com.json`) must never be committed: it is a credential
/// file, it is not used by the app or the build, and a public repository keeps
/// it in history.
///
/// Plain file and git checks, no Flutter bindings. The git checks are skipped
/// on a checkout that is not a git work tree (a source archive); the
/// `.gitignore` check reads the file and always runs.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A path the ignore rule must cover, in the folder the file was found in.
const _sample =
    'android/app/client_secret_0123456789-example.apps.googleusercontent.com.json';

bool get _insideGitWorkTree {
  try {
    final r = Process.runSync('git', ['rev-parse', '--is-inside-work-tree']);
    return r.exitCode == 0 && (r.stdout as String).trim() == 'true';
  } on ProcessException {
    return false;
  }
}

void main() {
  final skipGit = _insideGitWorkTree ? null : 'not a git work tree';

  test('no OAuth client file is tracked', () {
    final r = Process.runSync('git', [
      'ls-files',
      '--',
      ':(glob)**/client_secret*.json',
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(
      (r.stdout as String).trim(),
      isEmpty,
      reason:
          'A client_secret*.json is tracked. Delete it from git and rotate '
          'the client secret in Google Cloud Console if it held one.',
    );
  }, skip: skipGit);

  test('.gitignore names the OAuth client download pattern', () {
    final lines = File('.gitignore').readAsLinesSync().map((l) => l.trim());
    expect(
      lines,
      contains('**/client_secret*.json'),
      reason:
          'a re-downloaded OAuth client file would be committed by '
          '`git add .`',
    );
  });

  test('git ignores an OAuth client download', () {
    final r = Process.runSync('git', ['check-ignore', '-q', _sample]);
    expect(r.exitCode, 0, reason: '$_sample is not ignored');
  }, skip: skipGit);
}

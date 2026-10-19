// A38: CI and supply-chain guards. Plain file checks over .github/ and
// .gitleaks.toml, no Flutter bindings.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _workflows() => Directory('.github/workflows')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.yml'))
    .toList();

void main() {
  test('no workflow turns off TLS verification', () {
    final insecure = RegExp(r'curl\b[^\n]*\s(-\w*k\w*|--insecure)\b');
    final offenders = <String>[];
    for (final f in _workflows()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (insecure.hasMatch(lines[i])) {
          offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('no workflow runs an unpinned tool (@latest)', () {
    final offenders = <String>[];
    for (final f in _workflows()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('@latest')) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });

  test('third-party actions are pinned to a full commit SHA', () {
    final uses = RegExp(r'^\s*(?:-\s*)?uses:\s*([^\s#]+)');
    final sha = RegExp(r'@[0-9a-f]{40}$');
    final offenders = <String>[];
    for (final f in _workflows()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final ref = uses.firstMatch(lines[i])?.group(1);
        if (ref == null || ref.startsWith('./')) continue;
        // Own reusable workflows are versioned by release tag (v2).
        if (ref.startsWith('ravitejakamalapuram/release-platform/')) continue;
        if (!sha.hasMatch(ref)) offenders.add('${f.path}:${i + 1} $ref');
      }
    }
    expect(offenders, isEmpty);
  });

  test('the production rules deploy only runs from main', () {
    final text =
        File('.github/workflows/deploy-firestore-rules.yml').readAsStringSync();
    expect(text, contains("if: github.ref == 'refs/heads/main'"));
    expect(text, contains('environment: production'));
  });

  test('ci.yml sets a workflow-level permissions block', () {
    final text = File('.github/workflows/ci.yml').readAsStringSync();
    expect(text, matches(RegExp(r'^permissions:', multiLine: true)));
  });

  test('gitleaks has no repo-wide regex allow-list', () {
    final text = File('.gitleaks.toml').readAsStringSync();
    expect(text, isNot(contains('regexes')));
  });
}

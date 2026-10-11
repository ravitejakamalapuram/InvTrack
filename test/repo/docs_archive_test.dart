/// A68: docs/ must tell the truth about itself. Older status reports, specs
/// and plans live in docs/archive; docs/ itself holds only the guides that
/// still describe the code. These are plain file checks (no Flutter bindings)
/// so they also run on a bare checkout.
///
/// A failure means docs/ again fills up with outdated documents, or a living
/// file cites a document that is no longer there.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Relative markdown link targets in [markdown] (anchors stripped; web, mail
/// and in-page links ignored).
Iterable<String> _relativeLinks(String markdown) sync* {
  for (final m in RegExp(r'\]\(([^)\s]+)\)').allMatches(markdown)) {
    final target = m.group(1)!;
    if (RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(target) ||
        target.startsWith('#')) {
      continue;
    }
    yield target.split('#').first;
  }
}

/// Files directly inside [dir], or none when the directory does not exist
/// (a removed folder must not make a scan throw).
Iterable<File> _filesIn(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return const <File>[];
  return d.listSync().where((e) => e is! Directory).map((e) => File(e.path));
}

/// Guides in docs/ that the separate change removing the Jules crash-fix
/// automation deletes. That change asserts they are gone; they are skipped
/// here so this change also passes on its own, before that one is merged.
const _deletedWithJulesAutomation = {'JULES_CRASH_FIX_AUTOMATION.md'};

void main() {
  group('docs', () {
    test('docs/ has fewer than 15 top-level files', () {
      final files = Directory('docs')
          .listSync()
          .whereType<File>()
          .map((f) => f.path.split(Platform.pathSeparator).last)
          .toList();
      expect(files.length, lessThan(15), reason: files.join(', '));
    });

    test('status reports live in docs/archive and the review stays put', () {
      expect(Directory('docs/archive').existsSync(), isTrue);
      expect(File('docs/review-2026-10/ACTION_PLAN.md').existsSync(), isTrue);
      expect(File('docs/review-2026-10/FINDINGS.md').existsSync(), isTrue);
    });

    test('living docs do not link to files that are not there', () {
      final broken = <String>[];
      for (final entity in Directory('docs').listSync()) {
        if (entity is! File || !entity.path.endsWith('.md')) continue;
        if (_deletedWithJulesAutomation.contains(
          entity.path.split(Platform.pathSeparator).last,
        )) {
          continue;
        }
        for (final link in _relativeLinks(entity.readAsStringSync())) {
          if (link.isEmpty) continue;
          final target = File('docs/$link');
          if (!target.existsSync() && !Directory('docs/$link').existsSync()) {
            broken.add('${entity.path} -> $link');
          }
        }
      }
      expect(broken, isEmpty, reason: broken.join('\n'));
    });

    test('README, scripts and CodeRabbit config only cite docs that exist', () {
      final sources = <File>[
        File('README.md'),
        File('.coderabbit.yaml'),
        File('.github/PR_DESCRIPTION.md'),
        ..._filesIn('scripts').where((f) => f.path.endsWith('.sh')),
        ..._filesIn('.github/scripts'),
      ];
      final missing = <String>[];
      for (final source in sources) {
        for (final line in source.readAsLinesSync()) {
          // A path inside a URL (https://.../docs/...) is not ours to check.
          for (final m in RegExp(
            r'(?<!https?://\S*)docs/[A-Za-z0-9_\-./]*\.(?:md|csv)',
          ).allMatches(line)) {
            if (!File(m.group(0)!).existsSync()) {
              missing.add('${source.path}: ${m.group(0)}');
            }
          }
        }
      }
      expect(missing, isEmpty, reason: missing.join('\n'));
    });

    test('CodeRabbit is not fed the retired technical spec', () {
      final config = _read('.coderabbit.yaml');
      expect(config, isNot(contains('InvTracker_TechSpec')));
      expect(config, isNot(contains('InvTracker_PRD')));
    });
  });

  group('docs and the removed Jules crash-fix automation', () {
    Iterable<File> liveDocs() => _filesIn('docs').where(
      (f) => !_deletedWithJulesAutomation.contains(
        f.path.split(Platform.pathSeparator).last,
      ),
    );

    test('no live doc is named after Jules', () {
      final named = liveDocs()
          .map((f) => f.path)
          .where((p) => p.toLowerCase().contains('jules'));
      expect(named, isEmpty, reason: named.join('\n'));
    });

    test('no live doc still points at the deleted automation files', () {
      // Case-insensitive on purpose: a renamed copy must not slip through.
      // Read as latin1 so a binary file in docs/ cannot make it throw.
      final pointer = RegExp(
        r'create-jules-sessions|monitor-jules-sessions|run-all-crash-fix|'
        r'create-summary-issue|fetch-crashlytics-data|firebase-helper|'
        r'JULES_CRASH_FIX|jules-crash-fix|jules_sessions|JULES_API_KEY',
        caseSensitive: false,
      );
      final stale = <String>[];
      for (final f in liveDocs().where((f) => f.path.endsWith('.md'))) {
        final lines = f.readAsLinesSync(encoding: latin1);
        for (var i = 0; i < lines.length; i++) {
          if (pointer.hasMatch(lines[i])) stale.add('${f.path}:${i + 1}');
        }
      }
      expect(stale, isEmpty, reason: stale.join('\n'));
    });
  });
}

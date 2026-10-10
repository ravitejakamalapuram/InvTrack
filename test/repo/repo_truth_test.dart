/// A68 / A53: the repository must tell the truth about itself. These are plain
/// file checks (no Flutter bindings) so they also run on a bare checkout.
///
/// Each group names the claim it guards. A failure means the repo again says
/// something its files do not back up (a licence that does not exist, a name
/// the app does not use). The claims about removed platforms are in
/// platforms_test.dart and the ones about docs/ are in docs_archive_test.dart.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// True when [text] spells the old app name in any quoting or case. The class
/// name `InvTrackerApp` is allowed (users never see it). Lower-case
/// `invtracker` alone is not matched: it is part of the package id and the
/// support domain.
bool _mentionsOldAppName(String text) =>
    RegExp(r'InvTracker(?!App\b)').hasMatch(text) ||
    RegExp(r'Inv(?:estment)?\s+Tracker', caseSensitive: false).hasMatch(text);

String _pubspecVersion() {
  final match = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(_read('pubspec.yaml'));
  expect(match, isNotNull, reason: 'pubspec.yaml has no version line');
  return match!.group(1)!;
}

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

/// Every file or link under [dir] (recursive), skipping dependency and build
/// folders. Callers that read content check `existsSync()` first.
Iterable<File> _filesUnder(String dir) sync* {
  final d = Directory(dir);
  if (!d.existsSync()) return;
  for (final e in d.listSync(recursive: true, followLinks: false)) {
    // A symlink counts too: a link named after a deleted file must not hide it.
    if (e is Directory) continue;
    final parts = e.path.split(Platform.pathSeparator);
    if (parts.contains('node_modules') || parts.contains('.dart_tool')) {
      continue;
    }
    yield File(e.path);
  }
}

void main() {
  group('licence', () {
    test('LICENSE exists, reserves all rights and grants no MIT licence', () {
      final file = File('LICENSE');
      expect(file.existsSync(), isTrue, reason: 'LICENSE is missing');
      final text = file.readAsStringSync();
      final notice = RegExp(
        r'Copyright \(c\) 20\d\d(-20\d\d)? Raviteja Kamalapuram\. '
        r'All rights reserved\.',
      );
      expect(notice.hasMatch(text), isTrue, reason: 'copyright notice');
      expect(
        text.toLowerCase(),
        contains('no licence to use, copy, modify or distribute'),
      );
      expect(text, isNot(contains('MIT')));
      expect(text, isNot(contains('Permission is hereby granted')));
    });

    test('README claims no MIT licence and points to the LICENSE file', () {
      final readme = _read('README.md');
      expect(readme, isNot(contains('License-MIT')));
      expect(RegExp(r'\bMIT\b').hasMatch(readme), isFalse, reason: 'MIT');
      expect(readme, contains('All rights reserved'));
      expect(readme, contains('(LICENSE)'));
    });
  });

  group('README', () {
    test('has no screenshots placeholder and links the Play listing', () {
      final readme = _read('README.md');
      expect(readme.toLowerCase(), isNot(contains('coming soon')));
      expect(
        readme,
        contains(
          'https://play.google.com/store/apps/details?id='
          'com.invtracker.inv_tracker',
        ),
      );
    });

    test('says golden tests run in the nightly job, not in PR checks', () {
      final readme = _read('README.md');
      // The claim is only true while nightly.yml really runs them.
      expect(
        _read('.github/workflows/nightly.yml'),
        contains('flutter test --tags golden'),
      );
      final claim = readme
          .split('\n')
          .where((l) => RegExp(r'golden', caseSensitive: false).hasMatch(l))
          .where((l) => l.contains('nightly.yml') && l.contains('not on pull'));
      expect(claim, isNotEmpty, reason: 'README golden-tests claim');
    });

    test('does not quote a test count that will go stale', () {
      final readme = _read('README.md');
      expect(readme, isNot(contains('868')));
      final counts = RegExp(
        r'\d[\d,]*\+?\s+(?:automated\s+|unit\s+)?tests',
        caseSensitive: false,
      ).allMatches(readme).map((m) => m.group(0));
      expect(counts, isEmpty, reason: 'hard-coded test count in README');
    });

    test('milestone notifications in the feature list match the app', () {
      final source = _read(
        'lib/core/notifications/handlers/investment_notification_handler.dart',
      );
      final constant = RegExp(
        r'standardMilestones\s*=\s*\[([^\]]*)\]',
      ).firstMatch(source);
      expect(constant, isNotNull, reason: 'standardMilestones moved');
      final inApp = [
        for (final s in constant!.group(1)!.split(','))
          if (s.trim().isNotEmpty) double.parse(s.trim()),
      ];
      final line = RegExp(
        r'Investment milestones \(([^)]*)\)',
      ).firstMatch(_read('README.md'));
      expect(line, isNotNull, reason: 'README has no milestones line');
      final inReadme = [
        for (final m in RegExp(r'(\d+(?:\.\d+)?)x').allMatches(line!.group(1)!))
          double.parse(m.group(1)!),
      ];
      expect(inReadme, inApp);
    });

    test('every relative link resolves to a file or folder', () {
      final broken = [
        for (final link in _relativeLinks(_read('README.md')))
          if (link.isNotEmpty &&
              !File(link).existsSync() &&
              !Directory(link).existsSync())
            link,
      ];
      expect(broken, isEmpty, reason: 'broken README links: $broken');
    });
  });

  group('one name: InvTrack', () {
    test('Android launcher label is InvTrack', () {
      expect(
        _read('android/app/src/main/AndroidManifest.xml'),
        contains('android:label="InvTrack"'),
      );
    });

    test('iOS display name and bundle name are InvTrack', () {
      final plist = _read('ios/Runner/Info.plist');
      for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
        final value = RegExp(
          '<key>$key</key>\\s*<string>([^<]*)</string>',
        ).firstMatch(plist)?.group(1);
        expect(value, 'InvTrack', reason: key);
      }
    });

    test('the manifests and permission prompts never say InvTracker', () {
      expect(
        _read('android/app/src/main/AndroidManifest.xml'),
        isNot(contains('InvTracker')),
      );
      expect(_read('ios/Runner/Info.plist'), isNot(contains('InvTracker')));
    });

    test('pubspec description uses the app name InvTrack', () {
      final description = RegExp(
        r'^description:\s*"?([^"\n]*)',
        multiLine: true,
      ).firstMatch(_read('pubspec.yaml'))?.group(1);
      expect(description, startsWith('InvTrack -'));
    });

    test('no Dart string in lib/ says InvTracker or Investment Tracker', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (path.startsWith('lib/l10n/generated/')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (_mentionsOldAppName(line)) offenders.add('$path:${i + 1}');
        }
      }
      expect(offenders, isEmpty, reason: 'old app name in $offenders');
    });

    test('no localised string says the old app name', () {
      final offenders = <String>[];
      for (final entity in Directory('lib/l10n').listSync()) {
        if (entity is! File || !entity.path.endsWith('.arb')) continue;
        final arb =
            jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
        for (final entry in arb.entries) {
          final value = entry.value;
          if (!entry.key.startsWith('@') &&
              value is String &&
              _mentionsOldAppName(value)) {
            offenders.add('${entity.path}: ${entry.key}');
          }
        }
      }
      expect(offenders, isEmpty, reason: 'old app name in $offenders');
    });

    test('the old-name check catches every spelling and spares the rest', () {
      for (final text in [
        "'InvTracker'",
        '"InvTracker"',
        "'Investment Tracker'",
        '"Investment Tracker"',
        "'Welcome to Investment Tracker'",
        "'Inv Tracker'",
        "'investment tracker'",
        "'INVESTMENT TRACKER'",
        'InvTracker is a tracking tool only.',
      ]) {
        expect(_mentionsOldAppName(text), isTrue, reason: text);
      }
      for (final text in [
        "'InvTrack'",
        'class InvTrackerApp extends ConsumerWidget {',
        'const InvTrackerApp()',
        'support@invtracker.app',
        'com.invtracker.inv_tracker',
        "import 'package:inv_tracker/main.dart';",
        'investment tracking for alternative assets',
      ]) {
        expect(_mentionsOldAppName(text), isFalse, reason: text);
      }
    });
  });

  group('app metadata and release version', () {
    test('app-metadata.json is gone (nothing reads it)', () {
      expect(File('app-metadata.json').existsSync(), isFalse);
    });

    test('product.yaml has no private path and no outdated notes', () {
      final product = _read('.appforge/product.yaml');
      expect(product, isNot(contains('git-personal')));
      expect(product, isNot(contains('Three inconsistent support emails')));
      expect(
        product,
        isNot(contains('expectedCashFlows and document metadata are not')),
      );
    });

    test('product.yaml says whether a workflow runs the deletion job', () {
      final runsJob = Directory('.github/workflows')
          .listSync()
          .whereType<File>()
          .any((f) => f.readAsStringSync().contains('run.mjs'));
      final product = _read('.appforge/product.yaml');
      if (!runsJob && product.contains('scripts/account-deletion')) {
        expect(
          product,
          contains('workflow that runs it is not merged yet'),
          reason: 'no workflow runs scripts/account-deletion/run.mjs',
        );
      }
      if (runsJob) {
        expect(
          product,
          isNot(contains('not merged yet')),
          reason: 'a workflow runs scripts/account-deletion/run.mjs',
        );
        expect(product, contains('ACCOUNT_DELETION_SCHEDULE_ENABLED'));
      }
    });

    test('README and product.yaml do not hard-code the app version', () {
      final version = _pubspecVersion();
      final semver = version.split('+').first;
      for (final path in ['README.md', '.appforge/product.yaml']) {
        final text = _read(path);
        expect(text, isNot(contains(version)), reason: path);
        expect(text, isNot(contains(semver)), reason: path);
      }
    });

    test('the release version comes from the git release tag', () {
      // The claim is only true while release.yaml builds with the tag-derived
      // values and not with the version in pubspec.yaml.
      final release = _read('release.yaml');
      expect(release, contains('--build-name "\$VERSION_NAME"'));
      expect(release, contains('--build-number "\$VERSION_CODE"'));
      expect(release, contains('vX.Y.Z tag'));

      for (final path in ['README.md', '.appforge/product.yaml']) {
        final sentence = _read(path)
            .split('\n')
            .where(
              (l) =>
                  l.contains('git release tag') &&
                  l.contains('release.yaml') &&
                  l.contains('pubspec.yaml'),
            );
        expect(sentence, isNotEmpty, reason: '$path must name the git tag');
      }
    });

    test(
      'nothing claims pubspec.yaml is the source of the release version',
      () {
        final claim = RegExp(
          r'pubspec[^\n]*(source of truth|source in the repo|is the source)',
          caseSensitive: false,
        );
        for (final path in [
          'README.md',
          '.appforge/product.yaml',
          '.github/PR_DESCRIPTION.md',
        ]) {
          final offending = _read(path).split('\n').where(claim.hasMatch);
          expect(offending, isEmpty, reason: path);
        }
      },
    );
  });

  group('removed Jules crash-fix automation', () {
    const gone = [
      '.github/scripts/create-jules-sessions.sh',
      '.github/scripts/monitor-jules-sessions.sh',
      '.github/scripts/run-all-crash-fix.sh',
      '.github/scripts/create-summary-issue.sh',
      '.github/scripts/fetch-crashlytics-data.sh',
      '.github/scripts/firebase-helper.js',
      'docs/JULES_CRASH_FIX_AUTOMATION.md',
      'docs/archive/JULES_CRASH_FIX_AUTOMATION.md',
    ];

    test('its scripts and guide are deleted', () {
      final back = gone.where((p) => File(p).existsSync()).toList();
      expect(back, isEmpty, reason: 'deleted files are back: $back');
    });

    test('no script named after Jules is added again', () {
      final named = [
        ..._filesUnder('.github'),
        ..._filesUnder('scripts'),
      ].map((f) => f.path).where((p) => p.toLowerCase().contains('jules'));
      expect(named, isEmpty, reason: named.join('\n'));
    });

    test('nothing live still points at the deleted files', () {
      // Case-insensitive on purpose: a renamed copy must not slip through.
      // Read as latin1 so a binary file in these folders cannot make it throw.
      // The docs/ folder is checked the same way in docs_archive_test.dart.
      final pointer = RegExp(
        r'create-jules-sessions|monitor-jules-sessions|run-all-crash-fix|'
        r'create-summary-issue|fetch-crashlytics-data|firebase-helper|'
        r'JULES_CRASH_FIX|jules-crash-fix|jules_sessions|JULES_API_KEY',
        caseSensitive: false,
      );
      final sources = <File>[
        ..._filesUnder('.github'),
        ..._filesUnder('scripts'),
        ..._filesUnder('.augment'),
        File('README.md'),
        File('CLAUDE.md'),
        File('.coderabbit.yaml'),
        File('.gitignore'),
        File('release.yaml'),
      ];
      final stale = <String>[];
      for (final f in sources) {
        if (!f.existsSync()) continue;
        final lines = f.readAsLinesSync(encoding: latin1);
        for (var i = 0; i < lines.length; i++) {
          if (pointer.hasMatch(lines[i])) stale.add('${f.path}:${i + 1}');
        }
      }
      expect(stale, isEmpty, reason: stale.join('\n'));
    });
  });

  group('developer name', () {
    test('is spelled Raviteja Kamalapuram, never Ravi Teja', () {
      final misspelt = RegExp(r'Ravi[\s_-]+Teja', caseSensitive: false);
      final offenders = <String>[];
      for (final f in [
        File('README.md'),
        File('LICENSE'),
        File('pubspec.yaml'),
        ..._filesUnder('.appforge'),
        ..._filesUnder(
          'lib',
        ).where((f) => f.path.endsWith('.dart') || f.path.endsWith('.arb')),
        ..._filesUnder(
          'android/fastlane/metadata',
        ).where((f) => f.path.endsWith('.txt')),
      ]) {
        if (f.existsSync() &&
            misspelt.hasMatch(f.readAsStringSync(encoding: latin1))) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
      expect(
        _read('README.md'),
        contains('**Developer**: Raviteja Kamalapuram'),
      );
    });
  });
}

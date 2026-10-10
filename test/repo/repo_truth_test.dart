/// A68 / A53: the repository must tell the truth about itself. These are plain
/// file checks (no Flutter bindings) so they also run on a bare checkout.
///
/// Each group names the claim it guards. A failure means the repo again says
/// something its files do not back up (a licence that does not exist, a
/// platform that is not built, a name the app does not use).
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

  group('unused platforms', () {
    for (final folder in ['web', 'macos', 'windows', 'linux']) {
      test('$folder/ is gone', () {
        expect(Directory(folder).existsSync(), isFalse);
      });
    }

    test('android/ and ios/ are kept (iOS is deferred, not dropped)', () {
      expect(Directory('android').existsSync(), isTrue);
      expect(Directory('ios').existsSync(), isTrue);
    });

    test('launcher icons are configured for android and ios only', () {
      final pubspec = _read('pubspec.yaml');
      for (final platform in ['web', 'windows', 'macos']) {
        expect(
          RegExp('^  $platform:', multiLine: true).hasMatch(pubspec),
          isFalse,
          reason: 'flutter_launcher_icons still has a $platform block',
        );
      }
    });

    test('.metadata does not list the removed platforms', () {
      final metadata = _read('.metadata');
      for (final platform in ['linux', 'macos', 'web', 'windows']) {
        expect(metadata, isNot(contains('platform: $platform')));
      }
    });

    test('firebase.json configures android and ios only', () {
      final flutter =
          (jsonDecode(_read('firebase.json'))
                  as Map<String, dynamic>)['flutter']
              as Map<String, dynamic>;
      final platforms = flutter['platforms'] as Map<String, dynamic>;
      final dart = platforms['dart'] as Map<String, dynamic>;
      final configurations = [
        for (final file in dart.values)
          ...((file as Map<String, dynamic>)['configurations']
                  as Map<String, dynamic>)
              .keys,
      ];
      expect(
        [...platforms.keys.where((k) => k != 'dart'), ...configurations]
          ..sort(),
        ['android', 'android', 'ios', 'ios'],
        reason: 'firebase.json still names a removed platform',
      );
    });

    test('.gitleaks.toml no longer allowlists files of removed platforms', () {
      final gitleaks = _read('.gitleaks.toml');
      for (final folder in ['macos/', 'windows/', 'web/', 'linux/']) {
        expect(gitleaks, isNot(contains(folder)), reason: folder);
      }
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
        ...Directory(
          'scripts',
        ).listSync().whereType<File>().where((f) => f.path.endsWith('.sh')),
        ...Directory('.github/scripts').listSync().whereType<File>(),
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

  group('app metadata and version source of truth', () {
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

    test(
      'product.yaml says the deletion job runs only if a workflow runs it',
      () {
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
      },
    );

    test('pubspec.yaml is the only place that hard-codes the app version', () {
      final version = _pubspecVersion();
      final semver = version.split('+').first;
      for (final path in ['README.md', '.appforge/product.yaml']) {
        final text = _read(path);
        expect(text, isNot(contains(version)), reason: path);
        expect(text, isNot(contains(semver)), reason: path);
      }
      expect(_read('.appforge/product.yaml'), contains('pubspec.yaml'));
    });
  });
}

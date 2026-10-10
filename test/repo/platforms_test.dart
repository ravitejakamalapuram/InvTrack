/// A68: the repository must not carry platforms the app does not build.
/// These are plain file checks (no Flutter bindings) so they also run on a
/// bare checkout.
///
/// A failure means the repo again holds a platform folder, or config for one,
/// that nothing builds or ships: web, macOS, Windows and Linux were removed;
/// Android is the shipped platform and iOS is kept for a later release.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
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
}

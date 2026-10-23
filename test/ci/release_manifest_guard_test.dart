@TestOn('linux || mac-os')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _script = 'scripts/ci/check_release_manifest.sh';

/// Runs the guard on a manifest holding [body].
Future<ProcessResult> _run(String body) async {
  final dir = Directory.systemTemp.createTempSync('manifest_guard');
  addTearDown(() => dir.deleteSync(recursive: true));
  final file = File('${dir.path}/AndroidManifest.xml')..writeAsStringSync(body);
  return Process.run('bash', [_script, file.path]);
}

void main() {
  group('release manifest guard', () {
    test('the guard script exists', () {
      expect(File(_script).existsSync(), isTrue);
    });

    test(
      'passes a merged manifest with no advertising ID and no AdMob ID',
      () async {
        final r = await _run(
          '<manifest><uses-permission android:name="android.permission.INTERNET"/>'
          '<application/></manifest>',
        );
        expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      },
    );

    test('fails when the advertising ID permission is merged in', () async {
      final r = await _run(
        '<manifest><uses-permission '
        'android:name="com.google.android.gms.permission.AD_ID"/></manifest>',
      );
      expect(r.exitCode, 1);
      expect(r.stdout, contains('AD_ID'));
    });

    test('fails when an AdMob application ID is merged in', () async {
      final r = await _run(
        '<manifest><application><meta-data '
        'android:name="com.google.android.gms.ads.APPLICATION_ID" '
        'android:value="ca-app-pub-1~2"/></application></manifest>',
      );
      expect(r.exitCode, 1);
      expect(r.stdout, contains('AdMob'));
    });

    test('fails when the manifest file is missing', () async {
      final r = await Process.run('bash', [_script, '/nonexistent/m.xml']);
      expect(r.exitCode, isNot(0));
    });
  });
}

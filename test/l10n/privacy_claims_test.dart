@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';

/// A69 (C074, SEC-05): user data sits in the developer's Firebase project
/// without client-side encryption, so the operator can read it. No in-app
/// text may say that only the user can read it or call it a private cloud.
/// Whitespace runs (line breaks, no-break spaces) between words still match.
final _bannedClaims = <String, RegExp>{
  'only you can read': RegExp(
    r'only\s+you\s+can\s+(read|see|access)',
    caseSensitive: false,
  ),
  'private cloud': RegExp(r'private\s+cloud', caseSensitive: false),
};

const _dataNotice =
    'The app lock protects access to InvTrack on this device. Your data is '
    "stored in InvTrack's Google Firebase project under your account, with "
    'an offline copy on this device so InvTrack keeps working without a '
    'connection. In the app, only your signed-in account can see it. The '
    'developer can technically access stored data and does so only to '
    'handle your support or deletion requests, or when the law requires it.';

void main() {
  test('no app_en.arb string makes a false privacy claim', () {
    final arb =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final offending = <String>[];
    arb.forEach((key, value) {
      if (key.startsWith('@') || value is! String) return;
      _bannedClaims.forEach((name, pattern) {
        if (pattern.hasMatch(value)) offending.add('$key: "$name"');
      });
    });
    expect(offending, isEmpty);
  });

  test('no file under lib/ makes a false privacy claim', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') || f.path.endsWith('.arb'))
        .toList();
    // The scan must not pass just because it found nothing to read.
    expect(
      files.map((f) => f.path.replaceAll(r'\', '/')),
      containsAll([
        'lib/l10n/app_en.arb',
        'lib/features/settings/presentation/screens/legal_content.dart',
      ]),
    );
    final offending = <String>[];
    for (final file in files) {
      final text = file.readAsStringSync();
      _bannedClaims.forEach((name, pattern) {
        if (pattern.hasMatch(text)) offending.add('${file.path}: "$name"');
      });
    }
    expect(offending, isEmpty);
  });

  test('security data notice says plainly who can read stored data', () {
    expect(AppLocalizationsEn().dataStoredLocallyMessage, _dataNotice);
  });
}

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';

/// A76: `l10n.yaml` sets `use-escaping: true`, so `flutter gen-l10n` reads a
/// single `'` as the start or end of an escaped section and drops it. An
/// apostrophe in an ARB value must be written `''`.
void main() {
  final arbFiles =
      Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('the English template is among the checked ARB files', () {
    expect(
      arbFiles.map((file) => file.uri.pathSegments.last),
      contains('app_en.arb'),
    );
  });

  for (final file in arbFiles) {
    final name = file.uri.pathSegments.last;

    test("$name writes every apostrophe as ''", () {
      final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final bare = <String>[];
      arb.forEach((key, value) {
        if (key.startsWith('@') || value is! String) return;
        if (value.replaceAll("''", '').contains("'")) bare.add(key);
      });
      expect(
        bare,
        isEmpty,
        reason: "Values with a bare ' that gen-l10n drops. Write it as ''.",
      );
    });
  }

  test('the offline account-deletion message keeps both apostrophes', () {
    expect(
      AppLocalizationsEn().deletionNeedsInternet,
      "Couldn't finish deleting because you're offline or the connection is "
      'unstable. Some of your data may already have been removed, but your '
      'account is still active. Please connect to the internet and try '
      'again to finish.',
    );
  });
}

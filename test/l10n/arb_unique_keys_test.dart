@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A87: JSON allows a key to repeat, and `flutter gen-l10n` silently keeps
/// the last copy. An edit to an earlier copy then changes nothing on screen,
/// so every top-level ARB key must appear once.
///
/// `jsonDecode` already drops the earlier copies, so the keys are read from
/// the raw text instead.
List<String> _topLevelKeys(String source) {
  final keys = <String>[];
  var depth = 0;
  var expectKey = false;
  var i = 0;
  while (i < source.length) {
    final char = source[i];
    if (char == '"') {
      final start = i;
      i++;
      while (source[i] != '"') {
        if (source[i] == r'\') i++;
        i++;
      }
      if (depth == 1 && expectKey) {
        keys.add(jsonDecode(source.substring(start, i + 1)) as String);
      }
      expectKey = false;
    } else if (char == '{' || char == '[') {
      depth++;
      expectKey = char == '{' && depth == 1;
    } else if (char == '}' || char == ']') {
      depth--;
    } else if (char == ',' && depth == 1) {
      expectKey = true;
    }
    i++;
  }
  return keys;
}

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

  // When the duplicates were removed, the context from each dropped copy's
  // description was merged into the kept @-block, so translators still see
  // every place the string is used.
  test('kept @-blocks carry the context of the removed duplicates', () {
    final arb =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    expect(
      {
        for (final key in const [
          'daysAgo',
          'weeklySummary',
          'deleteAccount',
          'investmentType',
          'portfolioHealth',
          'exportAsCsv',
          'smartInsights',
        ])
          key: arb['@$key'],
      },
      equals({
        'daysAgo': {
          'description': 'Shows days in the past',
          'placeholders': {
            'days': {'type': 'int', 'example': '3'},
          },
        },
        'weeklySummary': {
          'description':
              'Weekly summary: notification toggle title and report title',
        },
        'deleteAccount': {'description': 'Title of the delete-account dialog'},
        'investmentType': {
          'description': 'Label for the investment type selection',
        },
        'portfolioHealth': {
          'description':
              'Portfolio health: dashboard card title and report title',
        },
        'exportAsCsv': {'description': 'Export as CSV menu item title'},
        'smartInsights': {
          'description': 'Section title for automatically generated insights',
        },
      }),
    );
  });

  for (final file in arbFiles) {
    final name = file.uri.pathSegments.last;

    test('$name defines each top-level key once', () {
      final source = file.readAsStringSync();
      final keys = _topLevelKeys(source);

      // The scanner must see every key jsonDecode sees, or it could pass by
      // missing keys.
      final decoded = jsonDecode(source) as Map<String, dynamic>;
      expect(keys.toSet(), equals(decoded.keys.toSet()));

      final counts = <String, int>{};
      for (final key in keys) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
      final duplicates = {
        for (final entry in counts.entries)
          if (entry.value > 1) entry.key: entry.value,
      };
      expect(
        duplicates,
        isEmpty,
        reason:
            'gen-l10n keeps only the last copy of these keys: '
            '${[for (final e in duplicates.entries) '${e.key} x${e.value}'].join(', ')}',
      );
    });
  }
}

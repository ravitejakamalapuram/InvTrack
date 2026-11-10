// The bundled tips file must stay valid: unique ids, short readable text,
// no investment advice wording.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/tips/domain/tip.dart';

void main() {
  final tips =
      (jsonDecode(File('assets/tips/tips.json').readAsStringSync()) as List)
          .map((e) => Tip.fromJson(e as Map<String, dynamic>))
          .toList();

  test('there are tips and ids are unique', () {
    expect(tips.length, greaterThanOrEqualTo(10));
    expect(tips.map((t) => t.id).toSet().length, tips.length);
  });

  test('titles and bodies are short', () {
    for (final t in tips) {
      expect(t.title.trim(), isNotEmpty, reason: t.id);
      expect(t.title.length, lessThanOrEqualTo(40), reason: t.id);
      expect(t.body.trim(), isNotEmpty, reason: t.id);
      expect(t.body.length, lessThanOrEqualTo(200), reason: t.id);
    }
  });

  test('no tip tells the reader to buy, sell or invest in something', () {
    final banned = RegExp(
      r'\b(you should (buy|sell|invest)|guaranteed|sure shot|best (fd|stock|scheme))\b',
      caseSensitive: false,
    );
    for (final t in tips) {
      expect(banned.hasMatch('${t.title} ${t.body}'), isFalse, reason: t.id);
    }
  });
}

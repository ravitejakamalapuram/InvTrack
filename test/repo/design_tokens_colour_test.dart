/// The neutral greys in design/system/tokens.json are copies of the constants in
/// lib/core/theme/app_colors.dart (the README says the code wins). This fails
/// when a grey is changed in one place and not the other. Plain file check, like
/// design_tokens_layout_test.dart.
///
/// Only the greys: the other colours are named differently in the tokens, so
/// there is no name to match them by.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `{name, value}` token in [node], by name.
void _collect(Object? node, Map<String, Object?> into) {
  if (node is Map<String, dynamic>) {
    final name = node['name'];
    if (name is String && node.containsKey('value')) into[name] = node['value'];
    for (final v in node.values) {
      _collect(v, into);
    }
  } else if (node is List) {
    for (final v in node) {
      _collect(v, into);
    }
  }
}

void main() {
  test('every neutral grey in app_colors.dart is a token with the same hex', () {
    final source = File('lib/core/theme/app_colors.dart').readAsStringSync();
    final greys = RegExp(
      r'static const Color neutral(\d+)(Light|Dark) = Color\(0xFF([0-9A-Fa-f]{6})\);',
    ).allMatches(source).toList();
    expect(
      greys.length,
      'static const Color neutral'.allMatches(source).length,
      reason: 'A neutral grey is written in a form this test cannot read.',
    );
    expect(greys, isNotEmpty);

    final tokens = <String, Object?>{};
    _collect(
      jsonDecode(File('design/system/tokens.json').readAsStringSync()),
      tokens,
    );
    final drift = <String>[];
    for (final m in greys) {
      final hex = '#${m.group(3)!.toLowerCase()}';
      final name = 'neutral-${m.group(1)}-${m.group(2)!.toLowerCase()}';
      final value = tokens[name];
      // A primitive carries one hex for both themes: {"light": ..., "dark": ...}.
      final painted = value is Map ? {value['light'], value['dark']} : {value};
      if (painted.length != 1 || painted.single != hex) {
        drift.add('$name: tokens.json has $value, app_colors.dart has $hex');
      }
    }
    expect(
      drift,
      isEmpty,
      reason: 'Change both in the same commit:\n${drift.join('\n')}',
    );
  });
}

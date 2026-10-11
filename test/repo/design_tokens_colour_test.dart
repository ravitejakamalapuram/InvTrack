/// The neutral greys in design/system/tokens.json are copies of the constants in
/// lib/core/theme/app_colors.dart (the README says the code wins). This fails
/// when a grey is changed in one place and not the other. Plain file check, like
/// design_tokens_layout_test.dart.
///
/// The greys are matched by name. The green and red status colours are named
/// differently in the code (`successLight`, `successTintLight`) and in the
/// tokens (`success`, `success-tint`), so they are matched by a short table.
/// The other colours have no test yet.
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

/// `static const Color name = Color(0xFFrrggbb);` as `name: #rrggbb`.
Map<String, String> _hexes(String source) => {
  for (final m in RegExp(
    r'static const Color (\w+) = Color\(0xFF([0-9A-Fa-f]{6})\);',
  ).allMatches(source))
    m.group(1)!: '#${m.group(2)!.toLowerCase()}',
};

void main() {
  test('the green and red tokens are the colours app_colors.dart paints', () {
    final hexes = _hexes(
      File('lib/core/theme/app_colors.dart').readAsStringSync(),
    );
    final tokens = <String, Object?>{};
    _collect(
      jsonDecode(File('design/system/tokens.json').readAsStringSync()),
      tokens,
    );
    // Token, the constant it paints in light and the one in dark. The tint
    // sources are the same in both themes.
    const table = [
      ('success', 'successLight', 'successDark'),
      ('success-tint', 'successTintLight', 'successTintLight'),
      ('success-bg', 'successBgLight', 'successBgLight'),
      ('danger', 'dangerLight', 'dangerDark'),
      ('danger-tint', 'dangerTintLight', 'dangerTintLight'),
      ('danger-bg', 'dangerBgLight', 'dangerBgLight'),
    ];
    final drift = <String>[];
    for (final (token, light, dark) in table) {
      final value = tokens[token];
      if (value is! Map) {
        drift.add('$token: missing from tokens.json');
        continue;
      }
      if (value['light'] != hexes[light]) {
        drift.add(
          '$token light: tokens.json ${value['light']}, $light ${hexes[light]}',
        );
      }
      if (value['dark'] != hexes[dark]) {
        drift.add(
          '$token dark: tokens.json ${value['dark']}, $dark ${hexes[dark]}',
        );
      }
    }
    expect(
      drift,
      isEmpty,
      reason: 'Change both in the same commit:\n${drift.join('\n')}',
    );
  });

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

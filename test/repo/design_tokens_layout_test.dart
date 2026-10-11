/// The layout tokens in design/system/tokens.json are copies of the Dart
/// constants (the README says the code wins). This fails when one is changed
/// without the other. Plain file check, like platforms_test.dart.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';

/// Token name -> the Dart constant it documents.
const _layoutTokens = <String, double>{
  'screen-padding-x': AppSpacing.screenPaddingHorizontal,
  'screen-edge': AppSpacing.screenEdge,
  'screen-padding-compact': AppSpacing.screenPaddingCompact,
  'fab-margin': AppSpacing.fabMargin,
  'fab-bottom-padding': AppSpacing.fabBottomPadding,
  'fab-size': AppSizes.fabSize,
  'touch-target-min': AppSizes.minTouchTarget,
  'tonal-action-chip': AppSizes.tonalActionChip,
};

/// Every `{name, value}` token in [node], by name.
void _collect(Object? node, Map<String, String> into) {
  if (node is Map<String, dynamic>) {
    final name = node['name'];
    final value = node['value'];
    if (name is String && value is String) into[name] = value;
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
  test('tokens.json matches the Dart layout constants', () {
    final tokens = <String, String>{};
    _collect(
      jsonDecode(File('design/system/tokens.json').readAsStringSync()),
      tokens,
    );
    for (final entry in _layoutTokens.entries) {
      expect(
        tokens[entry.key],
        '${entry.value.toInt()}px',
        reason:
            'design/system/tokens.json "${entry.key}" differs from the Dart '
            'constant; change both in the same commit',
      );
    }
  });
}

import 'package:flutter_test/flutter_test.dart';

/// Parameter names that would carry a name, an amount, an email, a file name
/// or path, notes or an id (CLAUDE.md rule 7). Amounts go out only as buckets
/// (`amount_range`), flags only as `has_notes` style 1/0 values.
const _forbiddenKeys = {
  'name',
  'display_name',
  'investment_name',
  'goal_name',
  'amount',
  'email',
  'file',
  'file_name',
  'path',
  'notes',
  'goal_id',
  'investment_id',
  'user_id',
  'uid',
};

final _snakeCase = RegExp(r'^[a-z][a-z0-9_]*$');

/// Fails unless [event] is safe to send to Analytics.
///
/// - the event and parameter names are snake_case and within GA4's 40
///   characters, with no forbidden key (see [_forbiddenKeys]);
/// - every value is a [String] or a [num], never a bool: the Firebase plugin
///   asserts on anything else;
/// - `has_*` and `is_*` flags are 1 or 0;
/// - every [String] value is in [allowedStrings] for its key, so text can
///   only be a known enum value, never something the user typed; it holds no
///   `@`, `/` or `\` (email, path) and is within GA4's 100 characters.
void expectPrivacySafe(
  ({String name, Map<String, Object>? parameters}) event, {
  Map<String, Set<String>> allowedStrings = const {},
}) {
  final name = event.name;
  expect(
    name,
    allOf(matches(_snakeCase), hasLength(lessThanOrEqualTo(40))),
    reason: 'event name "$name"',
  );
  for (final MapEntry(:key, :value) in (event.parameters ?? {}).entries) {
    final where = 'parameter "$key" of "$name"';
    expect(_forbiddenKeys, isNot(contains(key)), reason: '$where is forbidden');
    expect(
      key,
      allOf(matches(_snakeCase), hasLength(lessThanOrEqualTo(40))),
      reason: where,
    );
    expect(
      value is String || value is num,
      isTrue,
      reason: '$where must be a String or a num, was ${value.runtimeType}',
    );
    if (key.startsWith('has_') || key.startsWith('is_')) {
      expect(value, anyOf(0, 1), reason: '$where is a flag: send 1 or 0');
    }
    if (value is String) {
      expect(
        allowedStrings[key],
        isNotNull,
        reason: '$where is text but has no allow-list',
      );
      expect(
        allowedStrings[key],
        contains(value),
        reason: '$where is not an allowed value',
      );
      expect(
        value,
        isNot(matches(r'[@/\\]')),
        reason:
            '$where looks like '
            'an email or a path',
      );
      expect(value, hasLength(lessThanOrEqualTo(100)), reason: where);
    }
  }
}

// The privacy helper is only worth using if it fails on what rule 7 forbids.
import 'package:flutter_test/flutter_test.dart';

import 'analytics_privacy.dart';

({String name, Map<String, Object>? parameters}) _event(
  Map<String, Object>? parameters, {
  String name = 'xirr_viewed',
}) => (name: name, parameters: parameters);

void main() {
  test('accepts an allowed enum string, a bucket and 1/0 flags', () {
    expectPrivacySafe(
      _event({'surface': 'overview', 'is_estimate': 0, 'amount_range': '1k'}),
      allowedStrings: {
        'surface': {'overview'},
        'amount_range': {'1k'},
      },
    );
  });

  test('accepts an event without parameters', () {
    expectPrivacySafe(_event(null));
  });

  final violations = <String, ({String name, Map<String, Object>? parameters})>{
    'an amount key': _event({'amount': 50000}),
    'a name key': _event({'name': 'SBI FD'}),
    'a notes key': _event({'notes': 1}),
    'a goal id key': _event({'goal_id': 7}),
    'a bool value': _event({'has_notes': true}),
    'a flag that is not 1 or 0': _event({'has_notes': 2}),
    'an event name that is not snake_case': _event(null, name: 'XirrViewed'),
    'an event name over 40 characters': _event(null, name: 'a' * 41),
  };
  for (final MapEntry(key: what, value: event) in violations.entries) {
    test('rejects $what', () {
      expect(() => expectPrivacySafe(event), throwsA(isA<TestFailure>()));
    });
  }

  test('rejects text with no allow-list entry', () {
    expect(
      () => expectPrivacySafe(_event({'surface': 'overview'})),
      throwsA(isA<TestFailure>()),
    );
  });

  for (final MapEntry(key: what, value: text) in {
    'an email': 'ravi@example.com',
    'a path': '/data/user/0/backup.zip',
  }.entries) {
    test('rejects $what even when it is allow-listed', () {
      expect(
        () => expectPrivacySafe(
          _event({'surface': text}),
          allowedStrings: {
            'surface': {text},
          },
        ),
        throwsA(isA<TestFailure>()),
      );
    });
  }

  test('rejects a string that is not in the allow-list', () {
    expect(
      () => expectPrivacySafe(
        _event({'surface': 'My Savings'}),
        allowedStrings: {
          'surface': {'overview'},
        },
      ),
      throwsA(isA<TestFailure>()),
    );
  });
}

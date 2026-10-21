// A67 (#802): lib/features/goals is analysed with avoid_dynamic_calls. This pins
// the nested config so the rule is not dropped by accident.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('goals lint config', () {
    final config = File('lib/features/goals/analysis_options.yaml');

    test('the nested config exists', () {
      expect(config.existsSync(), isTrue);
    });

    test('it includes the root options and enables avoid_dynamic_calls', () {
      final text = config.readAsStringSync();
      expect(text, contains('include: ../../../analysis_options.yaml'));
      expect(text, contains('avoid_dynamic_calls: true'));
    });

    test('the include path reaches the real root options file', () {
      expect(File('analysis_options.yaml').existsSync(), isTrue);
    });
  });
}

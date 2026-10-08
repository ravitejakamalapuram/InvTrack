// A101: the Analytics and Crashlytics user IDs are kept in step with the
// signed-in account by one listener (lib/app/user_identity_sync.dart).
// A screen that sets or clears them as well would drift from it again.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no code under lib/features sets or clears the user IDs', () {
    final calls = RegExp(
      r'\b(setUserId|setUserIdentifier|clearUserIdentifier)\(',
    );
    final offenders = <String>[];
    final files = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (calls.hasMatch(lines[i])) offenders.add('${file.path}:${i + 1}');
      }
    }

    expect(offenders, isEmpty);
  });
}

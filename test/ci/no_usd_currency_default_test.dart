// A82: a missing currency must never silently become US dollars (money
// rule 1). Entity constructors take `required String currency`, so a
// caller that forgets the currency fails to compile instead of saving USD.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test("no parameter under lib/ defaults currency to 'USD'", () {
    final usdDefault = RegExp(
      r'''\b\w*[cC]urrency\w*\s*=\s*['"]USD['"]\s*[,)}]''',
    );
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (usdDefault.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(offenders, isEmpty);
  });
}

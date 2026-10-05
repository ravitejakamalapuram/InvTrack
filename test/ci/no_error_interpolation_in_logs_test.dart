// A125: a caught error's text can hold a document path, an email or a name,
// so no LoggerService call may interpolate it. Pass it as `error:` instead,
// which reaches Crashlytics only as its type and code.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _logCall = RegExp(r'LoggerService\.(debug|info|warn|error)\(');
final _errorInterpolation = RegExp(
  r'\$\{?(e|err|error|ex|exception|stack|st|stackTrace)\b',
);

/// The text between the parentheses of the call that starts at [open].
String _arguments(String source, int open) {
  var depth = 1;
  var i = open;
  while (i < source.length && depth > 0) {
    final char = source[i];
    if (char == '(') depth++;
    if (char == ')') depth--;
    i++;
  }
  return source.substring(open, i);
}

void main() {
  test('no LoggerService call in lib/ interpolates a caught error', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final call in _logCall.allMatches(source)) {
        if (_errorInterpolation.hasMatch(_arguments(source, call.end))) {
          final line = '\n'.allMatches(source.substring(0, call.start)).length;
          offenders.add('${file.path}:${line + 1}');
        }
      }
    }

    expect(offenders, isEmpty);
  });
}

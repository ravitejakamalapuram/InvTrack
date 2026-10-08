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

/// Index just past the string literal whose opening quote is at [i].
int _skipString(String source, int i, {required bool raw}) {
  final quote = source[i];
  final triple = source.startsWith(quote * 3, i);
  final close = triple ? quote * 3 : quote;
  var j = i + close.length;
  while (j < source.length) {
    if (!raw && source[j] == '\\') {
      j += 2;
    } else if (!raw && source.startsWith(r'${', j)) {
      var depth = 1;
      j += 2;
      while (j < source.length && depth > 0) {
        if (source[j] == '{') depth++;
        if (source[j] == '}') depth--;
        j++;
      }
    } else if (source.startsWith(close, j)) {
      return j + close.length;
    } else {
      j++;
    }
  }
  return j;
}

/// The message (first argument) of the call whose `(` ends at [open], and
/// whether it is written only as string literals.
({String text, bool literal}) _message(String source, int open) {
  final buffer = StringBuffer();
  var literal = true;
  var depth = 0;
  var i = open;
  while (i < source.length) {
    final char = source[i];
    if (char == "'" || char == '"') {
      final raw = i > 0 && source[i - 1] == 'r';
      final end = _skipString(source, i, raw: raw);
      buffer.write(source.substring(i, end));
      i = end;
      continue;
    }
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      i = end < 0 ? source.length : end;
      continue;
    }
    if (depth == 0 && (char == ',' || char == ')')) break;
    if ('([{'.contains(char)) depth++;
    if (')]}'.contains(char)) depth--;
    final isRawPrefix =
        char == 'r' &&
        i + 1 < source.length &&
        (source[i + 1] == "'" || source[i + 1] == '"');
    if (char.trim().isNotEmpty && !isRawPrefix) literal = false;
    buffer.write(char);
    i++;
  }
  return (text: buffer.toString(), literal: literal);
}

final _crashReportCall = RegExp(r'LoggerService\.(warn|error)\(');
final _interpolation = RegExp(r'(?<!\\)\$[{A-Za-z_]');

/// Reviewed messages that may carry a dynamic part, keyed by file. Each
/// value is the exact message source. Only fixed tokens are allowed here
/// (currency codes, enum names); never a name, amount, file name or path.
const _reviewedDynamicMessages = <String, List<String>>{
  'lib/features/settings/presentation/providers/currency_switch_provider.dart':
      [r"'Currency switch failed - rolled back to $currentCurrency'"],
  'lib/core/providers/in_app_update_provider.dart': [
    r"'Immediate update result: ${result.name}'",
    r"'Flexible update result: ${result.name}'",
  ],
};

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

  // A125: warn and error messages reach Crashlytics verbatim, so any dynamic
  // part could carry a path, a name or an amount. Put dynamic values in
  // metadata, where only numbers, booleans and plain tokens survive.
  test('warn and error messages in lib/ are fixed text unless reviewed', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      final path = file.path.replaceAll('\\', '/');
      for (final call in _crashReportCall.allMatches(source)) {
        final message = _message(source, call.end);
        final text = message.text.trim();
        final dynamic = !message.literal || _interpolation.hasMatch(text);
        if (!dynamic) continue;
        if (_reviewedDynamicMessages[path]?.contains(text) ?? false) continue;
        final line = '\n'.allMatches(source.substring(0, call.start)).length;
        offenders.add('$path:${line + 1}: $text');
      }
    }

    expect(offenders, isEmpty);
  });
}

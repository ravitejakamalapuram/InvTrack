/// A41 (#784): every `log*` method of `AnalyticsService` has a caller in `lib/`.
///
/// An event method nobody calls reports nothing, yet it reads like a funnel
/// step and its mocks have to be kept in step. The Reports feature went in
/// #1230 and left `logReportViewed`, `logReportExported` and
/// `logHistoricalReportAccessed` with no caller. These plain file checks fail
/// when the next feature removal leaves one behind: delete the method (and its
/// event constant and mock copies) or give it a caller.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _service = 'lib/core/analytics/analytics_service.dart';

/// [source] without block and line comments, so a doc example such as
/// `await analyticsService.logReportViewed(` does not count as a caller.
String stripComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// Names of the public `Future<...> log*(` methods declared in [serviceSource].
List<String> loggerMethods(String serviceSource) => RegExp(
  r'^\s*Future<[^>]+>\s+(log[A-Za-z0-9]+)\s*\(',
  multiLine: true,
).allMatches(stripComments(serviceSource)).map((m) => m.group(1)!).toList();

/// The methods in [methods] that no source in [callerSources] mentions.
List<String> uncalled(List<String> methods, Iterable<String> callerSources) {
  final code = callerSources.map(stripComments).toList();
  return [
    for (final name in methods)
      if (!code.any((s) => RegExp('\\b$name\\b').hasMatch(s))) name,
  ];
}

void main() {
  test('loggerMethods reads declarations and skips comments', () {
    const source = '''
class AnalyticsService {
  /// await analyticsService.logDocOnly(x);
  Future<void> logEvent({required String name}) async {}
  Future<bool> setUserProperty() async => true;
  Future<void> logGoalCreated() async {}
}
''';
    expect(loggerMethods(source), ['logEvent', 'logGoalCreated']);
  });

  test('uncalled ignores a mention in a comment', () {
    expect(
      uncalled(
        ['logA', 'logB', 'logC'],
        ['a.logA(); // logB later', '/* logC( */ final x = 1;'],
      ),
      ['logB', 'logC'],
    );
  });

  test('every AnalyticsService log method has a caller in lib/', () {
    final methods = loggerMethods(File(_service).readAsStringSync());
    expect(
      methods,
      isNotEmpty,
      reason: 'the pattern no longer matches $_service',
    );

    final callers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.path != _service)
        .map((f) => f.readAsStringSync());

    expect(
      uncalled(methods, callers),
      isEmpty,
      reason:
          'These AnalyticsService methods are never called. Delete each '
          'one with its AnalyticsEvents constant and its copies in '
          'test/mocks and integration_test/mocks, or call it.',
    );
  });
}

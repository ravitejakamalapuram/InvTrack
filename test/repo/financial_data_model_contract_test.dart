/// #944: docs/FINANCIAL_DATA_MODEL.md is the ownership contract for investment
/// data. These plain file checks stop it drifting from the code: a symbol the
/// doc names must exist, and a change the doc says has not happened yet must
/// fail here so the doc is updated in the same PR.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

/// Body of `class [name]` up to the next top-level `class`/`enum`.
String _classBody(String source, String name) {
  final start = RegExp('class $name\\b').firstMatch(source);
  expect(start, isNotNull, reason: '$name is not declared');
  final rest = source.substring(start!.end);
  final next = RegExp(
    r'^(?:abstract |final |sealed )?(?:class|enum) ',
    multiLine: true,
  ).firstMatch(rest);
  return next == null ? rest : rest.substring(0, next.start);
}

void main() {
  final doc = _read('docs/FINANCIAL_DATA_MODEL.md');
  final lib = _dartFiles('lib').map((f) => f.readAsStringSync()).join('\n');

  test('every current entity and calculator the doc names is declared', () {
    for (final name in [
      'InvestmentEntity',
      'CashFlowEntity',
      'ExpectedCashFlowEntity',
      'CurrentValueCalculator',
      'InvestmentValuation',
      'InvestmentValuationSnapshot',
      'ValuationSnapshotSelector',
    ]) {
      expect(doc, contains('`$name`'), reason: 'doc no longer names $name');
      expect(
        RegExp('(class|enum) $name\\b').hasMatch(lib),
        isTrue,
        reason: '$name is in the doc but not in lib/',
      );
    }
    expect(
      File(
        'lib/features/income_projection/data/services/'
        'income_guardian_sync_service.dart',
      ).existsSync(),
      isTrue,
    );
  });

  test('CashFlowEntity still has no breakdown fields (doc says so)', () {
    final body = _classBody(
      _read('lib/features/investment/domain/entities/transaction_entity.dart'),
      'CashFlowEntity',
    );
    final fields = RegExp(
      r'^\s*final\s+[\w<>?]+\s+(\w+);',
      multiLine: true,
    ).allMatches(body).map((m) => m.group(1)!);
    expect(
      fields.where(
        (f) => RegExp(r'principal|earning|tax|gross|net').hasMatch(f),
      ),
      isEmpty,
      reason:
          'A breakdown field was added to CashFlowEntity: update '
          '"Actual transactions" in docs/FINANCIAL_DATA_MODEL.md (#940/#947) '
          'and then this test.',
    );
  });

  test('the data layer only guards against synthetic flow ids', () {
    for (final f in _dartFiles('lib')) {
      if (!f.path.contains('/data/')) continue;
      expect(
        f.readAsStringSync(),
        isNot(
          matches(RegExp(r'TerminalValues\.(?!isEphemeralId)|current-value:')),
        ),
        reason:
            '${f.path} builds synthetic calculation flows; they must '
            'never be persisted (rejecting them via isEphemeralId is fine)',
      );
    }
  });

  test('the valuations collection is covered by account deletion', () {
    expect(
      _read(
        'lib/features/settings/data/services/account_data_deletion_service.dart',
      ),
      contains("'valuations'"),
    );
    expect(doc, contains('users/{uid}/valuations'));
  });
}

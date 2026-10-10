// #956 for custom_types.json (#936): a Replace import reads the whole backup
// before it deletes anything, and a damaged file stops it with one fixed
// error and no change. That includes the account's reusable custom types: the
// settings screen never shows warnings (#959), so skipping the file would
// wipe the account's investments (and, on the old path, its labels) without
// a word. Merge deletes nothing, so it skips the file with one fixed warning
// and imports the rest. Neither message holds label text (rule 7).
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../../investment/data/repositories/fake_custom_investment_type_repository.dart';
import '../../../investment/data/repositories/mock_investment_repository.dart';

class _PerformanceService extends Mock implements PerformanceService {
  @override
  Future<T> trackOperation<T>(
    String traceName,
    Future<T> Function() operation, {
    Map<String, int>? metrics,
    Map<String, String>? attributes,
  }) => operation();
}

class _DocumentRepository extends Mock implements DocumentRepository {}

class _DocumentStorageService extends Mock implements DocumentStorageService {}

// Logs every write the import can make to the investments and goals, so a
// stopped import can show that nothing was written at all, not even data that
// was deleted and put back. The type repository counts its own writes.
class _SpyInvestments extends FakeInvestmentRepository {
  _SpyInvestments(this.writes);
  final List<String> writes;

  @override
  Future<void> deleteInvestment(String id) {
    writes.add('deleteInvestment');
    return super.deleteInvestment(id);
  }

  @override
  Future<void> deleteArchivedInvestment(String id) {
    writes.add('deleteArchivedInvestment');
    return super.deleteArchivedInvestment(id);
  }

  @override
  Future<void> archiveInvestment(String id) {
    writes.add('archiveInvestment');
    return super.archiveInvestment(id);
  }

  @override
  Future<({int investments, int cashFlows})> bulkImport({
    required List<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
  }) {
    writes.add('bulkImport');
    return super.bulkImport(investments: investments, cashFlows: cashFlows);
  }
}

class _SpyGoals extends FakeGoalRepository {
  _SpyGoals(this.writes);
  final List<String> writes;

  @override
  Future<void> createGoal(GoalEntity goal) {
    writes.add('createGoal');
    return super.createGoal(goal);
  }

  @override
  Future<void> archiveGoal(String id) {
    writes.add('archiveGoal');
    return super.archiveGoal(id);
  }

  @override
  Future<void> deleteGoal(String id) {
    writes.add('deleteGoal');
    return super.deleteGoal(id);
  }

  @override
  Future<void> deleteArchivedGoal(String id) {
    writes.add('deleteArchivedGoal');
    return super.deleteArchivedGoal(id);
  }
}

const _cashflowsHeader =
    'Date,Investment Name,Type,Amount,Currency,Notes,Investment Type,'
    'Investment Status\n';

// Text that must never appear in an error or warning (rule 7).
const _secretLabel = 'Secret Hobby';
const _importedName = 'SGB 2031';
const _goalName = 'Retirement Fund';

const _customTypesWarning =
    'Custom types not imported: custom_types.json is invalid';
const _customTypesError =
    'Backup not imported: custom_types.json is damaged. Your existing data '
    'was not changed.';

final _validCustomTypes = jsonEncode({
  'version': 1,
  'types': [
    {'label': 'Stamps', 'removed': false},
  ],
  'investments': [
    {
      'name': _importedName,
      'archived': false,
      'label': 'Stamps',
      'linked': true,
    },
  ],
});

final _validFiles = <String, String>{
  'metadata.json': jsonEncode({'version': '1.0', 'documents': []}),
  'cashflows.csv':
      '$_cashflowsHeader'
      '2025-10-01,$_importedName,INVEST,100000,INR,,other,open\n',
  'goals.csv':
      'Name,Type,Target Amount\n'
      '$_goalName,targetAmount,1000000\n',
  'custom_types.json': _validCustomTypes,
};

/// A valid file followed by a byte that is not UTF-8.
List<int> _invalidUtf8(String valid) => [...utf8.encode(valid), 0xFF, 0xFE];

// The ways custom_types.json can be damaged while every other file in the
// backup is fine. The exporter always writes both lists, so a file without
// them, or with one of the wrong kind, is not a custom_types.json. A file with
// both lists and no rows is not damaged: see the readable group below.
final _damaged = <String, List<int>>{
  'not UTF-8': _invalidUtf8(_validCustomTypes),
  'cut off': utf8.encode('{"version":1,"types":[{"label":"$_secretLabel"'),
  'not an object': utf8.encode('["$_secretLabel"]'),
  'empty': const <int>[],
  'without its lists': utf8.encode('{"version":1}'),
  'types is not a list': utf8.encode(
    '{"types":"$_secretLabel","investments":[]}',
  ),
  'investments is not a list': utf8.encode(
    '{"types":[],"investments":{"$_secretLabel":1}}',
  ),
  'only unreadable rows': utf8.encode(
    jsonEncode({
      'types': [
        _secretLabel,
        {'label': 42},
        {'removed': true},
      ],
      'investments': [
        7,
        {'name': _importedName},
      ],
    }),
  ),
};

Uint8List _zip(Map<String, List<int>> files) {
  final zip = Archive();
  for (final entry in files.entries) {
    zip.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(zip)!);
}

/// The valid backup with [overrides] swapped in (bytes), or removed (null).
Uint8List _backup([Map<String, List<int>?> overrides = const {}]) {
  final files = <String, List<int>>{
    for (final e in _validFiles.entries) e.key: utf8.encode(e.value),
  };
  for (final e in overrides.entries) {
    final bytes = e.value;
    if (bytes == null) {
      files.remove(e.key);
    } else {
      files[e.key] = bytes;
    }
  }
  return _zip(files);
}

CustomInvestmentType _type(String id, String label, {bool removed = false}) =>
    CustomInvestmentType(
      id: id,
      label: label,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      removedAt: removed ? DateTime.utc(2026, 1, 1) : null,
    );

InvestmentEntity _investment(String id, String name, {bool labelled = false}) =>
    InvestmentEntity(
      id: id,
      name: name,
      type: InvestmentType.other,
      status: InvestmentStatus.open,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      currency: 'INR',
      customTypeId: labelled ? 'wine-id' : null,
      customTypeLabel: labelled ? 'Wine' : null,
    );

CashFlowEntity _cashFlow(String id, String investmentId) => CashFlowEntity(
  id: id,
  investmentId: investmentId,
  type: CashFlowType.invest,
  amount: 777,
  currency: 'INR',
  date: DateTime(2024, 1, 2),
  createdAt: DateTime(2024, 1, 2),
);

GoalEntity _goal(String id, String name, {bool archived = false}) => GoalEntity(
  id: id,
  name: name,
  type: GoalType.targetAmount,
  targetAmount: 5000,
  trackingMode: GoalTrackingMode.all,
  icon: 'x',
  colorValue: 1,
  isArchived: archived,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
  currency: 'INR',
);

void main() {
  late List<String> writes;
  late _DocumentRepository documents;
  late _DocumentStorageService documentStorage;
  late FakeInvestmentRepository investments;
  late FakeGoalRepository goals;
  late FakeCustomInvestmentTypeRepository types;
  late DataImportService service;

  // What the account holds before the import, including its reusable types:
  // one active and one removed, so a wipe of either would show.
  final existingInvestments = [
    _investment('old-active', 'Existing Album', labelled: true),
  ];
  final existingCashFlows = [_cashFlow('old-cf', 'old-active')];
  final existingArchivedInvestments = [
    _investment('old-archived', 'Existing Archived', labelled: true),
  ];
  final existingArchivedCashFlows = [_cashFlow('old-acf', 'old-archived')];
  final existingGoals = [_goal('old-goal', 'Existing Goal')];
  final existingArchivedGoals = [
    _goal('old-agoal', 'Existing Archived Goal', archived: true),
  ];
  final existingTypes = [
    _type('wine-id', 'Wine'),
    _type('coins-id', 'Coins', removed: true),
  ];

  setUp(() {
    writes = [];
    documents = _DocumentRepository();
    documentStorage = _DocumentStorageService();
    investments = _SpyInvestments(writes)
      ..seed(
        investments: existingInvestments,
        cashFlows: existingCashFlows,
        archivedInvestments: existingArchivedInvestments,
        archivedCashFlows: existingArchivedCashFlows,
      );
    goals = _SpyGoals(writes)
      ..seed(goals: existingGoals, archivedGoals: existingArchivedGoals);
    types = FakeCustomInvestmentTypeRepository(existingTypes);
    service = DataImportService(
      investmentRepository: investments,
      goalRepository: goals,
      documentRepository: documents,
      documentStorageService: documentStorage,
      customInvestmentTypeRepository: types,
      performanceService: _PerformanceService(),
    );
  });

  Future<ZipImportResult> importZip(
    Uint8List zip, [
    ImportStrategy strategy = ImportStrategy.replace,
  ]) => service.importFromZip(zip, strategy, baseCurrency: 'INR');

  void expectTypesUntouched() {
    expect(types.definitions, existingTypes);
    expect(types.deleteAlls, 0, reason: 'the types are not wiped');
    expect(types.writes, 0, reason: 'no type is written');
  }

  void expectAccountUntouched() {
    expect(investments.investments, existingInvestments);
    expect(investments.cashFlows, existingCashFlows);
    expect(investments.archivedInvestments, existingArchivedInvestments);
    expect(investments.archivedCashFlows, existingArchivedCashFlows);
    expect(goals.goals, existingGoals);
    expect(goals.archivedGoals, existingArchivedGoals);
    expect(writes, isEmpty, reason: 'nothing is written');
    expectTypesUntouched();
    verifyZeroInteractions(documents);
    verifyZeroInteractions(documentStorage);
  }

  void expectNoUserTextIn(Iterable<String> messages) {
    final text = messages.join('\n');
    for (final secret in [
      _secretLabel,
      'Stamps',
      'Wine',
      _importedName,
      _goalName,
      '100000',
    ]) {
      expect(text, isNot(contains(secret)));
    }
  }

  group('Replace: a damaged custom_types.json stops the import first', () {
    for (final mode in _damaged.entries) {
      test('Replace: custom_types.json is ${mode.key}', () async {
        final result = await importZip(
          _backup({'custom_types.json': mode.value}),
        );

        expect(result.errors, [_customTypesError]);
        expect(result.warnings, isEmpty);
        expect(result.totalImported, 0);
        expectNoUserTextIn(result.errors);
        expectAccountUntouched();
      });
    }

    test('Replace: several damaged files still stop it, naming one', () async {
      final result = await importZip(
        _backup({
          'custom_types.json': _damaged['not UTF-8'],
          'goals.csv': utf8.encode('Title,Kind,Goal\n$_goalName,x,1\n'),
        }),
      );

      expect(result.errors, hasLength(1));
      expect(result.errors.single, startsWith('Backup not imported: '));
      expect(
        result.errors.single,
        endsWith(' is damaged. Your existing data was not changed.'),
      );
      expect(result.warnings, isEmpty);
      expect(result.totalImported, 0);
      expectNoUserTextIn(result.errors);
      expectAccountUntouched();
    });
  });

  group('Merge: a damaged custom_types.json is skipped with a warning', () {
    for (final mode in _damaged.entries) {
      test('Merge: custom_types.json is ${mode.key}', () async {
        final result = await importZip(
          _backup({'custom_types.json': mode.value}),
          ImportStrategy.merge,
        );

        // One fixed warning with no label text, and the rest still merges.
        expect(result.errors, isEmpty);
        expect(result.warnings, [_customTypesWarning]);
        expectNoUserTextIn(result.warnings);
        expect(result.investmentsImported, 1);
        expect(result.cashflowsImported, 1);
        expect(result.goalsImported, 1);
        expect(
          investments.investments.map((i) => i.id),
          contains('old-active'),
        );
        expect(goals.goals.map((g) => g.name), contains('Existing Goal'));
        final added = investments.investments.singleWhere(
          (i) => i.name == _importedName,
        );
        expect(added.customTypeLabel, isNull);
        expect(added.customTypeId, isNull);
        expectTypesUntouched();
      });
    }
  });

  group('Replace: a readable custom_types.json still replaces', () {
    test('Replace: a file with empty lists is not damaged', () async {
      // Nothing to restore, so the account's old types are replaced by none,
      // like a goals.csv with only a header.
      final result = await importZip(
        _backup({
          'custom_types.json': utf8.encode(
            '{"version":1,"types":[],"investments":[]}',
          ),
        }),
      );

      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      expect(types.definitions, isEmpty);
      expect(types.deleteAlls, 1);
      expect(investments.investments.single.name, _importedName);
      expect(investments.investments.single.customTypeLabel, isNull);
    });

    test('Replace: one unreadable row keeps the readable ones', () async {
      final result = await importZip(
        _backup({
          'custom_types.json': utf8.encode(
            jsonEncode({
              'types': [
                7,
                {'label': 'Stamps', 'removed': false},
              ],
              'investments': [
                {'name': 'Nobody'},
                {
                  'name': _importedName,
                  'archived': false,
                  'label': 'Stamps',
                  'linked': true,
                },
              ],
            }),
          ),
        }),
      );

      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      expect(types.definitions.map((d) => d.label), ['Stamps']);
      expect(investments.investments.single.customTypeLabel, 'Stamps');
    });

    test('Replace: a valid backup replaces the types and labels', () async {
      final result = await importZip(_backup());

      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      expect(types.definitions.map((d) => d.label), ['Stamps']);
      expect(types.deleteAlls, 1);
      final imported = investments.investments.single;
      expect(imported.name, _importedName);
      expect(imported.customTypeLabel, 'Stamps');
      expect(imported.customTypeId, types.definitions.single.id);
    });

    test(
      'Replace: a backup without custom_types.json keeps the types',
      () async {
        final result = await importZip(_backup({'custom_types.json': null}));

        expect(result.errors, isEmpty);
        expect(result.warnings, isEmpty);
        expectTypesUntouched();
        expect(investments.investments.single.name, _importedName);
      },
    );
  });
}

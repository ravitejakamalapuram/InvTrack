// #956: a Replace import must read the whole backup before it deletes
// anything. One unreadable file used to throw after the account was wiped.
// And when any file in the backup is damaged, Replace stops with an error
// and changes nothing: the settings screen never shows warnings (#959), so
// skipping the file would delete the matching data without a word.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fire_number/data/repositories/mock_fire_settings_repository.dart';
import '../../../goals/data/repositories/mock_goal_repository.dart';
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

// The repositories below log every write the import can make, so a stopped
// import can show that nothing was written at all, not even data that was
// deleted and put back.
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

class _SpyFireSettings extends FakeFireSettingsRepository {
  _SpyFireSettings(this.writes);
  final List<String> writes;

  @override
  Future<void> saveSettings(FireSettingsEntity settings) {
    writes.add('saveSettings');
    return super.saveSettings(settings);
  }

  @override
  Future<void> deleteSettings() {
    writes.add('deleteSettings');
    return super.deleteSettings();
  }
}

const _cashflowsHeader =
    'Date,Investment Name,Type,Amount,Currency,Notes,Investment Type,'
    'Investment Status\n';

// Names and amounts that must never appear in an error or warning (rule 7).
const _activeName = 'SGB 2031';
const _archivedName = 'Old Bond';
const _goalName = 'Retirement Fund';
const _archivedGoalName = 'Archived Goal';
const _documentName = 'Salary Slip.pdf';

final _validFiles = <String, String>{
  'metadata.json': jsonEncode({'version': '1.0', 'documents': []}),
  'cashflows.csv':
      '$_cashflowsHeader'
      '2025-10-01,$_activeName,INVEST,100000,INR,,gold,open\n',
  'cashflows_archived.csv':
      '$_cashflowsHeader'
      '2025-09-01,$_archivedName,INVEST,50000,INR,,bonds,open\n',
  'valuations.csv':
      'Investment Name,Archived,Date,Value,Currency\n'
      '$_activeName,false,2025-10-05,125000,INR\n',
  'goals.csv':
      'Name,Type,Target Amount\n'
      '$_goalName,targetAmount,1000000\n',
  'goals_archived.csv':
      'Name,Type,Target Amount\n'
      '$_archivedGoalName,targetAmount,25000\n',
};

/// A valid file followed by a byte that is not UTF-8.
List<int> _invalidUtf8(String valid) => [...utf8.encode(valid), 0xFF, 0xFE];

const _valuationsHeader = 'Investment Name,Archived,Date,Value,Currency\n';

// Each optional file with the ways it can be damaged. A header-only file is
// not damaged: an account without goals exports exactly that.
final _damaged = <String, Map<String, List<int>>>{
  'valuations.csv': {
    'not UTF-8': _invalidUtf8(_validFiles['valuations.csv']!),
    'header-less': utf8.encode('$_activeName,false,2025-10-05,125000,INR\n'),
    'missing columns': utf8.encode('Name,Value\n$_activeName,125000\n'),
    'garbage': utf8.encode('this,is,not\na,backup,file\n'),
    'only unreadable rows': utf8.encode(
      '$_valuationsHeader$_activeName,false,2025-10-05,not-a-number,INR\n',
    ),
    'only a future-dated row': utf8.encode(
      '$_valuationsHeader$_activeName,false,2999-01-01,125000,INR\n',
    ),
    'empty': const <int>[],
  },
  'cashflows_archived.csv': {
    'not UTF-8': _invalidUtf8(_validFiles['cashflows_archived.csv']!),
    'header-less': utf8.encode(
      '2025-09-01,$_archivedName,INVEST,50000,INR,,bonds,open\n',
    ),
    'missing columns': utf8.encode(
      'When,What,Kind,Sum\n2025-09-01,$_archivedName,INVEST,50000\n',
    ),
    'only unreadable rows': utf8.encode(
      '$_cashflowsHeader'
      '2025-09-01,$_archivedName,INVEST,not-a-number,INR,,bonds,open\n',
    ),
    'empty': const <int>[],
  },
  'goals.csv': {
    'not UTF-8': _invalidUtf8(_validFiles['goals.csv']!),
    'header-less': utf8.encode('$_goalName,targetAmount,1000000\n'),
    'missing columns': utf8.encode(
      'Title,Kind,Goal\n$_goalName,targetAmount,1000000\n',
    ),
    'only unreadable rows': utf8.encode(
      'Name,Type,Target Amount\n$_goalName,targetAmount,a-lot\n',
    ),
    'empty': const <int>[],
  },
  'goals_archived.csv': {
    'not UTF-8': _invalidUtf8(_validFiles['goals_archived.csv']!),
    'header-less': utf8.encode('$_archivedGoalName,targetAmount,25000\n'),
    'missing columns': utf8.encode(
      'Title,Kind,Goal\n$_archivedGoalName,targetAmount,25000\n',
    ),
    'only unreadable rows': utf8.encode(
      'Name,Type,Target Amount\n$_archivedGoalName,targetAmount,little\n',
    ),
    'empty': const <int>[],
  },
  'fire_settings.json': {
    'not UTF-8': _invalidUtf8(
      '{"monthlyExpenses":30000,"currentAge":25,"targetFireAge":45}',
    ),
    'cut off': utf8.encode('{"monthlyExpenses":30000,"currentAge":2'),
    'not an object': utf8.encode('[30000,25,45]'),
    'missing its required fields': utf8.encode('{}'),
    'empty': const <int>[],
  },
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

InvestmentEntity _investment(String id, String name, {double? value}) =>
    InvestmentEntity(
      id: id,
      name: name,
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.open,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      currency: 'INR',
      currentValue: value,
      currentValueDate: value == null ? null : DateTime(2024, 6, 1),
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
  late FakeFireSettingsRepository fireSettings;
  late DataImportService service;

  // What the account holds before the import.
  // Both kinds hold a current value: a stopped import must keep them.
  final existingInvestments = [
    _investment('old-active', 'Existing FD', value: 90000),
  ];
  final existingCashFlows = [_cashFlow('old-cf', 'old-active')];
  final existingArchivedInvestments = [
    _investment('old-archived', 'Existing Archived', value: 40000),
  ];
  final existingArchivedCashFlows = [_cashFlow('old-acf', 'old-archived')];
  final existingGoals = [_goal('old-goal', 'Existing Goal')];
  final existingArchivedGoals = [
    _goal('old-agoal', 'Existing Archived Goal', archived: true),
  ];
  final existingFire = FireSettingsEntity(
    id: 'existing',
    monthlyExpenses: 200000,
    birthYear: DateTime.now().year - 40,
    targetFireAge: 55,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );

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
    fireSettings = _SpyFireSettings(writes)..seed(existingFire);
    service = DataImportService(
      investmentRepository: investments,
      goalRepository: goals,
      documentRepository: documents,
      documentStorageService: documentStorage,
      fireSettingsRepository: fireSettings,
      performanceService: _PerformanceService(),
    );
  });

  tearDown(() => fireSettings.dispose());

  Future<ZipImportResult> importZip(
    Uint8List zip, [
    ImportStrategy strategy = ImportStrategy.replace,
  ]) => service.importFromZip(zip, strategy, baseCurrency: 'INR');

  void expectAccountUntouched() {
    expect(investments.investments, existingInvestments);
    expect(investments.cashFlows, existingCashFlows);
    expect(investments.archivedInvestments, existingArchivedInvestments);
    expect(investments.archivedCashFlows, existingArchivedCashFlows);
    expect(goals.goals, existingGoals);
    expect(goals.archivedGoals, existingArchivedGoals);
    expect(fireSettings.settings, same(existingFire));
    expect(writes, isEmpty, reason: 'nothing is written');
    verifyZeroInteractions(documents);
    verifyZeroInteractions(documentStorage);
  }

  void expectNoUserTextIn(Iterable<String> messages) {
    final text = messages.join('\n');
    for (final secret in [
      _activeName,
      _archivedName,
      _goalName,
      _archivedGoalName,
      _documentName,
      '100000',
      '125000',
      '50000',
      '1000000',
    ]) {
      expect(text, isNot(contains(secret)));
    }
  }

  /// Replace stopped because [file] is damaged: one fixed error, no row
  /// contents or names, and the account exactly as it was.
  void expectStoppedAsDamaged(ZipImportResult result, String file) {
    final error =
        'Backup not imported: $file is damaged. Your existing data was not '
        'changed.';
    expect(result.errors, [error]);
    expect(result.warnings, isEmpty);
    expect(result.totalImported, 0);
    expect(result.fireSettingsImported, isFalse);
    expectNoUserTextIn(result.errors);
    expectAccountUntouched();
  }

  group('a required file that cannot be read stops the import first', () {
    const notRead =
        'Backup not imported: cashflows.csv could not be read. Your existing '
        'data was not changed.';
    const noRows =
        'Backup not imported: cashflows.csv has no readable rows. Your '
        'existing data was not changed.';
    const missing =
        'Backup not imported: cashflows.csv is missing. Your existing data '
        'was not changed.';

    test('Replace: cashflows.csv is not UTF-8', () async {
      final result = await importZip(
        _backup({'cashflows.csv': _invalidUtf8(_validFiles['cashflows.csv']!)}),
      );

      expect(result.errors, [notRead]);
      expect(result.totalImported, 0);
      expectAccountUntouched();
    });

    test('Merge: cashflows.csv is not UTF-8 (an error, not a throw)', () async {
      final result = await importZip(
        _backup({'cashflows.csv': _invalidUtf8(_validFiles['cashflows.csv']!)}),
        ImportStrategy.merge,
      );

      expect(result.errors, [notRead]);
      expect(result.totalImported, 0);
      expectAccountUntouched();
    });

    test('Replace: cashflows.csv has no readable rows', () async {
      final result = await importZip(
        _backup({'cashflows.csv': utf8.encode('this,is,not\na,backup,file\n')}),
      );

      expect(result.errors, [noRows]);
      expect(result.totalImported, 0);
      expectAccountUntouched();
    });

    test('Replace: cashflows.csv is missing from the backup', () async {
      // The exporter always writes cashflows.csv, so a backup without it is
      // damaged or edited. It holds the investments: do not wipe for it.
      final result = await importZip(_backup({'cashflows.csv': null}));

      expect(result.errors, [missing]);
      expect(result.totalImported, 0);
      expectAccountUntouched();
    });

    test(
      'Merge: a backup without cashflows.csv still adds its goals',
      () async {
        // Merge deletes nothing, so the rest of the backup is still worth
        // importing.
        final result = await importZip(
          _backup({'cashflows.csv': null}),
          ImportStrategy.merge,
        );

        expect(result.errors, isEmpty);
        expect(result.goalsImported, 2);
        expect(goals.goals.map((g) => g.name), contains('Existing Goal'));
        expect(goals.goals.map((g) => g.name), contains(_goalName));
        expect(investments.investments, existingInvestments);
      },
    );

    test('Replace: metadata.json lists documents in the wrong shape', () async {
      final result = await importZip(
        _backup({
          'metadata.json': utf8.encode(jsonEncode({'documents': 'oops'})),
        }),
      );

      expect(result.errors, ['Failed to parse metadata.json']);
      expect(result.totalImported, 0);
      expectAccountUntouched();
    });

    test(
      'Replace: a cut-off metadata.json is not quoted in the error',
      () async {
        // jsonDecode's FormatException repeats the text it could not parse
        // (rule 7), so the error must not carry it.
        final result = await importZip(
          _backup({
            'metadata.json': utf8.encode(
              '{"documents":[{"investmentName":"$_activeName",'
              '"fileName":"$_documentName"',
            ),
          }),
        );

        expect(result.errors, ['Failed to parse metadata.json']);
        expectNoUserTextIn(result.errors);
        expect(result.totalImported, 0);
        expectAccountUntouched();
      },
    );

    test(
      'Replace: bytes that are not a ZIP leave the error content-free',
      () async {
        final result = await importZip(
          Uint8List.fromList(utf8.encode('$_activeName is not a zip file')),
        );

        expect(result.errors, ['Invalid ZIP file']);
        expectNoUserTextIn(result.errors);
        expect(result.totalImported, 0);
        expectAccountUntouched();
      },
    );
  });

  group('Merge: a damaged optional file is skipped with a warning', () {
    // Merge deletes nothing, so the rest of the backup is still worth
    // importing. The warning names the file kind only, never an investment,
    // goal or amount (rule 7).
    const goalsWarning = 'Goals not imported: goals.csv is invalid';

    test(
      'Merge: goals.csv is not UTF-8, the cash flows still import',
      () async {
        final result = await importZip(
          _backup({'goals.csv': _invalidUtf8(_validFiles['goals.csv']!)}),
          ImportStrategy.merge,
        );

        expect(result.errors, isEmpty);
        expect(result.warnings, ['Goals not imported: goals.csv is invalid']);
        expect(result.cashflowsImported, 2);
        expect(
          investments.investments.map((i) => i.id),
          contains('old-active'),
        );
        expect(goals.goals, existingGoals);
      },
    );

    test('Merge: goals.csv is header-less, the rest still merges', () async {
      final result = await importZip(
        _backup({
          'goals.csv': utf8.encode('$_goalName,targetAmount,1000000\n'),
        }),
        ImportStrategy.merge,
      );

      expect(result.errors, isEmpty);
      expect(result.warnings, [goalsWarning]);
      expect(result.cashflowsImported, 2);
      expect(investments.investments.map((i) => i.id), contains('old-active'));
      expect(goals.goals, existingGoals);
    });
  });

  group('Replace: a damaged optional file stops the import first', () {
    // Each optional file below is damaged in turn while every other file in
    // the backup is fine. The settings screen never shows warnings (#959), so
    // skipping the file would silently delete the account's matching data
    // (all its goals, say). Replace stops before it deletes anything, and the
    // error names the file only, never what is in it (rule 7).
    for (final file in _damaged.entries) {
      for (final mode in file.value.entries) {
        test('Replace: ${file.key} is ${mode.key}', () async {
          final result = await importZip(_backup({file.key: mode.value}));

          expectStoppedAsDamaged(result, file.key);
        });
      }
    }

    test('Replace: several damaged files still stop it', () async {
      final result = await importZip(
        _backup({
          'valuations.csv': utf8.encode('Name,Value\n$_activeName,125000\n'),
          'goals.csv': _invalidUtf8(_validFiles['goals.csv']!),
          'fire_settings.json': utf8.encode('{}'),
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

  group('Replace: a backup that is readable still replaces', () {
    test('Replace: a file with a header and no rows is not damaged', () async {
      // An account with no goals or archived investments exports exactly
      // this, and replacing it empties the matching data without a warning.
      final result = await importZip(
        _backup({
          'cashflows_archived.csv': utf8.encode(_cashflowsHeader),
          'goals.csv': utf8.encode('Name,Type,Target Amount\n'),
          'goals_archived.csv': utf8.encode('Name,Type,Target Amount\n'),
          'valuations.csv': utf8.encode(
            'Investment Name,Archived,Date,Value,Currency\n',
          ),
        }),
      );

      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      expect(investments.archivedInvestments, isEmpty);
      expect(goals.goals, isEmpty);
      expect(goals.archivedGoals, isEmpty);
      expect(investments.investments.single.currentValue, isNull);
    });

    test(
      'Replace: one unreadable row does not hide the readable ones',
      () async {
        final result = await importZip(
          _backup({
            'goals.csv': utf8.encode(
              'Name,Type,Target Amount\n'
              '$_goalName,targetAmount,1000000\n'
              'Broken,targetAmount,a-lot\n',
            ),
          }),
        );

        expect(result.warnings, isEmpty);
        expect(result.errors, hasLength(1));
        expect(goals.goals.map((g) => g.name), [_goalName]);
      },
    );

    test('Replace: one unreadable valuation row keeps the readable ones, '
        'with a row warning', () async {
      final result = await importZip(
        _backup({
          'valuations.csv': utf8.encode(
            'Investment Name,Archived,Date,Value,Currency\n'
            '$_activeName,false,2025-10-05,125000,INR\n'
            '$_archivedName,true,2025-10-05,not-a-number,INR\n',
          ),
        }),
      );

      expect(result.errors, isEmpty);
      expect(result.warnings, hasLength(1));
      expect(investments.investments.single.currentValue, 125000);
      expect(investments.archivedInvestments.single.currentValue, isNull);
    });
  });

  group('a readable backup imports exactly as before', () {
    test('Replace: valid backup', () async {
      final result = await importZip(_backup());

      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      expect(result.investmentsImported, 2);
      expect(result.cashflowsImported, 2);
      expect(result.goalsImported, 2);
      expect(investments.investments.single.name, _activeName);
      expect(investments.investments.single.currentValue, 125000);
      expect(investments.cashFlows.single.amount, 100000);
      expect(investments.archivedInvestments.single.name, _archivedName);
      expect(investments.archivedCashFlows.single.amount, 50000);
      expect(goals.goals.single.name, _goalName);
      expect(goals.archivedGoals.single.name, _archivedGoalName);
    });

    test(
      'Replace: only archived data (empty cashflows.csv) still replaces',
      () async {
        final result = await importZip(
          _backup({'cashflows.csv': utf8.encode(_cashflowsHeader)}),
        );

        expect(result.errors, isEmpty);
        expect(investments.investments, isEmpty);
        expect(investments.archivedInvestments.single.name, _archivedName);
      },
    );

    test('Replace: a backup of an empty account clears the account', () async {
      final result = await importZip(
        _zip({
          'metadata.json': utf8.encode(_validFiles['metadata.json']!),
          'cashflows.csv': utf8.encode(_cashflowsHeader),
        }),
      );

      expect(result.errors, isEmpty);
      expect(investments.investments, isEmpty);
      expect(investments.archivedInvestments, isEmpty);
      expect(goals.goals, isEmpty);
    });

    test(
      'Replace: valid FIRE settings still replace the existing ones',
      () async {
        final result = await importZip(
          _backup({
            'fire_settings.json': utf8.encode(
              '{"monthlyExpenses":30000,"currentAge":25,"targetFireAge":45}',
            ),
          }),
        );

        expect(result.errors, isEmpty);
        expect(result.warnings, isEmpty);
        expect(result.fireSettingsImported, isTrue);
        expect(fireSettings.settings!.monthlyExpenses, 30000);
      },
    );

    test('Merge: valid backup adds to the existing data', () async {
      final result = await importZip(_backup(), ImportStrategy.merge);

      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      expect(investments.investments.map((i) => i.id), contains('old-active'));
      expect(investments.investments.map((i) => i.name), contains(_activeName));
      expect(goals.goals.map((g) => g.name), contains('Existing Goal'));
      expect(goals.goals.map((g) => g.name), contains(_goalName));
    });
  });
}

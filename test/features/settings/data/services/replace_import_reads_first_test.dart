// #956: a Replace import must read the whole backup before it deletes
// anything. One unreadable file used to throw after the account was wiped.
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

const _cashflowsHeader =
    'Date,Investment Name,Type,Amount,Currency,Notes,Investment Type,'
    'Investment Status\n';

// Names and amounts that must never appear in an error or warning (rule 7).
const _activeName = 'SGB 2031';
const _archivedName = 'Old Bond';
const _goalName = 'Retirement Fund';
const _archivedGoalName = 'Archived Goal';

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

InvestmentEntity _investment(String id, String name) => InvestmentEntity(
  id: id,
  name: name,
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
  currency: 'INR',
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
  late FakeInvestmentRepository investments;
  late FakeGoalRepository goals;
  late FakeFireSettingsRepository fireSettings;
  late DataImportService service;

  // What the account holds before the import.
  final existingInvestments = [_investment('old-active', 'Existing FD')];
  final existingCashFlows = [_cashFlow('old-cf', 'old-active')];
  final existingArchivedInvestments = [
    _investment('old-archived', 'Existing Archived'),
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
    investments = FakeInvestmentRepository()
      ..seed(
        investments: existingInvestments,
        cashFlows: existingCashFlows,
        archivedInvestments: existingArchivedInvestments,
        archivedCashFlows: existingArchivedCashFlows,
      );
    goals = FakeGoalRepository()
      ..seed(goals: existingGoals, archivedGoals: existingArchivedGoals);
    fireSettings = FakeFireSettingsRepository()..seed(existingFire);
    service = DataImportService(
      investmentRepository: investments,
      goalRepository: goals,
      documentRepository: _DocumentRepository(),
      documentStorageService: _DocumentStorageService(),
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
  }

  void expectNoUserTextIn(Iterable<String> messages) {
    final text = messages.join('\n');
    for (final secret in [
      _activeName,
      _archivedName,
      _goalName,
      _archivedGoalName,
      '100000',
      '125000',
      '50000',
      '1000000',
    ]) {
      expect(text, isNot(contains(secret)));
    }
  }

  group('a required file that cannot be read stops the import first', () {
    const notRead =
        'Backup not imported: cashflows.csv could not be read. Your existing '
        'data was not changed.';
    const noRows =
        'Backup not imported: cashflows.csv has no readable rows. Your '
        'existing data was not changed.';

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

    test('Replace: metadata.json lists documents in the wrong shape', () async {
      final result = await importZip(
        _backup({
          'metadata.json': utf8.encode(jsonEncode({'documents': 'oops'})),
        }),
      );

      expect(result.errors, hasLength(1));
      expect(result.errors.single, startsWith('Failed to parse metadata.json'));
      expect(result.totalImported, 0);
      expectAccountUntouched();
    });
  });

  group('an optional file that cannot be read is skipped with a warning', () {
    // Replace still replaces everything else; the warning names the file
    // kind only, never an investment, goal or amount (rule 7).
    void expectRestReplaced(ZipImportResult result) {
      expect(result.errors, isEmpty);
      expect(investments.investments.map((i) => i.name), contains(_activeName));
      expect(investments.investments.map((i) => i.id), isNot(['old-active']));
      expect(investments.cashFlows.map((c) => c.amount), [100000]);
    }

    test('valuations.csv is not UTF-8', () async {
      final result = await importZip(
        _backup({
          'valuations.csv': _invalidUtf8(_validFiles['valuations.csv']!),
        }),
      );

      expectRestReplaced(result);
      expect(result.warnings, [
        'Current values not imported: valuations.csv is invalid',
      ]);
      expectNoUserTextIn(result.warnings);
      expect(investments.investments.single.currentValue, isNull);
      expect(result.goalsImported, 2);
    });

    test('cashflows_archived.csv is not UTF-8', () async {
      final result = await importZip(
        _backup({
          'cashflows_archived.csv': _invalidUtf8(
            _validFiles['cashflows_archived.csv']!,
          ),
        }),
      );

      expectRestReplaced(result);
      expect(result.warnings, [
        'Archived cash flows not imported: cashflows_archived.csv is invalid',
      ]);
      expectNoUserTextIn(result.warnings);
      expect(investments.archivedInvestments, isEmpty);
      expect(result.goalsImported, 2);
    });

    test('goals.csv is not UTF-8', () async {
      final result = await importZip(
        _backup({'goals.csv': _invalidUtf8(_validFiles['goals.csv']!)}),
      );

      expectRestReplaced(result);
      expect(result.warnings, ['Goals not imported: goals.csv is invalid']);
      expectNoUserTextIn(result.warnings);
      expect(goals.goals, isEmpty);
      expect(goals.archivedGoals.map((g) => g.name), [_archivedGoalName]);
    });

    test('goals_archived.csv is not UTF-8', () async {
      final result = await importZip(
        _backup({
          'goals_archived.csv': _invalidUtf8(
            _validFiles['goals_archived.csv']!,
          ),
        }),
      );

      expectRestReplaced(result);
      expect(result.warnings, [
        'Archived goals not imported: goals_archived.csv is invalid',
      ]);
      expectNoUserTextIn(result.warnings);
      expect(goals.goals.map((g) => g.name), [_goalName]);
      expect(goals.archivedGoals, isEmpty);
    });

    test('fire_settings.json is not UTF-8', () async {
      final result = await importZip(
        _backup({
          'fire_settings.json': _invalidUtf8(
            '{"monthlyExpenses":30000,"currentAge":25,"targetFireAge":45}',
          ),
        }),
      );

      expectRestReplaced(result);
      expect(result.warnings, [
        'FIRE settings not imported: fire_settings.json is invalid',
      ]);
      expectNoUserTextIn(result.warnings);
      expect(result.fireSettingsImported, isFalse);
      expect(fireSettings.settings, same(existingFire));
    });

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

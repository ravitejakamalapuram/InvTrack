// #936: reusable custom investment types must survive export -> import
// (CLAUDE.md rule 6): the types themselves, the label each Other investment
// carries, and which investments were linked to a type. This is also the
// path the guest merge takes. A ZIP from before custom types imports as
// before, and an account with none exports the same files as before.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/custom_investment_type_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
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

/// A type store that is not reachable.
class _FailingTypes implements CustomInvestmentTypeRepository {
  @override
  Stream<List<CustomInvestmentType>> watchAll() => Stream.error(_failure());

  @override
  Future<List<CustomInvestmentType>> getAll() async => throw _failure();

  @override
  Future<void> put(CustomInvestmentType type) async => throw _failure();

  static StateError _failure() => StateError('unreachable');
}

final _day = DateTime.utc(2026, 1, 1);

CustomInvestmentType _def(String id, String label, {bool removed = false}) =>
    CustomInvestmentType(
      id: id,
      label: label,
      createdAt: _day,
      updatedAt: _day,
      removedAt: removed ? _day : null,
    );

InvestmentEntity _inv(
  String id,
  String name, {
  InvestmentType type = InvestmentType.other,
  String? customTypeId,
  String? customTypeLabel,
}) => InvestmentEntity(
  id: id,
  name: name,
  type: type,
  status: InvestmentStatus.open,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
  currency: 'INR',
  customTypeId: customTypeId,
  customTypeLabel: customTypeLabel,
);

CashFlowEntity _invest(String investmentId) => CashFlowEntity(
  id: 'cf-$investmentId',
  investmentId: investmentId,
  type: CashFlowType.invest,
  amount: 100000,
  currency: 'INR',
  date: DateTime(2025, 10, 1),
  createdAt: DateTime(2025, 10, 1),
);

Uint8List _zip(Map<String, String> files) {
  final zip = Archive();
  void add(String name, String content) {
    final data = utf8.encode(content);
    zip.addFile(ArchiveFile(name, data.length, data));
  }

  add('metadata.json', jsonEncode({'version': '1.0', 'documents': []}));
  files.forEach(add);
  return Uint8List.fromList(ZipEncoder().encode(zip)!);
}

const _cashFlowsHeader =
    'Date,Investment Name,Type,Amount,Currency,Notes,Investment Type,'
    'Investment Status\n';

void main() {
  late FakeInvestmentRepository investments;
  late FakeCustomInvestmentTypeRepository types;
  late DataExportService exportService;
  late DataImportService importService;

  void build({
    FakeInvestmentRepository? investmentRepo,
    FakeCustomInvestmentTypeRepository? typeRepo,
  }) {
    investments = investmentRepo ?? FakeInvestmentRepository();
    types = typeRepo ?? FakeCustomInvestmentTypeRepository();
    final goals = FakeGoalRepository();
    final documents = _DocumentRepository();
    final storage = _DocumentStorageService();
    when(
      () => documents.getDocumentsByInvestment(any()),
    ).thenAnswer((_) async => []);
    exportService = DataExportService(
      investmentRepository: investments,
      goalRepository: goals,
      documentRepository: documents,
      documentStorageService: storage,
      customInvestmentTypeRepository: types,
      performanceService: _PerformanceService(),
    );
    importService = DataImportService(
      investmentRepository: investments,
      goalRepository: goals,
      documentRepository: documents,
      documentStorageService: storage,
      customInvestmentTypeRepository: types,
      performanceService: _PerformanceService(),
    );
  }

  setUp(build);

  Future<ZipImportResult> import(
    Uint8List bytes, {
    ImportStrategy strategy = ImportStrategy.replace,
  }) => importService.importFromZip(bytes, strategy, baseCurrency: 'INR');

  Future<InvestmentEntity> imported(String name) async =>
      (await investments.getAllInvestments()).singleWhere(
        (i) => i.name == name,
      );

  test('types, labels and links round-trip, active and archived', () async {
    investments.seed(
      investments: [
        _inv('a', 'Album', customTypeId: 'c1', customTypeLabel: 'Stamps'),
        _inv('b', 'Cellar', customTypeLabel: 'Wine'),
        _inv('c', 'Misc'),
        _inv('d', 'Bond', type: InvestmentType.bonds),
      ],
      cashFlows: [_invest('a'), _invest('b'), _invest('c'), _invest('d')],
      archivedInvestments: [
        _inv('e', 'Old album', customTypeId: 'c1', customTypeLabel: 'Stamps'),
      ],
      archivedCashFlows: [_invest('e')],
    );
    types = FakeCustomInvestmentTypeRepository([
      _def('c1', 'Stamps'),
      _def('c2', 'Art', removed: true),
      _def('c3', 'Unused'),
    ]);
    build(investmentRepo: investments, typeRepo: types);
    final bytes = (await exportService.exportAsZipBytes()).bytes;

    // A new device: no investments, no types.
    investments.reset();
    types = FakeCustomInvestmentTypeRepository();
    build(investmentRepo: investments, typeRepo: types);
    final result = await import(bytes);

    expect(result.errors, isEmpty);
    expect(result.warnings, isEmpty);
    final byLabel = {for (final d in types.definitions) d.label: d};
    expect(byLabel.keys, {'Stamps', 'Art', 'Unused'});
    expect(byLabel['Stamps']!.isRemoved, isFalse);
    expect(byLabel['Art']!.isRemoved, isTrue);
    expect(byLabel['Unused']!.isRemoved, isFalse);

    final album = await imported('Album');
    expect(album.type, InvestmentType.other);
    expect(album.customTypeLabel, 'Stamps');
    expect(album.customTypeId, byLabel['Stamps']!.id);
    final cellar = await imported('Cellar');
    expect(cellar.customTypeLabel, 'Wine');
    expect(cellar.customTypeId, isNull);
    final misc = await imported('Misc');
    expect(misc.customTypeLabel, isNull);
    expect(misc.typeLabel, 'Other');
    final bond = await imported('Bond');
    expect(bond.customTypeLabel, isNull);
    expect(bond.type, InvestmentType.bonds);

    final archived =
        (await investments.watchArchivedInvestments().first).single;
    expect(archived.customTypeLabel, 'Stamps');
    expect(archived.customTypeId, byLabel['Stamps']!.id);
  });

  test(
    'an account with no custom types exports the same files as before',
    () async {
      investments.seed(
        investments: [_inv('c', 'Misc')],
        cashFlows: [_invest('c')],
      );

      final bytes = (await exportService.exportAsZipBytes()).bytes;

      final names = ZipDecoder().decodeBytes(bytes).files.map((f) => f.name);
      expect(names, isNot(contains('custom_types.csv')));
      expect(names, isNot(contains('investment_custom_types.csv')));
    },
  );

  test('a ZIP from before custom types imports as before', () async {
    types = FakeCustomInvestmentTypeRepository([_def('c1', 'Wine')]);
    build(investmentRepo: investments, typeRepo: types);

    final result = await import(
      _zip({
        'cashflows.csv':
            '${_cashFlowsHeader}2025-10-01,Album,INVEST,100000,INR,,other,open\n',
      }),
    );

    expect(result.errors, isEmpty);
    expect(result.warnings, isEmpty);
    final album = await imported('Album');
    expect(album.customTypeId, isNull);
    expect(album.customTypeLabel, isNull);
    expect(types.definitions.map((d) => d.label), ['Wine']);
    expect(types.writes, 0);
  });

  test('merge reuses a type with the same label in any case', () async {
    types = FakeCustomInvestmentTypeRepository([_def('mine', 'stamps')]);
    build(investmentRepo: investments, typeRepo: types);

    await import(
      _zip({
        'cashflows.csv':
            '${_cashFlowsHeader}2025-10-01,Album,INVEST,100000,INR,,other,open\n',
        'custom_types.csv': 'Label,Removed\nStamps,false\n',
        'investment_custom_types.csv':
            'Investment Name,Archived,Custom Type,Linked\nAlbum,false,Stamps,true\n',
      }),
      strategy: ImportStrategy.merge,
    );

    expect(types.definitions, hasLength(1));
    expect(types.definitions.single.id, 'mine');
    final album = await imported('Album');
    expect(album.customTypeId, 'mine');
    expect(album.customTypeLabel, 'Stamps');
  });

  test('replace keeps the types the account already has', () async {
    types = FakeCustomInvestmentTypeRepository([_def('w', 'Wine')]);
    build(investmentRepo: investments, typeRepo: types);

    await import(
      _zip({
        'cashflows.csv':
            '${_cashFlowsHeader}2025-10-01,Album,INVEST,100000,INR,,other,open\n',
        'custom_types.csv': 'Label,Removed\nStamps,false\n',
        'investment_custom_types.csv':
            'Investment Name,Archived,Custom Type,Linked\nAlbum,false,Stamps,true\n',
      }),
    );

    expect(types.definitions.map((d) => d.label).toSet(), {'Wine', 'Stamps'});
    expect((await imported('Album')).customTypeLabel, 'Stamps');
  });

  test('a removed type in the file does not come back as a suggestion', () async {
    types = FakeCustomInvestmentTypeRepository([_def('w', 'Wine')]);
    build(investmentRepo: investments, typeRepo: types);

    await import(
      _zip({
        'cashflows.csv':
            '${_cashFlowsHeader}2025-10-01,Album,INVEST,100000,INR,,other,open\n',
        'custom_types.csv': 'Label,Removed\nStamps,true\nwine,true\n',
      }),
      strategy: ImportStrategy.merge,
    );

    final byLabel = {for (final d in types.definitions) d.label: d};
    expect(byLabel['Stamps']!.isRemoved, isTrue);
    expect(byLabel['Wine']!.isRemoved, isFalse, reason: 'an active type stays');
    expect(types.definitions, hasLength(2));
  });

  test('a merge never labels an investment that already exists', () async {
    investments.seed(
      investments: [_inv('x', 'Album')],
      cashFlows: [_invest('x')],
    );

    await import(
      _zip({
        'cashflows.csv':
            '${_cashFlowsHeader}2025-10-01,Album,INVEST,100000,INR,,other,open\n',
        'investment_custom_types.csv':
            'Investment Name,Archived,Custom Type,Linked\nAlbum,false,Stamps,false\n',
      }),
      strategy: ImportStrategy.merge,
    );

    final existing = (await investments.getAllInvestments()).single;
    expect(existing.id, 'x');
    expect(existing.customTypeLabel, isNull);
  });

  test(
    'a label on a built-in type, or over 40 characters, is skipped with a warning',
    () async {
      final result = await import(
        _zip({
          'cashflows.csv':
              '$_cashFlowsHeader'
              '2025-10-01,Bond,INVEST,100000,INR,,bonds,open\n'
              '2025-10-01,Album,INVEST,100000,INR,,other,open\n',
          'investment_custom_types.csv':
              'Investment Name,Archived,Custom Type,Linked\n'
              'Bond,false,Stamps,false\n'
              'Album,false,${'x' * 41},false\n',
        }),
      );

      expect(result.errors, isEmpty);
      expect(result.warnings, hasLength(2));
      final bond = await imported('Bond');
      expect(bond.type, InvestmentType.bonds);
      expect(bond.customTypeLabel, isNull);
      final album = await imported('Album');
      expect(album.type, InvestmentType.other);
      expect(album.customTypeLabel, isNull);
    },
  );

  test('types beyond the limit of 50 are skipped with a warning', () async {
    final rows = [for (var i = 0; i < 52; i++) 'Type $i,false'].join('\n');

    final result = await import(
      _zip({'custom_types.csv': 'Label,Removed\n$rows\n'}),
    );

    expect(types.definitions.where((d) => !d.isRemoved), hasLength(50));
    expect(result.warnings, [
      '2 custom types not imported: an account holds at most 50',
    ]);
  });

  test(
    'a label that starts like a formula survives the CSV protection',
    () async {
      investments.seed(
        investments: [
          _inv('a', 'Album', customTypeId: 'c1', customTypeLabel: '=Stamps'),
        ],
        cashFlows: [_invest('a')],
      );
      types = FakeCustomInvestmentTypeRepository([_def('c1', '=Stamps')]);
      build(investmentRepo: investments, typeRepo: types);
      final bytes = (await exportService.exportAsZipBytes()).bytes;
      final csvText = utf8.decode(
        ZipDecoder().decodeBytes(bytes).findFile('custom_types.csv')!.content
            as List<int>,
      );
      expect(csvText, contains("'=Stamps"));

      investments.reset();
      types = FakeCustomInvestmentTypeRepository();
      build(investmentRepo: investments, typeRepo: types);
      await import(bytes);

      expect(types.definitions.single.label, '=Stamps');
      expect((await imported('Album')).customTypeLabel, '=Stamps');
    },
  );

  test('if the types cannot be saved, the investments still import with their '
      'labels, unlinked, and the user is told', () async {
    final broken = DataImportService(
      investmentRepository: investments,
      goalRepository: FakeGoalRepository(),
      documentRepository: _DocumentRepository(),
      documentStorageService: _DocumentStorageService(),
      customInvestmentTypeRepository: _FailingTypes(),
      performanceService: _PerformanceService(),
    );

    final result = await broken.importFromZip(
      _zip({
        'cashflows.csv':
            '${_cashFlowsHeader}2025-10-01,Album,INVEST,100000,INR,,other,open\n',
        'custom_types.csv': 'Label,Removed\nStamps,false\n',
        'investment_custom_types.csv':
            'Investment Name,Archived,Custom Type,Linked\nAlbum,false,Stamps,true\n',
      }),
      ImportStrategy.replace,
      baseCurrency: 'INR',
    );

    expect(result.errors, isEmpty);
    expect(result.investmentsImported, 1);
    expect(result.warnings, [
      'Custom types not imported: they could not be saved',
    ]);
    final album = await imported('Album');
    expect(album.customTypeLabel, 'Stamps');
    expect(album.customTypeId, isNull);
  });

  test('without a type repository the labels still import, unlinked', () async {
    final noTypes = DataImportService(
      investmentRepository: investments,
      goalRepository: FakeGoalRepository(),
      documentRepository: _DocumentRepository(),
      documentStorageService: _DocumentStorageService(),
      performanceService: _PerformanceService(),
    );

    await noTypes.importFromZip(
      _zip({
        'cashflows.csv':
            '${_cashFlowsHeader}2025-10-01,Album,INVEST,100000,INR,,other,open\n',
        'custom_types.csv': 'Label,Removed\nStamps,false\n',
        'investment_custom_types.csv':
            'Investment Name,Archived,Custom Type,Linked\nAlbum,false,Stamps,true\n',
      }),
      ImportStrategy.replace,
      baseCurrency: 'INR',
    );

    final album = await imported('Album');
    expect(album.customTypeLabel, 'Stamps');
    expect(album.customTypeId, isNull);
  });
}

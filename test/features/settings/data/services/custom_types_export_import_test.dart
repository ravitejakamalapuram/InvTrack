// #936: reusable custom investment types must survive export -> import
// (CLAUDE.md rule 6): the types themselves, the label each Other investment
// carries, and which investments were linked to a type, all in one
// custom_types.json. This is also the path the guest merge takes. A ZIP from
// before custom types imports as before, an account with none exports the
// same files as before, and an unreadable file never costs the account its
// investments: it is read before anything is deleted.
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

  @override
  Future<void> deleteAll() async => throw _failure();

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

/// The custom_types.json of a backup.
String _json({
  List<Map<String, Object?>> types = const [],
  List<Map<String, Object?>> investments = const [],
}) => jsonEncode({'version': 1, 'types': types, 'investments': investments});

Map<String, Object?> _type(String label, {bool removed = false}) => {
  'label': label,
  'removed': removed,
};

Map<String, Object?> _link(
  String name,
  String label, {
  bool archived = false,
  bool linked = false,
}) => {'name': name, 'archived': archived, 'label': label, 'linked': linked};

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

  test('the file is one custom_types.json and the metadata lists it', () async {
    investments.seed(
      investments: [_inv('a', 'Album', customTypeLabel: 'Stamps')],
      cashFlows: [_invest('a')],
    );
    types = FakeCustomInvestmentTypeRepository([_def('c1', 'Stamps')]);
    build(investmentRepo: investments, typeRepo: types);

    final zip = ZipDecoder().decodeBytes(
      (await exportService.exportAsZipBytes()).bytes,
    );

    final names = zip.files.map((f) => f.name);
    expect(names, contains('custom_types.json'));
    expect(names, isNot(contains('custom_types.csv')));
    expect(names, isNot(contains('investment_custom_types.csv')));
    final file =
        jsonDecode(
              utf8.decode(
                zip.findFile('custom_types.json')!.content as List<int>,
              ),
            )
            as Map<String, dynamic>;
    expect(file['types'], [
      {'label': 'Stamps', 'removed': false},
    ]);
    expect(file['investments'], [
      {'name': 'Album', 'archived': false, 'label': 'Stamps', 'linked': false},
    ]);
    final metadata =
        jsonDecode(
              utf8.decode(zip.findFile('metadata.json')!.content as List<int>),
            )
            as Map<String, dynamic>;
    expect(
      (metadata['files'] as List).map((f) => (f as Map)['fileName']),
      contains('custom_types.json'),
    );
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
      expect(names, isNot(contains('custom_types.json')));
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
    expect(types.deleteAlls, 0, reason: 'no file: the types are left alone');
  });

  test('merge reuses a type with the same label in any case', () async {
    types = FakeCustomInvestmentTypeRepository([_def('mine', 'stamps')]);
    build(investmentRepo: investments, typeRepo: types);

    await import(
      _zip({
        'cashflows.csv':
            '${_cashFlowsHeader}2025-10-01,Album,INVEST,100000,INR,,other,open\n',
        'custom_types.json': _json(
          types: [_type('Stamps')],
          investments: [_link('Album', 'Stamps', linked: true)],
        ),
      }),
      strategy: ImportStrategy.merge,
    );

    expect(types.definitions, hasLength(1));
    expect(types.definitions.single.id, 'mine');
    expect(types.deleteAlls, 0, reason: 'merge never deletes');
    final album = await imported('Album');
    expect(album.customTypeId, 'mine');
    expect(album.customTypeLabel, 'Stamps');
  });

  test('replace with the file wipes the account\'s old types first', () async {
    types = FakeCustomInvestmentTypeRepository([
      _def('w', 'Wine'),
      _def('o', 'Old', removed: true),
    ]);
    build(investmentRepo: investments, typeRepo: types);

    await import(
      _zip({
        'cashflows.csv':
            '${_cashFlowsHeader}2025-10-01,Album,INVEST,100000,INR,,other,open\n',
        'custom_types.json': _json(
          types: [_type('Stamps')],
          investments: [_link('Album', 'Stamps', linked: true)],
        ),
      }),
    );

    expect(types.deleteAlls, 1);
    expect(types.definitions.map((d) => d.label), ['Stamps']);
    final album = await imported('Album');
    expect(album.customTypeLabel, 'Stamps');
    expect(album.customTypeId, types.definitions.single.id);
  });

  test('replace with a ZIP that has no such file leaves the types', () async {
    types = FakeCustomInvestmentTypeRepository([_def('w', 'Wine')]);
    build(investmentRepo: investments, typeRepo: types);

    await import(
      _zip({
        'cashflows.csv':
            '${_cashFlowsHeader}2025-10-01,Album,INVEST,100000,INR,,other,open\n',
      }),
    );

    expect(types.definitions.map((d) => d.label), ['Wine']);
    expect(types.deleteAlls, 0);
  });

  test('a removed type in the file does not come back as a suggestion', () async {
    types = FakeCustomInvestmentTypeRepository([_def('w', 'Wine')]);
    build(investmentRepo: investments, typeRepo: types);

    await import(
      _zip({
        'cashflows.csv':
            '${_cashFlowsHeader}2025-10-01,Album,INVEST,100000,INR,,other,open\n',
        'custom_types.json': _json(
          types: [_type('Stamps', removed: true), _type('wine', removed: true)],
        ),
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
        'custom_types.json': _json(investments: [_link('Album', 'Stamps')]),
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
          'custom_types.json': _json(
            investments: [_link('Bond', 'Stamps'), _link('Album', 'x' * 41)],
          ),
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
    final result = await import(
      _zip({
        // Replace stops without it (#956): the exporter always writes it.
        'cashflows.csv': _cashFlowsHeader,
        'custom_types.json': _json(
          types: [for (var i = 0; i < 52; i++) _type('Type $i')],
        ),
      }),
    );

    expect(types.definitions.where((d) => !d.isRemoved), hasLength(50));
    expect(result.warnings, [
      '2 custom types not imported: an account holds at most 50',
    ]);
  });

  test(
    'labels that look like a formula, quotes or commas round-trip exactly',
    () async {
      const labels = [
        '=SUM(A1)',
        "'=x",
        '+1 plan',
        '-Gold',
        '@home',
        'Art, "prints"',
      ];
      investments.seed(
        investments: [
          for (var i = 0; i < labels.length; i++)
            _inv(
              'i$i',
              'Item $i',
              customTypeId: 'c$i',
              customTypeLabel: labels[i],
            ),
        ],
        cashFlows: [for (var i = 0; i < labels.length; i++) _invest('i$i')],
      );
      types = FakeCustomInvestmentTypeRepository([
        for (var i = 0; i < labels.length; i++) _def('c$i', labels[i]),
      ]);
      build(investmentRepo: investments, typeRepo: types);
      final bytes = (await exportService.exportAsZipBytes()).bytes;

      investments.reset();
      types = FakeCustomInvestmentTypeRepository();
      build(investmentRepo: investments, typeRepo: types);
      final result = await import(bytes);

      expect(result.warnings, isEmpty);
      expect(types.definitions.map((d) => d.label).toSet(), labels.toSet());
      for (var i = 0; i < labels.length; i++) {
        expect((await imported('Item $i')).customTypeLabel, labels[i]);
      }
    },
  );

  test(
    'an investment whose name starts like a formula keeps its label',
    () async {
      investments.seed(
        investments: [_inv('a', '=Album', customTypeLabel: 'Stamps')],
        cashFlows: [_invest('a')],
      );
      build(investmentRepo: investments, typeRepo: types);
      final bytes = (await exportService.exportAsZipBytes()).bytes;

      investments.reset();
      build(investmentRepo: investments, typeRepo: types);
      final result = await import(bytes);

      expect(result.warnings, isEmpty);
      expect(
        (await investments.getAllInvestments()).single.customTypeLabel,
        'Stamps',
      );
    },
  );

  // The CSV parser trims every cell, so cashflows.csv and valuations.csv
  // name an investment without its spaces. custom_types.json keeps the name
  // as typed, so the link is found only if its key is trimmed the same way.
  group('an investment name with spaces around it', () {
    test('keeps its custom label through a round trip', () async {
      investments.seed(
        investments: [
          _inv('a', 'Album ', customTypeId: 'c1', customTypeLabel: 'Stamps'),
          _inv('b', ' Cellar', customTypeLabel: 'Wine'),
        ],
        cashFlows: [_invest('a'), _invest('b')],
        archivedInvestments: [
          _inv('e', '  Old album  ', customTypeLabel: 'Coins'),
        ],
        archivedCashFlows: [_invest('e')],
      );
      types = FakeCustomInvestmentTypeRepository([_def('c1', 'Stamps')]);
      build(investmentRepo: investments, typeRepo: types);
      final bytes = (await exportService.exportAsZipBytes()).bytes;

      investments.reset();
      types = FakeCustomInvestmentTypeRepository();
      build(investmentRepo: investments, typeRepo: types);
      final result = await import(bytes);

      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      final album = await imported('Album');
      expect(album.customTypeLabel, 'Stamps');
      expect(album.customTypeId, types.definitions.single.id);
      expect((await imported('Cellar')).customTypeLabel, 'Wine');
      final archived =
          (await investments.watchArchivedInvestments().first).single;
      expect(archived.name, 'Old album');
      expect(archived.customTypeLabel, 'Coins');
    });

    test('is linked whatever spaces and case the two files use', () async {
      final result = await import(
        _zip({
          'cashflows.csv':
              '$_cashFlowsHeader'
              '2025-10-01,"  Album ",INVEST,100000,INR,,other,open\n'
              '2025-10-01,Cellar   ,INVEST,100000,INR,,other,open\n',
          'custom_types.json': _json(
            types: [_type('Stamps')],
            investments: [
              _link('Album  ', 'Stamps', linked: true),
              _link('   CELLAR', 'Wine'),
            ],
          ),
        }),
      );

      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      final album = await imported('Album');
      expect(album.customTypeLabel, 'Stamps');
      expect(album.customTypeId, types.definitions.single.id);
      expect((await imported('Cellar')).customTypeLabel, 'Wine');
    });
  });

  group('an unreadable custom_types.json', () {
    // The label is in the file so the warnings can be checked for it.
    const secret = 'Secret Hobby';

    Future<ZipImportResult> importBroken(
      List<int> fileBytes, {
      ImportStrategy strategy = ImportStrategy.replace,
    }) {
      final zip = Archive();
      void add(String name, List<int> data) =>
          zip.addFile(ArchiveFile(name, data.length, data));
      add('metadata.json', utf8.encode(jsonEncode({'documents': []})));
      add(
        'cashflows.csv',
        utf8.encode(
          '${_cashFlowsHeader}2025-10-01,Album,INVEST,100000,INR,,other,open\n',
        ),
      );
      add('custom_types.json', fileBytes);
      return importService.importFromZip(
        Uint8List.fromList(ZipEncoder().encode(zip)!),
        strategy,
        baseCurrency: 'INR',
      );
    }

    void expectCashFlowsImportedAndLabelsDropped(ZipImportResult result) {
      expect(result.errors, isEmpty);
      expect(result.investmentsImported, 1);
      expect(result.cashflowsImported, 1);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single, isNot(contains(secret)));
      expect(result.warnings.single, contains('custom_types.json'));
    }

    test('invalid UTF-8 imports the cash flows, with one warning and no label '
        'text', () async {
      investments.seed(
        investments: [_inv('old', 'Old one')],
        cashFlows: [_invest('old')],
      );
      types = FakeCustomInvestmentTypeRepository([_def('w', 'Wine')]);
      build(investmentRepo: investments, typeRepo: types);

      final result = await importBroken([
        ...utf8.encode('{"types":[{"label":"$secret"'),
        0xFF, 0xFE, 0xC3, 0x28, //
      ]);

      expectCashFlowsImportedAndLabelsDropped(result);
      final names = (await investments.getAllInvestments()).map((i) => i.name);
      expect(names, ['Album'], reason: 'Replace still replaced the data');
      expect(
        types.definitions.map((d) => d.label),
        ['Wine'],
        reason: 'the types are untouched, not wiped',
      );
      expect(types.deleteAlls, 0);
      expect((await imported('Album')).customTypeLabel, isNull);
    });

    test('JSON that does not parse', () async {
      final result = await importBroken(
        utf8.encode('{"types":[{"label":"$secret"'),
      );

      expectCashFlowsImportedAndLabelsDropped(result);
      expect(types.deleteAlls, 0);
    });

    test('JSON of the wrong shape', () async {
      final result = await importBroken(utf8.encode('["$secret"]'));

      expectCashFlowsImportedAndLabelsDropped(result);
      expect(types.deleteAlls, 0);
    });

    test('merge too', () async {
      final result = await importBroken([
        0xFF,
        0xFE,
        0xC3,
        0x28,
      ], strategy: ImportStrategy.merge);

      expectCashFlowsImportedAndLabelsDropped(result);
    });

    test('a row of the wrong shape is skipped, the others import', () async {
      final result = await importBroken(
        utf8.encode(
          jsonEncode({
            'types': [
              'not an object',
              {'label': 42},
              {'removed': true},
              _type('Stamps'),
            ],
            'investments': [
              7,
              {'name': 'Album'},
              _link('Album', 'Stamps', linked: true),
            ],
          }),
        ),
      );

      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      expect(types.definitions.map((d) => d.label), ['Stamps']);
      expect((await imported('Album')).customTypeLabel, 'Stamps');
    });
  });

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
        'custom_types.json': _json(
          types: [_type('Stamps')],
          investments: [_link('Album', 'Stamps', linked: true)],
        ),
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
        'custom_types.json': _json(
          types: [_type('Stamps')],
          investments: [_link('Album', 'Stamps', linked: true)],
        ),
      }),
      ImportStrategy.replace,
      baseCurrency: 'INR',
    );

    final album = await imported('Album');
    expect(album.customTypeLabel, 'Stamps');
    expect(album.customTypeId, isNull);
  });
}

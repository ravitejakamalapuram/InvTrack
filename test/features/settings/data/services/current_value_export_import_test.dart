// A10 (#754): a user's current value must survive export → import (money
// rule 6), for active and archived investments, without being attached to an
// investment that already existed before a merge.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:mocktail/mocktail.dart';

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

InvestmentEntity _inv(
  String id,
  String name, {
  double? value,
  DateTime? date,
  String currency = 'INR',
}) => InvestmentEntity(
  id: id,
  name: name,
  type: InvestmentType.gold,
  status: InvestmentStatus.open,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
  currency: currency,
  currentValue: value,
  currentValueDate: date,
);

CashFlowEntity _invest(String investmentId, {String currency = 'INR'}) =>
    CashFlowEntity(
      id: 'cf-$investmentId',
      investmentId: investmentId,
      type: CashFlowType.invest,
      amount: 100000,
      currency: currency,
      date: DateTime(2025, 10, 1),
      createdAt: DateTime(2025, 10, 1),
    );

void main() {
  late FakeInvestmentRepository repo;
  late DataExportService exportService;
  late DataImportService importService;

  setUp(() {
    repo = FakeInvestmentRepository();
    final goals = FakeGoalRepository();
    final documents = _DocumentRepository();
    final storage = _DocumentStorageService();
    when(
      () => documents.getDocumentsByInvestment(any()),
    ).thenAnswer((_) async => []);
    exportService = DataExportService(
      investmentRepository: repo,
      goalRepository: goals,
      documentRepository: documents,
      documentStorageService: storage,
      performanceService: _PerformanceService(),
    );
    importService = DataImportService(
      investmentRepository: repo,
      goalRepository: goals,
      documentRepository: documents,
      documentStorageService: storage,
      performanceService: _PerformanceService(),
    );
  });

  Future<Uint8List> exportBytes() async =>
      (await exportService.exportAsZipBytes()).bytes;

  test(
    'current values of active and archived investments round-trip',
    () async {
      repo.seed(
        investments: [
          _inv('a', 'SGB 2031', value: 125000.55, date: DateTime(2026, 10, 1)),
          _inv('b', 'Plot in Pune'),
        ],
        cashFlows: [_invest('a'), _invest('b')],
        archivedInvestments: [
          _inv('c', 'Old gold', value: 90000, date: DateTime(2026, 9, 1)),
        ],
        archivedCashFlows: [_invest('c')],
      );

      final bytes = await exportBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.findFile('valuations.csv'), isNotNull);

      repo.reset();
      final result = await importService.importFromZip(
        bytes,
        ImportStrategy.replace,
        baseCurrency: 'INR',
      );
      expect(result.errors, isEmpty);

      final active = await repo.getAllInvestments();
      final sgb = active.singleWhere((i) => i.name == 'SGB 2031');
      expect(sgb.currentValue, 125000.55);
      expect(sgb.currentValueDate, DateTime(2026, 10, 1));
      final plot = active.singleWhere((i) => i.name == 'Plot in Pune');
      expect(plot.currentValue, isNull);
      expect(plot.currentValueDate, isNull);

      final archived = await repo.watchArchivedInvestments().first;
      final old = archived.single;
      expect(old.currentValue, 90000);
      expect(old.currentValueDate, DateTime(2026, 9, 1));
    },
  );

  test('a merge never attaches a value to an existing investment', () async {
    repo.seed(
      investments: [
        _inv('a', 'SGB 2031', value: 125000, date: DateTime(2026, 10, 1)),
      ],
      cashFlows: [_invest('a')],
    );
    final bytes = await exportBytes();

    repo.reset();
    repo.seed(investments: [_inv('x', 'SGB 2031')], cashFlows: [_invest('x')]);
    await importService.importFromZip(
      bytes,
      ImportStrategy.merge,
      baseCurrency: 'INR',
    );

    final existing = (await repo.getAllInvestments()).single;
    expect(existing.id, 'x');
    expect(existing.currentValue, isNull);
  });

  test('a value in another currency than the imported investment is '
      'skipped with a warning', () async {
    final zip = Archive();
    void add(String name, String content) {
      final data = utf8.encode(content);
      zip.addFile(ArchiveFile(name, data.length, data));
    }

    add('metadata.json', jsonEncode({'version': '1.0', 'documents': []}));
    add(
      'cashflows.csv',
      'Date,Investment Name,Type,Amount,Currency,Notes,Investment Type,'
          'Investment Status\n'
          '2025-10-01,SGB 2031,INVEST,100000,INR,,gold,open\n',
    );
    add(
      'valuations.csv',
      'Investment Name,Archived,Date,Value,Currency\n'
          'SGB 2031,false,2026-10-01,1500,USD\n',
    );

    final result = await importService.importFromZip(
      Uint8List.fromList(ZipEncoder().encode(zip)!),
      ImportStrategy.replace,
      baseCurrency: 'INR',
    );

    final sgb = (await repo.getAllInvestments()).single;
    expect(sgb.currentValue, isNull);
    expect(result.warnings, isNotEmpty);
  });

  test(
    'a future-dated value is skipped with a warning, like in the app',
    () async {
      final zip = Archive();
      void add(String name, String content) {
        final data = utf8.encode(content);
        zip.addFile(ArchiveFile(name, data.length, data));
      }

      add('metadata.json', jsonEncode({'version': '1.0', 'documents': []}));
      add(
        'cashflows.csv',
        'Date,Investment Name,Type,Amount,Currency,Notes,Investment Type,'
            'Investment Status\n'
            '2025-10-01,SGB 2031,INVEST,100000,INR,,gold,open\n'
            '2025-10-02,Plot in Pune,INVEST,500000,INR,,property,open\n',
      );
      // Replace stops when valuations.csv has no readable row at all, so the
      // file keeps one valid row: the future-dated row is a row-level problem
      // in a file that can still be read.
      add(
        'valuations.csv',
        'Investment Name,Archived,Date,Value,Currency\n'
            'SGB 2031,false,2999-01-01,125000,INR\n'
            'Plot in Pune,false,2025-10-05,600000,INR\n',
      );

      final result = await importService.importFromZip(
        Uint8List.fromList(ZipEncoder().encode(zip)!),
        ImportStrategy.replace,
        baseCurrency: 'INR',
      );

      final active = await repo.getAllInvestments();
      final sgb = active.singleWhere((i) => i.name == 'SGB 2031');
      expect(sgb.currentValue, isNull);
      expect(sgb.currentValueDate, isNull);
      expect(
        active.singleWhere((i) => i.name == 'Plot in Pune').currentValue,
        600000,
      );
      expect(
        result.warnings,
        contains('Current value of "SGB 2031" not imported: invalid row'),
      );
    },
  );
}

// #946: quantity, unit and price per unit survive export -> wipe -> import
// (money rule 6), and a file with missing, partial or inconsistent unit
// columns still restores the value, without a weight claim.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../../investment/data/repositories/mock_investment_repository.dart';
import '../../../investment/valuation/in_memory_valuation_repository.dart';
import '../../../investment/valuation/valuation_fixtures.dart';

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
const _newHeader =
    'Investment Name,Archived,Date,Value,Currency,Snapshot ID,Kind,Source,'
    'Updated At,Investment Type,Investment Status\n';

void main() {
  late FakeInvestmentRepository repo;
  late InMemoryValuationRepository valuations;
  late DataExportService exportService;
  late DataImportService importService;

  setUp(() {
    repo = FakeInvestmentRepository();
    valuations = InMemoryValuationRepository();
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
      valuationRepository: valuations,
      performanceService: _PerformanceService(),
    );
    importService = DataImportService(
      investmentRepository: repo,
      goalRepository: goals,
      documentRepository: documents,
      documentStorageService: storage,
      valuationRepository: valuations,
      performanceService: _PerformanceService(),
    );
  });

  tearDown(() => valuations.dispose());

  Future<ZipExport> export() => exportService.exportAsZipBytes();

  List<List<dynamic>> valuationRows(Uint8List bytes) {
    final file = ZipDecoder().decodeBytes(bytes).findFile('valuations.csv')!;
    return csv.decode(utf8.decode(file.content as List<int>));
  }

  Future<ZipImportResult> importZip(
    Uint8List bytes, {
    ImportStrategy strategy = ImportStrategy.replace,
  }) => importService.importFromZip(bytes, strategy, baseCurrency: 'INR');

  void wipe() {
    repo.reset();
    valuations.docs.clear();
  }

  Future<List<InvestmentValuationSnapshot>> imported() => valuations.getAll();

  const holding = UnitHolding(
    quantity: 12.5,
    unit: QuantityUnit.gram,
    unitPrice: 6543.25,
  );

  test('a weighed gold holding survives export, wipe and import', () async {
    repo.seed(
      investments: [
        testInvestment(
          'gold1',
          compatValue: 81790.63,
          compatDate: DateTime(2026, 11, 3),
        ).copyWith(name: 'Digital gold'),
      ],
    );
    valuations.docs['g1'] = testSnapshot(
      'g1',
      investmentId: 'gold1',
      amount: 1,
      date: DateTime(2026, 11, 3),
      kind: ValuationKind.marketValue,
    ).copyWith(holding: holding);

    final bytes = (await export()).bytes;
    final header = valuationRows(bytes).first;
    expect(header, containsAll(['Quantity', 'Unit', 'Unit Price']));
    wipe();

    final result = await importZip(bytes);
    expect(result.errors, isEmpty);
    final snapshot = (await imported()).single;
    expect(snapshot.amount, 81790.63);
    expect(snapshot.holding, holding);
  });

  test('an amount-only value exports empty unit cells', () async {
    repo.seed(
      investments: [
        testInvestment(
          'fd',
          compatValue: 1000,
          compatDate: DateTime(2026, 1, 1),
        ),
      ],
    );
    valuations.docs['s'] = testSnapshot(
      's',
      investmentId: 'fd',
      amount: 1000,
      date: DateTime(2026, 1, 1),
    );
    final rows = valuationRows((await export()).bytes);
    final q = rows.first.indexOf('Quantity');
    expect(rows[1][q].toString(), '');
    wipe();
    // And it imports back with no holding.
  });

  const unitHeader =
      'Investment Name,Archived,Date,Value,Currency,Snapshot ID,Kind,Source,'
      'Updated At,Investment Type,Investment Status,Investment ID,Quantity,'
      'Unit,Unit Price\n';

  Future<ZipImportResult> importRow(String row) => importZip(
    _zip({
      'cashflows.csv':
          '${_cashFlowsHeader}2025-10-01,Gold,INVEST,100000,INR,,gold,open\n',
      'valuations.csv': '$unitHeader$row\n',
    }),
  );

  test('a file without unit columns restores the value alone', () async {
    final result = await importZip(
      _zip({
        'cashflows.csv':
            '${_cashFlowsHeader}2025-10-01,Gold,INVEST,100000,INR,,gold,open\n',
        'valuations.csv':
            '${_newHeader}Gold,false,2026-01-01,150000,INR,'
            ',marketValue,manual,,gold,open\n',
      }),
    );
    expect(result.errors, isEmpty);
    final snapshot = (await imported()).single;
    expect(snapshot.amount, 150000);
    expect(snapshot.holding, isNull);
  });

  test('consistent unit cells are restored', () async {
    final result = await importRow(
      'Gold,false,2026-01-01,60000,INR,,marketValue,manual,,gold,open,,10,gram,6000',
    );
    expect(result.errors, isEmpty);
    final snapshot = (await imported()).single;
    expect(snapshot.holding?.quantity, 10);
    expect(snapshot.holding?.unit, QuantityUnit.gram);
    expect(snapshot.holding?.unitPrice, 6000);
  });

  test('inconsistent or unknown unit cells keep the value and warn', () async {
    for (final cells in [
      '10,gram,5000',
      '10,carat,6000',
      '10,,6000',
      '-1,gram,6000',
    ]) {
      wipe();
      final result = await importRow(
        'Gold,false,2026-01-01,60000,INR,,marketValue,manual,,gold,open,,$cells',
      );
      expect(result.errors, isEmpty, reason: cells);
      final snapshot = (await imported()).single;
      expect(snapshot.amount, 60000, reason: cells);
      expect(snapshot.holding, isNull, reason: cells);
      expect(
        result.warnings.any((w) => w.contains('Weight details of "Gold"')),
        isTrue,
        reason: cells,
      );
    }
  });
}

/// A backup restores every investment as it was (A24 / #768).
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
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

class _NoTrace extends Mock implements PerformanceService {
  @override
  Future<T> trackOperation<T>(
    String traceName,
    Future<T> Function() operation, {
    Map<String, int>? metrics,
    Map<String, String>? attributes,
  }) => operation();
}

class _Docs extends Mock implements DocumentRepository {}

class _Storage extends Mock implements DocumentStorageService {}

void main() {
  late FakeInvestmentRepository repo;
  late DataExportService export;
  late DataImportService import;
  late Directory tempDir;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
    repo = FakeInvestmentRepository();
    final goals = FakeGoalRepository();
    final docs = _Docs();
    when(
      () => docs.getDocumentsByInvestment(any()),
    ).thenAnswer((_) async => []);
    final storage = _Storage();
    final perf = _NoTrace();
    export = DataExportService(
      investmentRepository: repo,
      goalRepository: goals,
      documentRepository: docs,
      documentStorageService: storage,
      performanceService: perf,
    );
    import = DataImportService(
      investmentRepository: repo,
      goalRepository: goals,
      documentRepository: docs,
      documentStorageService: storage,
      performanceService: perf,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  InvestmentEntity rich(String id, String name) => InvestmentEntity(
    id: id,
    name: name,
    type: InvestmentType.fixedDeposit,
    status: InvestmentStatus.open,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    currency: 'USD',
    maturityDate: DateTime(2028, 3, 31),
    expectedRate: 7.25,
    incomeFrequency: IncomeFrequency.quarterly,
    platform: 'Acme Bank',
    notes: 'line one\nline two, with "quotes"',
  );

  CashFlowEntity flow(String id, String investmentId, String notes) =>
      CashFlowEntity(
        id: id,
        investmentId: investmentId,
        date: DateTime(2026, 2, 1),
        type: CashFlowType.invest,
        amount: 1000,
        createdAt: DateTime(2026, 2, 1),
        currency: 'USD',
        notes: notes,
      );

  Future<void> seed() async {
    await repo.bulkImport(
      investments: [rich('a', 'Same name'), rich('b', 'Same name')],
      cashFlows: [flow('fa', 'a', 'first\nsecond'), flow('fb', 'b', 'only')],
    );
  }

  test('export, wipe, import reproduces every investment field', () async {
    await seed();
    final zip = await export.exportAsZipBytes();

    await repo.bulkDelete(['a', 'b']);
    expect(await repo.getAllInvestments(), isEmpty);

    final result = await import.importFromZip(
      zip.bytes,
      ImportStrategy.replace,
      baseCurrency: 'INR',
    );
    expect(result.errors, isEmpty);

    final back = await repo.getAllInvestments();
    expect(back, hasLength(2), reason: 'same-name investments stay separate');
    for (final inv in back) {
      expect(inv.name, 'Same name');
      expect(inv.currency, 'USD');
      expect(inv.maturityDate, DateTime(2028, 3, 31));
      expect(inv.expectedRate, 7.25);
      expect(inv.incomeFrequency, IncomeFrequency.quarterly);
      expect(inv.platform, 'Acme Bank');
      expect(inv.notes, 'line one\nline two, with "quotes"');
    }
    final notes = <String>[];
    for (final inv in back) {
      for (final cf in await repo.getCashFlowsByInvestment(inv.id)) {
        notes.add(cf.notes ?? '');
      }
    }
    expect(notes, unorderedEquals(['first\nsecond', 'only']));
  });

  // The backup with investments.json replaced by [json].
  Uint8List withInvestmentsJson(Uint8List zip, String json) {
    final out = Archive();
    for (final f in ZipDecoder().decodeBytes(zip).files) {
      if (f.name == 'investments.json') continue;
      out.addFile(ArchiveFile(f.name, f.size, f.content));
    }
    final bytes = utf8.encode(json);
    out.addFile(ArchiveFile('investments.json', bytes.length, bytes));
    return Uint8List.fromList(ZipEncoder().encode(out)!);
  }

  Future<Uint8List> exportedBackup() async {
    await seed();
    return (await export.exportAsZipBytes()).bytes;
  }

  final damagedFiles = <String, String>{
    'malformed': '{not json',
    'newer version': '{"schemaVersion": 99, "investments": []}',
    'unreadable row among readable ones':
        '{"schemaVersion": 1, "investments": [42]}',
  };

  for (final entry in damagedFiles.entries) {
    test('Replace stops on a damaged investments.json (${entry.key}) and '
        'keeps the existing data', () async {
      final zip = withInvestmentsJson(await exportedBackup(), entry.value);

      final result = await import.importFromZip(
        zip,
        ImportStrategy.replace,
        baseCurrency: 'INR',
      );

      expect(result.errors.single, contains('investments.json is damaged'));
      expect(await repo.getAllInvestments(), hasLength(2));
    });

    test('Merge skips a damaged investments.json (${entry.key}) with a '
        'warning and still imports', () async {
      final zip = withInvestmentsJson(await exportedBackup(), entry.value);
      await repo.bulkDelete(['a', 'b']);

      final result = await import.importFromZip(
        zip,
        ImportStrategy.merge,
        baseCurrency: 'INR',
      );

      expect(result.errors, isEmpty);
      expect(result.warnings, isNotEmpty);
      // Without investments.json the two same-name investments fall back to
      // matching by name, as in a backup from before the file existed.
      expect(await repo.getAllInvestments(), hasLength(1));
    });
  }

  test(
    'Replace stops when one row of investments.json is unreadable',
    () async {
      final backup = await exportedBackup();
      final text = utf8.decode(
        ZipDecoder().decodeBytes(backup).findFile('investments.json')!.content
            as List<int>,
      );
      final good = jsonDecode(text) as Map<String, dynamic>;
      (good['investments'] as List).add(42);
      final zip = withInvestmentsJson(backup, jsonEncode(good));

      final result = await import.importFromZip(
        zip,
        ImportStrategy.replace,
        baseCurrency: 'INR',
      );

      expect(result.errors.single, contains('investments.json is damaged'));
      expect(await repo.getAllInvestments(), hasLength(2));
    },
  );

  test('Merge restores a missing investment with its details and skips '
      'the one that exists', () async {
    await repo.bulkImport(
      investments: [rich('a', 'Alpha'), rich('b', 'Beta')],
      cashFlows: [flow('fa', 'a', 'x'), flow('fb', 'b', 'y')],
    );
    final zip = (await export.exportAsZipBytes()).bytes;
    await repo.bulkDelete(['b']);

    final result = await import.importFromZip(
      zip,
      ImportStrategy.merge,
      baseCurrency: 'INR',
    );

    expect(result.errors, isEmpty);
    expect(result.warnings, hasLength(1));
    final all = await repo.getAllInvestments();
    expect(all.map((i) => i.name), unorderedEquals(['Alpha', 'Beta']));
    final beta = all.firstWhere((i) => i.name == 'Beta');
    expect(beta.id, isNot('b'), reason: 'Merge adds under a new id');
    expect(beta.platform, 'Acme Bank');
    expect(beta.expectedRate, 7.25);
  });
}

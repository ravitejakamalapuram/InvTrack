/// A backup restores every investment as it was (A24 / #768).
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
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
  late _Docs docsRepo;
  late _Storage storageSvc;

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
    final docs = docsRepo = _Docs();
    when(
      () => docs.getDocumentsByInvestment(any()),
    ).thenAnswer((_) async => []);
    final storage = storageSvc = _Storage();
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

  test(
    'notes that start like a spreadsheet formula come back unchanged',
    () async {
      // The export guards such cells with a leading quote (CSV injection);
      // restoring them must take the guard off again, not keep it as data.
      const risky = [
        '-5% drawdown',
        '=SUM(A1)',
        '+91 broker call',
        '@desk',
        "'=SUM(A1)",
      ];
      await repo.bulkImport(
        investments: [rich('a', 'Plain')],
        cashFlows: [
          for (var i = 0; i < risky.length; i++) flow('f$i', 'a', risky[i]),
        ],
      );
      final zip = await export.exportAsZipBytes();
      await repo.bulkDelete(['a']);

      final result = await import.importFromZip(
        zip.bytes,
        ImportStrategy.replace,
        baseCurrency: 'INR',
      );
      expect(result.errors, isEmpty);

      final back = await repo.getAllInvestments();
      final notes = [
        for (final inv in back)
          for (final cf in await repo.getCashFlowsByInvestment(inv.id))
            cf.notes,
      ];
      expect(notes, unorderedEquals(risky));
    },
  );

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

      expect(
        result.errors.single,
        const ImportError.fileDamaged('investments.json'),
      );
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

      expect(
        result.errors.single,
        const ImportError.fileDamaged('investments.json'),
      );
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

  final damagedRows = <String, Object>{
    'a currency the app does not list': {
      'id': 'x',
      'name': 'X',
      'type': 'fixedDeposit',
      'status': 'open',
      'currency': 'ZZZ',
      'createdAt': '2026-01-01T00:00:00.000',
      'updatedAt': '2026-01-01T00:00:00.000',
    },
    'an expected rate that is not a number': {
      'id': 'x',
      'name': 'X',
      'type': 'fixedDeposit',
      'status': 'open',
      'currency': 'USD',
      'createdAt': '2026-01-01T00:00:00.000',
      'updatedAt': '2026-01-01T00:00:00.000',
      'expectedRate': 'seven',
    },
  };

  for (final entry in damagedRows.entries) {
    test('Replace stops on ${entry.key}', () async {
      final zip = withInvestmentsJson(
        await exportedBackup(),
        jsonEncode({
          'schemaVersion': 1,
          'investments': [entry.value],
        }),
      );

      final result = await import.importFromZip(
        zip,
        ImportStrategy.replace,
        baseCurrency: 'INR',
      );

      expect(
        result.errors.single,
        const ImportError.fileDamaged('investments.json'),
      );
      expect(await repo.getAllInvestments(), hasLength(2));
    });
  }

  test(
    'Merge warns when it skips one unreadable row among readable ones',
    () async {
      final backup = await exportedBackup();
      final text = utf8.decode(
        ZipDecoder().decodeBytes(backup).findFile('investments.json')!.content
            as List<int>,
      );
      final json = jsonDecode(text) as Map<String, dynamic>;
      (json['investments'] as List).add(42);
      await repo.bulkDelete(['a', 'b']);

      final result = await import.importFromZip(
        withInvestmentsJson(backup, jsonEncode(json)),
        ImportStrategy.merge,
        baseCurrency: 'INR',
      );

      expect(result.errors, isEmpty);
      expect(result.warnings, hasLength(1));
      final all = await repo.getAllInvestments();
      expect(all, hasLength(2), reason: 'the readable rows still restore');
      expect(all.every((i) => i.platform == 'Acme Bank'), isTrue);
    },
  );

  test('Merge restores the missing one of two same-name investments, and a '
      'second Merge adds nothing', () async {
    final zip = await exportedBackup();
    await repo.bulkDelete(['b']);

    var result = await import.importFromZip(
      zip,
      ImportStrategy.merge,
      baseCurrency: 'INR',
    );
    expect(result.errors, isEmpty);
    expect(await repo.getAllInvestments(), hasLength(2));

    result = await import.importFromZip(
      zip,
      ImportStrategy.merge,
      baseCurrency: 'INR',
    );
    expect(await repo.getAllInvestments(), hasLength(2));
  });

  test('Replace gives each same-name investment its own documents', () async {
    await seed();
    final zipBytes = (await export.exportAsZipBytes()).bytes;
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final meta =
        jsonDecode(
              utf8.decode(
                archive.findFile('metadata.json')!.content as List<int>,
              ),
            )
            as Map<String, dynamic>;
    final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0];
    meta['documents'] = [
      for (final id in ['a', 'b'])
        {
          'id': 'doc-$id',
          'investmentId': id,
          'investmentName': 'Same name',
          'fileName': '$id.png',
          'zipPath': 'documents/$id/$id.png',
        },
    ];
    final out = Archive();
    for (final f in archive.files) {
      if (f.name == 'metadata.json') continue;
      out.addFile(ArchiveFile(f.name, f.size, f.content));
    }
    final metaBytes = utf8.encode(jsonEncode(meta));
    out.addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));
    for (final id in ['a', 'b']) {
      out.addFile(ArchiveFile('documents/$id/$id.png', png.length, png));
    }
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(
      DocumentEntity(
        id: 'f',
        investmentId: 'f',
        name: 'f',
        fileName: 'f',
        type: DocumentType.other,
        mimeType: 'x',
        localPath: 'f',
        fileSize: 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    when(
      () => storageSvc.saveDocument(
        investmentId: any(named: 'investmentId'),
        documentId: any(named: 'documentId'),
        fileName: any(named: 'fileName'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) async => '/tmp/x');
    when(() => docsRepo.createDocument(any())).thenAnswer((_) async {});

    await import.importFromZip(
      Uint8List.fromList(ZipEncoder().encode(out)!),
      ImportStrategy.replace,
      baseCurrency: 'INR',
    );

    final saved = verify(
      () => storageSvc.saveDocument(
        investmentId: captureAny(named: 'investmentId'),
        documentId: captureAny(named: 'documentId'),
        fileName: any(named: 'fileName'),
        bytes: any(named: 'bytes'),
      ),
    ).captured;
    final byDoc = {saved[1]: saved[0], saved[3]: saved[2]};
    expect(byDoc['doc-a'], 'a');
    expect(byDoc['doc-b'], 'b');
  });
}

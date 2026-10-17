/// A backup restores every investment as it was (A24 / #768).
library;

import 'dart:io';

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
}

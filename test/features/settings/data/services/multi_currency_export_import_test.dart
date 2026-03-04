import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../../investment/data/repositories/mock_investment_repository.dart';

class MockPerformanceService extends Mock implements PerformanceService {}

/// Tests for multi-currency export/import round-trip (Rule 21.4)
///
/// Verifies that:
/// - Multi-currency investments export correctly to CSV/ZIP
/// - Currency information is preserved in exports
/// - Import restores all currency data without loss
/// - Round-trip (export → import) maintains data integrity
void main() {
  late FakeInvestmentRepository investmentRepository;
  late FakeGoalRepository goalRepository;
  late MockDocumentRepository documentRepository;
  late MockDocumentStorageService documentStorageService;
  late MockPerformanceService performanceService;
  late DataExportService exportService;
  late DataImportService importService;
  late Directory tempDir;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync();

    // Mock path_provider
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return tempDir.path;
    });

    investmentRepository = FakeInvestmentRepository();
    goalRepository = FakeGoalRepository();
    documentRepository = MockDocumentRepository();
    documentStorageService = MockDocumentStorageService();
    performanceService = MockPerformanceService();

    // Default mock behavior
    when(
      () => documentStorageService.readDocument(any()),
    ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

    when(
      () => documentRepository.getDocumentsByInvestment(any()),
    ).thenAnswer((_) async => []);

    exportService = DataExportService(
      investmentRepository: investmentRepository,
      goalRepository: goalRepository,
      documentRepository: documentRepository,
      documentStorageService: documentStorageService,
      performanceService: performanceService,
    );

    importService = DataImportService(
      investmentRepository: investmentRepository,
      goalRepository: goalRepository,
      documentRepository: documentRepository,
      documentStorageService: documentStorageService,
      performanceService: performanceService,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (e) {
        // Ignore deletion errors in tests
      }
    }
  });

  /// Helper to create a valid ZIP archive with given files
  Uint8List createZipArchive(Map<String, String> files) {
    final archive = Archive();
    for (final entry in files.entries) {
      final bytes = utf8.encode(entry.value);
      archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
    }
    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded!);
  }

  group('Multi-Currency Export/Import Round-Trip', () {
    test('preserves currency information in CSV export', () async {
      // Arrange: Create multi-currency investment
      final investment = InvestmentEntity(
        id: 'inv-1',
        name: 'Multi-Currency Portfolio',
        type: InvestmentType.stocks,
        status: InvestmentStatus.open,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      await investmentRepository.createInvestment(investment);

      // Add cash flows in different currencies
      final cashFlows = [
        CashFlowEntity(
          id: 'cf-1',
          investmentId: 'inv-1',
          type: CashFlowType.invest,
          amount: 1000.0,
          currency: 'USD',
          date: DateTime(2024, 1, 15),
          notes: 'US investment',
          createdAt: DateTime(2024, 1, 15),
        ),
        CashFlowEntity(
          id: 'cf-2',
          investmentId: 'inv-1',
          type: CashFlowType.invest,
          amount: 50000.0,
          currency: 'INR',
          date: DateTime(2024, 2, 15),
          notes: 'Indian investment',
          createdAt: DateTime(2024, 2, 15),
        ),
        CashFlowEntity(
          id: 'cf-3',
          investmentId: 'inv-1',
          type: CashFlowType.income,
          amount: 500.0,
          currency: 'EUR',
          date: DateTime(2024, 3, 15),
          notes: 'European dividend',
          createdAt: DateTime(2024, 3, 15),
        ),
      ];

      for (final cf in cashFlows) {
        await investmentRepository.addCashFlow(cf);
      }

      // Act: Export to ZIP
      final zipPath = await exportService.exportAsZip();
      final zipFile = File(zipPath);
      final zipBytes = await zipFile.readAsBytes();

      // Assert: Verify ZIP contains currency information
      final archive = ZipDecoder().decodeBytes(zipBytes);
      final cashflowsFile = archive.findFile('cashflows.csv');
      expect(cashflowsFile, isNotNull);

      final csvContent = utf8.decode(cashflowsFile!.content as List<int>);
      final csvRows = const CsvToListConverter().convert(csvContent);

      // Verify header includes Currency column
      expect(csvRows[0], contains('Currency'));
      final currencyIndex = csvRows[0].indexOf('Currency');

      // Verify each row has correct currency
      expect(csvRows[1][currencyIndex], 'USD');
      expect(csvRows[2][currencyIndex], 'INR');
      expect(csvRows[3][currencyIndex], 'EUR');
    });

    test('round-trip preserves all currency data', () async {
      // Arrange: Create multi-currency investment
      final investment = InvestmentEntity(
        id: 'inv-1',
        name: 'Global Portfolio',
        type: InvestmentType.stocks,
        status: InvestmentStatus.open,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      await investmentRepository.createInvestment(investment);

      final originalCashFlows = [
        CashFlowEntity(
          id: 'cf-1',
          investmentId: 'inv-1',
          type: CashFlowType.invest,
          amount: 1000.0,
          currency: 'USD',
          date: DateTime(2024, 1, 15),
          notes: 'US stocks',
          createdAt: DateTime(2024, 1, 15),
        ),
        CashFlowEntity(
          id: 'cf-2',
          investmentId: 'inv-1',
          type: CashFlowType.invest,
          amount: 75000.0,
          currency: 'INR',
          date: DateTime(2024, 2, 15),
          notes: 'Indian mutual funds',
          createdAt: DateTime(2024, 2, 15),
        ),
        CashFlowEntity(
          id: 'cf-3',
          investmentId: 'inv-1',
          type: CashFlowType.income,
          amount: 800.0,
          currency: 'EUR',
          date: DateTime(2024, 3, 15),
          notes: 'European bonds dividend',
          createdAt: DateTime(2024, 3, 15),
        ),
      ];

      for (final cf in originalCashFlows) {
        await investmentRepository.addCashFlow(cf);
      }

      // Act: Export → Clear → Import
      final zipPath = await exportService.exportAsZip();
      final zipFile = File(zipPath);
      final zipBytes = await zipFile.readAsBytes();

      // Clear all data
      investmentRepository.reset();

      // Import
      final result = await importService.importFromZip(
        zipBytes,
        ImportStrategy.replace,
      );

      // Assert: Verify import success
      expect(result.isSuccess, true);
      expect(result.cashflowsImported, 3);

      // Verify all cash flows restored with correct currencies
      final importedCashFlows = investmentRepository.cashFlows;
      expect(importedCashFlows.length, 3);

      // Sort by date for comparison
      final sortedCashFlows = List<CashFlowEntity>.from(importedCashFlows)
        ..sort((a, b) => a.date.compareTo(b.date));

      expect(sortedCashFlows[0].amount, 1000.0);
      expect(sortedCashFlows[0].currency, 'USD');
      expect(sortedCashFlows[0].notes, 'US stocks');

      expect(sortedCashFlows[1].amount, 75000.0);
      expect(sortedCashFlows[1].currency, 'INR');
      expect(sortedCashFlows[1].notes, 'Indian mutual funds');

      expect(sortedCashFlows[2].amount, 800.0);
      expect(sortedCashFlows[2].currency, 'EUR');
      expect(sortedCashFlows[2].notes, 'European bonds dividend');
    });

    test('handles missing currency column (backward compatibility)', () async {
      // Arrange: Create ZIP with old CSV format (no Currency column)
      final metadata = {
        'version': '1.0',
        'files': [
          {'fileName': 'cashflows.csv', 'type': 'cashflows'}
        ]
      };

      // Old CSV format without Currency column
      final csvContent = '''Date,Investment Name,Type,Amount,Notes
2024-01-15,Legacy Investment,INVEST,100000,Old format
2024-02-15,Legacy Investment,INCOME,1500,No currency''';

      final zipBytes = createZipArchive({
        'metadata.json': jsonEncode(metadata),
        'cashflows.csv': csvContent,
      });

      // Act: Import
      final result = await importService.importFromZip(
        zipBytes,
        ImportStrategy.merge,
      );

      // Assert: Verify import success with default currency
      expect(result.isSuccess, true);
      expect(result.cashflowsImported, 2);

      final importedCashFlows = investmentRepository.cashFlows;
      expect(importedCashFlows.length, 2);

      // Verify default currency is USD (backward compatibility)
      for (final cf in importedCashFlows) {
        expect(cf.currency, 'USD');
      }
    });

    test('preserves currency across multiple investments', () async {
      // Arrange: Create multiple investments with different currencies
      final investments = [
        InvestmentEntity(
          id: 'inv-1',
          name: 'US Stocks',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
        InvestmentEntity(
          id: 'inv-2',
          name: 'Indian FD',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
      ];

      for (final inv in investments) {
        await investmentRepository.createInvestment(inv);
      }

      final cashFlows = [
        CashFlowEntity(
          id: 'cf-1',
          investmentId: 'inv-1',
          type: CashFlowType.invest,
          amount: 5000.0,
          currency: 'USD',
          date: DateTime(2024, 1, 15),
          createdAt: DateTime(2024, 1, 15),
        ),
        CashFlowEntity(
          id: 'cf-2',
          investmentId: 'inv-2',
          type: CashFlowType.invest,
          amount: 100000.0,
          currency: 'INR',
          date: DateTime(2024, 1, 15),
          createdAt: DateTime(2024, 1, 15),
        ),
      ];

      for (final cf in cashFlows) {
        await investmentRepository.addCashFlow(cf);
      }

      // Act: Export → Clear → Import
      final zipPath = await exportService.exportAsZip();
      final zipFile = File(zipPath);
      final zipBytes = await zipFile.readAsBytes();

      investmentRepository.reset();

      final result = await importService.importFromZip(
        zipBytes,
        ImportStrategy.replace,
      );

      // Assert
      expect(result.isSuccess, true);
      expect(result.cashflowsImported, 2);

      final usCashFlows = investmentRepository.cashFlows
          .where((cf) => cf.currency == 'USD')
          .toList();
      final inrCashFlows = investmentRepository.cashFlows
          .where((cf) => cf.currency == 'INR')
          .toList();

      expect(usCashFlows.length, 1);
      expect(usCashFlows.first.amount, 5000.0);

      expect(inrCashFlows.length, 1);
      expect(inrCashFlows.first.amount, 100000.0);
    });
  });
}

// Mock classes
class MockDocumentRepository extends Mock implements DocumentRepository {}

class MockDocumentStorageService extends Mock
    implements DocumentStorageService {}


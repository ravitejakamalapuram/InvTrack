import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fire_number/data/repositories/mock_fire_settings_repository.dart';
import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../../investment/data/repositories/mock_investment_repository.dart';

class MockDocumentRepository extends Mock implements DocumentRepository {}

class MockDocumentStorageService extends Mock
    implements DocumentStorageService {}

class MockPerformanceService extends Mock implements PerformanceService {}

void main() {
  late FakeInvestmentRepository investmentRepository;
  late FakeGoalRepository goalRepository;
  late MockDocumentRepository documentRepository;
  late MockDocumentStorageService documentStorageService;
  late MockPerformanceService performanceService;
  late DataImportService service;

  setUpAll(() {
    registerFallbackValue(
      DocumentEntity(
        id: 'test',
        investmentId: 'test',
        name: 'test',
        fileName: 'test.pdf',
        type: DocumentType.other,
        mimeType: 'application/pdf',
        localPath: '/test',
        fileSize: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    investmentRepository = FakeInvestmentRepository();
    goalRepository = FakeGoalRepository();
    documentRepository = MockDocumentRepository();
    documentStorageService = MockDocumentStorageService();
    performanceService = MockPerformanceService();

    // Mock performance service to just execute the operation
    when(
      () => performanceService.trackOperation<ZipImportResult>(
        any(),
        any(),
        metrics: any(named: 'metrics'),
        attributes: any(named: 'attributes'),
      ),
    ).thenAnswer((invocation) async {
      final operation =
          invocation.positionalArguments[1]
              as Future<ZipImportResult> Function();
      return await operation();
    });

    service = DataImportService(
      investmentRepository: investmentRepository,
      goalRepository: goalRepository,
      documentRepository: documentRepository,
      documentStorageService: documentStorageService,
      performanceService: performanceService,
    );

    // Setup default mock behaviors
    when(
      () => documentRepository.createDocument(any()),
    ).thenAnswer((_) async {});
    when(
      () => documentStorageService.saveDocument(
        investmentId: any(named: 'investmentId'),
        documentId: any(named: 'documentId'),
        fileName: any(named: 'fileName'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) async => '/path/to/file');
  });

  tearDown(() {
    investmentRepository.reset();
    goalRepository.reset();
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

  group('DataImportService', () {
    group('importFromZip - Basic Validation', () {
      test('returns error for invalid ZIP data', () async {
        final result = await service.importFromZip(
          Uint8List.fromList([1, 2, 3]),
          ImportStrategy.merge,
          baseCurrency: 'INR',
        );

        expect(result.isSuccess, false);
        expect(result.errors, contains(contains('Invalid ZIP file')));
      });

      test('returns error for empty ZIP archive (missing metadata)', () async {
        final archive = Archive();
        final encoded = ZipEncoder().encode(archive);
        final bytes = Uint8List.fromList(encoded!);

        final result = await service.importFromZip(
          bytes,
          ImportStrategy.merge,
          baseCurrency: 'INR',
        );

        expect(result.isSuccess, false);
        // Empty archive returns "metadata.json not found" error
        expect(result.errors, contains(contains('metadata.json')));
      });

      test('returns error for missing metadata.json', () async {
        final bytes = createZipArchive({
          'cashflows.csv':
              'Date,Investment Name,Type,Amount\n2024-01-01,Test,invest,1000',
        });

        final result = await service.importFromZip(
          bytes,
          ImportStrategy.merge,
          baseCurrency: 'INR',
        );

        expect(result.isSuccess, false);
        expect(result.errors, contains(contains('metadata.json')));
      });
    });

    group('importFromZip - Cashflows Import', () {
      test('imports cashflows successfully', () async {
        final bytes = createZipArchive({
          'metadata.json':
              '{"version":"1.0","files":[{"fileName":"cashflows.csv","type":"cashflows"}]}',
          'cashflows.csv': '''Date,Investment Name,Type,Amount,Notes
2024-01-15,Test Investment,INVEST,100000,Initial investment
2024-02-15,Test Investment,INCOME,1500,Monthly interest''',
        });

        final result = await service.importFromZip(
          bytes,
          ImportStrategy.merge,
          baseCurrency: 'INR',
        );

        expect(result.isSuccess, true);
        expect(result.cashflowsImported, 2);
        expect(investmentRepository.investments.length, 1);
        expect(investmentRepository.cashFlows.length, 2);
      });

      test('groups cashflows by investment name', () async {
        final bytes = createZipArchive({
          'metadata.json':
              '{"version":"1.0","files":[{"fileName":"cashflows.csv","type":"cashflows"}]}',
          'cashflows.csv': '''Date,Investment Name,Type,Amount
2024-01-15,Investment A,INVEST,100000
2024-02-15,Investment B,INVEST,50000
2024-03-15,Investment A,INCOME,1000''',
        });

        final result = await service.importFromZip(
          bytes,
          ImportStrategy.merge,
          baseCurrency: 'INR',
        );

        expect(result.isSuccess, true);
        expect(result.cashflowsImported, 3);
        expect(investmentRepository.investments.length, 2);
      });
    });

    group('importFromZip - Goals Import', () {
      test('imports goals successfully', () async {
        final bytes = createZipArchive({
          'metadata.json':
              '{"version":"1.0","files":[{"fileName":"goals.csv","type":"goals"}]}',
          'goals.csv':
              '''Name,Type,Target Amount,Target Monthly Income,Target Date,Tracking Mode,Linked Investment IDs,Linked Types,Icon,Color
Retirement Fund,targetAmount,1000000,,,all,,,🎯,4282339765''',
        });

        final result = await service.importFromZip(
          bytes,
          ImportStrategy.merge,
          baseCurrency: 'INR',
        );

        expect(result.isSuccess, true);
        expect(result.goalsImported, 1);
        expect(goalRepository.goals.length, 1);
        expect(goalRepository.goals.first.name, 'Retirement Fund');
      });
    });

    group('importFromZip - Archived Data', () {
      test('imports archived cashflows', () async {
        final bytes = createZipArchive({
          'metadata.json':
              '{"version":"1.0","files":[{"fileName":"cashflows_archived.csv","type":"cashflowsArchived"}]}',
          'cashflows_archived.csv': '''Date,Investment Name,Type,Amount
2024-01-15,Archived Investment,INVEST,50000''',
        });

        final result = await service.importFromZip(
          bytes,
          ImportStrategy.merge,
          baseCurrency: 'INR',
        );

        expect(result.isSuccess, true);
        expect(result.cashflowsImported, 1);
      });

      test('imports archived goals', () async {
        final bytes = createZipArchive({
          'metadata.json':
              '{"version":"1.0","files":[{"fileName":"goals_archived.csv","type":"goalsArchived"}]}',
          'goals_archived.csv': '''Name,Type,Target Amount
Archived Goal,targetAmount,25000''',
        });

        final result = await service.importFromZip(
          bytes,
          ImportStrategy.merge,
          baseCurrency: 'INR',
        );

        expect(result.isSuccess, true);
        expect(result.goalsImported, 1);
      });

      test('reports archived cash flow and goal rows that cannot be read as '
          'errors instead of dropping them silently', () async {
        final bytes = createZipArchive({
          'metadata.json': '{"version":"1.0","files":[]}',
          'cashflows_archived.csv': '''Date,Investment Name,Type,Amount
2024-01-15,Archived Investment,INVEST,50000
2024-02-15,Archived Investment,INVEST,''',
          'goals_archived.csv': '''Name,Type,Target Amount
Archived Goal,targetAmount,25000
,targetAmount,10000''',
        });

        final result = await service.importFromZip(
          bytes,
          ImportStrategy.merge,
          baseCurrency: 'INR',
        );

        expect(result.cashflowsImported, 1);
        expect(result.goalsImported, 1);
        expect(result.isSuccess, isFalse);
        expect(result.errors, hasLength(2));
      });
    });

    group('importFromZip - FIRE Settings Import', () {
      late FakeFireSettingsRepository fireSettingsRepository;
      late DataImportService serviceWithFire;

      setUp(() {
        fireSettingsRepository = FakeFireSettingsRepository();
        serviceWithFire = DataImportService(
          investmentRepository: investmentRepository,
          goalRepository: goalRepository,
          documentRepository: documentRepository,
          documentStorageService: documentStorageService,
          fireSettingsRepository: fireSettingsRepository,
          performanceService: performanceService,
        );
      });

      tearDown(() {
        fireSettingsRepository.dispose();
      });

      test('imports FIRE settings successfully', () async {
        final fireSettingsJson = jsonEncode({
          'id': 'fire-test-1',
          'monthlyExpenses': 50000.0,
          'safeWithdrawalRate': 4.0,
          'currentAge': 30,
          'targetFireAge': 45,
          'lifeExpectancy': 85,
          'inflationRate': 6.0,
          'preRetirementReturn': 12.0,
          'postRetirementReturn': 8.0,
          'healthcareBuffer': 20.0,
          'emergencyMonths': 6.0,
          'fireType': 'regular',
          'monthlyPassiveIncome': 5000.0,
          'expectedPension': 10000.0,
          'isSetupComplete': true,
          'createdAt': '2024-01-01T00:00:00.000',
          'updatedAt': '2024-01-01T00:00:00.000',
        });

        final bytes = createZipArchive({
          'metadata.json': '{"version":"1.0","files":[]}',
          'fire_settings.json': fireSettingsJson,
        });

        final result = await serviceWithFire.importFromZip(
          bytes,
          ImportStrategy.merge,
          baseCurrency: 'INR',
        );

        expect(result.isSuccess, true);
        expect(result.fireSettingsImported, true);
        expect(fireSettingsRepository.settings, isNotNull);
        expect(fireSettingsRepository.settings!.monthlyExpenses, 50000.0);
        // A11 / PLAN-05: an export from before birth years were stored has
        // the age entered at setup (30 on 2024-01-01). The age now advances
        // instead of staying 30.
        expect(fireSettingsRepository.settings!.birthYear, 1994);
        expect(fireSettingsRepository.settings!.targetFireAge, 45);
        expect(fireSettingsRepository.settings!.fireType, FireType.regular);
        expect(fireSettingsRepository.settings!.currency, isNull);
      });

      // Rule 6: every stored FIRE field survives export and import.
      test('imports the birth year, currency, other assets and SIP', () async {
        final exported = FireSettingsEntity(
          id: 'fire-test-2',
          monthlyExpenses: 75000,
          birthYear: 1990,
          targetFireAge: 50,
          healthcareBuffer: 15,
          emergencyMonths: 9,
          otherAssets: 1500000,
          monthlySip: 40000,
          currency: 'USD',
          isSetupComplete: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final bytes = createZipArchive({
          'metadata.json': '{"version":"1.0","files":[]}',
          'fire_settings.json': jsonEncode(exported.toJson()),
        });

        final result = await serviceWithFire.importFromZip(
          bytes,
          ImportStrategy.merge,
          baseCurrency: 'INR',
        );

        expect(result.fireSettingsImported, true);
        final imported = fireSettingsRepository.settings!;
        expect(imported, exported);
        expect(imported.birthYear, 1990);
        expect(imported.currency, 'USD');
        expect(imported.otherAssets, 1500000);
        expect(imported.monthlySip, 40000);
        expect(imported.healthcareBuffer, 15);
        expect(imported.emergencyMonths, 9);
      });

      // FIRE amounts carry no currency, and the guest merge runs this import
      // against the user's main account, so merge must never overwrite FIRE
      // settings the account already has.
      FireSettingsEntity existingSettings() => FireSettingsEntity(
        id: 'existing',
        monthlyExpenses: 200000,
        birthYear: DateTime.now().year - 40,
        targetFireAge: 55,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      Uint8List backupWithFireSettings() => createZipArchive({
        'metadata.json': '{"version":"1.0","files":[]}',
        'fire_settings.json':
            '{"monthlyExpenses":30000,"currentAge":25,"targetFireAge":45}',
      });

      test(
        'merge keeps existing FIRE settings and reports a warning',
        () async {
          final existing = existingSettings();
          fireSettingsRepository.seed(existing);

          final result = await serviceWithFire.importFromZip(
            backupWithFireSettings(),
            ImportStrategy.merge,
            baseCurrency: 'INR',
          );

          expect(result.fireSettingsImported, false);
          expect(fireSettingsRepository.settings, same(existing));
          expect(fireSettingsRepository.settings!.monthlyExpenses, 200000.0);
          expect(fireSettingsRepository.settings!.currentAge, 40);
          const warning =
              'FIRE settings not imported: this account already has FIRE '
              'settings';
          expect(result.warnings, [warning]);
        },
      );

      test('replace overwrites existing FIRE settings', () async {
        fireSettingsRepository.seed(existingSettings());

        final result = await serviceWithFire.importFromZip(
          backupWithFireSettings(),
          ImportStrategy.replace,
          baseCurrency: 'INR',
        );

        expect(result.fireSettingsImported, true);
        expect(fireSettingsRepository.settings!.monthlyExpenses, 30000.0);
        expect(fireSettingsRepository.settings!.currentAge, 25);
        expect(result.warnings, isEmpty);
      });

      test('handles missing FIRE settings gracefully', () async {
        final bytes = createZipArchive({
          'metadata.json': '{"version":"1.0","files":[]}',
        });

        final result = await serviceWithFire.importFromZip(
          bytes,
          ImportStrategy.merge,
          baseCurrency: 'INR',
        );

        expect(result.isSuccess, true);
        expect(result.fireSettingsImported, false);
        expect(fireSettingsRepository.settings, isNull);
      });

      test('handles invalid FIRE settings JSON with warning', () async {
        final bytes = createZipArchive({
          'metadata.json': '{"version":"1.0","files":[]}',
          'fire_settings.json': 'invalid json',
        });

        final result = await serviceWithFire.importFromZip(
          bytes,
          ImportStrategy.merge,
          baseCurrency: 'INR',
        );

        expect(result.isSuccess, true);
        expect(result.fireSettingsImported, false);
        expect(result.warnings, contains(contains('FIRE settings')));
      });

      test('does not import FIRE settings when repository is null', () async {
        final bytes = createZipArchive({
          'metadata.json': '{"version":"1.0","files":[]}',
          'fire_settings.json':
              '{"monthlyExpenses":50000,"currentAge":30,"targetFireAge":45}',
        });

        // Use the original service without FIRE repository
        final result = await service.importFromZip(
          bytes,
          ImportStrategy.merge,
          baseCurrency: 'INR',
        );

        expect(result.isSuccess, true);
        expect(result.fireSettingsImported, false);
      });
    });
  });
}

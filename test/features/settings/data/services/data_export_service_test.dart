import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../../investment/data/repositories/mock_investment_repository.dart';

class MockDocumentRepository extends Mock implements DocumentRepository {}
class MockDocumentStorageService extends Mock implements DocumentStorageService {}
class MockPerformanceService extends Mock implements PerformanceService {}

void main() {
  late FakeInvestmentRepository investmentRepository;
  late FakeGoalRepository goalRepository;
  late MockDocumentRepository documentRepository;
  late MockDocumentStorageService documentStorageService;
  late MockPerformanceService performanceService;
  late DataExportService service;
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

    // Mock performance service to just execute the operation
    when(() => performanceService.trackOperation<String>(
          any(),
          any(),
          metrics: any(named: 'metrics'),
          attributes: any(named: 'attributes'),
        )).thenAnswer((invocation) async {
      final operation = invocation.positionalArguments[1] as Future<String> Function();
      return await operation();
    });

    service = DataExportService(
      investmentRepository: investmentRepository,
      goalRepository: goalRepository,
      documentRepository: documentRepository,
      documentStorageService: documentStorageService,
      performanceService: performanceService,
    );

    // Default mock behavior
    when(
      () => documentStorageService.readDocument(any()),
    ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
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

  test(
    'exportAsZip sanitizes document filenames preventing path traversal',
    () async {
      // Arrange
      final investment = InvestmentEntity(
        id: 'inv-1',
        name: 'Test Investment',
        type: InvestmentType.other,
        status: InvestmentStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await investmentRepository.createInvestment(investment);

      final document = DocumentEntity(
        id: 'doc-1',
        investmentId: 'inv-1',
        name: 'Malicious Document',
        fileName: '../../evil.sh', // Path traversal payload
        type: DocumentType.other,
        mimeType: 'text/x-sh',
        localPath: '/local/path/evil.sh',
        fileSize: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(
        () => documentRepository.getDocumentsByInvestment('inv-1'),
      ).thenAnswer((_) async => [document]);

      // Act
      final zipPath = await service.exportAsZip();

      // Assert
      final zipFile = File(zipPath);
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Check for entries with path traversal
      final maliciousEntry = archive.files.firstWhere(
        (f) => f.name.contains('evil.sh'),
        orElse: () => throw Exception('Entry not found'),
      );

      // This assertion will FAIL if vulnerable
      expect(
        maliciousEntry.name,
        isNot(contains('../')),
        reason: 'ZIP entry should not contain path traversal characters',
      );
      // It should be normalized to documents/inv-1/evil.sh
      expect(maliciousEntry.name, endsWith('documents/inv-1/evil.sh'));
    },
  );
}

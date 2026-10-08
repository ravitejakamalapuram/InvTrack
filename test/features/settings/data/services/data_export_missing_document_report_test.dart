// A127: a document deleted from the device is one missing document, so an
// export reports it once, as a count, with no name or path. Before, the path
// check, the read and the export each logged it.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/crashlytics_recorder.dart';
import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../../investment/data/repositories/mock_investment_repository.dart';

class _MockDocumentRepository extends Mock implements DocumentRepository {}

class _PassThroughPerformanceService extends Fake
    implements PerformanceService {
  @override
  Future<T> trackOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    Map<String, int>? metrics,
    Map<String, String>? attributes,
  }) => operation();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory appDocs;

  setUp(() {
    appDocs = Directory.systemTemp.createTempSync('inv_tracker_export_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return appDocs.path;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      appDocs.deleteSync(recursive: true);
    });
  });

  test(
    'one missing document gives one report with a count and no path',
    () async {
      final records = recordCrashReports();
      final created = DateTime(2026, 4, 1);
      final investments = FakeInvestmentRepository();
      await investments.createInvestment(
        InvestmentEntity(
          id: 'inv-1',
          name: 'HDFC FD',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          createdAt: created,
          updatedAt: created,
          currency: 'INR',
        ),
      );
      // Exists in the investment's folder layout, but the file was deleted.
      final missingPath =
          '${appDocs.path}/documents/uid-abc123/inv-1/doc-1.pdf';
      final documents = _MockDocumentRepository();
      when(() => documents.getDocumentsByInvestment('inv-1')).thenAnswer(
        (_) async => [
          DocumentEntity(
            id: 'doc-1',
            investmentId: 'inv-1',
            name: 'Aadhaar - Ravi',
            fileName: 'Ravi Aadhaar.pdf',
            type: DocumentType.other,
            mimeType: 'application/pdf',
            localPath: missingPath,
            fileSize: 1024,
            createdAt: created,
            updatedAt: created,
          ),
        ],
      );

      await DataExportService(
        investmentRepository: investments,
        goalRepository: FakeGoalRepository(),
        documentRepository: documents,
        documentStorageService: DocumentStorageService(userId: 'uid-abc123'),
        performanceService: _PassThroughPerformanceService(),
      ).exportAsZipBytes();

      expect(records, hasLength(1));
      final report = records.single;
      expect(
        report.reason,
        'Documents missing from export | Metadata: documentsMissing=1',
      );
      final text = '${report.exception} ${report.reason}';
      for (final leaked in [
        missingPath,
        'uid-abc123',
        'doc-1.pdf',
        'Ravi',
        'Aadhaar',
      ]) {
        expect(text, isNot(contains(leaked)), reason: 'leaked "$leaked"');
      }
    },
  );
}

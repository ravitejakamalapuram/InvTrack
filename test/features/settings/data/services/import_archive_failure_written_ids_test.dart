// #1099: a restore whose archive step throws still reports the ids it wrote,
// so the US dollar check looks at them, and the result carries the failure.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../../investment/data/repositories/mock_investment_repository.dart';

class _MockDocumentRepository extends Mock implements DocumentRepository {}

class _MockDocumentStorageService extends Mock
    implements DocumentStorageService {}

class _PassThroughPerformanceService extends Mock
    implements PerformanceService {
  @override
  Future<T> trackOperation<T>(
    String traceName,
    Future<T> Function() operation, {
    Map<String, int>? metrics,
    Map<String, String>? attributes,
  }) => operation();
}

class _ArchiveFailsInvestments extends FakeInvestmentRepository {
  @override
  Future<void> archiveInvestment(String id) async =>
      throw StateError('archive failed');
}

class _ArchiveFailsGoals extends FakeGoalRepository {
  @override
  Future<void> archiveGoal(String id) async =>
      throw StateError('archive failed');
}

void main() {
  late _MockDocumentRepository documents;
  late _MockDocumentStorageService storage;
  late _PassThroughPerformanceService performance;
  final created = DateTime(2024, 3, 5);

  setUp(() {
    documents = _MockDocumentRepository();
    when(
      () => documents.getDocumentsByInvestment(any()),
    ).thenAnswer((_) async => []);
    storage = _MockDocumentStorageService();
    performance = _PassThroughPerformanceService();
  });

  Future<Uint8List> backup(
    FakeInvestmentRepository investments,
    FakeGoalRepository goals,
  ) async {
    final zip = await DataExportService(
      investmentRepository: investments,
      goalRepository: goals,
      documentRepository: documents,
      documentStorageService: storage,
      performanceService: performance,
    ).exportAsZipBytes();
    return Uint8List.fromList(zip.bytes);
  }

  Future<ZipImportResult> restore(
    Uint8List zip,
    FakeInvestmentRepository investments,
    FakeGoalRepository goals,
  ) => DataImportService(
    investmentRepository: investments,
    goalRepository: goals,
    documentRepository: documents,
    documentStorageService: storage,
    performanceService: performance,
  ).importFromZip(zip, ImportStrategy.replace, baseCurrency: 'INR');

  test(
    'an archived investment whose archive step fails is still reported',
    () async {
      final source = FakeInvestmentRepository();
      await source.createInvestment(
        InvestmentEntity(
          id: 'inv-1',
          name: 'Old FD',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          createdAt: created,
          updatedAt: created,
          currency: 'USD',
        ),
      );
      await source.addCashFlow(
        CashFlowEntity(
          id: 'cf-1',
          investmentId: 'inv-1',
          type: CashFlowType.invest,
          amount: 1000,
          currency: 'USD',
          date: created,
          createdAt: created,
        ),
      );
      await source.archiveInvestment('inv-1');
      final zip = await backup(source, FakeGoalRepository());

      final result = await restore(
        zip,
        _ArchiveFailsInvestments(),
        FakeGoalRepository(),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errors, isNotEmpty);
      expect(result.importedInvestmentIds, hasLength(1));
    },
  );

  test('an archived goal whose archive step fails is still reported', () async {
    final goals = FakeGoalRepository()
      ..seed(
        archivedGoals: [
          GoalEntity(
            id: 'goal-1',
            name: 'Old goal',
            type: GoalType.targetAmount,
            targetAmount: 5000,
            trackingMode: GoalTrackingMode.all,
            icon: 'x',
            colorValue: 1,
            isArchived: true,
            createdAt: created,
            updatedAt: created,
            currency: 'USD',
          ),
        ],
      );
    final zip = await backup(FakeInvestmentRepository(), goals);

    final result = await restore(
      zip,
      FakeInvestmentRepository(),
      _ArchiveFailsGoals(),
    );

    expect(result.isSuccess, isFalse);
    expect(result.errors, isNotEmpty);
    expect(result.importedGoalIds, hasLength(1));
  });
}

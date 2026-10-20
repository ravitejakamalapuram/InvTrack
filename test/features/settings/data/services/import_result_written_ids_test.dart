// A110: the import reports every investment it wrote, so the US dollar check
// can look at all of them, also same-name ones in the active and archived
// lists.
import 'dart:typed_data';

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

void main() {
  test('Replace reports the ids of a same-name active and '
      'archived investment', () async {
    final source = FakeInvestmentRepository();
    final documents = _MockDocumentRepository();
    when(
      () => documents.getDocumentsByInvestment(any()),
    ).thenAnswer((_) async => []);
    final storage = _MockDocumentStorageService();
    final performance = _PassThroughPerformanceService();
    final created = DateTime(2024, 3, 5);

    Future<void> add(String id) async {
      await source.createInvestment(
        InvestmentEntity(
          id: id,
          name: 'Same FD',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          createdAt: created,
          updatedAt: created,
          currency: 'USD',
        ),
      );
      await source.addCashFlow(
        CashFlowEntity(
          id: 'cf-$id',
          investmentId: id,
          type: CashFlowType.invest,
          amount: 1000,
          currency: 'USD',
          date: DateTime(2024, 3, 5),
          createdAt: created,
        ),
      );
    }

    await add('active');
    await add('archived');
    await source.archiveInvestment('archived');

    final zip = await DataExportService(
      investmentRepository: source,
      goalRepository: FakeGoalRepository(),
      documentRepository: documents,
      documentStorageService: storage,
      performanceService: performance,
    ).exportAsZipBytes();

    final target = FakeInvestmentRepository();
    final result =
        await DataImportService(
          investmentRepository: target,
          goalRepository: FakeGoalRepository(),
          documentRepository: documents,
          documentStorageService: storage,
          performanceService: performance,
        ).importFromZip(
          Uint8List.fromList(zip.bytes),
          ImportStrategy.replace,
          baseCurrency: 'INR',
        );

    expect(result.errors, isEmpty);
    final written = {
      for (final i in [...target.investments, ...target.archivedInvestments])
        i.id,
    };
    expect(written, hasLength(2));
    expect(result.importedInvestmentIds, written);
  });
}

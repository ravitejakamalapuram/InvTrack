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

/// A25 review: ZIP restore reads cashflows.csv with the bulk-import parser,
/// and Replace deletes everything before it parses. A row the app stored and
/// exported must come back, even when a bulk import would now reject it.
void main() {
  test('Replace restores a year-24 date, a stored "RS" code and a negative '
      'amount exactly as exported', () async {
    final repository = FakeInvestmentRepository();
    final documents = _MockDocumentRepository();
    when(
      () => documents.getDocumentsByInvestment(any()),
    ).thenAnswer((_) async => []);
    final storage = _MockDocumentStorageService();
    final performance = _PassThroughPerformanceService();
    final goals = FakeGoalRepository();

    final created = DateTime(2024, 3, 5);
    await repository.createInvestment(
      InvestmentEntity(
        id: 'fd',
        name: 'Old FD',
        type: InvestmentType.fixedDeposit,
        status: InvestmentStatus.open,
        createdAt: created,
        updatedAt: created,
        currency: 'INR',
      ),
    );
    // Stored by older versions: '5-Mar-24' read as the year 24, any currency
    // text upper-cased, and a negative bulk-imported amount.
    await repository.addCashFlow(
      CashFlowEntity(
        id: 'cf-1',
        investmentId: 'fd',
        type: CashFlowType.invest,
        amount: 5000,
        currency: 'RS',
        date: DateTime(24, 3, 5),
        createdAt: created,
      ),
    );
    await repository.addCashFlow(
      CashFlowEntity(
        id: 'cf-2',
        investmentId: 'fd',
        type: CashFlowType.income,
        amount: -20,
        currency: 'INR',
        date: DateTime(2024, 4, 5),
        createdAt: created,
      ),
    );

    final zip = await DataExportService(
      investmentRepository: repository,
      goalRepository: goals,
      documentRepository: documents,
      documentStorageService: storage,
      performanceService: performance,
    ).exportAsZipBytes();

    final result =
        await DataImportService(
          investmentRepository: repository,
          goalRepository: goals,
          documentRepository: documents,
          documentStorageService: storage,
          performanceService: performance,
        ).importFromZip(
          Uint8List.fromList(zip.bytes),
          ImportStrategy.replace,
          baseCurrency: 'INR',
        );

    expect(result.errors, isEmpty);
    final restored = [...repository.cashFlows]
      ..sort((a, b) => a.date.compareTo(b.date));
    expect(
      restored.map((cf) => (cf.date, cf.currency, cf.amount, cf.type)).toList(),
      [
        (DateTime(24, 3, 5), 'RS', 5000.0, CashFlowType.invest),
        (DateTime(2024, 4, 5), 'INR', -20.0, CashFlowType.income),
      ],
    );
  });
}

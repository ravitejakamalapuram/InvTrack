import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';
import 'package:inv_tracker/features/income_projection/domain/repositories/expected_cash_flow_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../../investment/data/repositories/mock_investment_repository.dart';

class _MockDocumentRepository extends Mock implements DocumentRepository {}

class _MockExpectedCashFlowRepository extends Mock
    implements ExpectedCashFlowRepository {}

class _FakeExpectedCashFlow extends Fake implements ExpectedCashFlowEntity {}

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

/// A05-F1 / auth-account-01: the export ZIP carries only name, type, status
/// and cash flows per investment, and no expected cash flows. A caller that
/// moves data with it (the guest merge) must be able to tell when something
/// was left out, instead of reporting a full move.
void main() {
  final created = DateTime(2026, 4, 1);
  final plain = InvestmentEntity(
    id: 'inv-plain',
    name: 'P2P loan',
    type: InvestmentType.p2pLending,
    status: InvestmentStatus.open,
    createdAt: created,
    updatedAt: created,
    currency: 'INR',
  );

  group('investmentHasDetailsNotInExport', () {
    test('is false for an investment the export carries in full', () {
      expect(investmentHasDetailsNotInExport(plain), isFalse);
      expect(
        investmentHasDetailsNotInExport(plain.copyWith(notes: '')),
        isFalse,
        reason: 'empty notes lose nothing',
      );
    });

    final withOneDetail = <String, InvestmentEntity>{
      'notes': plain.copyWith(notes: 'Joint with spouse'),
      'closedAt': plain.copyWith(closedAt: DateTime(2026, 9, 30)),
      'maturityDate': plain.copyWith(maturityDate: DateTime(2027, 4, 1)),
      'incomeFrequency': plain.copyWith(
        incomeFrequency: IncomeFrequency.quarterly,
      ),
      'startDate': plain.copyWith(startDate: DateTime(2026, 4, 1)),
      'expectedRate': plain.copyWith(expectedRate: 7.1),
      'tenureMonths': plain.copyWith(tenureMonths: 12),
      'platform': plain.copyWith(platform: 'SBI'),
      'interestPayoutMode': plain.copyWith(
        interestPayoutMode: InterestPayoutMode.periodic,
      ),
      'autoRenewal': plain.copyWith(autoRenewal: false),
      'riskLevel': plain.copyWith(riskLevel: RiskLevel.low),
      'compoundingFrequency': plain.copyWith(
        compoundingFrequency: CompoundingFrequency.quarterly,
      ),
    };
    for (final MapEntry(key: field, value: investment)
        in withOneDetail.entries) {
      test('is true when $field is set', () {
        expect(investmentHasDetailsNotInExport(investment), isTrue);
      });
    }
  });

  test('exportAsZipBytes counts the investments with details the ZIP cannot '
      'carry and the expected cash flows it leaves out', () async {
    final investments = FakeInvestmentRepository();
    final fd = plain.copyWith(
      id: 'inv-fd',
      name: 'SBI FD',
      type: InvestmentType.fixedDeposit,
      maturityDate: DateTime(2027, 4, 1),
      expectedRate: 7.1,
      incomeFrequency: IncomeFrequency.quarterly,
      notes: 'Branch: MG Road',
    );
    await investments.createInvestment(plain);
    await investments.createInvestment(fd);
    for (final inv in [plain, fd]) {
      await investments.addCashFlow(
        CashFlowEntity(
          id: 'cf-${inv.id}',
          investmentId: inv.id,
          type: CashFlowType.invest,
          amount: 100000,
          date: DateTime(2026, 4, 1),
          createdAt: created,
          currency: 'INR',
        ),
      );
    }
    final documents = _MockDocumentRepository();
    when(
      () => documents.getDocumentsByInvestment(any()),
    ).thenAnswer((_) async => []);
    final expected = _MockExpectedCashFlowRepository();
    when(() => expected.getAllExpectedCashFlows()).thenAnswer(
      (_) async => [
        _FakeExpectedCashFlow(),
        _FakeExpectedCashFlow(),
        _FakeExpectedCashFlow(),
      ],
    );

    final export = await DataExportService(
      investmentRepository: investments,
      goalRepository: FakeGoalRepository(),
      documentRepository: documents,
      documentStorageService: DocumentStorageService(userId: 'u'),
      expectedCashFlowRepository: expected,
      performanceService: _PassThroughPerformanceService(),
    ).exportAsZipBytes();

    expect(export.investments, 2);
    expect(export.cashFlows, 2);
    expect(export.investmentsWithDetailsNotInExport, 1);
    expect(export.expectedCashFlows, 3);
    expect(export.carriesEverything, isFalse);
  });
}

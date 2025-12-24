import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'mock_investment_repository.dart';

void main() {
  late FakeInvestmentRepository repository;

  setUp(() {
    repository = FakeInvestmentRepository();
  });

  tearDown(() {
    repository.reset();
  });

  group('FakeInvestmentRepository - Investments', () {
    final testInvestment = InvestmentEntity(
      id: 'inv-1',
      name: 'Test Investment',
      type: InvestmentType.p2pLending,
      status: InvestmentStatus.open,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

    test('createInvestment adds investment to repository', () async {
      await repository.createInvestment(testInvestment);

      expect(repository.investments, hasLength(1));
      expect(repository.investments.first.id, 'inv-1');
      expect(repository.investments.first.name, 'Test Investment');
    });

    test('getAllInvestments returns all investments', () async {
      await repository.createInvestment(testInvestment);
      await repository.createInvestment(testInvestment.copyWith(id: 'inv-2', name: 'Second'));

      final investments = await repository.getAllInvestments();

      expect(investments, hasLength(2));
    });

    test('getInvestmentById returns correct investment', () async {
      await repository.createInvestment(testInvestment);

      final result = await repository.getInvestmentById('inv-1');

      expect(result, isNotNull);
      expect(result!.name, 'Test Investment');
    });

    test('getInvestmentById returns null for non-existent id', () async {
      final result = await repository.getInvestmentById('non-existent');

      expect(result, isNull);
    });

    test('updateInvestment modifies existing investment', () async {
      await repository.createInvestment(testInvestment);
      final updated = testInvestment.copyWith(name: 'Updated Name');

      await repository.updateInvestment(updated);

      final result = await repository.getInvestmentById('inv-1');
      expect(result!.name, 'Updated Name');
    });

    test('closeInvestment changes status to closed', () async {
      await repository.createInvestment(testInvestment);

      await repository.closeInvestment('inv-1');

      final result = await repository.getInvestmentById('inv-1');
      expect(result!.status, InvestmentStatus.closed);
      expect(result.closedAt, isNotNull);
    });

    test('reopenInvestment changes status back to open', () async {
      await repository.createInvestment(testInvestment.copyWith(
        status: InvestmentStatus.closed,
        closedAt: DateTime.now(),
      ));

      await repository.reopenInvestment('inv-1');

      final result = await repository.getInvestmentById('inv-1');
      expect(result!.status, InvestmentStatus.open);
      expect(result.closedAt, isNull);
    });

    test('deleteInvestment removes investment and its cash flows', () async {
      await repository.createInvestment(testInvestment);
      await repository.addCashFlow(CashFlowEntity(
        id: 'cf-1',
        investmentId: 'inv-1',
        date: DateTime.now(),
        type: CashFlowType.invest,
        amount: 1000,
        createdAt: DateTime.now(),
      ));

      await repository.deleteInvestment('inv-1');

      expect(repository.investments, isEmpty);
      expect(repository.cashFlows, isEmpty);
    });

    test('watchAllInvestments emits investments stream', () async {
      await repository.createInvestment(testInvestment);

      final stream = repository.watchAllInvestments();

      expect(await stream.first, hasLength(1));
    });

    test('watchInvestmentsByStatus filters by status', () async {
      await repository.createInvestment(testInvestment);
      await repository.createInvestment(testInvestment.copyWith(
        id: 'inv-2',
        status: InvestmentStatus.closed,
      ));

      final openStream = repository.watchInvestmentsByStatus(InvestmentStatus.open);
      final closedStream = repository.watchInvestmentsByStatus(InvestmentStatus.closed);

      expect(await openStream.first, hasLength(1));
      expect(await closedStream.first, hasLength(1));
    });
  });

  group('FakeInvestmentRepository - Cash Flows', () {
    final testCashFlow = CashFlowEntity(
      id: 'cf-1',
      investmentId: 'inv-1',
      date: DateTime(2024, 1, 15),
      type: CashFlowType.invest,
      amount: 5000,
      createdAt: DateTime(2024, 1, 15),
    );

    test('addCashFlow adds cash flow to repository', () async {
      await repository.addCashFlow(testCashFlow);

      expect(repository.cashFlows, hasLength(1));
      expect(repository.cashFlows.first.amount, 5000);
    });

    test('getCashFlowsByInvestment returns filtered cash flows', () async {
      await repository.addCashFlow(testCashFlow);
      await repository.addCashFlow(testCashFlow.copyWith(
        id: 'cf-2',
        investmentId: 'inv-2',
      ));

      final result = await repository.getCashFlowsByInvestment('inv-1');

      expect(result, hasLength(1));
      expect(result.first.investmentId, 'inv-1');
    });

    test('updateCashFlow modifies existing cash flow', () async {
      await repository.addCashFlow(testCashFlow);
      final updated = testCashFlow.copyWith(amount: 10000);

      await repository.updateCashFlow(updated);

      final all = await repository.getAllCashFlows();
      expect(all.first.amount, 10000);
    });

    test('deleteCashFlow removes cash flow', () async {
      await repository.addCashFlow(testCashFlow);

      await repository.deleteCashFlow('cf-1');

      expect(repository.cashFlows, isEmpty);
    });
  });

  group('FakeInvestmentRepository - Bulk Operations', () {
    test('bulkImport adds multiple investments and cash flows', () async {
      final investments = [
        InvestmentEntity(
          id: 'inv-1',
          name: 'Investment 1',
          type: InvestmentType.p2pLending,
          status: InvestmentStatus.open,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
        InvestmentEntity(
          id: 'inv-2',
          name: 'Investment 2',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
      ];
      final cashFlows = [
        CashFlowEntity(
          id: 'cf-1',
          investmentId: 'inv-1',
          date: DateTime(2024, 1, 15),
          type: CashFlowType.invest,
          amount: 5000,
          createdAt: DateTime(2024, 1, 15),
        ),
        CashFlowEntity(
          id: 'cf-2',
          investmentId: 'inv-2',
          date: DateTime(2024, 1, 20),
          type: CashFlowType.invest,
          amount: 3000,
          createdAt: DateTime(2024, 1, 20),
        ),
      ];

      final result = await repository.bulkImport(
        investments: investments,
        cashFlows: cashFlows,
      );

      expect(result.investments, 2);
      expect(result.cashFlows, 2);
      expect(repository.investments, hasLength(2));
      expect(repository.cashFlows, hasLength(2));
    });

    test('bulkDelete removes multiple investments and their cash flows', () async {
      repository.seed(
        investments: [
          InvestmentEntity(
            id: 'inv-1',
            name: 'Investment 1',
            type: InvestmentType.p2pLending,
            status: InvestmentStatus.open,
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
          InvestmentEntity(
            id: 'inv-2',
            name: 'Investment 2',
            type: InvestmentType.stocks,
            status: InvestmentStatus.open,
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
          InvestmentEntity(
            id: 'inv-3',
            name: 'Investment 3',
            type: InvestmentType.realEstate,
            status: InvestmentStatus.open,
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ],
        cashFlows: [
          CashFlowEntity(
            id: 'cf-1',
            investmentId: 'inv-1',
            date: DateTime(2024, 1, 15),
            type: CashFlowType.invest,
            amount: 5000,
            createdAt: DateTime(2024, 1, 15),
          ),
          CashFlowEntity(
            id: 'cf-2',
            investmentId: 'inv-2',
            date: DateTime(2024, 1, 20),
            type: CashFlowType.invest,
            amount: 3000,
            createdAt: DateTime(2024, 1, 20),
          ),
        ],
      );

      final result = await repository.bulkDelete(['inv-1', 'inv-2']);

      expect(result, 2);
      expect(repository.investments, hasLength(1));
      expect(repository.investments.first.id, 'inv-3');
      expect(repository.cashFlows, isEmpty);
    });

    test('bulkDelete with empty list returns 0', () async {
      final result = await repository.bulkDelete([]);

      expect(result, 0);
    });
  });
}


import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/database/app_database.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

void main() {
  group('App Flow Integration Tests', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
    });

    tearDown(() async {
      await db.close();
      container.dispose();
    });

    test('Create Investment -> Add Cash Flow -> Verify Totals', () async {
      // 1. Add Investment
      final investmentRepo = container.read(investmentRepositoryProvider);
      final investment = InvestmentEntity(
        id: 'test-investment-1',
        name: 'P2P Lending',
        type: InvestmentType.p2pLending,
        status: InvestmentStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await investmentRepo.createInvestment(investment);

      // Verify investment created
      final investments = await investmentRepo.getAllInvestments();
      expect(investments.length, 1);
      expect(investments.first.name, 'P2P Lending');

      // 2. Add Cash Flow (Invest 1500)
      final cashFlow = CashFlowEntity(
        id: 'test-cashflow-1',
        investmentId: investment.id,
        type: CashFlowType.invest,
        amount: 1500.0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await investmentRepo.addCashFlow(cashFlow);

      // Verify cash flow created
      final cashFlows = await investmentRepo.getCashFlowsByInvestment(investment.id);
      expect(cashFlows.length, 1);
      expect(cashFlows.first.amount, 1500.0);
      expect(cashFlows.first.type, CashFlowType.invest);
    });

    test('Multiple cash flows calculate correct totals', () async {
      final investmentRepo = container.read(investmentRepositoryProvider);

      final investment = InvestmentEntity(
        id: 'test-investment-2',
        name: 'Real Estate Fund',
        type: InvestmentType.realEstate,
        status: InvestmentStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await investmentRepo.createInvestment(investment);

      // Add multiple cash flows
      await investmentRepo.addCashFlow(CashFlowEntity(
        id: 'cf-1',
        investmentId: investment.id,
        type: CashFlowType.invest,
        amount: 500.0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      ));

      await investmentRepo.addCashFlow(CashFlowEntity(
        id: 'cf-2',
        investmentId: investment.id,
        type: CashFlowType.invest,
        amount: 1200.0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      ));

      await investmentRepo.addCashFlow(CashFlowEntity(
        id: 'cf-3',
        investmentId: investment.id,
        type: CashFlowType.returnFlow,
        amount: 300.0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      ));

      // Verify cash flows
      final cashFlows = await investmentRepo.getCashFlowsByInvestment(investment.id);
      expect(cashFlows.length, 3);

      // Calculate total invested: 500 + 1200 = 1700
      final totalInvested = cashFlows
          .where((cf) => cf.type == CashFlowType.invest || cf.type == CashFlowType.fee)
          .fold<double>(0, (sum, cf) => sum + cf.amount);
      expect(totalInvested, 1700.0);

      // Calculate total returned: 300
      final totalReturned = cashFlows
          .where((cf) => cf.type == CashFlowType.returnFlow || cf.type == CashFlowType.income)
          .fold<double>(0, (sum, cf) => sum + cf.amount);
      expect(totalReturned, 300.0);
    });
  });
}

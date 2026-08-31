import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/reports/data/services/monthly_income_service.dart';

void main() {
  group('MonthlyIncomeService', () {
    late MonthlyIncomeService service;
    late DateTime monthPeriod;

    setUp(() {
      service = MonthlyIncomeService();
      monthPeriod = DateTime(2024, 1, 15); // January 2024
    });

    test('should calculate total income for the month', () {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 500,
          date: DateTime(2024, 1, 10),
          type: CashFlowType.income,
          notes: 'Dividend',
          currency: 'USD',
          createdAt: DateTime(2024, 1, 10),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv2',
          amount: 1000,
          date: DateTime(2024, 1, 20),
          type: CashFlowType.income,
          notes: 'Interest',
          currency: 'USD',
          createdAt: DateTime(2024, 1, 20),
        ),
      ];

      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Stock A',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv2',
          name: 'FD B',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
      ];

      final report = service.generateReport(
        period: monthPeriod,
        allCashFlows: cashFlows,
        allInvestments: investments,
      );

      expect(report.totalIncome, 1500.0);
      expect(report.incomeByType['Dividend'], 500.0);
      expect(report.incomeByType['Interest'], 1000.0);
    });

    test('should calculate all cashflow types', () {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 10000,
          date: DateTime(2024, 1, 5),
          type: CashFlowType.invest,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 5),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          amount: 500,
          date: DateTime(2024, 1, 10),
          type: CashFlowType.income,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 10),
        ),
        CashFlowEntity(
          id: '3',
          investmentId: 'inv1',
          amount: 11000,
          date: DateTime(2024, 1, 15),
          type: CashFlowType.returnFlow,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 15),
        ),
        CashFlowEntity(
          id: '4',
          investmentId: 'inv1',
          amount: 100,
          date: DateTime(2024, 1, 20),
          type: CashFlowType.fee,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 20),
        ),
      ];

      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Test Investment',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
      ];

      final report = service.generateReport(
        period: monthPeriod,
        allCashFlows: cashFlows,
        allInvestments: investments,
      );

      expect(report.totalInvested, 10000.0);
      expect(report.totalReturns, 11000.0);
      expect(report.totalIncome, 500.0);
      expect(report.totalFees, 100.0);
      // Net = (income + returns) - (invested + fees)
      expect(report.netCashFlow, 1400.0); // (500 + 11000) - (10000 + 100)
    });

    test('should group income by type', () {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 500,
          date: DateTime(2024, 1, 5),
          type: CashFlowType.income,
          notes: 'Dividend',
          currency: 'USD',
          createdAt: DateTime(2024, 1, 5),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv2',
          amount: 300,
          date: DateTime(2024, 1, 10),
          type: CashFlowType.income,
          notes: 'Dividend',
          currency: 'USD',
          createdAt: DateTime(2024, 1, 10),
        ),
        CashFlowEntity(
          id: '3',
          investmentId: 'inv3',
          amount: 200,
          date: DateTime(2024, 1, 15),
          type: CashFlowType.income,
          notes: 'Rent',
          currency: 'USD',
          createdAt: DateTime(2024, 1, 15),
        ),
      ];

      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Stock A',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv2',
          name: 'FD B',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv3',
          name: 'Property C',
          type: InvestmentType.realEstate,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
      ];

      final report = service.generateReport(
        period: monthPeriod,
        allCashFlows: cashFlows,
        allInvestments: investments,
      );

      expect(report.totalIncome, 1000.0);
      expect(report.incomeByType['Dividend'], 800.0); // 500 + 300
      expect(report.incomeByType['Rent'], 200.0);
    });

    test('should identify top income earners', () {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 500,
          date: DateTime(2024, 1, 5),
          type: CashFlowType.income,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 5),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          amount: 300,
          date: DateTime(2024, 1, 10),
          type: CashFlowType.income,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 10),
        ),
        CashFlowEntity(
          id: '3',
          investmentId: 'inv2',
          amount: 1000,
          date: DateTime(2024, 1, 15),
          type: CashFlowType.income,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 15),
        ),
      ];

      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Stock A',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
        InvestmentEntity(
          id: 'inv2',
          name: 'FD B',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          startDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
      ];

      final report = service.generateReport(
        period: monthPeriod,
        allCashFlows: cashFlows,
        allInvestments: investments,
      );

      expect(report.topEarners.length, 2);
      expect(report.topEarners.first.investment.id, 'inv2'); // Top earner (1000)
      expect(report.topEarners.first.income, 1000.0);
      expect(report.topEarners[1].investment.id, 'inv1'); // Second (800)
      expect(report.topEarners[1].income, 800.0);
    });

    test('should filter out transactions from other months', () {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          amount: 500,
          date: DateTime(2023, 12, 31), // Previous month
          type: CashFlowType.income,
          currency: 'USD',
          createdAt: DateTime(2023, 12, 31),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          amount: 1000,
          date: DateTime(2024, 1, 15), // Current month
          type: CashFlowType.income,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 15),
        ),
        CashFlowEntity(
          id: '3',
          investmentId: 'inv1',
          amount: 200,
          date: DateTime(2024, 2, 2), // Next month (outside filter range)
          type: CashFlowType.income,
          currency: 'USD',
          createdAt: DateTime(2024, 2, 2),
        ),
      ];

      final investments = [
        InvestmentEntity(
          id: 'inv1',
          name: 'Test Investment',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
          currency: 'USD',
        ),
      ];

      final report = service.generateReport(
        period: monthPeriod,
        allCashFlows: cashFlows,
        allInvestments: investments,
      );

      expect(report.totalIncome, 1000.0); // Only Jan 15 transaction
    });

    test('should handle empty data', () {
      final report = service.generateReport(
        period: monthPeriod,
        allCashFlows: [],
        allInvestments: [],
      );

      expect(report.totalIncome, 0.0);
      expect(report.totalInvested, 0.0);
      expect(report.totalReturns, 0.0);
      expect(report.totalFees, 0.0);
      expect(report.netCashFlow, 0.0);
      expect(report.topEarners, isEmpty);
      expect(report.incomeByType, isEmpty);
    });
  });
}


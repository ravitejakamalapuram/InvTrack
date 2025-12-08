import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

void main() {
  group('InvestmentEntity', () {
    test('creates investment with correct properties', () {
      final investment = InvestmentEntity(
        id: '1',
        name: 'P2P Lending Investment',
        type: InvestmentType.p2pLending,
        status: InvestmentStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(investment.id, '1');
      expect(investment.name, 'P2P Lending Investment');
      expect(investment.type, InvestmentType.p2pLending);
      expect(investment.status, InvestmentStatus.open);
    });

    test('investment type has correct display name', () {
      expect(InvestmentType.p2pLending.displayName, 'P2P Lending');
      expect(InvestmentType.realEstate.displayName, 'Real Estate');
      expect(InvestmentType.privateEquity.displayName, 'Private Equity');
    });

    test('investment status has correct display name', () {
      expect(InvestmentStatus.open.displayName, 'Open');
      expect(InvestmentStatus.closed.displayName, 'Closed');
    });
  });

  group('CashFlowEntity', () {
    test('creates cash flow with correct properties', () {
      final cashFlow = CashFlowEntity(
        id: 'cf1',
        investmentId: '1',
        date: DateTime.now(),
        type: CashFlowType.invest,
        amount: 1000,
        createdAt: DateTime.now(),
      );

      expect(cashFlow.id, 'cf1');
      expect(cashFlow.investmentId, '1');
      expect(cashFlow.type, CashFlowType.invest);
      expect(cashFlow.amount, 1000);
    });

    test('cash flow type has correct display name', () {
      expect(CashFlowType.invest.displayName, 'Invest');
      expect(CashFlowType.returnFlow.displayName, 'Return');
      expect(CashFlowType.income.displayName, 'Income');
      expect(CashFlowType.fee.displayName, 'Fee');
    });

    test('cash flow type correctly identifies inflow/outflow', () {
      expect(CashFlowType.invest.isOutflow, true);
      expect(CashFlowType.invest.isInflow, false);
      expect(CashFlowType.fee.isOutflow, true);
      expect(CashFlowType.returnFlow.isInflow, true);
      expect(CashFlowType.income.isInflow, true);
    });
  });
}

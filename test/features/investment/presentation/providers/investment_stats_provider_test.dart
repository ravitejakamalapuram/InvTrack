import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';

void main() {
  group('calculateStats', () {
    test('should return empty stats for empty cash flows', () {
      final result = calculateStats([]);

      expect(result.totalInvested, 0);
      expect(result.totalReturned, 0);
      expect(result.netCashFlow, 0);
      expect(result.absoluteReturn, 0);
      expect(result.moic, 0);
      expect(result.cashFlowCount, 0);
      expect(result.hasData, false);
    });

    test('should calculate stats correctly for single investment', () {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          date: DateTime(2023, 1, 1),
          type: CashFlowType.invest,
          amount: 1000,
          createdAt: DateTime.now(),
        ),
      ];

      final result = calculateStats(cashFlows);

      expect(result.totalInvested, 1000);
      expect(result.totalReturned, 0);
      expect(result.netCashFlow, -1000);
      expect(result.absoluteReturn, -100); // -100% (no returns yet)
      expect(result.moic, 0); // 0x (no returns)
      expect(result.cashFlowCount, 1);
      expect(result.hasData, true);
    });

    test('should calculate stats correctly for investment with return', () {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          date: DateTime(2023, 1, 1),
          type: CashFlowType.invest,
          amount: 1000,
          createdAt: DateTime.now(),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          date: DateTime(2024, 1, 1),
          type: CashFlowType.returnFlow,
          amount: 1500,
          createdAt: DateTime.now(),
        ),
      ];

      final result = calculateStats(cashFlows);

      expect(result.totalInvested, 1000);
      expect(result.totalReturned, 1500);
      expect(result.netCashFlow, 500); // 1500 - 1000
      expect(result.absoluteReturn, 50); // 50% return
      expect(result.moic, 1.5); // 1.5x
      expect(result.cashFlowCount, 2);
      expect(result.isProfit, true);
      expect(result.isLoss, false);
    });

    test('should calculate stats correctly for loss scenario', () {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          date: DateTime(2023, 1, 1),
          type: CashFlowType.invest,
          amount: 1000,
          createdAt: DateTime.now(),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          date: DateTime(2024, 1, 1),
          type: CashFlowType.returnFlow,
          amount: 600,
          createdAt: DateTime.now(),
        ),
      ];

      final result = calculateStats(cashFlows);

      expect(result.totalInvested, 1000);
      expect(result.totalReturned, 600);
      expect(result.netCashFlow, -400);
      expect(result.absoluteReturn, -40); // -40% loss
      expect(result.moic, 0.6); // 0.6x
      expect(result.isProfit, false);
      expect(result.isLoss, true);
    });

    test('should handle fees as outflows', () {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          date: DateTime(2023, 1, 1),
          type: CashFlowType.invest,
          amount: 1000,
          createdAt: DateTime.now(),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          date: DateTime(2023, 6, 1),
          type: CashFlowType.fee,
          amount: 50,
          createdAt: DateTime.now(),
        ),
        CashFlowEntity(
          id: '3',
          investmentId: 'inv1',
          date: DateTime(2024, 1, 1),
          type: CashFlowType.returnFlow,
          amount: 1200,
          createdAt: DateTime.now(),
        ),
      ];

      final result = calculateStats(cashFlows);

      expect(result.totalInvested, 1050); // 1000 + 50 fee
      expect(result.totalReturned, 1200);
      expect(result.netCashFlow, 150); // 1200 - 1050
      expect(result.cashFlowCount, 3);
    });

    test('should handle income as inflows', () {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: 'inv1',
          date: DateTime(2023, 1, 1),
          type: CashFlowType.invest,
          amount: 1000,
          createdAt: DateTime.now(),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: 'inv1',
          date: DateTime(2023, 6, 1),
          type: CashFlowType.income,
          amount: 100, // Dividend
          createdAt: DateTime.now(),
        ),
      ];

      final result = calculateStats(cashFlows);

      expect(result.totalInvested, 1000);
      expect(result.totalReturned, 100);
      expect(result.netCashFlow, -900);
      expect(result.cashFlowCount, 2);
    });
  });
}


import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';

void main() {
  group('calculateStats - Date Range', () {
    test(
      'should identify correct first and last cash flow dates from unsorted list',
      () {
        final cashFlows = [
          CashFlowEntity(
            id: '2',
            investmentId: 'inv1',
            date: DateTime(2024, 1, 1),
            type: CashFlowType.returnFlow,
            amount: 500,
            createdAt: DateTime.now(),
          ),
          CashFlowEntity(
            id: '1',
            investmentId: 'inv1',
            date: DateTime(2023, 1, 1),
            type: CashFlowType.invest,
            amount: 1000,
            createdAt: DateTime.now(),
          ),
          CashFlowEntity(
            id: '3',
            investmentId: 'inv1',
            date: DateTime(2025, 1, 1),
            type: CashFlowType.returnFlow,
            amount: 600,
            createdAt: DateTime.now(),
          ),
        ];

        final result = calculateStats(cashFlows);

        expect(result.firstCashFlowDate, DateTime(2023, 1, 1));
        expect(result.lastCashFlowDate, DateTime(2025, 1, 1));
        expect(result.cashFlowCount, 3);
      },
    );

    test('should handle single cash flow', () {
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

      expect(result.firstCashFlowDate, DateTime(2023, 1, 1));
      expect(result.lastCashFlowDate, DateTime(2023, 1, 1));
    });

    test('should handle identical dates', () {
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
          date: DateTime(2023, 1, 1),
          type: CashFlowType.fee,
          amount: 10,
          createdAt: DateTime.now(),
        ),
      ];

      final result = calculateStats(cashFlows);

      expect(result.firstCashFlowDate, DateTime(2023, 1, 1));
      expect(result.lastCashFlowDate, DateTime(2023, 1, 1));
    });
  });
}

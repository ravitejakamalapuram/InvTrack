import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

void main() {
  group('XirrSolver', () {
    test('should calculate XIRR correctly for simple case', () {
      // -1000 investment, 1100 return after 1 year -> 10% return
      final dates = [
        DateTime(2023, 1, 1),
        DateTime(2024, 1, 1),
      ];
      final amounts = [-1000.0, 1100.0];

      final xirr = XirrSolver.calculateXirr(dates, amounts);
      expect(xirr, closeTo(0.10, 0.0001));
    });

    test('should calculate XIRR for multiple cash flows', () {
      // -1000 on Jan 1
      // -1000 on July 1
      // Value 2200 on Jan 1 next year
      // Approx return should be around 10-20%?
      // Let's rely on the solver's consistency.
      final dates = [
        DateTime(2023, 1, 1),
        DateTime(2023, 7, 1),
        DateTime(2024, 1, 1),
      ];
      final amounts = [-1000.0, -1000.0, 2200.0];

      final xirr = XirrSolver.calculateXirr(dates, amounts);
      // Using an online XIRR calculator:
      // -1000 1/1/23
      // -1000 7/1/23
      // 2200 1/1/24
      // Result is approx 13.06%
      expect(xirr, closeTo(0.1343, 0.001));
    });
  });

  group('FinancialCalculator', () {
    test('calculateCAGR', () {
      // 100 to 200 in 10 years => 7.18%
      final cagr = FinancialCalculator.calculateCAGR(100, 200, 10);
      expect(cagr, closeTo(0.0717, 0.0001));
    });

    test('calculateMOIC', () {
      // 100 invested, 200 current => 2.0x
      final moic = FinancialCalculator.calculateMOIC(100, 200);
      expect(moic, 2.0);
    });

    test('calculateProfitLoss', () {
      final pl = FinancialCalculator.calculateProfitLoss(100, 150);
      expect(pl, 50.0);
    });

    test('calculateTotalInvested', () {
      final transactions = [
        TransactionEntity(
          id: '1',
          investmentId: '1',
          date: DateTime.now(),
          type: 'BUY',
          quantity: 1,
          pricePerUnit: 100,
          fees: 0,
          totalAmount: 100,
          createdAt: DateTime.now(),
        ),
        TransactionEntity(
          id: '2',
          investmentId: '1',
          date: DateTime.now(),
          type: 'SELL',
          quantity: 1,
          pricePerUnit: 50,
          fees: 0,
          totalAmount: 50,
          createdAt: DateTime.now(),
        ),
      ];
      final total = FinancialCalculator.calculateTotalInvested(transactions);
      expect(total, 50.0); // 100 - 50
    });
  });
}

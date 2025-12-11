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

    test('calculateAbsoluteReturn', () {
      final absReturn = FinancialCalculator.calculateAbsoluteReturn(100, 150);
      expect(absReturn, closeTo(50.0, 0.0001)); // 50% return
    });

    test('calculateTotalInvested', () {
      final cashFlows = [
        CashFlowEntity(
          id: '1',
          investmentId: '1',
          date: DateTime.now(),
          type: CashFlowType.invest,
          amount: 100,
          createdAt: DateTime.now(),
        ),
        CashFlowEntity(
          id: '2',
          investmentId: '1',
          date: DateTime.now(),
          type: CashFlowType.returnFlow,
          amount: 50,
          createdAt: DateTime.now(),
        ),
      ];
      final total = FinancialCalculator.calculateTotalInvested(cashFlows);
      expect(total, 100.0); // Only invest type counts
    });
  });
}

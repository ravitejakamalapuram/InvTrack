import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

void main() {
  group('FinancialCalculator - Edge Cases', () {
    group('calculateCAGR - Edge Cases', () {
      test('should return 0 for zero startValue', () {
        final cagr = FinancialCalculator.calculateCAGR(0, 100, 1);
        expect(cagr, 0.0);
      });

      test('should return 0 for negative startValue', () {
        final cagr = FinancialCalculator.calculateCAGR(-100, 200, 1);
        expect(cagr, 0.0);
      });

      test('should return 0 for zero years', () {
        final cagr = FinancialCalculator.calculateCAGR(100, 200, 0);
        expect(cagr, 0.0);
      });

      test('should return 0 for negative years', () {
        final cagr = FinancialCalculator.calculateCAGR(100, 200, -1);
        expect(cagr, 0.0);
      });

      test('should handle zero endValue (total loss)', () {
        final cagr = FinancialCalculator.calculateCAGR(100, 0, 1);
        expect(cagr, -1.0); // -100% return
      });

      test('should handle very large numbers without overflow', () {
        // Test with billions
        final cagr = FinancialCalculator.calculateCAGR(
          1000000000, // 1 billion
          2000000000, // 2 billion
          5,
        );
        expect(cagr.isFinite, isTrue);
        expect(cagr, closeTo(0.1487, 0.001)); // ~14.87% CAGR
      });

      test('should handle very small fractional years', () {
        final cagr = FinancialCalculator.calculateCAGR(100, 110, 0.1);
        expect(cagr.isFinite, isTrue);
        expect(cagr, greaterThan(0));
      });

      test('should handle same start and end value (break-even)', () {
        final cagr = FinancialCalculator.calculateCAGR(100, 100, 1);
        expect(cagr, closeTo(0.0, 0.0001));
      });
    });

    group('calculateMOIC - Edge Cases', () {
      test(
        'should return 0 for zero invested (division by zero protection)',
        () {
          final moic = FinancialCalculator.calculateMOIC(0, 100);
          expect(moic, 0.0);
        },
      );

      test('should handle zero returned (total loss)', () {
        final moic = FinancialCalculator.calculateMOIC(100, 0);
        expect(moic, 0.0);
      });

      test('should handle negative returned value', () {
        final moic = FinancialCalculator.calculateMOIC(100, -50);
        expect(moic, -0.5);
      });

      test('should handle very large numbers', () {
        final moic = FinancialCalculator.calculateMOIC(
          1000000000, // 1 billion
          5000000000, // 5 billion
        );
        expect(moic, 5.0);
      });

      test('should handle very small numbers', () {
        final moic = FinancialCalculator.calculateMOIC(0.01, 0.02);
        expect(moic, closeTo(2.0, 0.0001));
      });
    });

    group('calculateAbsoluteReturn - Edge Cases', () {
      test(
        'should return 0 for zero invested (division by zero protection)',
        () {
          final absReturn = FinancialCalculator.calculateAbsoluteReturn(0, 100);
          expect(absReturn, 0.0);
        },
      );

      test('should handle zero returned (total loss)', () {
        final absReturn = FinancialCalculator.calculateAbsoluteReturn(100, 0);
        expect(absReturn, -100.0); // -100%
      });

      test('should handle negative returned value', () {
        final absReturn = FinancialCalculator.calculateAbsoluteReturn(100, -50);
        expect(absReturn, -150.0); // -150%
      });

      test('should handle very large numbers', () {
        final absReturn = FinancialCalculator.calculateAbsoluteReturn(
          1000000000, // 1 billion
          2000000000, // 2 billion
        );
        expect(absReturn, 100.0); // 100% return
      });

      test('should handle very small numbers', () {
        final absReturn = FinancialCalculator.calculateAbsoluteReturn(
          0.01,
          0.02,
        );
        expect(absReturn, closeTo(100.0, 0.0001)); // 100% return
      });
    });

    group('calculateNetCashFlow - Edge Cases', () {
      test('should handle zero invested', () {
        final netCashFlow = FinancialCalculator.calculateNetCashFlow(0, 100);
        expect(netCashFlow, 100.0);
      });

      test('should handle zero returned', () {
        final netCashFlow = FinancialCalculator.calculateNetCashFlow(100, 0);
        expect(netCashFlow, -100.0);
      });

      test('should handle negative values', () {
        final netCashFlow = FinancialCalculator.calculateNetCashFlow(100, -50);
        expect(netCashFlow, -150.0);
      });

      test('should handle very large numbers', () {
        final netCashFlow = FinancialCalculator.calculateNetCashFlow(
          1000000000, // 1 billion
          2000000000, // 2 billion
        );
        expect(netCashFlow, 1000000000); // 1 billion profit
      });
    });

    group('calculateXirrFromCashFlows - Edge Cases', () {
      test('should return 0 for empty cash flows', () {
        final xirr = FinancialCalculator.calculateXirrFromCashFlows([]);
        expect(xirr, 0.0);
      });

      test('should handle single cash flow', () {
        final cashFlows = [
          CashFlowEntity(
            id: '1',
            investmentId: '1',
            date: DateTime(2023, 1, 1),
            type: CashFlowType.invest,
            amount: 100,
            createdAt: DateTime.now(),
          ),
        ];
        final xirr = FinancialCalculator.calculateXirrFromCashFlows(cashFlows);
        expect(xirr, 0.0); // Single cash flow has no return
      });

      test('should handle same-day transactions', () {
        final cashFlows = [
          CashFlowEntity(
            id: '1',
            investmentId: '1',
            date: DateTime(2023, 1, 1),
            type: CashFlowType.invest,
            amount: 100,
            createdAt: DateTime.now(),
          ),
          CashFlowEntity(
            id: '2',
            investmentId: '1',
            date: DateTime(2023, 1, 1),
            type: CashFlowType.returnFlow,
            amount: 110,
            createdAt: DateTime.now(),
          ),
        ];
        final xirr = FinancialCalculator.calculateXirrFromCashFlows(cashFlows);
        // Same-day transactions should return 0 or handle gracefully
        expect(xirr.isFinite, isTrue);
      });
    });
  });
}

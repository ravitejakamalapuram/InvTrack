import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';

void main() {
  group('XirrSolver', () {
    group('calculateXirr - Basic Scenarios', () {
      test('should calculate correct XIRR for simple 1-year investment with 10% return', () {
        // Scenario: Invest ₹1,00,000 on Jan 1, 2023
        //           Get back ₹1,10,000 on Jan 1, 2024 (exactly 1 year)
        //           Expected: 10% annual return
        final dates = [
          DateTime(2023, 1, 1),
          DateTime(2024, 1, 1),
        ];
        final amounts = [-100000.0, 110000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        // Should be approximately 10% (0.10)
        expect(xirr, isNotNull);
        expect(xirr, closeTo(0.10, 0.01)); // Within 1% tolerance
      });

      test('should calculate correct XIRR for 2-year investment with 50% return', () {
        // Scenario: Invest ₹1,00,000 on Jan 1, 2023
        //           Get back ₹1,50,000 on Jan 1, 2025 (2 years)
        //           Expected: ~22.47% annual return (CAGR)
        final dates = [
          DateTime(2023, 1, 1),
          DateTime(2025, 1, 1),
        ];
        final amounts = [-100000.0, 150000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        // CAGR = (1.50)^(1/2) - 1 = 0.2247 = 22.47%
        expect(xirr, isNotNull);
        expect(xirr, closeTo(0.2247, 0.01));
      });

      test('should calculate correct XIRR for 6-month investment with 5% return', () {
        // Scenario: Invest ₹1,00,000 on Jan 1, 2024
        //           Get back ₹1,05,000 on July 1, 2024 (6 months)
        //           Expected: ~10.25% annualized return
        final dates = [
          DateTime(2024, 1, 1),
          DateTime(2024, 7, 1),
        ];
        final amounts = [-100000.0, 105000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        // CAGR = (1.05)^(1/0.5) - 1 = (1.05)^2 - 1 = 0.1025 = 10.25%
        expect(xirr, isNotNull);
        expect(xirr, closeTo(0.1025, 0.01));
      });

      test('should calculate correct XIRR for 3-month investment with 2% return', () {
        // Scenario: Invest ₹1,00,000 on Jan 1, 2024
        //           Get back ₹1,02,000 on April 1, 2024 (3 months)
        //           Expected: ~8.24% annualized return
        final dates = [
          DateTime(2024, 1, 1),
          DateTime(2024, 4, 1),
        ];
        final amounts = [-100000.0, 102000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        // CAGR = (1.02)^(1/0.25) - 1 = (1.02)^4 - 1 = 0.0824 = 8.24%
        expect(xirr, isNotNull);
        expect(xirr, closeTo(0.0824, 0.01));
      });

      test('should calculate correct XIRR for 5-year investment with 100% return', () {
        // Scenario: Invest ₹1,00,000 on Jan 1, 2020
        //           Get back ₹2,00,000 on Jan 1, 2025 (5 years)
        //           Expected: ~14.87% annual return
        final dates = [
          DateTime(2020, 1, 1),
          DateTime(2025, 1, 1),
        ];
        final amounts = [-100000.0, 200000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        // CAGR = (2.00)^(1/5) - 1 = 0.1487 = 14.87%
        expect(xirr, isNotNull);
        expect(xirr, closeTo(0.1487, 0.01));
      });
    });

    group('calculateXirr - Multiple Cash Flows (SIP)', () {
      test('should calculate correct XIRR for monthly SIP with positive returns', () {
        // Scenario: Monthly SIP of ₹10,000 for 12 months
        //           Final value: ₹1,30,000 (invested ₹1,20,000)
        //           Expected: Positive XIRR
        final dates = <DateTime>[];
        final amounts = <double>[];

        // 12 monthly investments
        for (int i = 0; i < 12; i++) {
          dates.add(DateTime(2023, 1 + i, 1));
          amounts.add(-10000.0);
        }

        // Final redemption
        dates.add(DateTime(2024, 1, 1));
        amounts.add(130000.0);

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, greaterThan(0)); // Should be positive
        expect(xirr, lessThan(0.5)); // Should be reasonable (<50%)
      });

      test('should calculate correct XIRR for quarterly investments', () {
        // Scenario: Quarterly investments of ₹25,000 for 1 year
        //           Final value: ₹1,10,000 (invested ₹1,00,000)
        final dates = [
          DateTime(2023, 1, 1),
          DateTime(2023, 4, 1),
          DateTime(2023, 7, 1),
          DateTime(2023, 10, 1),
          DateTime(2024, 1, 1),
        ];
        final amounts = [-25000.0, -25000.0, -25000.0, -25000.0, 110000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, greaterThan(0)); // Positive return
      });
    });

    group('calculateXirr - Edge Cases', () {
      test('should handle single cash flow (return null or zero)', () {
        final dates = [DateTime(2023, 1, 1)];
        final amounts = [-100000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        // Single cash flow has no return
        expect(xirr, anyOf(isNull, equals(0.0)));
      });

      test('should handle all outflows (no returns yet)', () {
        final dates = [
          DateTime(2023, 1, 1),
          DateTime(2023, 2, 1),
          DateTime(2023, 3, 1),
        ];
        final amounts = [-10000.0, -10000.0, -10000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        // All outflows, no inflows - should return null or handle gracefully
        expect(xirr, anyOf(isNull, lessThan(0)));
      });

      test('should handle all inflows (no investments)', () {
        final dates = [
          DateTime(2023, 1, 1),
          DateTime(2023, 2, 1),
        ];
        final amounts = [10000.0, 10000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        // All inflows, no outflows - should return null
        expect(xirr, isNull);
      });

      test('should handle zero return (break-even)', () {
        // Invest ₹1,00,000, get back ₹1,00,000
        final dates = [
          DateTime(2023, 1, 1),
          DateTime(2024, 1, 1),
        ];
        final amounts = [-100000.0, 100000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, closeTo(0.0, 0.01)); // Should be ~0%
      });

      test('should handle negative return (loss)', () {
        // Invest ₹1,00,000, get back ₹90,000 (10% loss)
        final dates = [
          DateTime(2023, 1, 1),
          DateTime(2024, 1, 1),
        ];
        final amounts = [-100000.0, 90000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, closeTo(-0.10, 0.01)); // Should be ~-10%
      });

      test('should handle total loss', () {
        // Invest ₹1,00,000, get back ₹0 (100% loss)
        final dates = [
          DateTime(2023, 1, 1),
          DateTime(2024, 1, 1),
        ];
        final amounts = [-100000.0, 0.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, closeTo(-1.0, 0.01)); // Should be ~-100%
      });
    });
  });

    group('calculateXirr - Approximation Formula Tests (Bug Fix Verification)', () {
      // These tests specifically verify the fix for the XIRR approximation formula
      // The bug was: using days instead of years in the CAGR formula

      test('REGRESSION TEST: 1-year investment should show 10% not 0.0267%', () {
        // This is the exact example from the bug report
        // Before fix: Would show 0.0267% (375x too small)
        // After fix: Should show 10%

        final dates = [
          DateTime(2023, 1, 1),
          DateTime(2024, 1, 1),
        ];
        final amounts = [-100000.0, 110000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        // The key assertion: should be 10%, NOT 0.0267%
        expect(xirr, greaterThan(0.05)); // At least 5%
        expect(xirr, closeTo(0.10, 0.02)); // Close to 10%

        // Verify it's NOT the buggy value
        expect(xirr, isNot(closeTo(0.000267, 0.0001)));
      });

      test('REGRESSION TEST: 2-year investment should show 22.47% not 0.0558%', () {
        // Before fix: Would show 0.0558% (402x too small)
        // After fix: Should show 22.47%

        final dates = [
          DateTime(2023, 1, 1),
          DateTime(2025, 1, 1),
        ];
        final amounts = [-100000.0, 150000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        // Should be ~22.47%, NOT 0.0558%
        expect(xirr, greaterThan(0.15)); // At least 15%
        expect(xirr, closeTo(0.2247, 0.02)); // Close to 22.47%

        // Verify it's NOT the buggy value
        expect(xirr, isNot(closeTo(0.000558, 0.0001)));
      });

      test('REGRESSION TEST: 6-month investment should show 10.25% not 0.0268%', () {
        // Before fix: Would show 0.0268%
        // After fix: Should show 10.25%

        final dates = [
          DateTime(2024, 1, 1),
          DateTime(2024, 7, 1),
        ];
        final amounts = [-100000.0, 105000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        // Should be ~10.25%, NOT 0.0268%
        expect(xirr, greaterThan(0.05)); // At least 5%
        expect(xirr, closeTo(0.1025, 0.02)); // Close to 10.25%

        // Verify it's NOT the buggy value
        expect(xirr, isNot(closeTo(0.000268, 0.0001)));
      });

      test('REGRESSION TEST: Very short period (30 days) should annualize correctly', () {
        // 1% return in 30 days should annualize to ~12.68% per year
        // Before fix: Would show 0.0003% (42,000x too small!)
        // After fix: Should show ~12.68%

        final dates = [
          DateTime(2024, 1, 1),
          DateTime(2024, 1, 31),
        ];
        final amounts = [-100000.0, 101000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        // 1% in 30 days = (1.01)^(365/30) - 1 = 12.68%
        expect(xirr, greaterThan(0.10)); // At least 10%
        expect(xirr, lessThan(0.15)); // Less than 15%
      });

      test('REGRESSION TEST: Very long period (10 years) should annualize correctly', () {
        // 200% return in 10 years should annualize to ~11.61% per year
        // Before fix: Would show 0.0003% (38,000x too small!)
        // After fix: Should show ~11.61%

        final dates = [
          DateTime(2014, 1, 1),
          DateTime(2024, 1, 1),
        ];
        final amounts = [-100000.0, 300000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        // 200% in 10 years = (3.00)^(1/10) - 1 = 11.61%
        expect(xirr, greaterThan(0.10)); // At least 10%
        expect(xirr, closeTo(0.1161, 0.02)); // Close to 11.61%
      });

      test('REGRESSION TEST: Negative return should annualize correctly', () {
        // -20% return in 1 year should show as -20%, not -0.0055%

        final dates = [
          DateTime(2023, 1, 1),
          DateTime(2024, 1, 1),
        ];
        final amounts = [-100000.0, 80000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, lessThan(0)); // Should be negative
        expect(xirr, closeTo(-0.20, 0.02)); // Close to -20%

        // Verify it's NOT the buggy value
        expect(xirr, isNot(closeTo(-0.000055, 0.0001)));
      });
    });

    group('calculateXirr - Real-World Scenarios', () {
      test('Fixed Deposit: 8% annual interest for 1 year', () {
        // Real FD scenario
        final dates = [
          DateTime(2023, 1, 1),
          DateTime(2024, 1, 1),
        ];
        final amounts = [-100000.0, 108000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, closeTo(0.08, 0.01)); // Should be ~8%
      });

      test('Recurring Deposit: Monthly deposits with 7% annual return', () {
        // RD: ₹10,000/month for 12 months at 7% p.a.
        final dates = <DateTime>[];
        final amounts = <double>[];

        // 12 monthly deposits
        for (int i = 0; i < 12; i++) {
          dates.add(DateTime(2023, 1 + i, 1));
          amounts.add(-10000.0);
        }

        // Maturity value (approximate)
        dates.add(DateTime(2024, 1, 1));
        amounts.add(124200.0); // Approximate maturity value

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, greaterThan(0.05)); // At least 5%
        expect(xirr, lessThan(0.10)); // Less than 10%
      });

      test('Mutual Fund SIP: Monthly SIP with market volatility', () {
        // SIP with varying returns
        final dates = [
          DateTime(2023, 1, 1),
          DateTime(2023, 2, 1),
          DateTime(2023, 3, 1),
          DateTime(2023, 4, 1),
          DateTime(2023, 5, 1),
          DateTime(2023, 6, 1),
          DateTime(2023, 12, 31), // Redemption
        ];
        final amounts = [
          -5000.0, -5000.0, -5000.0, -5000.0, -5000.0, -5000.0,
          33000.0, // 10% gain
        ];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, greaterThan(0)); // Positive return
      });

      test('P2P Lending: Quarterly interest payments', () {
        // ₹1,00,000 lent, quarterly interest of ₹2,000, principal back after 1 year
        final dates = [
          DateTime(2023, 1, 1), // Principal
          DateTime(2023, 4, 1), // Q1 interest
          DateTime(2023, 7, 1), // Q2 interest
          DateTime(2023, 10, 1), // Q3 interest
          DateTime(2024, 1, 1), // Q4 interest + principal
        ];
        final amounts = [
          -100000.0,
          2000.0,
          2000.0,
          2000.0,
          102000.0, // Last interest + principal
        ];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, closeTo(0.08, 0.02)); // Should be ~8%
      });

      test('Stock Investment: Buy and sell with dividend', () {
        // Buy stock, receive dividend, sell at profit
        final dates = [
          DateTime(2023, 1, 1), // Buy
          DateTime(2023, 6, 1), // Dividend
          DateTime(2024, 1, 1), // Sell
        ];
        final amounts = [
          -100000.0, // Buy
          2000.0, // Dividend
          115000.0, // Sell (15% capital gain)
        ];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, greaterThan(0.15)); // Should be >15%
      });
    });

    group('calculateXirr - Performance Tests', () {
      test('should handle large number of cash flows efficiently', () {
        // 100 monthly SIP transactions
        final dates = <DateTime>[];
        final amounts = <double>[];

        for (int i = 0; i < 100; i++) {
          dates.add(DateTime(2015, 1 + (i % 12), 1 + (i ~/ 12)));
          amounts.add(-10000.0);
        }

        // Final redemption
        dates.add(DateTime(2023, 5, 1));
        amounts.add(1500000.0);

        final stopwatch = Stopwatch()..start();
        final xirr = XirrSolver.calculateXirr(dates, amounts);
        stopwatch.stop();

        expect(xirr, isNotNull);
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should complete in <1 second
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';

// Expected rates are exact (actual/365 day count, as Excel's XIRR), computed
// independently with a Python bisection solver. See
// xirr_excel_parity_test.dart for the method and the wider golden suite.

const double _tol = 1e-6;

void main() {
  group('XirrSolver', () {
    group('calculateXirr - Basic Scenarios', () {
      test(
        'should calculate correct XIRR for simple 1-year investment with 10% return',
        () {
          // Scenario: Invest ₹1,00,000 on Jan 1, 2023
          //           Get back ₹1,10,000 on Jan 1, 2024 (exactly 1 year)
          //           Expected: 10% annual return
          final dates = [DateTime.utc(2023, 1, 1), DateTime.utc(2024, 1, 1)];
          final amounts = [-100000.0, 110000.0];

          final xirr = XirrSolver.calculateXirr(dates, amounts);

          // Should be approximately 10% (0.10)
          expect(xirr, isNotNull);
          expect(xirr, closeTo(0.1000000000, _tol));
        },
      );

      test(
        'should calculate correct XIRR for 2-year investment with 50% return',
        () {
          // Scenario: Invest ₹1,00,000 on Jan 1, 2023
          //           Get back ₹1,50,000 on Jan 1, 2025 (2 years)
          //           Expected: 22.44% annual return (731 days)
          final dates = [DateTime.utc(2023, 1, 1), DateTime.utc(2025, 1, 1)];
          final amounts = [-100000.0, 150000.0];

          final xirr = XirrSolver.calculateXirr(dates, amounts);

          // XIRR = 1.50^(365/731) - 1 = 0.2244052527
          expect(xirr, isNotNull);
          expect(xirr, closeTo(0.2244052527, _tol)); // 731 days
        },
      );

      test(
        'should calculate correct XIRR for 6-month investment with 5% return',
        () {
          // Scenario: Invest ₹1,00,000 on Jan 1, 2024
          //           Get back ₹1,05,000 on July 1, 2024 (6 months)
          //           Expected: 10.28% annualized return (182 days)
          final dates = [DateTime.utc(2024, 1, 1), DateTime.utc(2024, 7, 1)];
          final amounts = [-100000.0, 105000.0];

          final xirr = XirrSolver.calculateXirr(dates, amounts);

          // XIRR = 1.05^(365/182) - 1 = 0.1027955954
          expect(xirr, isNotNull);
          expect(xirr, closeTo(0.1027955954, _tol)); // 182 days
        },
      );

      test(
        'should calculate correct XIRR for 3-month investment with 2% return',
        () {
          // Scenario: Invest ₹1,00,000 on Jan 1, 2024
          //           Get back ₹1,02,000 on April 1, 2024 (3 months)
          //           Expected: 8.27% annualized return (91 days)
          final dates = [DateTime.utc(2024, 1, 1), DateTime.utc(2024, 4, 1)];
          final amounts = [-100000.0, 102000.0];

          final xirr = XirrSolver.calculateXirr(dates, amounts);

          // XIRR = 1.02^(365/91) - 1 = 0.0826677351
          expect(xirr, isNotNull);
          expect(xirr, closeTo(0.0826677351, _tol)); // 91 days
        },
      );

      test(
        'should calculate correct XIRR for 5-year investment with 100% return',
        () {
          // Scenario: Invest ₹1,00,000 on Jan 1, 2020
          //           Get back ₹2,00,000 on Jan 1, 2025 (5 years)
          //           Expected: 14.85% annual return (1,827 days)
          final dates = [DateTime.utc(2020, 1, 1), DateTime.utc(2025, 1, 1)];
          final amounts = [-100000.0, 200000.0];

          final xirr = XirrSolver.calculateXirr(dates, amounts);

          // XIRR = 2.00^(365/1827) - 1 = 0.1485240459
          expect(xirr, isNotNull);
          expect(xirr, closeTo(0.1485240459, _tol)); // 1,827 days
        },
      );
    });

    group('calculateXirr - Multiple Cash Flows (SIP)', () {
      test(
        'should calculate correct XIRR for monthly SIP with positive returns',
        () {
          // Scenario: Monthly SIP of ₹10,000 for 12 months
          //           Final value: ₹1,30,000 (invested ₹1,20,000)
          //           Expected: Positive XIRR
          final dates = <DateTime>[];
          final amounts = <double>[];

          // 12 monthly investments
          for (int i = 0; i < 12; i++) {
            dates.add(DateTime.utc(2023, 1 + i, 1));
            amounts.add(-10000.0);
          }

          // Final redemption
          dates.add(DateTime.utc(2024, 1, 1));
          amounts.add(130000.0);

          final xirr = XirrSolver.calculateXirr(dates, amounts);

          expect(xirr, isNotNull);
          expect(xirr, closeTo(0.1566983509, _tol));
        },
      );

      test('should calculate correct XIRR for quarterly investments', () {
        // Scenario: Quarterly investments of ₹25,000 for 1 year
        //           Final value: ₹1,10,000 (invested ₹1,00,000)
        final dates = [
          DateTime.utc(2023, 1, 1),
          DateTime.utc(2023, 4, 1),
          DateTime.utc(2023, 7, 1),
          DateTime.utc(2023, 10, 1),
          DateTime.utc(2024, 1, 1),
        ];
        final amounts = [-25000.0, -25000.0, -25000.0, -25000.0, 110000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, closeTo(0.1624285055, _tol));
      });
    });

    group('calculateXirr - Edge Cases', () {
      test('should handle single cash flow (return null or zero)', () {
        final dates = [DateTime.utc(2023, 1, 1)];
        final amounts = [-100000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        // Single cash flow has no return
        expect(xirr, anyOf(isNull, equals(0.0)));
      });

      test('should handle all outflows (no returns yet)', () {
        final dates = [
          DateTime.utc(2023, 1, 1),
          DateTime.utc(2023, 2, 1),
          DateTime.utc(2023, 3, 1),
        ];
        final amounts = [-10000.0, -10000.0, -10000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        // All outflows and no terminal value: no rate solves NPV = 0, so
        // there is no XIRR. A negative rate here would be a made-up loss.
        expect(xirr, isNull);
      });

      test('should handle all inflows (no investments)', () {
        final dates = [DateTime.utc(2023, 1, 1), DateTime.utc(2023, 2, 1)];
        final amounts = [10000.0, 10000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        // All inflows, no outflows - should return null
        expect(xirr, isNull);
      });

      test('should handle zero return (break-even)', () {
        // Invest ₹1,00,000, get back ₹1,00,000
        final dates = [DateTime.utc(2023, 1, 1), DateTime.utc(2024, 1, 1)];
        final amounts = [-100000.0, 100000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, closeTo(0.0, _tol));
      });

      test('should handle negative return (loss)', () {
        // Invest ₹1,00,000, get back ₹90,000 (10% loss)
        final dates = [DateTime.utc(2023, 1, 1), DateTime.utc(2024, 1, 1)];
        final amounts = [-100000.0, 90000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, closeTo(-0.1000000000, _tol));
      });

      test('should handle total loss', () {
        // Invest ₹1,00,000, get back ₹0 (100% loss)
        final dates = [DateTime.utc(2023, 1, 1), DateTime.utc(2024, 1, 1)];
        final amounts = [-100000.0, 0.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, closeTo(-1.0, _tol)); // -100%
      });
    });

    group('calculateXirr - Approximation Formula Tests (Bug Fix Verification)', () {
      // These tests specifically verify the fix for the XIRR approximation formula
      // The bug was: using days instead of years in the CAGR formula

      test(
        'REGRESSION TEST: 1-year investment should show 10% not 0.0267%',
        () {
          // This is the exact example from the bug report
          // Before fix: Would show 0.0267% (375x too small)
          // After fix: Should show 10%

          final dates = [DateTime.utc(2023, 1, 1), DateTime.utc(2024, 1, 1)];
          final amounts = [-100000.0, 110000.0];

          final xirr = XirrSolver.calculateXirr(dates, amounts);

          expect(xirr, isNotNull);
          // The key assertion: should be 10%, NOT 0.0267%
          expect(xirr, greaterThan(0.05)); // At least 5%
          expect(xirr, closeTo(0.1000000000, _tol));

          // Verify it's NOT the buggy value
          expect(xirr, isNot(closeTo(0.000267, 0.0001)));
        },
      );

      test(
        'REGRESSION TEST: 2-year investment should show 22.44% not 0.0558%',
        () {
          // Before fix: Would show 0.0558% (402x too small)
          // After fix: Should show 22.44%

          final dates = [DateTime.utc(2023, 1, 1), DateTime.utc(2025, 1, 1)];
          final amounts = [-100000.0, 150000.0];

          final xirr = XirrSolver.calculateXirr(dates, amounts);

          expect(xirr, isNotNull);
          // Should be 22.44%, NOT 0.0558%
          expect(xirr, greaterThan(0.15)); // At least 15%
          expect(xirr, closeTo(0.2244052527, _tol)); // 731 days

          // Verify it's NOT the buggy value
          expect(xirr, isNot(closeTo(0.000558, 0.0001)));
        },
      );

      test(
        'REGRESSION TEST: 6-month investment should show 10.28% not 0.0268%',
        () {
          // Before fix: Would show 0.0268%
          // After fix: Should show 10.28%

          final dates = [DateTime.utc(2024, 1, 1), DateTime.utc(2024, 7, 1)];
          final amounts = [-100000.0, 105000.0];

          final xirr = XirrSolver.calculateXirr(dates, amounts);

          expect(xirr, isNotNull);
          // Should be 10.28%, NOT 0.0268%
          expect(xirr, greaterThan(0.05)); // At least 5%
          expect(xirr, closeTo(0.1027955954, _tol)); // 182 days

          // Verify it's NOT the buggy value
          expect(xirr, isNot(closeTo(0.000268, 0.0001)));
        },
      );

      test(
        'REGRESSION TEST: Very short period (30 days) should annualize correctly',
        () {
          // 1% return in 30 days should annualize to ~12.68% per year
          // Before fix: Would show 0.0003% (42,000x too small!)
          // After fix: Should show ~12.68%

          final dates = [DateTime.utc(2024, 1, 1), DateTime.utc(2024, 1, 31)];
          final amounts = [-100000.0, 101000.0];

          final xirr = XirrSolver.calculateXirr(dates, amounts);

          expect(xirr, isNotNull);
          // 1% in 30 days = (1.01)^(365/30) - 1 = 12.68%
          expect(xirr, closeTo(0.1286952942, _tol));
        },
      );

      test(
        'REGRESSION TEST: Very long period (10 years) should annualize correctly',
        () {
          // 200% return in 10 years should annualize to ~11.61% per year
          // Before fix: Would show 0.0003% (38,000x too small!)
          // After fix: Should show ~11.61%

          final dates = [DateTime.utc(2014, 1, 1), DateTime.utc(2024, 1, 1)];
          final amounts = [-100000.0, 300000.0];

          final xirr = XirrSolver.calculateXirr(dates, amounts);

          expect(xirr, isNotNull);
          // 200% in 10 years = (3.00)^(1/10) - 1 = 11.61%
          expect(xirr, greaterThan(0.10)); // At least 10%
          expect(xirr, closeTo(0.1160560245, _tol));
        },
      );

      test('REGRESSION TEST: Negative return should annualize correctly', () {
        // -20% return in 1 year should show as -20%, not -0.0055%

        final dates = [DateTime.utc(2023, 1, 1), DateTime.utc(2024, 1, 1)];
        final amounts = [-100000.0, 80000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, lessThan(0)); // Should be negative
        expect(xirr, closeTo(-0.2000000000, _tol));

        // Verify it's NOT the buggy value
        expect(xirr, isNot(closeTo(-0.000055, 0.0001)));
      });
    });

    group('calculateXirr - Real-World Scenarios', () {
      test('Fixed Deposit: 8% annual interest for 1 year', () {
        // Real FD scenario
        final dates = [DateTime.utc(2023, 1, 1), DateTime.utc(2024, 1, 1)];
        final amounts = [-100000.0, 108000.0];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, closeTo(0.0800000000, _tol));
      });

      test('Recurring Deposit: Monthly deposits with 7% annual return', () {
        // RD: ₹10,000/month for 12 months at 7% p.a.
        final dates = <DateTime>[];
        final amounts = <double>[];

        // 12 monthly deposits
        for (int i = 0; i < 12; i++) {
          dates.add(DateTime.utc(2023, 1 + i, 1));
          amounts.add(-10000.0);
        }

        // Maturity value (approximate)
        dates.add(DateTime.utc(2024, 1, 1));
        amounts.add(124200.0); // Approximate maturity value

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, closeTo(0.0649793821, _tol));
      });

      test('Mutual Fund SIP: Monthly SIP with market volatility', () {
        // SIP with varying returns
        final dates = [
          DateTime.utc(2023, 1, 1),
          DateTime.utc(2023, 2, 1),
          DateTime.utc(2023, 3, 1),
          DateTime.utc(2023, 4, 1),
          DateTime.utc(2023, 5, 1),
          DateTime.utc(2023, 6, 1),
          DateTime.utc(2023, 12, 31), // Redemption
        ];
        final amounts = [
          -5000.0, -5000.0, -5000.0, -5000.0, -5000.0, -5000.0,
          33000.0, // 10% gain
        ];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, closeTo(0.1277932068, _tol));
      });

      test('P2P Lending: Quarterly interest payments', () {
        // ₹1,00,000 lent, quarterly interest of ₹2,000, principal back after 1 year
        final dates = [
          DateTime.utc(2023, 1, 1), // Principal
          DateTime.utc(2023, 4, 1), // Q1 interest
          DateTime.utc(2023, 7, 1), // Q2 interest
          DateTime.utc(2023, 10, 1), // Q3 interest
          DateTime.utc(2024, 1, 1), // Q4 interest + principal
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
        expect(xirr, closeTo(0.0824484906, _tol));
      });

      test('Stock Investment: Buy and sell with dividend', () {
        // Buy stock, receive dividend, sell at profit
        final dates = [
          DateTime.utc(2023, 1, 1), // Buy
          DateTime.utc(2023, 6, 1), // Dividend
          DateTime.utc(2024, 1, 1), // Sell
        ];
        final amounts = [
          -100000.0, // Buy
          2000.0, // Dividend
          115000.0, // Sell (15% capital gain)
        ];

        final xirr = XirrSolver.calculateXirr(dates, amounts);

        expect(xirr, isNotNull);
        expect(xirr, closeTo(0.1719498447, _tol));
      });
    });

    group('calculateXirr - Performance Tests', () {
      test('should handle large number of cash flows efficiently', () {
        // 100 monthly SIP transactions
        final dates = <DateTime>[];
        final amounts = <double>[];

        for (int i = 0; i < 100; i++) {
          dates.add(DateTime.utc(2015, 1 + (i % 12), 1 + (i ~/ 12)));
          amounts.add(-10000.0);
        }

        // Final redemption
        dates.add(DateTime.utc(2023, 5, 1));
        amounts.add(1500000.0);

        final stopwatch = Stopwatch()..start();
        final xirr = XirrSolver.calculateXirr(dates, amounts);
        stopwatch.stop();

        expect(xirr, isNotNull);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(1000),
        ); // Should complete in <1 second
      });
    });

    // A70 (#835): dates are read as local midnights, and two local midnights
    // either side of a DST change are a whole number of days minus (or plus)
    // an hour apart. The day count must come from the calendar day.
    group('day count by calendar day', () {
      test('15 Jan to 1 Apr 2026 is 76 days even when the two values are '
          'an hour short of 76 x 24 hours apart', () {
        // 75 days and 23 hours apart, as local midnights in New York are.
        final dates = [DateTime.utc(2026, 1, 15, 1), DateTime.utc(2026, 4, 1)];

        // 1.01^(365/76) - 1
        expect(
          XirrSolver.calculateXirr(dates, [-100000.0, 101000.0]),
          closeTo(0.048948016794645666, _tol),
        );
      });

      test('local midnights of 15 Jan and 1 Apr 2026 give the 76-day rate '
          'in every device zone', () {
        // Only guards the DST case on a machine whose zone changes clocks
        // between the two dates, for example TZ=America/New_York.
        final dates = [DateTime(2026, 1, 15), DateTime(2026, 4, 1)];

        expect(
          XirrSolver.calculateXirr(dates, [-100000.0, 101000.0]),
          closeTo(0.048948016794645666, _tol),
        );
      });
    });
  });
}

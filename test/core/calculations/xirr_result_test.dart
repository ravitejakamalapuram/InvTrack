import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';

/// Tests for the result-type API of [XirrSolver] (review ticket A09, CALC-06
/// and CALC-15): callers must be able to tell an exact XIRR from the
/// timing-blind approximation and from "no XIRR at all".
void main() {
  group('XirrSolver.solve', () {
    test('a solvable flow is exact and matches calculateXirr', () {
      // -1,00,000 then +1,10,000 exactly 365 days later: XIRR is exactly 10%.
      final dates = [DateTime(2023, 1, 1), DateTime(2024, 1, 1)];
      final amounts = [-100000.0, 110000.0];

      final result = XirrSolver.solve(dates, amounts);

      expect(result.method, XirrMethod.exact);
      expect(result.reason, isNull);
      expect(result.value, closeTo(0.10, 1e-6));
      expect(result.value, XirrSolver.calculateXirr(dates, amounts));
    });

    test('a 3-day 2% gain above the 1000% search range is approximate', () {
      // -1,00,000 then +1,02,000 three days later. The annualised rate is
      // 1.02^(365/3) - 1 = 1012.6%, outside the solver's search range, so the
      // value comes from the CAGR fallback and must be flagged as such.
      final dates = [DateTime(2026, 1, 1), DateTime(2026, 1, 4)];
      final amounts = [-100000.0, 102000.0];
      final expected = pow(1.02, 365 / 3) - 1;

      final result = XirrSolver.solve(dates, amounts);

      expect(result.method, XirrMethod.approximate);
      expect(result.isApproximate, isTrue);
      expect(result.value, closeTo(expected, 1e-6));
      expect(result.value! * 100, greaterThan(1000));
      // The legacy API keeps returning the same number (A19 goldens rely on it).
      expect(XirrSolver.calculateXirr(dates, amounts), result.value);
    });

    test('a single INVEST flow is undefined, not 0%', () {
      final dates = [DateTime(2026, 1, 1)];
      final amounts = [-100000.0];

      final result = XirrSolver.solve(dates, amounts);

      expect(result.method, XirrMethod.undefined);
      expect(result.isDefined, isFalse);
      expect(result.value, isNull);
      expect(result.reason, XirrUndefinedReason.insufficientFlows);
      // Legacy behaviour is unchanged.
      expect(XirrSolver.calculateXirr(dates, amounts), 0.0);
    });

    test('only outflows is undefined because there is no sign change', () {
      final dates = [DateTime(2026, 1, 1), DateTime(2026, 4, 1)];
      final amounts = [-100000.0, -50000.0];

      final result = XirrSolver.solve(dates, amounts);

      expect(result.method, XirrMethod.undefined);
      expect(result.value, isNull);
      expect(result.reason, XirrUndefinedReason.noSignChange);
      expect(XirrSolver.calculateXirr(dates, amounts), isNull);
    });

    test('empty input is undefined and legacy still returns 0.0', () {
      final result = XirrSolver.solve(const [], const []);

      expect(result.method, XirrMethod.undefined);
      expect(result.reason, XirrUndefinedReason.insufficientFlows);
      expect(XirrSolver.calculateXirr(const [], const []), 0.0);
    });

    test('mismatched lengths still throw', () {
      expect(
        () => XirrSolver.solve([DateTime(2026, 1, 1)], const []),
        throwsArgumentError,
      );
    });
  });
}

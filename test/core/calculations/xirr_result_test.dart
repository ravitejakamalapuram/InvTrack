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

    test('a 3-day 2% gain above 1000% is exact', () {
      // -1,00,000 then +1,02,000 three days later. The annualised rate is
      // 1.02^(365/3) - 1 = 1012.6%. A73 (#838): the solver searches above
      // 1000%, so this is a true root, not the CAGR fallback.
      final dates = [DateTime(2026, 1, 1), DateTime(2026, 1, 4)];
      final amounts = [-100000.0, 102000.0];
      final expected = pow(1.02, 365 / 3) - 1;

      final result = XirrSolver.solve(dates, amounts);

      expect(result.method, XirrMethod.exact);
      expect(result.isApproximate, isFalse);
      expect(result.value, closeTo(expected, 1e-6));
      expect(result.value, closeTo(10.126388779, 1e-6));
      expect(result.value! * 100, greaterThan(1000));
      // The legacy API keeps returning the same number (A19 goldens rely on it).
      expect(XirrSolver.calculateXirr(dates, amounts), result.value);
    });

    test('a total loss has no root and stays approximate at -100%', () {
      // -1,00,000 then 0 a year later: NPV is -1,00,000 at every rate, so
      // there is nothing to find and the CAGR fallback gives -100%.
      final dates = [DateTime(2023, 1, 1), DateTime(2024, 1, 1)];
      final amounts = [-100000.0, 0.0];

      final result = XirrSolver.solve(dates, amounts);

      expect(result.method, XirrMethod.approximate);
      expect(result.value, closeTo(-1.0, 1e-6));
    });

    test('a root above the 1e6 search bound stays approximate', () {
      // -1,00,000 then +1,05,000 one day later: the true rate is
      // 1.05^365 - 1 = 54,211,840.58 (5.4 billion %), above the bound the
      // solver searches to, so the CAGR fallback answers and says so.
      final dates = [DateTime(2023, 3, 1), DateTime(2023, 3, 2)];
      final amounts = [-100000.0, 105000.0];

      final result = XirrSolver.solve(dates, amounts);

      expect(result.method, XirrMethod.approximate);
      expect(result.value, closeTo(54211840.577839525, 1e-6));
    });

    test('a net loss never gets an exact rate above 1000%', () {
      // An early payout followed by larger INVESTs: the flows lost 2,63,597
      // in 113 days. NPV has a far root above 1000% (about 1039.82), but a
      // money-losing investment must not show ">1000%". With no root in
      // [-99%, 1000%] the labelled CAGR fallback answers with a loss.
      final dates = [
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 23),
        DateTime(2024, 3, 6),
        DateTime(2024, 4, 21),
        DateTime(2024, 4, 23),
      ];
      final amounts = [-44359.0, 186256.0, -175070.0, -122816.0, -107608.0];

      final result = XirrSolver.solve(dates, amounts);

      expect(result.method, XirrMethod.approximate);
      expect(result.value, isNegative);
      // The same CAGR fallback the solver gave before A73: -94.2% approx.
      expect(result.value, closeTo(-0.9420565724177042, 1e-6));
    });

    test('a single INVEST flow is undefined, not 0%', () {
      final dates = [DateTime(2026, 1, 1)];
      final amounts = [-100000.0];

      final result = XirrSolver.solve(dates, amounts);

      expect(result.method, XirrMethod.undefined);
      expect(result.isDefined, isFalse);
      expect(result.value, isNull);
      expect(result.reason, XirrUndefinedReason.insufficientFlows);
      // A71: the bare-number API no longer turns this into 0.0.
      expect(XirrSolver.calculateXirr(dates, amounts), isNull);
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

    test('empty input is undefined, also in the bare-number API', () {
      final result = XirrSolver.solve(const [], const []);

      expect(result.method, XirrMethod.undefined);
      expect(result.reason, XirrUndefinedReason.insufficientFlows);
      // A71: no longer 0.0.
      expect(XirrSolver.calculateXirr(const [], const []), isNull);
    });

    test('mismatched lengths still throw', () {
      expect(
        () => XirrSolver.solve([DateTime(2026, 1, 1)], const []),
        throwsArgumentError,
      );
    });
  });
}

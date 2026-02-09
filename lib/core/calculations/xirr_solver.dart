import 'dart:math';

class XirrSolver {
  static const double _tolerance = 1e-7;
  static const int _maxIterations = 200;

  /// Calculates XIRR for a series of cash flows.
  /// [dates] and [amounts] must be of the same length.
  /// Amounts should be negative for outflows (investments) and positive for inflows (returns/current value).
  /// Returns null if the cash flows are invalid (e.g., all inflows or all outflows).
  static double? calculateXirr(List<DateTime> dates, List<double> amounts) {
    if (dates.length != amounts.length) {
      throw ArgumentError('Dates and amounts must have the same length');
    }
    if (dates.isEmpty) return 0.0;
    if (dates.length == 1) return 0.0;

    // Normalize dates to years from the first date
    final firstDate = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final yearsFromStart = dates
        .map((d) => d.difference(firstDate).inDays / 365.0)
        .toList();

    // Calculate total inflows and outflows to determine initial guess direction
    double totalInflows = 0;
    double totalOutflows = 0;
    bool hasNonNegativeAmount = false;
    bool hasNegativeAmount = false;

    for (final amount in amounts) {
      if (amount >= 0) {
        totalInflows += amount;
        hasNonNegativeAmount = true;
      } else {
        totalOutflows += amount.abs();
        hasNegativeAmount = true;
      }
    }

    // Invalid scenarios: all inflows or all outflows
    // Note: 0.0 is treated as a valid inflow (e.g., total loss scenario)
    if (!hasNonNegativeAmount || !hasNegativeAmount) {
      return null;
    }

    // Try Newton-Raphson with multiple initial guesses
    final initialGuesses = <double>[
      0.1, // 10% gain
      -0.1, // 10% loss
      0.0, // break even
      0.5, // 50% gain
      -0.5, // 50% loss
      -0.9, // 90% loss (near total loss)
      1.0, // 100% gain
    ];

    // If it looks like a loss, try negative guesses first
    if (totalInflows < totalOutflows) {
      initialGuesses.insert(0, -0.3);
      initialGuesses.insert(0, -0.5);
    }

    for (final guess in initialGuesses) {
      final result = _newtonRaphson(guess, yearsFromStart, amounts);
      if (result != null && result > -1.0 && result.isFinite) {
        return result;
      }
    }

    // Fallback: bisection method for stubborn cases
    final bisectionResult = _bisection(yearsFromStart, amounts);
    if (bisectionResult != null) {
      return bisectionResult;
    }

    return 0.0; // Failed to find solution
  }

  /// Newton-Raphson iteration
  static double? _newtonRaphson(
    double x0,
    List<double> yearsFromStart,
    List<double> amounts,
  ) {
    double x = x0;

    for (int i = 0; i < _maxIterations; i++) {
      // Prevent x from going below -1 (which would cause pow issues)
      if (x <= -1.0) x = -0.99;

      final (fValue, dfValue) = _calculateFandDf(x, yearsFromStart, amounts);

      if (dfValue.abs() < 1e-10) return null; // Derivative too small

      final x1 = x - fValue / dfValue;

      // Check for convergence
      if ((x1 - x).abs() < _tolerance) {
        // Verify the solution is valid
        if (x1 > -1.0 && x1.isFinite && _f(x1, yearsFromStart, amounts).abs() < 0.01) {
          return x1;
        }
      }

      // Dampen large jumps
      if ((x1 - x).abs() > 1.0) {
        x = x + (x1 - x).sign * 0.5;
      } else {
        x = x1;
      }

      // Bounds check
      if (x <= -1.0) x = -0.99;
      if (x > 10.0) x = 10.0; // 1000% return cap
    }

    return null;
  }

  /// Bisection method as fallback
  static double? _bisection(List<double> yearsFromStart, List<double> amounts) {
    double low = -0.99;
    double high = 5.0;

    final fLow = _f(low, yearsFromStart, amounts);
    final fHigh = _f(high, yearsFromStart, amounts);

    // Check if there's a root in this interval
    if (fLow.sign == fHigh.sign) {
      // Try expanding the range
      high = 10.0;
      final fHigh2 = _f(high, yearsFromStart, amounts);
      if (fLow.sign == fHigh2.sign) {
        // No root exists - calculate approximate annualized return
        return _calculateApproximateReturn(yearsFromStart, amounts);
      }
    }

    for (int i = 0; i < _maxIterations; i++) {
      final mid = (low + high) / 2;
      final fMid = _f(mid, yearsFromStart, amounts);

      if (fMid.abs() < _tolerance || (high - low) / 2 < _tolerance) {
        return mid;
      }

      if (fMid.sign == _f(low, yearsFromStart, amounts).sign) {
        low = mid;
      } else {
        high = mid;
      }
    }

    return (low + high) / 2;
  }

  /// Calculate approximate annualized return when XIRR doesn't converge
  /// This happens when there's a total loss or unusual cash flow patterns
  static double? _calculateApproximateReturn(
    List<double> yearsFromStart,
    List<double> amounts,
  ) {
    if (yearsFromStart.isEmpty || amounts.isEmpty) return null;

    // Calculate total inflows and outflows
    double totalInflows = 0;
    double totalOutflows = 0;
    for (final amount in amounts) {
      if (amount > 0) {
        totalInflows += amount;
      } else {
        totalOutflows += amount.abs();
      }
    }

    if (totalOutflows == 0) return null;

    // Calculate simple return
    final simpleReturn = (totalInflows - totalOutflows) / totalOutflows;

    // Find time span in years
    // Note: yearsFromStart already contains years (converted at line 19)
    final maxYear = yearsFromStart.reduce((a, b) => a > b ? a : b);
    final minYear = yearsFromStart.reduce((a, b) => a < b ? a : b);
    final timeSpanYears = maxYear - minYear;

    if (timeSpanYears <= 0) return simpleReturn;

    // Annualize the return
    // For losses, we use a different formula since (1 + r)^(1/n) doesn't work for r < -1
    if (simpleReturn >= -1) {
      // Standard CAGR formula
      return pow(1 + simpleReturn, 1 / timeSpanYears) - 1;
    } else {
      // Total loss scenario - annualize the loss rate
      return simpleReturn / timeSpanYears;
    }
  }

  /// XNPV function: sum of present values
  static double _f(double x, List<double> yearsFromStart, List<double> amounts) {
    if (x <= -1.0) return double.infinity;

    double sum = 0.0;
    for (int i = 0; i < amounts.length; i++) {
      final power = yearsFromStart[i];
      final base = 1 + x;
      if (base <= 0) return double.infinity;
      sum += amounts[i] / pow(base, power);
    }
    return sum;
  }

  /// Calculates both function value and derivative in a single pass
  /// Reduces pow() calls by 50%
  static (double, double) _calculateFandDf(
    double x,
    List<double> yearsFromStart,
    List<double> amounts,
  ) {
    if (x <= -1.0) return (double.infinity, double.infinity);

    double fSum = 0.0;
    double dfSum = 0.0;
    final base = 1 + x;

    if (base <= 0) return (double.infinity, double.infinity);

    for (int i = 0; i < amounts.length; i++) {
      final p = yearsFromStart[i];
      // Calculate pow once and reuse for both f and df
      // f term: amount / (1+x)^p
      // df term: amount * -p / (1+x)^(p+1) = (f term) * -p / (1+x)
      final powTerm = pow(base, p);
      final termF = amounts[i] / powTerm;

      fSum += termF;
      dfSum += termF * (-p) / base;
    }
    return (fSum, dfSum);
  }
}

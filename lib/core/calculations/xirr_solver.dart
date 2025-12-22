import 'dart:math';

/// XIRR (Extended Internal Rate of Return) solver using Newton-Raphson method
/// with multiple initial guesses and bisection fallback for robust convergence.
class XirrSolver {
  static const double _tolerance = 1e-7;
  static const int _maxIterations = 200;

  /// Calculates XIRR for a series of cash flows.
  /// [dates] and [amounts] must be of the same length.
  /// Amounts should be negative for outflows (investments) and positive for inflows (returns/current value).
  ///
  /// Returns 0.0 if XIRR cannot be calculated (e.g., insufficient data).
  /// For investments with total losses where XIRR mathematically doesn't exist,
  /// returns an approximate annualized return.
  static double calculateXirr(List<DateTime> dates, List<double> amounts) {
    if (dates.length != amounts.length) {
      throw ArgumentError('Dates and amounts must have the same length');
    }
    if (dates.isEmpty) return 0.0;
    if (dates.length == 1) return 0.0;

    // Normalize dates to years from the first date
    final firstDate = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final days = dates.map((d) => d.difference(firstDate).inDays / 365.0).toList();

    // Calculate total inflows and outflows to determine initial guess strategy
    double totalInflows = 0;
    double totalOutflows = 0;
    for (final amount in amounts) {
      if (amount > 0) {
        totalInflows += amount;
      } else {
        totalOutflows += amount.abs();
      }
    }

    // Try multiple initial guesses - prioritize based on expected return
    final initialGuesses = <double>[0.1, -0.1, 0.0, 0.5, -0.5, -0.9, 1.0, 2.0];

    // If loss-making, prioritize negative guesses
    if (totalInflows < totalOutflows) {
      initialGuesses.insert(0, -0.3);
      initialGuesses.insert(0, -0.5);
      initialGuesses.insert(0, -0.7);
    }

    for (final guess in initialGuesses) {
      final result = _newtonRaphson(guess, days, amounts);
      if (result != null && result > -1.0 && result.isFinite && !result.isNaN) {
        return result;
      }
    }

    // Fallback to bisection method
    final bisectionResult = _bisection(days, amounts);
    if (bisectionResult != null && bisectionResult.isFinite && !bisectionResult.isNaN) {
      return bisectionResult;
    }

    return 0.0;
  }

  /// Newton-Raphson iteration with a specific initial guess
  static double? _newtonRaphson(double initialGuess, List<double> days, List<double> amounts) {
    double x = initialGuess;

    for (int i = 0; i < _maxIterations; i++) {
      final fValue = _f(x, days, amounts);
      final dfValue = _df(x, days, amounts);

      if (dfValue.abs() < 1e-12) {
        // Derivative too small, try adjusting
        x += 0.01;
        continue;
      }

      final step = fValue / dfValue;
      final x1 = x - step;

      // Prevent x from going below -1 (which would cause division issues)
      if (x1 <= -1.0) {
        x = -0.99;
        continue;
      }

      if (step.abs() < _tolerance) {
        // Verify this is actually a valid solution
        if (_f(x1, days, amounts).abs() < 0.01) {
          return x1;
        }
      }

      x = x1;
    }

    // Check if we converged to a reasonable solution
    if (_f(x, days, amounts).abs() < 0.1 && x > -1.0) {
      return x;
    }

    return null;
  }

  /// Bisection method as fallback
  static double? _bisection(List<double> days, List<double> amounts) {
    double low = -0.99;
    double high = 5.0;

    final fLow = _f(low, days, amounts);
    final fHigh = _f(high, days, amounts);

    // Check if there's a root in this interval
    if (fLow.sign == fHigh.sign) {
      // Try expanding the range
      high = 10.0;
      final fHigh2 = _f(high, days, amounts);
      if (fLow.sign == fHigh2.sign) {
        // No root exists - calculate approximate annualized return
        return _calculateApproximateReturn(days, amounts);
      }
    }

    for (int i = 0; i < _maxIterations; i++) {
      final mid = (low + high) / 2;
      final fMid = _f(mid, days, amounts);

      if (fMid.abs() < _tolerance || (high - low) / 2 < _tolerance) {
        return mid;
      }

      if (fMid.sign == _f(low, days, amounts).sign) {
        low = mid;
      } else {
        high = mid;
      }
    }

    return (low + high) / 2;
  }

  /// Calculate approximate annualized return when XIRR doesn't converge.
  /// This happens when there's a total loss or unusual cash flow patterns
  /// where no discount rate makes NPV = 0.
  static double? _calculateApproximateReturn(List<double> days, List<double> amounts) {
    if (days.isEmpty || amounts.isEmpty) return null;

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
    final maxDay = days.reduce((a, b) => a > b ? a : b);
    final minDay = days.reduce((a, b) => a < b ? a : b);
    final years = maxDay - minDay;

    if (years <= 0) return simpleReturn;

    // Annualize the return
    // For losses, we use a different formula since (1 + r)^(1/n) doesn't work for r < -1
    if (simpleReturn >= -1) {
      // Standard CAGR formula
      return pow(1 + simpleReturn, 1 / years) - 1;
    } else {
      // Total loss scenario - annualize the loss rate
      return simpleReturn / years;
    }
  }

  /// NPV function: f(r) = sum of PV of all cash flows
  static double _f(double x, List<double> days, List<double> amounts) {
    if (x <= -1) return double.infinity;

    double sum = 0.0;
    for (int i = 0; i < amounts.length; i++) {
      final denominator = pow(1 + x, days[i]);
      if (denominator == 0 || !denominator.isFinite) continue;
      sum += amounts[i] / denominator;
    }
    return sum;
  }

  /// Derivative of NPV function: f'(r)
  static double _df(double x, List<double> days, List<double> amounts) {
    if (x <= -1) return double.infinity;

    double sum = 0.0;
    for (int i = 0; i < amounts.length; i++) {
      final denominator = pow(1 + x, days[i] + 1);
      if (denominator == 0 || !denominator.isFinite) continue;
      sum += -days[i] * amounts[i] / denominator;
    }
    return sum;
  }
}

/// XIRR (Extended Internal Rate of Return) calculation using numerical methods.
///
/// This solver implements two numerical methods for finding the internal rate of return
/// for irregular cash flows:
/// 1. **Newton-Raphson method** (primary): Fast convergence for most cases
/// 2. **Bisection method** (fallback): Guaranteed convergence for stubborn cases
///
/// ## Algorithm Overview
///
/// XIRR finds the discount rate (r) that makes the Net Present Value (NPV) of all
/// cash flows equal to zero:
///
/// ```
/// NPV = Σ(CFᵢ / (1 + r)^tᵢ) = 0
/// ```
///
/// Where:
/// - CFᵢ = Cash flow at time i (negative for investments, positive for returns)
/// - tᵢ = Time in years from the first cash flow
/// - r = XIRR (the rate we're solving for)
///
/// ## Newton-Raphson Method
///
/// Uses iterative formula: `x₁ = x₀ - f(x₀)/f'(x₀)`
///
/// Where:
/// - f(x) = NPV function (sum of discounted cash flows)
/// - f'(x) = Derivative of NPV with respect to discount rate
///
/// **Convergence criteria:**
/// - Tolerance: 1e-7 (0.00001% precision)
/// - Max iterations: 200
/// - Solution must satisfy: |f(x)| < 0.01 and x > -1.0
///
/// **Optimization techniques:**
/// - Multiple initial guesses (10%, -10%, 0%, 50%, -50%, -90%, 100%)
/// - Damping for large jumps (prevents oscillation)
/// - Bounds checking (prevents x ≤ -1.0 which causes pow() errors)
///
/// ## Bisection Method (Fallback)
///
/// Binary search in range [-0.99, 5.0] (i.e., -99% to 500% return)
/// - Guaranteed to find a root if one exists in the interval
/// - Slower but more robust than Newton-Raphson
/// - Used when Newton-Raphson fails to converge
///
/// ## Edge Cases Handled
///
/// 1. **Total loss**: Returns approximate annualized loss rate
/// 2. **All inflows or all outflows**: Returns null (invalid scenario)
/// 3. **Single cash flow**: Returns 0.0 (no return)
/// 4. **Same-day transactions**: Normalized to years from first date
/// 5. **Extreme returns**: Capped at 1000% (x ≤ 10.0)
///
/// ## Usage Example
///
/// ```dart
/// final dates = [
///   DateTime(2023, 1, 1),  // Investment
///   DateTime(2023, 6, 1),  // Partial return
///   DateTime(2024, 1, 1),  // Final value
/// ];
/// final amounts = [-10000.0, 500.0, 11000.0];
///
/// final xirr = XirrSolver.calculateXirr(dates, amounts);
/// // Returns ~0.15 (15% annualized return)
/// ```
///
/// ## Performance Characteristics
///
/// - **Time complexity**: O(n × m) where n = cash flows, m = iterations (typically < 10)
/// - **Space complexity**: O(n) for normalized years array
/// - **Typical convergence**: 3-5 iterations for normal cases
/// - **Worst case**: 200 iterations before fallback to bisection
library;

import 'dart:math';

/// Solver for calculating XIRR (Extended Internal Rate of Return) using numerical methods.
///
/// See library documentation above for detailed algorithm explanation.
class XirrSolver {
  /// Convergence tolerance for Newton-Raphson method (0.00001% precision).
  static const double _tolerance = 1e-7;

  /// Maximum iterations before giving up or falling back to bisection method.
  static const int _maxIterations = 200;

  /// Calculates XIRR (Extended Internal Rate of Return) for a series of cash flows.
  ///
  /// XIRR is the annualized rate of return for investments with irregular cash flows.
  /// It's more accurate than simple ROI or CAGR for real-world investment scenarios.
  ///
  /// ## Parameters
  ///
  /// - [dates]: List of transaction dates (must be same length as [amounts])
  /// - [amounts]: List of cash flow amounts at each date
  ///   - **Negative values**: Outflows (investments, purchases)
  ///   - **Positive values**: Inflows (returns, sales, current value)
  ///   - **Zero**: Valid inflow (represents total loss scenario)
  ///
  /// ## Returns
  ///
  /// - **double**: XIRR as decimal (e.g., 0.15 = 15% annual return)
  /// - **null**: Invalid cash flows (all inflows or all outflows)
  /// - **0.0**: Single cash flow or empty list (no return to calculate)
  ///
  /// ## Algorithm
  ///
  /// 1. Normalize dates to years from first date
  /// 2. Try Newton-Raphson with multiple initial guesses
  /// 3. If Newton-Raphson fails, fall back to bisection method
  /// 4. If bisection fails, calculate approximate annualized return
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Investment scenario: Invest ₹10,000, get ₹500 dividend, final value ₹11,000
  /// final dates = [
  ///   DateTime(2023, 1, 1),  // Initial investment
  ///   DateTime(2023, 6, 1),  // Dividend received
  ///   DateTime(2024, 1, 1),  // Current value
  /// ];
  /// final amounts = [-10000.0, 500.0, 11000.0];
  ///
  /// final xirr = XirrSolver.calculateXirr(dates, amounts);
  /// print('XIRR: ${(xirr! * 100).toStringAsFixed(2)}%'); // ~15%
  /// ```
  ///
  /// ## Edge Cases
  ///
  /// ```dart
  /// // Total loss
  /// calculateXirr([date1, date2], [-1000.0, 0.0]); // Returns negative XIRR
  ///
  /// // All outflows (invalid)
  /// calculateXirr([date1, date2], [-1000.0, -500.0]); // Returns null
  ///
  /// // Single transaction
  /// calculateXirr([date1], [-1000.0]); // Returns 0.0
  /// ```
  ///
  /// ## Throws
  ///
  /// - [ArgumentError]: If [dates] and [amounts] have different lengths
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

  /// Newton-Raphson iterative solver for finding XIRR.
  ///
  /// Uses the iterative formula: `x₁ = x₀ - f(x₀)/f'(x₀)`
  ///
  /// ## Parameters
  ///
  /// - [x0]: Initial guess for XIRR (e.g., 0.1 for 10% return)
  /// - [yearsFromStart]: Normalized time in years from first cash flow
  /// - [amounts]: Cash flow amounts (negative for outflows, positive for inflows)
  ///
  /// ## Returns
  ///
  /// - **double**: Converged XIRR value if successful
  /// - **null**: Failed to converge (derivative too small, invalid solution, etc.)
  ///
  /// ## Convergence Criteria
  ///
  /// Solution is accepted if:
  /// 1. Change between iterations < tolerance (1e-7)
  /// 2. Solution > -1.0 (prevents invalid discount rates)
  /// 3. Solution is finite (not NaN or infinity)
  /// 4. NPV at solution < 0.01 (close enough to zero)
  ///
  /// ## Optimization Techniques
  ///
  /// - **Damping**: Large jumps (>1.0) are reduced to 0.5 to prevent oscillation
  /// - **Bounds checking**: x is kept in range (-0.99, 10.0) to prevent pow() errors
  /// - **Early termination**: Returns null if derivative too small (< 1e-10)
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
        if (x1 > -1.0 &&
            x1.isFinite &&
            _f(x1, yearsFromStart, amounts).abs() < 0.01) {
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

  /// Bisection method as fallback when Newton-Raphson fails to converge.
  ///
  /// Binary search algorithm that's guaranteed to find a root if one exists
  /// in the search interval. Slower than Newton-Raphson but more robust.
  ///
  /// ## Parameters
  ///
  /// - [yearsFromStart]: Normalized time in years from first cash flow
  /// - [amounts]: Cash flow amounts (negative for outflows, positive for inflows)
  ///
  /// ## Returns
  ///
  /// - **double**: XIRR value found by bisection
  /// - **null**: No root exists in search interval (falls back to approximate return)
  ///
  /// ## Algorithm
  ///
  /// 1. Start with interval [-0.99, 5.0] (i.e., -99% to 500% return)
  /// 2. Check if f(low) and f(high) have opposite signs (root exists)
  /// 3. If not, expand range to [-0.99, 10.0] and try again
  /// 4. If still no root, calculate approximate annualized return
  /// 5. Otherwise, repeatedly bisect interval until convergence
  ///
  /// ## Convergence Criteria
  ///
  /// Stops when either:
  /// - |f(mid)| < tolerance (1e-7)
  /// - Interval width < tolerance
  /// - Max iterations (200) reached
  static double? _bisection(List<double> yearsFromStart, List<double> amounts) {
    double low = -0.99;
    double high = 5.0;

    // Cache fLow to avoid recalculation in loop
    double fLow = _f(low, yearsFromStart, amounts);
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

      if (fMid.sign == fLow.sign) {
        low = mid;
        fLow = fMid;
      } else {
        high = mid;
      }
    }

    return (low + high) / 2;
  }

  /// Calculate approximate annualized return when XIRR doesn't converge.
  ///
  /// This fallback method is used when both Newton-Raphson and bisection fail,
  /// typically in edge cases like total loss or unusual cash flow patterns.
  ///
  /// ## Parameters
  ///
  /// - [yearsFromStart]: Normalized time in years from first cash flow
  /// - [amounts]: Cash flow amounts (negative for outflows, positive for inflows)
  ///
  /// ## Returns
  ///
  /// - **double**: Approximate annualized return
  /// - **null**: Invalid input (empty lists or zero outflows)
  ///
  /// ## Algorithm
  ///
  /// 1. Calculate simple return: `(totalInflows - totalOutflows) / totalOutflows`
  /// 2. Find time span in years
  /// 3. Annualize using CAGR formula: `(1 + simpleReturn)^(1/years) - 1`
  /// 4. For total loss (simpleReturn < -1), use linear annualization
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Total loss scenario: Invested ₹10,000, current value ₹0
  /// // Simple return = (0 - 10000) / 10000 = -1.0 (100% loss)
  /// // Over 2 years: annualized = -1.0 / 2 = -0.5 (50% loss per year)
  /// ```
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

  /// NPV (Net Present Value) function for XIRR calculation.
  ///
  /// Calculates the sum of discounted cash flows at a given discount rate.
  /// This is the function we're trying to find the root of (where NPV = 0).
  ///
  /// ## Formula
  ///
  /// ```
  /// NPV(x) = Σ(CFᵢ / (1 + x)^tᵢ)
  /// ```
  ///
  /// Where:
  /// - x = Discount rate (XIRR we're solving for)
  /// - CFᵢ = Cash flow at time i
  /// - tᵢ = Time in years from first cash flow
  ///
  /// ## Parameters
  ///
  /// - [x]: Discount rate to evaluate (e.g., 0.1 for 10%)
  /// - [yearsFromStart]: Time in years for each cash flow
  /// - [amounts]: Cash flow amounts
  ///
  /// ## Returns
  ///
  /// - **double**: NPV at the given discount rate
  /// - **double.infinity**: If x ≤ -1.0 (invalid discount rate)
  ///
  /// ## Example
  ///
  /// ```dart
  /// // At 10% discount rate:
  /// // NPV = -10000/(1.1)^0 + 500/(1.1)^0.5 + 11000/(1.1)^1
  /// //     = -10000 + 476.73 + 10000 = 476.73
  /// // (Positive NPV means actual return > 10%)
  /// ```
  static double _f(
    double x,
    List<double> yearsFromStart,
    List<double> amounts,
  ) {
    if (x <= -1.0) return double.infinity;

    final base = 1 + x;
    if (base <= 0) return double.infinity;

    double sum = 0.0;
    for (int i = 0; i < amounts.length; i++) {
      final power = yearsFromStart[i];
      sum += amounts[i] / pow(base, power);
    }
    return sum;
  }

  /// Calculates both NPV and its derivative in a single pass (performance optimization).
  ///
  /// This optimization reduces pow() calls by 50% compared to calculating f(x) and f'(x)
  /// separately, significantly improving Newton-Raphson performance.
  ///
  /// ## Mathematical Formulas
  ///
  /// **NPV function:**
  /// ```
  /// f(x) = Σ(CFᵢ / (1 + x)^tᵢ)
  /// ```
  ///
  /// **Derivative:**
  /// ```
  /// f'(x) = Σ(-tᵢ × CFᵢ / (1 + x)^(tᵢ+1))
  ///       = Σ(termF × -tᵢ / (1 + x))
  /// ```
  ///
  /// Where `termF = CFᵢ / (1 + x)^tᵢ` is calculated once and reused.
  ///
  /// ## Parameters
  ///
  /// - [x]: Discount rate to evaluate
  /// - [yearsFromStart]: Time in years for each cash flow
  /// - [amounts]: Cash flow amounts
  ///
  /// ## Returns
  ///
  /// A tuple `(f, f')` containing:
  /// - **f**: NPV at discount rate x
  /// - **f'**: Derivative of NPV at discount rate x
  /// - **(infinity, infinity)**: If x ≤ -1.0 (invalid discount rate)
  ///
  /// ## Performance
  ///
  /// - **Before optimization**: 2n pow() calls (n for f, n for f')
  /// - **After optimization**: n pow() calls (shared between f and f')
  /// - **Speedup**: ~2x faster Newton-Raphson iterations
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

    // Pre-calculate inverse base to replace division with multiplication in loop
    final invBase = 1.0 / base;

    for (int i = 0; i < amounts.length; i++) {
      final p = yearsFromStart[i];
      // Calculate pow once and reuse for both f and df
      // f term: amount / (1+x)^p
      // df term: amount * -p / (1+x)^(p+1) = (f term) * -p / (1+x)
      final powTerm = pow(base, p);
      final termF = amounts[i] / powTerm;

      fSum += termF;
      dfSum += termF * (-p) * invBase;
    }
    return (fSum, dfSum);
  }
}

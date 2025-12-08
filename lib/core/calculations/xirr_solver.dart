import 'dart:math';

class XirrSolver {
  static const double _tolerance = 1e-6;
  static const int _maxIterations = 100;

  /// Calculates XIRR for a series of cash flows.
  /// [dates] and [amounts] must be of the same length.
  /// Amounts should be negative for outflows (investments) and positive for inflows (returns/current value).
  static double calculateXirr(List<DateTime> dates, List<double> amounts) {
    if (dates.length != amounts.length) {
      throw ArgumentError('Dates and amounts must have the same length');
    }
    if (dates.isEmpty) return 0.0;

    // Normalize dates to days from the first date
    final firstDate = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final days = dates.map((d) => d.difference(firstDate).inDays / 365.0).toList();

    double x0 = 0.1; // Initial guess: 10%
    for (int i = 0; i < _maxIterations; i++) {
      final fValue = _f(x0, days, amounts);
      final dfValue = _df(x0, days, amounts);

      if (dfValue == 0) return 0.0; // Avoid division by zero

      final x1 = x0 - fValue / dfValue;

      if ((x1 - x0).abs() < _tolerance) {
        return x1;
      }

      x0 = x1;
    }

    return 0.0; // Failed to converge
  }

  static double _f(double x, List<double> days, List<double> amounts) {
    double sum = 0.0;
    for (int i = 0; i < amounts.length; i++) {
      sum += amounts[i] / pow(1 + x, days[i]);
    }
    return sum;
  }

  static double _df(double x, List<double> days, List<double> amounts) {
    double sum = 0.0;
    for (int i = 0; i < amounts.length; i++) {
      sum += -days[i] * amounts[i] / pow(1 + x, days[i] + 1);
    }
    return sum;
  }
}

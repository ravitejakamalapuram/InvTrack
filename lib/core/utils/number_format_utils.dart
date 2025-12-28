/// Utility functions for formatting numbers, especially financial metrics.
library;

/// Configuration for XIRR display formatting.
/// Can be extended in the future to support user preferences.
class XirrFormatConfig {
  /// Maximum decimal places for XIRR display
  final int decimalPlaces;

  /// Maximum XIRR percentage to display (values above this are considered invalid)
  /// For example, 1000 means anything above 1000% (10x annual return) is capped
  final double maxDisplayPercent;

  /// Minimum XIRR percentage to display (values below this are considered invalid)
  /// For example, -100 means anything below -100% (total loss) is capped
  final double minDisplayPercent;

  const XirrFormatConfig({
    this.decimalPlaces = 1,
    this.maxDisplayPercent = 1000.0,
    this.minDisplayPercent = -100.0,
  });

  /// Default configuration
  static const XirrFormatConfig defaultConfig = XirrFormatConfig();
}

/// Formats an XIRR value for display.
///
/// Returns a formatted string like "+25.3%" or "-12.5%", or null if the value is invalid.
///
/// [xirr] - The raw XIRR value (as a decimal, e.g., 0.25 for 25%)
/// [config] - Optional formatting configuration
/// [showSign] - Whether to show + sign for positive values
///
/// Returns null for invalid values (NaN, Infinite, out of range)
String? formatXirr(
  double xirr, {
  XirrFormatConfig config = XirrFormatConfig.defaultConfig,
  bool showSign = true,
}) {
  // Handle invalid values
  if (xirr.isNaN || xirr.isInfinite) {
    return null;
  }

  // Convert to percentage
  final xirrPercent = xirr * 100;

  // Check if within valid display range
  if (xirrPercent > config.maxDisplayPercent ||
      xirrPercent < config.minDisplayPercent) {
    return null;
  }

  // Skip near-zero values
  if (xirrPercent.abs() < 0.05) {
    return null;
  }

  // Format with configured decimal places
  final formatted = xirrPercent.toStringAsFixed(config.decimalPlaces);
  final sign = showSign && xirrPercent >= 0 ? '+' : '';
  return '$sign$formatted%';
}

/// Checks if an XIRR value is valid for display.
///
/// Returns true if the value can be meaningfully displayed.
bool isValidXirr(
  double xirr, {
  XirrFormatConfig config = XirrFormatConfig.defaultConfig,
}) {
  if (xirr.isNaN || xirr.isInfinite) return false;

  final xirrPercent = xirr * 100;
  if (xirrPercent > config.maxDisplayPercent ||
      xirrPercent < config.minDisplayPercent) {
    return false;
  }

  // Skip near-zero values
  if (xirrPercent.abs() < 0.05) return false;

  return true;
}

/// Formats a percentage value with configurable decimals.
///
/// [value] - The percentage value (e.g., 25.3 for 25.3%)
/// [decimals] - Number of decimal places (default 1)
/// [showSign] - Whether to show + sign for positive values
String formatPercent(double value, {int decimals = 1, bool showSign = false}) {
  final formatted = value.toStringAsFixed(decimals);
  final sign = showSign && value >= 0 ? '+' : '';
  return '$sign$formatted%';
}

/// Formats a multiplier (MOIC) value.
///
/// [value] - The multiplier value (e.g., 2.5 for 2.5x)
/// [decimals] - Number of decimal places (default 2)
String formatMultiplier(double value, {int decimals = 2}) {
  return '${value.toStringAsFixed(decimals)}x';
}

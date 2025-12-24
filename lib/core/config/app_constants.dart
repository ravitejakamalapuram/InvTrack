/// Application-wide configuration constants.
/// 
/// This file centralizes all configurable values that may need to be
/// adjusted or referenced across multiple parts of the application.
library;

/// Validation constants for user inputs
class ValidationConstants {
  ValidationConstants._();

  /// Maximum length for investment names
  static const int maxNameLength = 100;

  /// Maximum length for notes fields
  static const int maxNotesLength = 500;

  /// Maximum length for transaction notes
  static const int maxTransactionNotesLength = 500;

  /// Minimum investment amount
  static const double minInvestmentAmount = 0.01;
}

/// Animation duration constants
class AnimationDurations {
  AnimationDurations._();

  /// Default screen transition duration
  static const Duration screenTransition = Duration(milliseconds: 400);

  /// Shimmer effect duration for loading states
  static const Duration shimmer = Duration(milliseconds: 1500);

  /// Pulse animation duration
  static const Duration pulse = Duration(milliseconds: 1500);

  /// Floating animation duration
  static const Duration floating = Duration(milliseconds: 2000);

  /// Quick feedback animation (snackbars, toasts)
  static const Duration feedback = Duration(milliseconds: 200);

  /// Modal/dialog animation
  static const Duration modal = Duration(milliseconds: 300);
}

/// Business logic constants
class BusinessConstants {
  BusinessConstants._();

  /// Default currency code if none is set
  static const String defaultCurrencyCode = 'INR';

  /// Number of decimal places for currency display
  static const int currencyDecimalDigits = 0;

  /// Number of decimal places for precise currency display
  static const int currencyPreciseDecimalDigits = 2;

  /// Excel epoch date (1899-12-30) for serial date conversion
  static final DateTime excelEpoch = DateTime(1899, 12, 30);
}


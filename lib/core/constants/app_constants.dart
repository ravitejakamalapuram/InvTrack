/// Application-wide constants.
/// 
/// Contains configuration values, magic numbers, and other
/// constants used throughout the app.
class AppConstants {
  AppConstants._();

  /// App name displayed in UI
  static const String appName = 'InvTracker';

  /// App version
  static const String appVersion = '1.0.0';

  /// Minimum iOS version supported
  static const String minIosVersion = '13.0';

  /// Minimum Android API level supported
  static const int minAndroidSdk = 24;

  /// Default currency code
  static const String defaultCurrency = 'INR';

  /// Date format for display
  static const String dateFormat = 'dd MMM yyyy';

  /// Date format for storage
  static const String storageDateFormat = 'yyyy-MM-dd';

  /// Maximum investments allowed in free tier
  static const int maxFreeInvestments = 10;

  /// Maximum entries per investment in free tier
  static const int maxFreeEntriesPerInvestment = 50;
}


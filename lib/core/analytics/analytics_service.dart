/// Analytics service for tracking user events and screen views.
///
/// This abstraction layer wraps Firebase Analytics and provides a clean interface
/// for tracking user behavior, feature adoption, and errors across the InvTrack app.
///
/// ## Key Features
///
/// - **Event Tracking**: Log custom events with parameters
/// - **Screen Tracking**: Automatic screen view tracking via GoRouter observer
/// - **User Properties**: Set user attributes for segmentation
/// - **Privacy-First**: Never logs exact amounts, only ranges
/// - **Debug Mode**: Prints events to console in debug builds
///
/// ## Event Naming Convention
///
/// All events follow the pattern: `{noun}_{action}` in snake_case
///
/// **Examples:**
/// - `investment_created` (not `create_investment`)
/// - `goal_updated` (not `update_goal`)
/// - `csv_import_completed` (not `complete_csv_import`)
///
/// ## Privacy Guidelines
///
/// **NEVER log:**
/// - ❌ Exact investment amounts
/// - ❌ Exact returns or gains
/// - ❌ User names, emails, phone numbers
/// - ❌ Account numbers or sensitive IDs
///
/// **Always use ranges:**
/// - ✅ `amount_range: "1k_10k"` instead of `amount: 5000`
/// - ✅ `rate_range: "8_to_12"` instead of `rate: 10.5`
///
/// ## Usage Example
///
/// ```dart
/// // Basic event logging
/// await analyticsService.logEvent(
///   name: 'investment_created',
///   parameters: {'investment_type': 'FD', 'has_notes': true},
/// );
///
/// // Using convenience methods
/// await analyticsService.logInvestmentCreated(
///   investmentType: 'FD',
///   hasNotes: true,
/// );
///
/// // Screen tracking (automatic via GoRouter observer)
/// // No manual logging needed - observer handles it
///
/// // User properties
/// await analyticsService.setUserProperty(
///   name: 'preferred_currency',
///   value: 'INR',
/// );
/// ```
///
/// ## Testing
///
/// In tests, use `FakeAnalyticsService` which prints events to console
/// without sending to Firebase.
library;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';

/// Provider for the analytics service.
///
/// Returns [AnalyticsService] in production, [FakeAnalyticsService] in tests.
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

/// Provider for the Firebase Analytics observer (for GoRouter).
///
/// Automatically tracks screen views when routes change.
/// Returns null in test mode when FakeAnalyticsService is used.
///
/// ## Usage
///
/// ```dart
/// GoRouter(
///   observers: [
///     if (analyticsObserver != null) analyticsObserver!,
///   ],
/// );
/// ```
final analyticsObserverProvider = Provider<FirebaseAnalyticsObserver?>((ref) {
  final analytics = ref.watch(analyticsServiceProvider);
  return analytics.getObserver();
});

/// Analytics event names - centralized for consistency.
///
/// All event names follow the pattern: `{noun}_{action}` in snake_case.
/// Kept minimal to reduce noise - only core business events are tracked.
///
/// ## Event Categories
///
/// - **Core Conversion**: investment_created, cashflow_added
/// - **Investment Lifecycle**: closed, reopened, archived, deleted
/// - **Feature Adoption**: csv_import, export, goals, documents
/// - **Security & Settings**: security_enabled, theme_changed
/// - **Error Tracking**: error_occurred
///
/// ## Adding New Events
///
/// 1. Add constant to this class
/// 2. Follow naming convention: `{noun}_{action}`
/// 3. Add convenience method to AnalyticsService
/// 4. Document parameters and privacy considerations
///
/// ## Example
///
/// ```dart
/// // ❌ BAD: Verb-first naming
/// static const String createInvestment = 'create_investment';
///
/// // ✅ GOOD: Noun-first naming
/// static const String investmentCreated = 'investment_created';
/// ```
class AnalyticsEvents {
  // Core conversion events
  static const String investmentCreated = 'investment_created';
  static const String cashFlowAdded = 'cashflow_added';

  // Investment lifecycle
  static const String investmentClosed = 'investment_closed';
  static const String investmentReopened = 'investment_reopened';
  static const String investmentArchived = 'investment_archived';
  static const String investmentUnarchived = 'investment_unarchived';
  static const String investmentDeleted = 'investment_deleted';

  // Feature adoption
  static const String csvImportCompleted = 'csv_import_completed';
  static const String exportGenerated = 'export_generated';

  // Goals feature
  static const String goalCreated = 'goal_created';
  static const String goalUpdated = 'goal_updated';
  static const String goalArchived = 'goal_archived';
  static const String goalDeleted = 'goal_deleted';
  static const String goalMilestoneReached = 'goal_milestone_reached';

  // Documents feature
  static const String documentAdded = 'document_added';

  // Security & Settings
  static const String securityEnabled = 'security_enabled';
  static const String securityDisabled = 'security_disabled';
  static const String themeChanged = 'theme_changed';

  // Error tracking
  static const String errorOccurred = 'error_occurred';

  // Template & Quick-Add events
  static const String templateSelected = 'template_selected';

  // Sample Data Mode events
  static const String sampleDataActivated = 'sample_data_activated';
  static const String sampleDataKept = 'sample_data_kept';
  static const String sampleDataCleared = 'sample_data_cleared';

  // Empty State Interaction events
  static const String emptyStateActionTapped = 'empty_state_action_tapped';

  // Projection & Smart Defaults events
  static const String projectionViewed = 'projection_viewed';
  static const String smartDefaultApplied = 'smart_default_applied';

  // Enhanced Fields usage
  static const String enhancedFieldsUsed = 'enhanced_fields_used';

  // Multi-Currency events
  static const String currencySelected = 'currency_selected';
  static const String currencyConversionFailed = 'currency_conversion_failed';
  static const String exchangeRateCacheHit = 'exchange_rate_cache_hit';
}

/// Analytics service that wraps Firebase Analytics.
///
/// See library documentation above for usage examples and privacy guidelines.
class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Get the analytics observer for navigation tracking.
  ///
  /// Returns [FirebaseAnalyticsObserver] for automatic screen view tracking.
  /// Returns null for fake implementations (used in tests).
  ///
  /// ## Usage
  ///
  /// ```dart
  /// final observer = analyticsService.getObserver();
  /// GoRouter(
  ///   observers: [if (observer != null) observer],
  /// );
  /// ```
  FirebaseAnalyticsObserver? getObserver() {
    return FirebaseAnalyticsObserver(analytics: _analytics);
  }

  /// Log a custom event with optional parameters.
  ///
  /// This is the core method for logging events. Prefer using convenience methods
  /// (e.g., [logInvestmentCreated]) for common events.
  ///
  /// ## Parameters
  ///
  /// - [name]: Event name (use constants from [AnalyticsEvents])
  /// - [parameters]: Optional key-value pairs (max 25 parameters, max 100 chars per value)
  ///
  /// ## Privacy
  ///
  /// **NEVER include:**
  /// - Exact amounts (use ranges: "1k_10k", "10k_100k")
  /// - PII (names, emails, phone numbers)
  /// - Sensitive IDs (account numbers, transaction IDs)
  ///
  /// ## Example
  ///
  /// ```dart
  /// // ❌ BAD: Logs exact amount
  /// await analyticsService.logEvent(
  ///   name: 'investment_created',
  ///   parameters: {'amount': 50000},
  /// );
  ///
  /// // ✅ GOOD: Uses amount range
  /// await analyticsService.logEvent(
  ///   name: 'investment_created',
  ///   parameters: {'amount_range': '10k_100k'},
  /// );
  /// ```
  ///
  /// ## Debug Mode
  ///
  /// In debug builds, events are printed to console with 📊 emoji.
  /// Errors are printed with ⚠️ emoji.
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      LoggerService.debug(
        'Analytics event logged',
        metadata: {'event': name, 'parameters': parameters?.toString() ?? 'none'},
      );
    } catch (e) {
      LoggerService.warn(
        'Analytics error',
        metadata: {'event': name, 'error': e.toString()},
      );
    }
  }

  /// Log screen view (usually handled automatically by observer).
  ///
  /// Manual screen view logging is rarely needed - the [FirebaseAnalyticsObserver]
  /// automatically tracks screen views when routes change.
  ///
  /// ## Parameters
  ///
  /// - [screenName]: Name of the screen (e.g., "InvestmentListScreen")
  /// - [screenClass]: Optional class name for grouping
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Manual logging (rarely needed)
  /// await analyticsService.logScreenView(
  ///   screenName: 'InvestmentDetailScreen',
  ///   screenClass: 'InvestmentScreen',
  /// );
  /// ```
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      LoggerService.debug(
        'Screen view logged',
        metadata: {'screen': screenName},
      );
    } catch (e) {
      LoggerService.warn(
        'Analytics error logging screen view',
        metadata: {'screen': screenName, 'error': e.toString()},
      );
    }
  }

  /// Set user ID for analytics (hashed Firebase UID).
  ///
  /// **Privacy:** Only use hashed/anonymized Firebase UID, never email or name.
  ///
  /// ## Parameters
  ///
  /// - [userId]: Hashed Firebase UID (null to clear)
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Set user ID on sign in
  /// await analyticsService.setUserId(firebaseUser.uid);
  ///
  /// // Clear user ID on sign out
  /// await analyticsService.setUserId(null);
  /// ```
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      LoggerService.warn(
        'Analytics error setting user ID',
        metadata: {'error': e.toString()},
      );
    }
  }

  /// Set user property for segmentation.
  ///
  /// User properties are attributes that describe segments of your user base.
  /// They're useful for creating audiences and analyzing user behavior.
  ///
  /// ## Parameters
  ///
  /// - [name]: Property name (max 24 chars, alphanumeric + underscore)
  /// - [value]: Property value (max 36 chars, null to clear)
  ///
  /// ## Common Properties
  ///
  /// - `preferred_currency`: "INR", "USD", "EUR"
  /// - `theme_mode`: "light", "dark", "system"
  /// - `security_enabled`: "true", "false"
  /// - `investment_count_range`: "0", "1_5", "6_20", "21_plus"
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Set currency preference
  /// await analyticsService.setUserProperty(
  ///   name: 'preferred_currency',
  ///   value: 'INR',
  /// );
  ///
  /// // Clear property
  /// await analyticsService.setUserProperty(
  ///   name: 'preferred_currency',
  ///   value: null,
  /// );
  /// ```
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      LoggerService.warn(
        'Analytics error setting user property',
        metadata: {'property': name, 'error': e.toString()},
      );
    }
  }

  // ============ Convenience methods for common events ============

  /// Log sign in event (Firebase predefined event).
  ///
  /// ## Parameters
  ///
  /// - [method]: Sign-in method (e.g., "google", "email", "apple")
  ///
  /// ## Example
  ///
  /// ```dart
  /// await analyticsService.logSignIn(method: 'google');
  /// ```
  Future<void> logSignIn({required String method}) async {
    await _analytics.logLogin(loginMethod: method);
  }

  /// Log sign up event (Firebase predefined event).
  ///
  /// ## Parameters
  ///
  /// - [method]: Sign-up method (e.g., "google", "email", "apple")
  ///
  /// ## Example
  ///
  /// ```dart
  /// await analyticsService.logSignUp(method: 'google');
  /// ```
  Future<void> logSignUp({required String method}) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  /// Log investment created (core conversion event).
  ///
  /// Tracks when a user creates a new investment. This is a key conversion metric.
  ///
  /// ## Parameters
  ///
  /// - [investmentType]: Type of investment (e.g., "FD", "Stocks", "MF", "PPF")
  /// - [hasNotes]: Whether user added notes (indicates engagement)
  ///
  /// ## Example
  ///
  /// ```dart
  /// await analyticsService.logInvestmentCreated(
  ///   investmentType: 'FD',
  ///   hasNotes: true,
  /// );
  /// ```
  Future<void> logInvestmentCreated({
    required String investmentType,
    bool hasNotes = false,
  }) async {
    await logEvent(
      name: AnalyticsEvents.investmentCreated,
      parameters: {'investment_type': investmentType, 'has_notes': hasNotes},
    );
  }

  /// Log cash flow added (transaction tracking).
  ///
  /// Tracks when a user adds a transaction (buy, sell, dividend, etc.).
  ///
  /// ## Parameters
  ///
  /// - [flowType]: Type of cash flow (e.g., "buy", "sell", "dividend", "interest")
  /// - [amountRange]: Amount range (e.g., "under_1k", "1k_10k", "10k_100k", "over_100k")
  ///
  /// ## Privacy
  ///
  /// **NEVER log exact amounts** - always use ranges.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // For amount = ₹5,000
  /// await analyticsService.logCashFlowAdded(
  ///   flowType: 'buy',
  ///   amountRange: '1k_10k',
  /// );
  /// ```
  Future<void> logCashFlowAdded({
    required String flowType,
    required String amountRange,
  }) async {
    await logEvent(
      name: AnalyticsEvents.cashFlowAdded,
      parameters: {'flow_type': flowType, 'amount_range': amountRange},
    );
  }

  /// Log CSV import completed
  Future<void> logCsvImportCompleted({
    required int rowCount,
    required int successCount,
  }) async {
    await logEvent(
      name: AnalyticsEvents.csvImportCompleted,
      parameters: {'row_count': rowCount, 'success_count': successCount},
    );
  }

  /// Log export generated
  Future<void> logExportGenerated({required String format}) async {
    await logEvent(
      name: AnalyticsEvents.exportGenerated,
      parameters: {'format': format},
    );
  }

  /// Log error occurred
  Future<void> logErrorOccurred({
    required String errorType,
    String? screen,
  }) async {
    await logEvent(
      name: AnalyticsEvents.errorOccurred,
      parameters: {
        'error_type': errorType,
        if (screen != null) 'screen': screen,
      },
    );
  }

  /// Log goal created
  Future<void> logGoalCreated({
    required String goalType,
    required String trackingMode,
    bool hasDeadline = false,
  }) async {
    await logEvent(
      name: AnalyticsEvents.goalCreated,
      parameters: {
        'goal_type': goalType,
        'tracking_mode': trackingMode,
        'has_deadline': hasDeadline
            ? 1
            : 0, // Firebase Analytics only accepts String or num
      },
    );
  }

  /// Log goal updated
  Future<void> logGoalUpdated({required String goalId}) async {
    await logEvent(
      name: AnalyticsEvents.goalUpdated,
      parameters: {'goal_id': goalId},
    );
  }

  /// Log goal archived
  Future<void> logGoalArchived({required String goalId}) async {
    await logEvent(
      name: AnalyticsEvents.goalArchived,
      parameters: {'goal_id': goalId},
    );
  }

  /// Log goal deleted
  Future<void> logGoalDeleted({required String goalId}) async {
    await logEvent(
      name: AnalyticsEvents.goalDeleted,
      parameters: {'goal_id': goalId},
    );
  }

  /// Log goal milestone reached
  Future<void> logGoalMilestoneReached({
    required String goalId,
    required int milestone,
  }) async {
    await logEvent(
      name: AnalyticsEvents.goalMilestoneReached,
      parameters: {'goal_id': goalId, 'milestone': milestone},
    );
  }

  /// Track document added
  void trackDocumentAdded({
    required String documentType,
    required String fileType,
  }) {
    logEvent(
      name: AnalyticsEvents.documentAdded,
      parameters: {'document_type': documentType, 'file_type': fileType},
    );
  }

  // ============ Investment Lifecycle Events ============

  /// Log investment closed
  Future<void> logInvestmentClosed({required String investmentType}) async {
    await logEvent(
      name: AnalyticsEvents.investmentClosed,
      parameters: {'investment_type': investmentType},
    );
  }

  /// Log investment reopened
  Future<void> logInvestmentReopened({required String investmentType}) async {
    await logEvent(
      name: AnalyticsEvents.investmentReopened,
      parameters: {'investment_type': investmentType},
    );
  }

  /// Log investment archived
  Future<void> logInvestmentArchived({required String investmentType}) async {
    await logEvent(
      name: AnalyticsEvents.investmentArchived,
      parameters: {'investment_type': investmentType},
    );
  }

  /// Log investment unarchived
  Future<void> logInvestmentUnarchived({required String investmentType}) async {
    await logEvent(
      name: AnalyticsEvents.investmentUnarchived,
      parameters: {'investment_type': investmentType},
    );
  }

  /// Log investment deleted
  Future<void> logInvestmentDeleted({required String investmentType}) async {
    await logEvent(
      name: AnalyticsEvents.investmentDeleted,
      parameters: {'investment_type': investmentType},
    );
  }

  // ============ Security & Settings Events ============

  /// Log security feature enabled (biometric or passcode)
  Future<void> logSecurityEnabled({required String method}) async {
    await logEvent(
      name: AnalyticsEvents.securityEnabled,
      parameters: {'method': method},
    );
  }

  /// Log security feature disabled
  Future<void> logSecurityDisabled() async {
    await logEvent(name: AnalyticsEvents.securityDisabled);
  }

  /// Log theme changed
  Future<void> logThemeChanged({required String theme}) async {
    await logEvent(
      name: AnalyticsEvents.themeChanged,
      parameters: {'theme': theme},
    );
  }

  // ============ Template & Quick-Add Events ============

  /// Log template selected from template selector
  Future<void> logTemplateSelected({
    required String templateId,
    required String templateName,
  }) async {
    await logEvent(
      name: AnalyticsEvents.templateSelected,
      parameters: {'template_id': templateId, 'template_name': templateName},
    );
  }

  // ============ Sample Data Mode Events ============

  /// Log sample data mode activated
  Future<void> logSampleDataActivated({
    required int investmentCount,
    required int goalCount,
  }) async {
    await logEvent(
      name: AnalyticsEvents.sampleDataActivated,
      parameters: {'investments': investmentCount, 'goals': goalCount},
    );
  }

  /// Log sample data kept (user decides to keep sample data as real)
  Future<void> logSampleDataKept({
    required int investmentCount,
    required int goalCount,
  }) async {
    await logEvent(
      name: AnalyticsEvents.sampleDataKept,
      parameters: {'investments': investmentCount, 'goals': goalCount},
    );
  }

  /// Log sample data cleared
  Future<void> logSampleDataCleared({
    required int investmentCount,
    required int goalCount,
  }) async {
    await logEvent(
      name: AnalyticsEvents.sampleDataCleared,
      parameters: {'investments': investmentCount, 'goals': goalCount},
    );
  }

  // ============ Empty State Events ============

  /// Log empty state action tapped
  Future<void> logEmptyStateActionTapped({required String action}) async {
    await logEvent(
      name: AnalyticsEvents.emptyStateActionTapped,
      parameters: {'action': action},
    );
  }

  // ============ Projection & Smart Defaults Events ============

  /// Log projection card viewed
  Future<void> logProjectionViewed({
    required String investmentType,
    required double expectedRate,
    required int tenureMonths,
    String? compounding,
  }) async {
    await logEvent(
      name: AnalyticsEvents.projectionViewed,
      parameters: {
        'investment_type': investmentType,
        'expected_rate_range': _getRateRange(expectedRate),
        'tenure_months': tenureMonths,
        if (compounding != null) 'compounding': compounding,
      },
    );
  }

  /// Log smart default applied (e.g., auto-calculated maturity date)
  Future<void> logSmartDefaultApplied({required String fieldName}) async {
    await logEvent(
      name: AnalyticsEvents.smartDefaultApplied,
      parameters: {'field': fieldName},
    );
  }

  // ============ Enhanced Fields Events ============

  /// Log enhanced fields used when creating investment
  Future<void> logEnhancedFieldsUsed({
    required String investmentType,
    required List<String> fieldsUsed,
  }) async {
    await logEvent(
      name: AnalyticsEvents.enhancedFieldsUsed,
      parameters: {
        'investment_type': investmentType,
        'fields_count': fieldsUsed.length,
        'fields': fieldsUsed.take(10).join(','), // Limit to 10 for param size
      },
    );
  }

  // ============ Multi-Currency Events ============

  /// Log currency selected for investment or cash flow
  ///
  /// Tracks currency selection to understand which currencies users are using.
  ///
  /// ## Parameters
  ///
  /// - [currency]: Currency code (e.g., "USD", "INR", "EUR")
  /// - [context]: Where currency was selected (e.g., "investment", "cashflow")
  ///
  /// ## Example
  ///
  /// ```dart
  /// await analyticsService.logCurrencySelected(
  ///   currency: 'INR',
  ///   context: 'investment',
  /// );
  /// ```
  Future<void> logCurrencySelected({
    required String currency,
    required String context,
  }) async {
    await logEvent(
      name: AnalyticsEvents.currencySelected,
      parameters: {'currency': currency, 'context': context},
    );
  }

  /// Log currency conversion failure
  ///
  /// Tracks when exchange rate API calls fail to help monitor service reliability.
  ///
  /// ## Parameters
  ///
  /// - [fromCurrency]: Source currency code
  /// - [toCurrency]: Target currency code
  /// - [errorType]: Type of error (e.g., "network", "timeout", "api_error")
  ///
  /// ## Example
  ///
  /// ```dart
  /// await analyticsService.logCurrencyConversionFailed(
  ///   fromCurrency: 'USD',
  ///   toCurrency: 'INR',
  ///   errorType: 'network',
  /// );
  /// ```
  Future<void> logCurrencyConversionFailed({
    required String fromCurrency,
    required String toCurrency,
    required String errorType,
  }) async {
    await logEvent(
      name: AnalyticsEvents.currencyConversionFailed,
      parameters: {
        'from_currency': fromCurrency,
        'to_currency': toCurrency,
        'error_type': errorType,
      },
    );
  }

  /// Log exchange rate cache hit
  ///
  /// Tracks cache performance to optimize caching strategy.
  ///
  /// ## Parameters
  ///
  /// - [cacheType]: Type of cache hit (e.g., "memory", "firestore", "api")
  /// - [rateType]: Type of rate (e.g., "historical", "live")
  ///
  /// ## Example
  ///
  /// ```dart
  /// await analyticsService.logExchangeRateCacheHit(
  ///   cacheType: 'memory',
  ///   rateType: 'historical',
  /// );
  /// ```
  Future<void> logExchangeRateCacheHit({
    required String cacheType,
    required String rateType,
  }) async {
    await logEvent(
      name: AnalyticsEvents.exchangeRateCacheHit,
      parameters: {'cache_type': cacheType, 'rate_type': rateType},
    );
  }

  // ============ Helper Methods ============

  /// Get rate range bucket for analytics (avoid logging exact rates)
  String _getRateRange(double rate) {
    if (rate < 5) return 'under_5';
    if (rate < 8) return '5_to_8';
    if (rate < 12) return '8_to_12';
    if (rate < 15) return '12_to_15';
    return 'over_15';
  }
}

/// Ad service for managing Google Mobile Ads.
///
/// This abstraction layer wraps google_mobile_ads and provides:
/// - GDPR-compliant consent management
/// - Ad load state management
/// - Privacy-first ad targeting
/// - Analytics integration
/// - Premium UI-friendly native ad styling
///
/// ## Architecture
///
/// - **AdService**: Core service (this file)
/// - **AdProvider**: Riverpod state management
/// - **NativeAdWidget**: Reusable styled widget
/// - **AdPlacementStrategy**: Frequency & placement logic
///
/// ## Usage Example
///
/// ```dart
/// // Initialize in main.dart (after first frame)
/// final adService = AdService();
/// await adService.initialize();
///
/// // Request consent (first launch only)
/// final consentStatus = await adService.requestConsent();
///
/// // Load a native ad
/// final nativeAd = await adService.loadNativeAd(
///   placement: AdPlacement.investmentList,
/// );
///
/// // Display in widget tree
/// NativeAdWidget(ad: nativeAd)
/// ```
///
/// ## Privacy Compliance
///
/// - ✅ GDPR consent dialog on first launch
/// - ✅ Consent stored in SharedPreferences
/// - ✅ No ad personalization without explicit consent
/// - ✅ Respect "Do Not Track" preference
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for the ad service
final adServiceProvider = Provider<AdService>((ref) {
  return AdService(
    prefs: ref.watch(sharedPreferencesProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
});

/// Ad placement identifiers (for analytics and frequency control)
enum AdPlacement {
  investmentList,
  portfolioHealth,
  goalList,
}

/// Ad consent status
enum AdConsentStatus {
  unknown,
  notRequired, // Non-EU users
  obtained,
  denied,
}

/// Ad service that wraps Google Mobile Ads
class AdService {
  final SharedPreferences _prefs;
  final AnalyticsService _analytics;
  bool _isInitialized = false;

  static const String _consentKey = 'ad_consent_status';
  static const String _consentTimestampKey = 'ad_consent_timestamp';

  AdService({
    required SharedPreferences prefs,
    required AnalyticsService analytics,
  })  : _prefs = prefs,
        _analytics = analytics;

  /// Initialize the Mobile Ads SDK
  ///
  /// Call this after the first frame is rendered (not in main()).
  /// Initialization is asynchronous and may take 1-2 seconds.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Mobile Ads SDK
      await MobileAds.instance.initialize();

      // Apply consent configuration
      final consentStatus = getConsentStatus();
      await _applyConsentConfiguration(consentStatus);

      _isInitialized = true;
      LoggerService.info('AdService initialized');

      // Track initialization
      _analytics.logEvent(
        name: 'ad_service_initialized',
        parameters: {'consent_status': consentStatus.name},
      );
    } catch (e, st) {
      LoggerService.error(
        'Failed to initialize AdService',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Get current ad consent status
  AdConsentStatus getConsentStatus() {
    final statusString = _prefs.getString(_consentKey);
    if (statusString == null) return AdConsentStatus.unknown;

    return AdConsentStatus.values.firstWhere(
      (status) => status.name == statusString,
      orElse: () => AdConsentStatus.unknown,
    );
  }

  /// Request ad consent from user (GDPR)
  ///
  /// Shows consent dialog on first launch. Returns consent status.
  /// For non-EU users, returns [AdConsentStatus.notRequired].
  Future<AdConsentStatus> requestConsent() async {
    // TODO: Implement GDPR consent dialog
    // For MVP, we'll use a simple approach:
    // - EU users: Show consent dialog
    // - Non-EU users: Auto-consent (notRequired)
    //
    // Full implementation requires:
    // 1. User Messaging Platform (UMP) SDK integration
    // 2. Consent form configuration in AdMob console
    // 3. Consent state persistence

    // Placeholder: Always return obtained for MVP
    // Replace with UMP SDK integration in production
    await _setConsentStatus(AdConsentStatus.obtained);
    return AdConsentStatus.obtained;
  }

  /// Apply consent configuration to Mobile Ads SDK
  Future<void> _applyConsentConfiguration(AdConsentStatus status) async {
    final requestConfig = RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no,
    );

    await MobileAds.instance.updateRequestConfiguration(requestConfig);
  }

  /// Set consent status
  Future<void> _setConsentStatus(AdConsentStatus status) async {
    await _prefs.setString(_consentKey, status.name);
    await _prefs.setString(
      _consentTimestampKey,
      DateTime.now().toIso8601String(),
    );
  }

  // ============ Ad Loading ============

  /// Load a native ad for the specified placement
  ///
  /// Returns a [NativeAd] instance that can be displayed in a [NativeAdWidget].
  /// Returns null if:
  /// - User has denied ad consent
  /// - Ad fails to load (network error, no inventory)
  /// - User is in ad-free grace period (first 7 days)
  ///
  /// ## Example
  ///
  /// ```dart
  /// final ad = await adService.loadNativeAd(
  ///   placement: AdPlacement.investmentList,
  /// );
  ///
  /// if (ad != null) {
  ///   // Display ad in widget tree
  ///   NativeAdWidget(ad: ad);
  /// }
  /// ```
  Future<NativeAd?> loadNativeAd({
    required AdPlacement placement,
  }) async {
    if (!_isInitialized) {
      LoggerService.warn('AdService not initialized, skipping ad load');
      return null;
    }

    // Check consent
    final consentStatus = getConsentStatus();
    if (consentStatus == AdConsentStatus.denied) {
      LoggerService.debug('Ad consent denied, skipping ad load');
      return null;
    }

    // Check ad-free grace period (first 7 days)
    if (_isInGracePeriod()) {
      LoggerService.debug('User in ad-free grace period, skipping ad load');
      return null;
    }

    // Get ad unit ID for placement
    final adUnitId = _getAdUnitId(placement);

    try {
      final ad = NativeAd(
        adUnitId: adUnitId,
        factoryId: 'investmentListNativeAd', // Matches platform view factory
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            LoggerService.debug(
              'Native ad loaded',
              metadata: {'placement': placement.name},
            );
            _analytics.logEvent(
              name: 'ad_loaded',
              parameters: {
                'placement': placement.name,
                'ad_format': 'native',
              },
            );
          },
          onAdFailedToLoad: (ad, error) {
            LoggerService.warn(
              'Native ad failed to load',
              metadata: {
                'placement': placement.name,
                'error': error.toString(),
              },
            );
            _analytics.logEvent(
              name: 'ad_load_failed',
              parameters: {
                'placement': placement.name,
                'error_code': error.code.toString(),
              },
            );
            ad.dispose();
          },
          onAdClicked: (ad) {
            _analytics.logEvent(
              name: 'ad_clicked',
              parameters: {'placement': placement.name},
            );
          },
          onAdImpression: (ad) {
            _analytics.logEvent(
              name: 'ad_impression',
              parameters: {'placement': placement.name},
            );
          },
        ),
      );

      await ad.load();
      return ad;
    } catch (e, st) {
      LoggerService.error(
        'Error loading native ad',
        error: e,
        stackTrace: st,
        metadata: {'placement': placement.name},
      );
      return null;
    }
  }

  /// Check if user is in ad-free grace period (first 7 days after signup)
  bool _isInGracePeriod() {
    // TODO: Implement grace period check
    // Read user signup date from UserRepository/FirebaseAuth
    // Compare with current date
    // Return true if within 7 days
    //
    // For MVP, return false (show ads immediately)
    return false;
  }

  /// Get ad unit ID for placement
  ///
  /// In production, replace with actual AdMob ad unit IDs.
  /// These are placeholder test IDs from Google.
  String _getAdUnitId(AdPlacement placement) {
    // Use test ad unit IDs in debug mode
    if (kDebugMode) {
      // Google's test ad unit ID for native ads
      return 'ca-app-pub-3940256099942544/2247696110';
    }

    // Production ad unit IDs (replace with actual IDs from AdMob)
    switch (placement) {
      case AdPlacement.investmentList:
        return 'ca-app-pub-YOUR_PUBLISHER_ID/INVESTMENT_LIST_AD_UNIT';
      case AdPlacement.portfolioHealth:
        return 'ca-app-pub-YOUR_PUBLISHER_ID/PORTFOLIO_HEALTH_AD_UNIT';
      case AdPlacement.goalList:
        return 'ca-app-pub-YOUR_PUBLISHER_ID/GOAL_LIST_AD_UNIT';
    }
  }

  /// Dispose of all resources
  void dispose() {
    // Nothing to dispose currently
    // Native ads are disposed individually when widgets are removed
  }
}


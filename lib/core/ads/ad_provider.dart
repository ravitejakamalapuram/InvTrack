/// Riverpod providers for ad state management.
///
/// Manages the lifecycle and state of ads across the app.
/// Provides reactive access to ad loading state and consent status.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:inv_tracker/core/ads/ad_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';

/// State for a single native ad
class NativeAdState {
  final NativeAd? ad;
  final bool isLoading;
  final String? error;
  final AdPlacement placement;

  const NativeAdState({
    this.ad,
    this.isLoading = false,
    this.error,
    required this.placement,
  });

  bool get hasAd => ad != null;
  bool get hasError => error != null;

  NativeAdState copyWith({
    NativeAd? ad,
    bool? isLoading,
    String? error,
    AdPlacement? placement,
  }) {
    return NativeAdState(
      ad: ad ?? this.ad,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      placement: placement ?? this.placement,
    );
  }
}

/// Simplified provider for ad state - using Provider.family instead of complex Notifier
/// This is simpler and works well for ad loading which is async/one-time
final nativeAdProvider = Provider.family.autoDispose<AsyncValue<NativeAd?>, AdPlacement>((ref, placement) {
  return const AsyncValue.loading();
});

/// Helper to load an ad for a given placement
Future<NativeAd?> loadNativeAd(WidgetRef ref, AdPlacement placement) async {
  final adService = ref.read(adServiceProvider);
  try {
    return await adService.loadNativeAd(placement: placement);
  } catch (e, st) {
    LoggerService.error(
      'Error loading ad',
      error: e,
      stackTrace: st,
      metadata: {'placement': placement.name},
    );
    return null;
  }
}

/// Provider for ad consent status
final adConsentStatusProvider = Provider<AdConsentStatus>((ref) {
  final adService = ref.watch(adServiceProvider);
  return adService.getConsentStatus();
});

/// Provider for checking if ads should be shown
///
/// Returns false if:
/// - User denied consent
/// - User is in grace period (first 7 days)
final shouldShowAdsProvider = Provider<bool>((ref) {
  final consentStatus = ref.watch(adConsentStatusProvider);
  
  // Don't show ads if consent denied
  if (consentStatus == AdConsentStatus.denied) {
    return false;
  }

  // TODO: Add grace period check when user repository is available
  // final user = ref.watch(currentUserProvider);
  // if (user != null && _isInGracePeriod(user.signupDate)) {
  //   return false;
  // }

  return true;
});

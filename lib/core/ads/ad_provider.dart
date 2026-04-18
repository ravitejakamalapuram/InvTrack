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

/// Notifier for managing native ad state
class NativeAdNotifier extends StateNotifier<NativeAdState> {
  final AdService _adService;

  NativeAdNotifier({
    required AdService adService,
    required AdPlacement placement,
  })  : _adService = adService,
        super(NativeAdState(placement: placement));

  /// Load the ad
  Future<void> loadAd() async {
    if (state.isLoading || state.hasAd) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final ad = await _adService.loadNativeAd(placement: state.placement);

      if (ad != null) {
        state = state.copyWith(ad: ad, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load ad',
        );
      }
    } catch (e, st) {
      LoggerService.error(
        'Error loading ad',
        error: e,
        stackTrace: st,
        metadata: {'placement': state.placement.name},
      );
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Dispose of the ad
  void disposeAd() {
    state.ad?.dispose();
    state = NativeAdState(placement: state.placement);
  }

  @override
  void dispose() {
    disposeAd();
    super.dispose();
  }
}

/// Provider family for native ad state (one per placement)
final nativeAdProvider = StateNotifierProvider.family<
    NativeAdNotifier,
    NativeAdState,
    AdPlacement>(
  (ref, placement) {
    final adService = ref.watch(adServiceProvider);
    return NativeAdNotifier(
      adService: adService,
      placement: placement,
    );
  },
);

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

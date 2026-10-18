/// Native ad widget styled to match InvTrack's Premium UI.
///
/// Displays Google Mobile Ads native ads with:
/// - Clean, minimal design matching app aesthetic
/// - Light/Dark mode support
/// - Proper spacing and borders
/// - "Ad" label for transparency
/// - Error state handling
/// - Loading state shimmer
///
/// ## Usage Example
///
/// ```dart
/// final adState = ref.watch(nativeAdProvider(AdPlacement.investmentList));
///
/// if (adState.hasAd) {
///   NativeAdWidget(adState: adState);
/// } else if (adState.isLoading) {
///   NativeAdLoadingWidget();
/// }
/// ```
library;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:inv_tracker/core/ads/ad_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// Widget that displays a native ad
class NativeAdWidget extends StatelessWidget {
  final NativeAdState adState;

  const NativeAdWidget({
    super.key,
    required this.adState,
  });

  @override
  Widget build(BuildContext context) {
    if (!adState.hasAd) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.neutral800Dark : AppColors.neutral100Light,
        borderRadius: AppSizes.borderRadiusMd,
        border: Border.all(
          color: isDark
              ? AppColors.neutral700Dark
              : AppColors.neutral200Light,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Ad" label (REQUIRED by Google Ads policy)
          Padding(
            padding: EdgeInsets.all(AppSpacing.xs),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.neutral700Dark
                    : AppColors.neutral200Light,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Ad',
                style: AppTypography.caption.copyWith(
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral600Light,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Native ad content
          SizedBox(
            height: 300, // Standard height for medium template
            child: AdWidget(ad: adState.ad!),
          ),
        ],
      ),
    );
  }
}

/// Loading state widget (shimmer effect)
class NativeAdLoadingWidget extends StatelessWidget {
  const NativeAdLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      height: 320, // Match ad height + label
      decoration: BoxDecoration(
        color: isDark ? AppColors.neutral800Dark : AppColors.neutral100Light,
        borderRadius: AppSizes.borderRadiusMd,
        border: Border.all(
          color: isDark
              ? AppColors.neutral700Dark
              : AppColors.neutral200Light,
          width: 1,
        ),
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryLight,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

/// Error state widget (when ad fails to load)
class NativeAdErrorWidget extends StatelessWidget {
  final String? error;

  const NativeAdErrorWidget({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    // Don't show error state - just return empty space
    // Ads failing to load should be silent (no visual disruption)
    return const SizedBox.shrink();

    // Debug-only error display (commented out for production)
    // return Container(
    //   margin: EdgeInsets.symmetric(
    //     horizontal: AppSpacing.md,
    //     vertical: AppSpacing.sm,
    //   ),
    //   padding: EdgeInsets.all(AppSpacing.md),
    //   decoration: BoxDecoration(
    //     color: AppColors.errorLight.withOpacity(0.1),
    //     borderRadius: AppSizes.borderRadiusMd,
    //     border: Border.all(color: AppColors.errorLight, width: 1),
    //   ),
    //   child: Text('Ad failed to load: $error'),
    // );
  }
}

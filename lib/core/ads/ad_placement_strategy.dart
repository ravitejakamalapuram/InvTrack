/// Ad placement strategy for controlling ad frequency and positioning.
///
/// Implements InvTrack's "Premium UI" ad policy:
/// - 1 ad per 10 investments in Investment List
/// - 1 ad at bottom of Portfolio Health screen
/// - 1 ad per 5 goals in Goals List
/// - No ads in FIRE Number dashboard
/// - No ads in Settings/Security
///
/// ## Usage Example
///
/// ```dart
/// // In InvestmentListScreen
/// final shouldShowAd = AdPlacementStrategy.shouldShowInvestmentListAd(
///   investmentCount: investments.length,
///   scrollPosition: 15, // User scrolled past 15 items
/// );
///
/// if (shouldShowAd) {
///   NativeAdWidget(adState: adState);
/// }
/// ```
library;

import 'package:inv_tracker/core/ads/ad_service.dart';

/// Ad placement strategy
class AdPlacementStrategy {
  /// Ad frequency for investment list (1 per N investments)
  static const int investmentListFrequency = 10;

  /// Ad frequency for goal list (1 per N goals)
  static const int goalListFrequency = 5;

  /// Minimum scroll position to show first ad (avoid immediate ad on screen load)
  static const int minScrollPositionForFirstAd = 3;

  /// Check if ad should be shown in investment list
  ///
  /// Shows ad every 10 investments, starting after the 3rd investment.
  ///
  /// ## Example
  ///
  /// - 0-2 investments: No ad
  /// - 3-9 investments: No ad
  /// - 10 investments: Show ad at position 10
  /// - 20 investments: Show ad at position 20
  /// - 25 investments: Show ad at position 20 (not 25, waits for 30)
  static bool shouldShowInvestmentListAd({
    required int investmentCount,
    required int position,
  }) {
    // Don't show ad until user has scrolled past min position
    if (position < minScrollPositionForFirstAd) {
      return false;
    }

    // Don't show ad if not enough investments
    if (investmentCount < investmentListFrequency) {
      return false;
    }

    // Show ad every 10 investments
    return position > 0 &&
        position % investmentListFrequency == 0 &&
        position <= investmentCount;
  }

  /// Get ad insertion position for investment list
  ///
  /// Returns the list of positions where ads should be inserted.
  ///
  /// ## Example
  ///
  /// - 25 investments → [10, 20]
  /// - 35 investments → [10, 20, 30]
  static List<int> getInvestmentListAdPositions(int investmentCount) {
    final positions = <int>[];

    for (int i = investmentListFrequency;
        i <= investmentCount;
        i += investmentListFrequency) {
      positions.add(i);
    }

    return positions;
  }

  /// Check if ad should be shown in goal list
  ///
  /// Shows ad every 5 goals, starting after the 2nd goal.
  static bool shouldShowGoalListAd({
    required int goalCount,
    required int position,
  }) {
    if (position < 2) {
      return false;
    }

    if (goalCount < goalListFrequency) {
      return false;
    }

    return position > 0 &&
        position % goalListFrequency == 0 &&
        position <= goalCount;
  }

  /// Get ad insertion position for goal list
  static List<int> getGoalListAdPositions(int goalCount) {
    final positions = <int>[];

    for (int i = goalListFrequency;
        i <= goalCount;
        i += goalListFrequency) {
      positions.add(i);
    }

    return positions;
  }

  /// Check if ad should be shown in Portfolio Health screen
  ///
  /// Shows single ad at the bottom of the screen.
  static bool shouldShowPortfolioHealthAd() {
    // Always show ad at bottom of Portfolio Health
    // (User has scrolled to see full dashboard - engaged user)
    return true;
  }

  /// Get ad placement type for a given screen
  static AdPlacement? getPlacementForScreen(String screenName) {
    switch (screenName) {
      case 'InvestmentListScreen':
        return AdPlacement.investmentList;
      case 'PortfolioHealthDetailsScreen':
        return AdPlacement.portfolioHealth;
      case 'GoalsScreen':
        return AdPlacement.goalList;
      default:
        return null; // No ads for other screens
    }
  }

  /// Check if screen should never show ads
  ///
  /// These screens are "premium" and never show ads:
  /// - FIRE Number dashboard
  /// - Settings
  /// - Security/Passcode screens
  /// - Onboarding
  static bool isAdFreeScreen(String screenName) {
    const adFreeScreens = {
      'FireDashboardScreen',
      'FireSetupScreen',
      'FireSettingsScreen',
      'SettingsScreen',
      'PasscodeScreen',
      'SecuritySettingsScreen',
      'OnboardingScreen',
      'SignInScreen',
    };

    return adFreeScreens.contains(screenName);
  }
}

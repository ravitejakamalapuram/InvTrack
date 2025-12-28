import 'package:flutter/material.dart';

/// Centralized size constants for UI components.
/// Ensures consistent sizing across all screens.
///
/// Usage:
/// ```dart
/// Container(height: AppSizes.buttonHeight)
/// BorderRadius.circular(AppSizes.radiusMd)
/// Icon(Icons.add, size: AppSizes.iconMd)
/// ```
class AppSizes {
  // ============================================
  // BORDER RADIUS
  // ============================================

  /// 4px - Extra small radius (chips, tags)
  static const double radiusXs = 4.0;

  /// 8px - Small radius (small buttons, inputs)
  static const double radiusSm = 8.0;

  /// 12px - Medium radius (buttons, cards)
  static const double radiusMd = 12.0;

  /// 16px - Large radius (cards, modals)
  static const double radiusLg = 16.0;

  /// 20px - Extra large radius (bottom sheets, large cards)
  static const double radiusXl = 20.0;

  /// 24px - Extra extra large radius (modals, special cards)
  static const double radiusXxl = 24.0;

  /// 28px - Huge radius (bottom sheet handles)
  static const double radiusHuge = 28.0;

  /// Full round (circular elements)
  static const double radiusFull = 999.0;

  // ============================================
  // BORDER RADIUS PRESETS
  // ============================================

  static BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  static BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);
  static BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);
  static BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);
  static BorderRadius get borderRadiusXxl => BorderRadius.circular(radiusXxl);

  // ============================================
  // BUTTON HEIGHTS
  // ============================================

  /// 36px - Small button height
  static const double buttonHeightSm = 36.0;

  /// 44px - Medium button height
  static const double buttonHeightMd = 44.0;

  /// 52px - Large button height
  static const double buttonHeightLg = 52.0;

  /// 56px - Extra large button height (primary actions)
  static const double buttonHeightXl = 56.0;

  // ============================================
  // ICON SIZES
  // ============================================

  /// 16px - Extra small icon
  static const double iconXs = 16.0;

  /// 20px - Small icon (in buttons, list items)
  static const double iconSm = 20.0;

  /// 24px - Medium icon (standard)
  static const double iconMd = 24.0;

  /// 28px - Large icon
  static const double iconLg = 28.0;

  /// 32px - Extra large icon
  static const double iconXl = 32.0;

  /// 48px - Huge icon (empty states, features)
  static const double iconHuge = 48.0;

  /// 64px - Display icon (onboarding, hero sections)
  static const double iconDisplay = 64.0;

  // ============================================
  // COMPONENT SIZES
  // ============================================

  /// Standard app bar height
  static const double appBarHeight = 56.0;

  /// Bottom navigation bar height
  static const double bottomNavHeight = 80.0;

  /// FAB size
  static const double fabSize = 56.0;

  /// Avatar sizes
  static const double avatarSm = 32.0;
  static const double avatarMd = 40.0;
  static const double avatarLg = 56.0;
  static const double avatarXl = 80.0;

  /// Thumbnail/icon container sizes
  static const double thumbnailSm = 40.0;
  static const double thumbnailMd = 48.0;
  static const double thumbnailLg = 64.0;

  /// Touch target minimum (accessibility)
  static const double minTouchTarget = 48.0;

  /// Divider thickness
  static const double dividerThickness = 1.0;

  /// Border width
  static const double borderWidth = 1.0;
  static const double borderWidthThick = 2.0;

  // ============================================
  // ONBOARDING / HERO SIZES
  // ============================================

  /// Onboarding icon container
  static const double onboardingIconSize = 140.0;

  /// Onboarding icon border radius
  static const double onboardingIconRadius = 35.0;

  /// Sign-in logo container
  static const double signInLogoSize = 110.0;

  /// Sign-in logo border radius
  static const double signInLogoRadius = 32.0;
}

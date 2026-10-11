import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';

/// Centralized spacing constants following an 8px grid system.
/// Based on PRD specifications for consistent UI/UX across all screens.
///
/// Usage:
/// ```dart
/// Padding(padding: AppSpacing.paddingMd)
/// SizedBox(height: AppSpacing.md)
/// EdgeInsets.symmetric(horizontal: AppSpacing.lg)
/// ```
class AppSpacing {
  // ============================================
  // BASE SPACING VALUES (8px grid)
  // ============================================

  /// 4px - Extra extra small spacing
  static const double xxs = 4.0;

  /// 8px - Extra small spacing
  static const double xs = 8.0;

  /// 12px - Small spacing
  static const double sm = 12.0;

  /// 16px - Medium spacing (base unit)
  static const double md = 16.0;

  /// 20px - Medium-large spacing
  static const double lg = 20.0;

  /// 24px - Large spacing
  static const double xl = 24.0;

  /// 32px - Extra large spacing
  static const double xxl = 32.0;

  /// 40px - Extra extra large spacing
  static const double xxxl = 40.0;

  /// 48px - Huge spacing
  static const double huge = 48.0;

  // ============================================
  // SCREEN PADDING PRESETS
  // ============================================

  /// Standard screen horizontal padding (24px)
  static const double screenPaddingHorizontal = 24.0;

  /// Standard screen vertical padding (16px)
  static const double screenPaddingVertical = 16.0;

  /// The one left/right edge of Overview, Investments, Investment detail and
  /// Goals (16px): the app bar title, the first and last app bar action chip,
  /// section headings, the hero, cards and notes all start here. Forms keep
  /// [screenPaddingHorizontal]. Place content with `ScreenSliver` or
  /// `ScreenEdge` (`core/widgets/screen_layout.dart`), not with a literal.
  static const double screenEdge = 16.0;

  /// Compact screen padding for lists/grids (16px). An alias of [screenEdge].
  static const double screenPaddingCompact = screenEdge;

  // ============================================
  // EDGE INSETS PRESETS
  // ============================================

  /// Padding: all sides 8px
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);

  /// Padding: all sides 12px
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);

  /// Padding: all sides 16px
  static const EdgeInsets paddingMd = EdgeInsets.all(md);

  /// Padding: all sides 24px
  static const EdgeInsets paddingLg = EdgeInsets.all(xl);

  /// Padding: all sides 32px
  static const EdgeInsets paddingXl = EdgeInsets.all(xxl);

  /// Standard screen padding for forms and detail screens
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenPaddingHorizontal,
    vertical: screenPaddingVertical,
  );

  /// Compact screen padding for list/grid screens
  static const EdgeInsets screenPaddingList = EdgeInsets.all(
    screenPaddingCompact,
  );

  /// Button area padding (bottom sheets, form footers)
  static const EdgeInsets buttonAreaPadding = EdgeInsets.fromLTRB(
    screenPaddingHorizontal,
    md,
    screenPaddingHorizontal,
    xxl,
  );

  /// Card internal padding
  static const EdgeInsets cardPadding = EdgeInsets.all(md);

  /// Card internal padding - large variant
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(lg);

  // ============================================
  // COMPONENT SPACING
  // ============================================

  /// Spacing between form fields
  static const double formFieldSpacing = lg;

  /// Spacing between sections
  static const double sectionSpacing = xl;

  /// Spacing between list items
  static const double listItemSpacing = sm;

  /// Spacing between icon and text in buttons/labels
  static const double iconTextSpacing = xs;

  /// Spacing between chips
  static const double chipSpacing = xs;

  /// Margin Material keeps between the extended FAB and the body's bottom edge
  /// (16px, `kFloatingActionButtonMargin`).
  static const double fabMargin = 16.0;

  /// Bottom padding for screens with a FAB (80px): the 56px button, its 16px
  /// margin and an 8px gap. Add the bottom inset with [fabClearance].
  static const double fabBottomPadding = AppSizes.fabSize + fabMargin + xs;

  /// Space a scrolling body leaves under its last item so that item can be
  /// scrolled fully clear of the FAB: [fabBottomPadding] plus the bottom inset.
  ///
  /// Read it from the context of the sliver that needs it. Inside the shell's
  /// navigation bar and inside a `SafeArea` the inset is already consumed
  /// there and reads 0, as it does for `Scaffold`'s own FAB placement. On a
  /// screen shown without either, it is the real inset.
  static double fabClearance(BuildContext context) =>
      fabBottomPadding + MediaQuery.paddingOf(context).bottom;

  /// Gap between the 48px tap box of an app bar action and its 36px chip (6px).
  static const double actionInset =
      (AppSizes.minTouchTarget - AppSizes.tonalActionChip) / 2;

  /// Space between the screen edge and the 48px tap box of the first or last
  /// app bar action (10px), so the chip inside it starts or ends on
  /// [screenEdge] and only the transparent box hangs into the gutter.
  static const double appBarTrailingGap = screenEdge - actionInset;

  /// Width of the app bar leading slot that holds one tonal action (58px).
  static const double appBarLeadingWidth =
      appBarTrailingGap + AppSizes.minTouchTarget;
}

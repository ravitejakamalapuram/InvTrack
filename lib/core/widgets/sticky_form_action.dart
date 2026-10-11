import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';

/// The action bar at the foot of a long form: the submit button stays in
/// view while the form scrolls behind it (A40, #783).
///
/// It has the screen's background, a 1px line above it, 16 x 24 padding, and
/// keeps clear of the system navigation bar. Use it as a Scaffold's
/// `bottomNavigationBar`: a floating SnackBar then appears above it instead of
/// over the button, and the bar goes up with the keyboard (a Scaffold would
/// leave a bottom bar under the keyboard, so the bar pads itself by the
/// keyboard's height). Do not also pad it from outside.
class StickyFormAction extends StatelessWidget {
  const StickyFormAction({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    // The keyboard covers the system navigation bar, so only the larger of the
    // two is cleared.
    final bottomClearance = media.viewInsets.bottom > media.padding.bottom
        ? media.viewInsets.bottom
        : media.padding.bottom;

    // Full width, also inside a Column that centres its children.
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppColors.neutral800Dark
                    : AppColors.neutral200Light,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomClearance),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

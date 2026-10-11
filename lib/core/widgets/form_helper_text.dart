import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// The 12px line under a form field: an optional-field note, a readout of what
/// was typed, or a helper (A40, #783).
///
/// It sits 6px under the field's box and 16px in from its edge, in the muted
/// text colour. [emphasized] is for a readout the user should check, such as
/// "₹1 L" under an amount: heavier and in the secondary text colour.
///
/// A screen reader hears [text], or [semanticsLabel] where the spoken form
/// differs from the written one ("1 lakh rupees" for "₹1 L").
class FormHelperText extends StatelessWidget {
  const FormHelperText(
    this.text, {
    super.key,
    this.emphasized = false,
    this.semanticsLabel,
  });

  final String text;
  final bool emphasized;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = emphasized
        ? (isDark ? AppColors.neutral400Dark : AppColors.neutral600Light)
        : (isDark ? AppColors.neutral400Dark : AppColors.neutral500Light);

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, top: 6),
      child: Text(
        text,
        semanticsLabel: semanticsLabel,
        style: AppTypography.small.copyWith(
          color: color,
          fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

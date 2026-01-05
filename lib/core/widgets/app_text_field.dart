import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// A styled text field widget following the app's design language.
/// Supports both single-line and multi-line input with optional prefix icon and label.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final String? prefixText;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;

  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.prefixIcon,
    this.prefixText,
    this.validator,
    this.onSubmitted,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: textCapitalization,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          readOnly: readOnly,
          enabled: enabled,
          autofocus: autofocus,
          style: AppTypography.body.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.neutral500Dark
                  : AppColors.neutral400Light,
            ),
            prefixText: prefixText,
            prefixStyle: AppTypography.body.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
            prefixIcon: prefixIcon != null
                ? Padding(
                    padding: EdgeInsets.only(
                      bottom: maxLines > 1 ? (maxLines - 1) * 20.0 : 0,
                    ),
                    child: Icon(
                      prefixIcon,
                      color: isDark
                          ? AppColors.neutral400Dark
                          : AppColors.neutral500Light,
                    ),
                  )
                : null,
            filled: true,
            fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.neutral700Dark
                    : AppColors.neutral200Light,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.neutral700Dark
                    : AppColors.neutral200Light,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primaryLight, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.errorLight),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.errorLight, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: validator,
          onFieldSubmitted: onSubmitted,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

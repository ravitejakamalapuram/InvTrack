import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// A gradient button widget with loading state support.
///
/// Features:
/// - Gradient background with customizable color
/// - Loading state with circular progress indicator
/// - Box shadow with glow effect
/// - Icon and text content
class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final Color? color;
  final double height;
  final double borderRadius;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.color,
    this.height = 56,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = color ?? AppColors.primaryLight;
    // The default indigo keeps the white label. A custom fill (the green and
    // red of Add Transaction) takes the label colour with the higher contrast
    // and stays solid, so the label reads over the whole gradient.
    final onButton = color == null
        ? Colors.white
        : AppColors.onFill(buttonColor);
    final tailAlpha = color == null ? 0.87 : 1.0;

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: isLoading
            ? null
            : LinearGradient(
                // The tail is 87% so that the white label reads over it on the
                // light page (4.63:1; at 80% it was 4.04:1). The fill stays the
                // button colour in both themes.
                colors: [
                  buttonColor,
                  buttonColor.withValues(alpha: tailAlpha),
                ],
              ),
        color: isLoading
            ? (isDark ? AppColors.neutral700Dark : AppColors.neutral300Light)
            : null,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isLoading
            ? null
            : [
                BoxShadow(
                  color: buttonColor.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: isLoading
            ? Semantics(
                label: 'Loading $label',
                excludeSemantics: true,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Colors.white : AppColors.neutral700Light,
                    ),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: onButton),
                    const SizedBox(width: 8),
                  ],
                  // At a large text size on a narrow screen the label shrinks to
                  // fit the button instead of overflowing it.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: AppTypography.button.copyWith(
                          color: onButton,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

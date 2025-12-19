import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// A generic type selector widget that displays selectable chips in a wrap layout.
///
/// Supports haptic feedback, animated transitions, and gradient styling.
class TypeSelector<T> extends StatelessWidget {
  final String? label;
  final List<T> values;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final Color Function(T item) colorBuilder;
  final IconData Function(T item) iconBuilder;
  final String Function(T item) labelBuilder;
  final double spacing;
  final double runSpacing;

  const TypeSelector({
    super.key,
    this.label,
    required this.values,
    required this.selectedValue,
    required this.onSelected,
    required this.colorBuilder,
    required this.iconBuilder,
    required this.labelBuilder,
    this.spacing = 10,
    this.runSpacing = 10,
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
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: values.map((item) {
            final isSelected = selectedValue == item;
            final color = colorBuilder(item);

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(item);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [color, color.withValues(alpha: 0.8)],
                        )
                      : null,
                  color: isSelected
                      ? null
                      : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : (isDark
                            ? AppColors.neutral700Dark
                            : AppColors.neutral200Light),
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      iconBuilder(item),
                      size: 18,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? AppColors.neutral400Dark
                              : AppColors.neutral600Light),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      labelBuilder(item),
                      style: AppTypography.body.copyWith(
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? AppColors.neutral300Dark
                                : AppColors.neutral700Light),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}


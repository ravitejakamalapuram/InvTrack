import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// A generic type selector widget that displays selectable chips in a wrap layout.
///
/// Supports haptic feedback, animated transitions, and gradient styling.
/// Now with improved layout options for better UX.
class TypeSelector<T> extends StatelessWidget {
  final String? label;
  final String? subtitle;
  final List<T> values;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final Color Function(T item) colorBuilder;
  final IconData Function(T item) iconBuilder;
  final String Function(T item) labelBuilder;
  final double spacing;
  final double runSpacing;

  /// If true, uses a more compact chip style (icon only visible when selected)
  final bool compactMode;

  /// If true, chips are sized to fit a 2-column grid layout
  final bool gridLayout;

  const TypeSelector({
    super.key,
    this.label,
    this.subtitle,
    required this.values,
    required this.selectedValue,
    required this.onSelected,
    required this.colorBuilder,
    required this.iconBuilder,
    required this.labelBuilder,
    this.spacing = 10,
    this.runSpacing = 10,
    this.compactMode = false,
    this.gridLayout = false,
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
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
        gridLayout ? _buildGridLayout(isDark) : _buildWrapLayout(isDark),
      ],
    );
  }

  Widget _buildWrapLayout(bool isDark) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: values.map((item) => _buildChip(item, isDark)).toList(),
    );
  }

  Widget _buildGridLayout(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chipWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: values.map((item) {
            return SizedBox(
              width: chipWidth,
              child: _buildChip(item, isDark, expanded: true),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildChip(T item, bool isDark, {bool expanded = false}) {
    final isSelected = selectedValue == item;
    final color = colorBuilder(item);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelected(item);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: compactMode ? 12 : 16,
          vertical: compactMode ? 10 : 12,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.85)],
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark
                      ? AppColors.neutral700Dark
                      : AppColors.neutral200Light),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment:
              expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            // Icon with subtle color tint when not selected
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                iconBuilder(item),
                size: compactMode ? 16 : 18,
                color: isSelected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                labelBuilder(item),
                style: AppTypography.body.copyWith(
                  fontSize: compactMode ? 13 : 14,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                            ? AppColors.neutral200Dark
                            : AppColors.neutral700Light),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

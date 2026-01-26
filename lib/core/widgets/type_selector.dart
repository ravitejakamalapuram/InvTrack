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
    final itemLabel = labelBuilder(item);

    return Semantics(
      button: true,
      selected: isSelected,
      label: itemLabel,
      excludeSemantics: true,
      onTap: () {
        HapticFeedback.selectionClick();
        onSelected(item);
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onSelected(item);
        },
        child: _TypeSelectorChip(
          isSelected: isSelected,
          color: color,
          isDark: isDark,
          expanded: expanded,
          compactMode: compactMode,
          icon: iconBuilder(item),
          label: itemLabel,
        ),
      ),
    );
  }
}

/// Stateful chip widget with smooth animations that avoid flickering.
/// Uses TweenAnimationBuilder for controlled, non-rebuilding animations.
class _TypeSelectorChip extends StatelessWidget {
  final bool isSelected;
  final Color color;
  final bool isDark;
  final bool expanded;
  final bool compactMode;
  final IconData icon;
  final String label;

  const _TypeSelectorChip({
    required this.isSelected,
    required this.color,
    required this.isDark,
    required this.expanded,
    required this.compactMode,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isSelected ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, selectionProgress, child) {
        // Interpolate colors based on selection progress
        final backgroundColor = Color.lerp(
          isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          color,
          selectionProgress,
        )!;

        final borderColor = Color.lerp(
          isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
          Colors.transparent,
          selectionProgress,
        )!;

        final iconBgColor = Color.lerp(
          color.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.2),
          selectionProgress,
        )!;

        final iconColor = Color.lerp(color, Colors.white, selectionProgress)!;

        final textColor = Color.lerp(
          isDark ? AppColors.neutral200Dark : AppColors.neutral700Light,
          Colors.white,
          selectionProgress,
        )!;

        final shadowOpacity = selectionProgress * 0.35;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compactMode ? 12 : 16,
            vertical: compactMode ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: selectionProgress > 0.1
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: shadowOpacity),
                      blurRadius: 16 * selectionProgress,
                      offset: Offset(0, 6 * selectionProgress),
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: compactMode ? 16 : 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.body.copyWith(
                    fontSize: compactMode ? 13 : 14,
                    color: textColor,
                    fontWeight: selectionProgress > 0.5
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

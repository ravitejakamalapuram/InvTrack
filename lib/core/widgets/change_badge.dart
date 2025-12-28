import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// A badge widget showing percentage change with color coding
class ChangeBadge extends StatelessWidget {
  final double value;
  final String? prefix;
  final String? suffix;
  final bool showIcon;
  final bool filled;
  final ChangeBadgeSize size;

  const ChangeBadge({
    super.key,
    required this.value,
    this.prefix,
    this.suffix = '%',
    this.showIcon = true,
    this.filled = true,
    this.size = ChangeBadgeSize.medium,
  });

  bool get isPositive => value >= 0;
  bool get isZero => value == 0;

  @override
  Widget build(BuildContext context) {
    final color = isZero
        ? AppColors.neutral500Light
        : (isPositive ? AppColors.successLight : AppColors.dangerLight);

    final bgColor = isZero
        ? AppColors.neutral200Light
        : (isPositive ? AppColors.successBgLight : AppColors.dangerBgLight);

    final textStyle = switch (size) {
      ChangeBadgeSize.small => AppTypography.tiny,
      ChangeBadgeSize.medium => AppTypography.small,
      ChangeBadgeSize.large => AppTypography.percentage,
    };

    final padding = switch (size) {
      ChangeBadgeSize.small => const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      ChangeBadgeSize.medium => const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      ChangeBadgeSize.large => const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
    };

    final iconSize = switch (size) {
      ChangeBadgeSize.small => 10.0,
      ChangeBadgeSize.medium => 12.0,
      ChangeBadgeSize.large => 16.0,
    };

    final displayValue =
        '${isPositive && !isZero ? '+' : ''}${value.toStringAsFixed(2)}';

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: filled ? bgColor : Colors.transparent,
        borderRadius: BorderRadius.circular(
          size == ChangeBadgeSize.large ? 10 : 6,
        ),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon && !isZero) ...[
            Icon(
              isPositive
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: iconSize,
              color: color,
            ),
            SizedBox(width: size == ChangeBadgeSize.small ? 2 : 4),
          ],
          Text(
            '${prefix ?? ''}$displayValue${suffix ?? ''}',
            style: textStyle.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum ChangeBadgeSize { small, medium, large }

/// A pill-shaped badge for status or category display
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: outlined
            ? Border.all(color: color.withValues(alpha: 0.5))
            : null,
      ),
      child: Text(
        label,
        style: AppTypography.tiny.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

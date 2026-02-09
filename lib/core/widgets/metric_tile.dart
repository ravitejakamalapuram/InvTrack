import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// A compact metric display widget for showing KPIs
class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? change;
  final bool? isPositive;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.change,
    this.isPositive,
    this.icon,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Accessibility: Construct a comprehensive label including trend
    final positive = isPositive ?? true;
    final trendText = change != null
        ? ', ${positive ? "Trending up" : "Trending down"} $change'
        : '';
    final semanticLabel = '$label: $value$trendText';

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.neutral700Dark
                  : AppColors.neutral200Light,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (iconColor ?? AppColors.primaryLight).withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 16,
                        color: iconColor ?? AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.neutral400Dark
                            : AppColors.neutral600Light,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: AppTypography.numberSmall.copyWith(
                  color: isDark
                      ? AppColors.neutral50Dark
                      : AppColors.neutral900Light,
                ),
              ),
              if (change != null) ...[
                const SizedBox(height: 4),
                _buildChangeIndicator(isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangeIndicator(bool isDark) {
    final positive = isPositive ?? true;
    final color = positive ? AppColors.successLight : AppColors.dangerLight;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          change!,
          style: AppTypography.small.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// A large hero metric widget for the main dashboard card
class HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Widget? trailing;

  const HeroMetric({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                value,
                style: AppTypography.numberLarge.copyWith(color: Colors.white),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: AppTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

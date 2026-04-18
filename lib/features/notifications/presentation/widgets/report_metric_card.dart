/// Metric card widget for displaying key metrics in report screens.
///
/// Shows a single metric with:
/// - Label (e.g., "Investments Tracked")
/// - Value (e.g., "5")
/// - Optional trend indicator (e.g., "+2 from last week")
/// - Optional icon
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// Metric card widget
class ReportMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? trend;
  final IconData? icon;
  final Color? accentColor;

  const ReportMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.trend,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAccentColor = accentColor ?? AppColors.primaryLight;

    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.neutral800Dark : Colors.white,
        borderRadius: AppSizes.borderRadiusMd,
        border: Border.all(
          color: isDark
              ? AppColors.neutral700Dark
              : AppColors.neutral200Light,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label with optional icon
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral600Light,
                ),
                SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body2.copyWith(
                    color: isDark
                        ? AppColors.neutral400Dark
                        : AppColors.neutral600Light,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),

          // Value
          Text(
            value,
            style: AppTypography.h1.copyWith(
              color: effectiveAccentColor,
              fontWeight: FontWeight.bold,
            ),
          ),

          // Trend indicator
          if (trend != null) ...[
            SizedBox(height: AppSpacing.xs),
            Text(
              trend!,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.neutral500Dark
                    : AppColors.neutral500Light,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Grid layout for multiple metric cards
class ReportMetricsGrid extends StatelessWidget {
  final List<ReportMetricCard> metrics;

  const ReportMetricsGrid({
    super.key,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
        ),
        itemCount: metrics.length,
        itemBuilder: (context, index) => metrics[index],
      ),
    );
  }
}

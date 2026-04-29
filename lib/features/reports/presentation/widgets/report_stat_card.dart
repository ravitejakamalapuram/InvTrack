/// Stat card widget for displaying report metrics
///
/// Displays a key metric with:
/// - Icon
/// - Label
/// - Value
/// - Optional trend indicator
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';

/// Stat card for report metrics
class ReportStatCard extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final bool isPrivacySensitive;
  final double? trendValue;
  final bool? isTrendPositive;
  final String? tooltip; // Optional tooltip explanation

  const ReportStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.isPrivacySensitive = true,
    this.trendValue,
    this.isTrendPositive,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor =
        iconColor ?? (isDark ? AppColors.primaryLight : AppColors.primaryDark);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + Label (with optional tooltip)
          Row(
            children: [
              Icon(icon, color: effectiveIconColor, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (tooltip != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: tooltip!,
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 5),
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.inverseSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onInverseSurface,
                    fontSize: 13,
                  ),
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Value
          isPrivacySensitive
              ? PrivacyMask(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                )
              : Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

          // Trend indicator (optional)
          if (trendValue != null && isTrendPositive != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _buildTrendIndicator(context),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendIndicator(BuildContext context) {
    final color = isTrendPositive! ? Colors.green : Colors.red;
    final icon = isTrendPositive!
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;

    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          '${trendValue!.abs().toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

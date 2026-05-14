/// Smart Insight Card Widget
///
/// Displays an auto-generated insight in a visually appealing card
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/reports/domain/entities/smart_insight.dart';

/// Card that displays a smart insight
class SmartInsightCard extends StatelessWidget {
  /// The insight to display
  final SmartInsight insight;
  
  const SmartInsightCard({
    required this.insight,
    super.key,
  });
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GlassCard(
      child: InkWell(
        onTap: insight.actionPath != null
            ? () => context.push(insight.actionPath!)
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Icon with colored background
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getPriorityColor(context, isDark).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIcon(),
                  color: _getPriorityColor(context, isDark),
                  size: 24,
                ),
              ),
              
              const SizedBox(width: AppSpacing.md),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      insight.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Subtitle
                    Text(
                      insight.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: AppSpacing.sm),
              
              // Value
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    insight.value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getPriorityColor(context, isDark),
                    ),
                  ),
                  if (insight.secondaryValue != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      insight.secondaryValue!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Get icon based on insight type
  IconData _getIcon() {
    switch (insight.icon) {
      case 'calendar_today':
        return Icons.calendar_today;
      case 'trending_up':
        return Icons.trending_up;
      case 'trending_down':
        return Icons.trending_down;
      case 'schedule':
        return Icons.schedule;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'flag':
        return Icons.flag_outlined;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.analytics_outlined;
    }
  }
  
  /// Get color based on priority
  Color _getPriorityColor(BuildContext context, bool isDark) {
    switch (insight.priority) {
      case InsightPriority.urgent:
        return isDark ? AppColors.errorDark : AppColors.errorLight;
      case InsightPriority.warning:
        return isDark ? AppColors.warningDark : AppColors.warningLight;
      case InsightPriority.info:
        return isDark ? AppColors.successDark : AppColors.successLight;
    }
  }
}

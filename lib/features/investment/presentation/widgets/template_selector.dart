import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_template.dart';

/// A horizontal scrollable selector for investment templates.
/// Displays template cards with emoji, name, and description.
/// Used to quick-start investment creation with pre-filled data.
class TemplateSelector extends StatelessWidget {
  /// Called when a template is selected
  final ValueChanged<InvestmentTemplate> onTemplateSelected;

  /// Optional: currently selected template (for highlighting)
  final InvestmentTemplate? selectedTemplate;

  /// Whether to show "Skip" option at the end
  final bool showSkipOption;

  /// Called when skip is tapped
  final VoidCallback? onSkip;

  const TemplateSelector({
    super.key,
    required this.onTemplateSelected,
    this.selectedTemplate,
    this.showSkipOption = true,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Text(
                '⚡ Quick Start',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
              const Spacer(),
              if (showSkipOption)
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onSkip?.call();
                  },
                  child: Text(
                    'Custom',
                    style: AppTypography.label.copyWith(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'Pick a template to pre-fill common fields',
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: InvestmentTemplates.all.length,
            separatorBuilder: (_, _) => SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final template = InvestmentTemplates.all[index];
              final isSelected = selectedTemplate?.id == template.id;
              return _TemplateCard(
                template: template,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTemplateSelected(template);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final InvestmentTemplate template;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 130,
        padding: EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? template.color.withValues(alpha: 0.15)
              : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? template.color
                : (isDark
                    ? AppColors.neutral700Dark
                    : AppColors.neutral200Light),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: template.color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(template.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              template.name,
              style: AppTypography.label.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isSelected
                    ? template.color
                    : (isDark ? Colors.white : AppColors.neutral900Light),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (template.typicalRate != null) ...[
              const SizedBox(height: 2),
              Text(
                '~${template.typicalRate!.toStringAsFixed(0)}% p.a.',
                style: AppTypography.caption.copyWith(
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral500Light,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

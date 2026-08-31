import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/expected_cash_flow_providers.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Filter chips for Income Calendar screen
class IncomeCalendarFilterChips extends StatelessWidget {
  final bool isDark;
  final IncomeCalendarFilter currentFilter;
  final ValueChanged<IncomeCalendarFilter> onFilterChanged;

  const IncomeCalendarFilterChips({
    super.key,
    required this.isDark,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: l10n.allPaymentsFilter,
            icon: Icons.calendar_month_rounded,
            filter: IncomeCalendarFilter.all,
            isSelected: currentFilter == IncomeCalendarFilter.all,
            isDark: isDark,
            onTap: () => onFilterChanged(IncomeCalendarFilter.all),
          ),
          SizedBox(width: AppSpacing.sm),
          _FilterChip(
            label: l10n.pendingFilter,
            icon: Icons.schedule_rounded,
            filter: IncomeCalendarFilter.pending,
            isSelected: currentFilter == IncomeCalendarFilter.pending,
            isDark: isDark,
            onTap: () => onFilterChanged(IncomeCalendarFilter.pending),
          ),
          SizedBox(width: AppSpacing.sm),
          _FilterChip(
            label: l10n.overdueFilter,
            icon: Icons.warning_rounded,
            filter: IncomeCalendarFilter.overdue,
            isSelected: currentFilter == IncomeCalendarFilter.overdue,
            isDark: isDark,
            onTap: () => onFilterChanged(IncomeCalendarFilter.overdue),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final IncomeCalendarFilter filter;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.filter,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
        : (isDark ? AppColors.neutral800Dark : AppColors.neutral100Light);

    final textColor = isSelected
        ? Colors.white
        : (isDark ? AppColors.neutral300Dark : AppColors.neutral600Light);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
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
                    color: (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                        .withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: textColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.small.copyWith(
                color: textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

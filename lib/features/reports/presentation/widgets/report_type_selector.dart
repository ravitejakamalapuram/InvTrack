/// Report Type Selector Widget
///
/// Allows users to select the type of report they want to create
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_type.dart';

class ReportTypeSelector extends StatelessWidget {
  final ReportType? selectedType;
  final ValueChanged<ReportType> onTypeSelected;

  const ReportTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.chooseReportType,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _ReportTypeCard(
          type: ReportType.weeklySummary,
          title: l10n.weeklySummary,
          description: l10n.weeklySummaryDesc,
          icon: Icons.calendar_view_week_rounded,
          isSelected: selectedType == ReportType.weeklySummary,
          onTap: () => onTypeSelected(ReportType.weeklySummary),
        ),
        const SizedBox(height: 12),
        _ReportTypeCard(
          type: ReportType.monthlyIncome,
          title: l10n.monthlyIncome,
          description: l10n.monthlyIncomeDesc,
          icon: Icons.currency_rupee_rounded,
          isSelected: selectedType == ReportType.monthlyIncome,
          onTap: () => onTypeSelected(ReportType.monthlyIncome),
        ),
        const SizedBox(height: 12),
        _ReportTypeCard(
          type: ReportType.fyReport,
          title: l10n.fyReport,
          description: l10n.fyReportDesc,
          icon: Icons.assessment_rounded,
          isSelected: selectedType == ReportType.fyReport,
          onTap: () => onTypeSelected(ReportType.fyReport),
        ),
        const SizedBox(height: 12),
        _ReportTypeCard(
          type: ReportType.performance,
          title: l10n.performanceReport,
          description: l10n.performanceReportDesc,
          icon: Icons.trending_up_rounded,
          isSelected: selectedType == ReportType.performance,
          onTap: () => onTypeSelected(ReportType.performance),
        ),
        const SizedBox(height: 12),
        _ReportTypeCard(
          type: ReportType.goalProgress,
          title: l10n.goalsReport,
          description: l10n.goalsReportDesc,
          icon: Icons.emoji_events_rounded,
          isSelected: selectedType == ReportType.goalProgress,
          onTap: () => onTypeSelected(ReportType.goalProgress),
        ),
        const SizedBox(height: 12),
        _ReportTypeCard(
          type: ReportType.maturityCalendar,
          title: l10n.maturityCalendar,
          description: l10n.maturityCalendarDesc,
          icon: Icons.event_available_rounded,
          isSelected: selectedType == ReportType.maturityCalendar,
          onTap: () => onTypeSelected(ReportType.maturityCalendar),
        ),
      ],
    );
  }
}

class _ReportTypeCard extends StatelessWidget {
  final ReportType type;
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReportTypeCard({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.05)
              : theme.colorScheme.surface,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

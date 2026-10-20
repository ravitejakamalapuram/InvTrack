/// Date Range Selector Widget
///
/// Allows users to select date range for their custom report
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_configuration.dart';

class DateRangeSelector extends StatelessWidget {
  final DateRangePreset selectedPreset;
  final ValueChanged<DateRangePreset> onPresetSelected;

  const DateRangeSelector({
    super.key,
    required this.selectedPreset,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.selectTimeframe,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DateRangeChip(
              label: l10n.thisWeek,
              isSelected: selectedPreset == DateRangePreset.thisWeek,
              onTap: () => onPresetSelected(DateRangePreset.thisWeek),
            ),
            _DateRangeChip(
              label: l10n.thisMonth,
              isSelected: selectedPreset == DateRangePreset.thisMonth,
              onTap: () => onPresetSelected(DateRangePreset.thisMonth),
            ),
            _DateRangeChip(
              label: l10n.thisQuarter,
              isSelected: selectedPreset == DateRangePreset.thisQuarter,
              onTap: () => onPresetSelected(DateRangePreset.thisQuarter),
            ),
            _DateRangeChip(
              label: l10n.thisYear,
              isSelected: selectedPreset == DateRangePreset.thisYear,
              onTap: () => onPresetSelected(DateRangePreset.thisYear),
            ),
            _DateRangeChip(
              label: l10n.lastThreeMonths,
              isSelected: selectedPreset == DateRangePreset.last3Months,
              onTap: () => onPresetSelected(DateRangePreset.last3Months),
            ),
            _DateRangeChip(
              label: l10n.lastSixMonths,
              isSelected: selectedPreset == DateRangePreset.last6Months,
              onTap: () => onPresetSelected(DateRangePreset.last6Months),
            ),
            _DateRangeChip(
              label: l10n.lastYear,
              isSelected: selectedPreset == DateRangePreset.lastYear,
              onTap: () => onPresetSelected(DateRangePreset.lastYear),
            ),
            _DateRangeChip(
              label: l10n.allTime,
              isSelected: selectedPreset == DateRangePreset.allTime,
              onTap: () => onPresetSelected(DateRangePreset.allTime),
            ),
          ],
        ),
      ],
    );
  }
}

class _DateRangeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateRangeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      checkmarkColor: theme.colorScheme.primary,
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
        width: isSelected ? 2 : 1,
      ),
    );
  }
}

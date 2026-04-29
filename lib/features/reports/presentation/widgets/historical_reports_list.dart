/// Widget for displaying list of historical reports with quick access
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Widget that displays a list of available historical reports
/// Shows recent FY years and past months for quick access
class HistoricalReportsList extends StatelessWidget {
  const HistoricalReportsList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final currentFYYear = now.month >= 4 ? now.year : now.year - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Financial Year Reports
        Text(
          l10n.financialYearReports,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        
        // Last 3 FY years
        _buildFYReportList(context, currentFYYear),
        
        const SizedBox(height: AppSpacing.lg),
        
        // Monthly Reports
        Text(
          l10n.monthlyReports,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        
        // Last 6 months
        _buildMonthlyReportList(context, now),
      ],
    );
  }

  /// Build list of past FY reports
  Widget _buildFYReportList(BuildContext context, int currentFYYear) {
    final l10n = AppLocalizations.of(context);
    
    // Show last 3 FY years
    final fyYears = List.generate(3, (index) => currentFYYear - index);
    
    return Column(
      children: fyYears.map((fyYear) {
        final fyLabel = 'FY $fyYear-${(fyYear + 1) % 100}';
        final isCurrent = fyYear == currentFYYear;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: GlassCard(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(fyLabel),
              subtitle: Text(isCurrent ? l10n.currentYear : l10n.tapToView),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Navigate to FY report screen with year parameter
                context.push('/reports/fy/$fyYear');
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Build list of past monthly reports
  Widget _buildMonthlyReportList(BuildContext context, DateTime now) {
    final l10n = AppLocalizations.of(context);
    
    // Show last 6 months
    final months = List.generate(6, (index) {
      final monthDate = DateTime(now.year, now.month - index, 1);
      return monthDate;
    });
    
    return Column(
      children: months.map((month) {
        final monthLabel = _formatMonth(month, l10n);
        final isCurrent = month.year == now.year && month.month == now.month;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: GlassCard(
            child: ListTile(
              leading: const Icon(Icons.date_range),
              title: Text(monthLabel),
              subtitle: Text(isCurrent ? l10n.currentMonth : l10n.tapToView),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Navigate to monthly income screen with month parameter
                final yearMonth = '${month.year}-${month.month.toString().padLeft(2, '0')}';
                context.push('/reports/monthly/$yearMonth');
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Format month for display
  String _formatMonth(DateTime month, AppLocalizations l10n) {
    final monthNames = [
      l10n.january, l10n.february, l10n.march, l10n.april,
      l10n.may, l10n.june, l10n.july, l10n.august,
      l10n.september, l10n.october, l10n.november, l10n.december,
    ];
    
    return '${monthNames[month.month - 1]} ${month.year}';
  }
}

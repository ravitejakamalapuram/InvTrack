/// Filter Selector Widget
///
/// Allows users to apply optional filters to their custom report
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_type.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';

class FilterSelector extends ConsumerWidget {
  final ReportType? reportType;
  final String? selectedInvestmentId;
  final String? selectedGoalId;
  final ValueChanged<String?> onInvestmentSelected;
  final ValueChanged<String?> onGoalSelected;

  const FilterSelector({
    super.key,
    required this.reportType,
    required this.selectedInvestmentId,
    required this.selectedGoalId,
    required this.onInvestmentSelected,
    required this.onGoalSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Determine which filters to show based on report type
    final showInvestmentFilter = reportType != null &&
        (reportType == ReportType.performance ||
         reportType == ReportType.weeklySummary ||
         reportType == ReportType.monthlyIncome);

    final showGoalFilter = reportType == ReportType.goalProgress;

    if (!showInvestmentFilter && !showGoalFilter) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.noFiltersNeeded,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noFiltersNeededDesc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.optionalFilters,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        if (showInvestmentFilter) ...[
          Text(
            l10n.filterByInvestment,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _InvestmentFilterDropdown(
            selectedInvestmentId: selectedInvestmentId,
            onChanged: onInvestmentSelected,
          ),
          const SizedBox(height: 16),
        ],

        if (showGoalFilter) ...[
          Text(
            l10n.filterByGoal,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _GoalFilterDropdown(
            selectedGoalId: selectedGoalId,
            onChanged: onGoalSelected,
          ),
        ],
      ],
    );
  }
}

class _InvestmentFilterDropdown extends ConsumerWidget {
  final String? selectedInvestmentId;
  final ValueChanged<String?> onChanged;

  const _InvestmentFilterDropdown({
    required this.selectedInvestmentId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final investmentsAsync = ref.watch(activeInvestmentsProvider);

    return investmentsAsync.when(
      data: (investments) {
        return DropdownButtonFormField<String>(
          initialValue: selectedInvestmentId,
          decoration: InputDecoration(
            hintText: l10n.allInvestments,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(l10n.allInvestments),
            ),
            ...investments.map((investment) {
              return DropdownMenuItem<String>(
                value: investment.id,
                child: Text(investment.name),
              );
            }),
          ],
          onChanged: onChanged,
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => Text(l10n.errorLoadingInvestments),
    );
  }
}

class _GoalFilterDropdown extends ConsumerWidget {
  final String? selectedGoalId;
  final ValueChanged<String?> onChanged;

  const _GoalFilterDropdown({
    required this.selectedGoalId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final goalsAsync = ref.watch(activeGoalsProvider);

    return goalsAsync.when(
      data: (goals) {
        return DropdownButtonFormField<String>(
          initialValue: selectedGoalId,
          decoration: InputDecoration(
            hintText: l10n.allGoals,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(l10n.allGoals),
            ),
            ...goals.map((goal) {
              return DropdownMenuItem<String>(
                value: goal.id,
                child: Text(goal.name),
              );
            }),
          ],
          onChanged: onChanged,
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => Text(l10n.errorLoadingGoals),
    );
  }
}

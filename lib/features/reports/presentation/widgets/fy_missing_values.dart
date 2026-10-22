/// "Needs a current value" list of the Tax-Year (FY) report (#800). Shown
/// when the XIRR is unknown. No amounts, so privacy mode has nothing to hide.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class FyMissingValues extends StatelessWidget {
  const FyMissingValues({
    super.key,
    required this.report,
    required this.onAddValue,
  });

  final FYReport report;
  final void Function(InvestmentEntity investment) onAddValue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = theme.brightness == Brightness.dark
        ? AppColors.primaryDark
        : AppColors.primaryLight;
    final dates = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    final lastDay = DateTime(
      report.fyEnd.year,
      report.fyEnd.month,
      report.fyEnd.day,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.fyReportNeedsValueTitle(
            dates.format(report.fyStart),
            dates.format(lastDay),
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final m in report.missingValues)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GlassCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.investment.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.returnAwaitingCurrentValue,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Semantics(
                    label: l10n.fyReportAddValueFor(m.investment.name),
                    button: true,
                    excludeSemantics: true,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppSizes.borderRadiusXl,
                        ),
                      ),
                      onPressed: () => onAddValue(m.investment),
                      child: Text(l10n.fyReportAddValue),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

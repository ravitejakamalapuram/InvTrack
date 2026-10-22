/// Hero card of the Tax-Year (FY) report (#800).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// [xirr] as a percentage with one decimal, in the app locale (0.114 -> 11.4%).
String fyPercent(BuildContext context, double xirr) =>
    NumberFormat.decimalPercentPattern(
      locale: Localizations.localeOf(context).toString(),
      decimalDigits: 1,
    ).format(xirr);

class FyHero extends StatelessWidget {
  const FyHero({super.key, required this.report, required this.money});

  final FYReport report;
  final String Function(double, {bool signed}) money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onHero = AppColors.onFill(
      isDark ? AppColors.primaryDarkLight : AppColors.primaryLight,
    );
    final label = theme.textTheme.bodySmall?.copyWith(
      color: onHero.withValues(alpha: 0.85),
    );
    final xirr = report.xirr;

    Widget chip(String title, Widget value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: onHero.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: label),
          value,
        ],
      ),
    );
    final chipValue = theme.textTheme.titleMedium?.copyWith(
      color: onHero,
      fontWeight: FontWeight.w700,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.primaryGradientDark
            : AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.fyReportNetCashFlow, style: label),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MaskedAmountText(
              text: money(report.netCashFlow, signed: true),
              maxLines: 1,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: onHero,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              chip(
                l10n.fyReportXirrLabel,
                xirr == null
                    ? Text('—', style: chipValue)
                    : MaskedAmountText(
                        text: fyPercent(context, xirr),
                        style: chipValue,
                        maskedSemanticsLabel: l10n.hiddenPercentage,
                      ),
              ),
              if (report.portfolioValueAtEnd > 0)
                chip(
                  l10n.fyReportPortfolioValue,
                  MaskedAmountText(
                    text: money(report.portfolioValueAtEnd),
                    style: chipValue,
                  ),
                ),
            ],
          ),
          if (xirr == null) ...[
            const SizedBox(height: 14),
            Text(l10n.fyReportXirrMissing, style: label),
          ],
        ],
      ),
    );
  }
}

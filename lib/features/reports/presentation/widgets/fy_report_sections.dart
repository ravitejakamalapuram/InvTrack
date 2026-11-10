/// Sections of the Tax-Year (FY) report screen (#800). Amounts and XIRR go
/// through [MaskedAmountText] so privacy mode hides them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/fy_hero.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/fy_report_lists.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class FyReportBody extends ConsumerWidget {
  const FyReportBody({super.key, required this.report});

  final FYReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final code = ref.watch(currencyCodeProvider);
    final symbol = getCurrencySymbol(code);
    final locale = getCurrencyLocale(code);
    String money(double v, {bool signed = false}) =>
        '${signed && v > 0 ? '+' : ''}${formatCurrency(v, symbol, locale)}';

    final muted = theme.colorScheme.onSurfaceVariant;
    final dates = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    final heading = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.fyReportPeriod(
            dates.format(report.fyStart),
            dates.format(
              DateTime(report.fyEnd.year, report.fyEnd.month, report.fyEnd.day),
            ),
          ),
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        const SizedBox(height: AppSpacing.md),
        FyHero(report: report, money: money),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.fyReportMoneyTitle, style: heading),
        const SizedBox(height: AppSpacing.sm),
        FyTiles(
          tiles: [
            (l10n.fyReportInvested, money(report.totalInvested)),
            (l10n.fyReportReturned, money(report.totalReturns)),
            (l10n.fyReportIncomeReceived, money(report.totalIncome)),
            (l10n.fyReportFeesPaid, money(report.totalFees)),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.fyReportTaxTitle, style: heading),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          l10n.fyReportTaxSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        const SizedBox(height: AppSpacing.sm),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              FyTaxRow(
                label: l10n.fyReportInterestIncome,
                amount: money(report.interestIncome),
              ),
              const Divider(height: 1),
              FyTaxRow(
                label: l10n.fyReportDividendIncome,
                amount: money(report.dividendIncome),
              ),
              const Divider(height: 1),
              // Capital gains are always 0 until a cost-basis model exists, so
              // say so instead of showing a misleading zero.
              FyTaxRow(
                label: l10n.fyReportCapitalGains,
                value: l10n.fyReportNotCalculated,
                hint: l10n.fyReportCapitalGainsHint,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FyMonthly(report: report, money: money),
        if (report.topPerformersByReturns.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.topPerformers, style: heading),
          const SizedBox(height: AppSpacing.sm),
          for (final p in report.topPerformersByReturns.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: FyPerformer(p: p, money: money),
            ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.fyReportDisclaimer,
          style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.5),
        ),
      ],
    );
  }
}

class FyTiles extends StatelessWidget {
  const FyTiles({super.key, required this.tiles});

  final List<(String, String)> tiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget tile((String, String) t) => Expanded(
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.$1,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MaskedAmountText(
                text: t.$2,
                maxLines: 1,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2)
          Padding(
            padding: EdgeInsets.only(
              bottom: i + 2 < tiles.length ? AppSpacing.sm : 0,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tile(tiles[i]),
                  const SizedBox(width: AppSpacing.sm),
                  tile(tiles[i + 1]),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class FyTaxRow extends StatelessWidget {
  const FyTaxRow({
    super.key,
    required this.label,
    this.amount,
    this.value,
    this.hint,
  });

  /// Either [amount] (masked in privacy mode) or a plain [value] text.
  final String label;
  final String? amount;
  final String? value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final style = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: amount == null ? muted : null,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: amount != null
                      ? MaskedAmountText(
                          text: amount!,
                          style: style,
                          textAlign: TextAlign.end,
                        )
                      : Text(value!, style: style, textAlign: TextAlign.end),
                ),
              ],
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Text(
                  hint!,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

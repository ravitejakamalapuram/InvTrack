/// Tax-Year (financial year) report screen (#800).
///
/// Shows an [FYReport] for an Apr-Mar year: hero net cash flow, money tiles,
/// the figures needed for a tax return, monthly bars and top performers. Every
/// amount goes through [MaskedAmountText] so privacy mode hides it. An
/// undefined XIRR reads "—" with a hint, never 0%.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';
import 'package:inv_tracker/features/reports/presentation/providers/fy_report_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class FyReportScreen extends ConsumerStatefulWidget {
  const FyReportScreen({super.key, required this.initialFyYear});

  /// Start year of the FY shown first (2025 = 1 Apr 2025 to 31 Mar 2026).
  final int initialFyYear;

  @override
  ConsumerState<FyReportScreen> createState() => _FyReportScreenState();
}

class _FyReportScreenState extends ConsumerState<FyReportScreen> {
  late int _fyYear = widget.initialFyYear;

  /// The current FY and the two before it, plus the one opened from history.
  List<int> get _chipYears {
    final now = DateTime.now();
    final current = now.month >= 4 ? now.year : now.year - 1;
    final latest = math.max(current, widget.initialFyYear);
    return {latest, latest - 1, latest - 2, widget.initialFyYear}.toList()
      ..sort((a, b) => b.compareTo(a));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPrivate = ref.watch(privacyModeProvider);
    final report = ref.watch(fyReportProvider(_fyYear));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fyReportScreenTitle),
        actions: [
          IconButton(
            tooltip: isPrivate
                ? l10n.fyReportShowAmounts
                : l10n.fyReportHideAmounts,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              isPrivate
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () => ref.read(privacyModeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenEdge,
          AppSpacing.xs,
          AppSpacing.screenEdge,
          AppSpacing.xl,
        ),
        children: [
          _YearChips(
            years: _chipYears,
            selected: _fyYear,
            onSelected: (y) => setState(() => _fyYear = y),
          ),
          const SizedBox(height: AppSpacing.xl),
          report.when(
            data: (r) => _ReportBody(report: r),
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(l10n.fyReportLoadError),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearChips extends StatelessWidget {
  const _YearChips({
    required this.years,
    required this.selected,
    required this.onSelected,
  });

  final List<int> years;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Semantics(
      container: true,
      label: l10n.fyReportYearChipsLabel,
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final y in years)
            Semantics(
              button: true,
              selected: y == selected,
              child: Material(
                color: y == selected ? primary : Colors.transparent,
                shape: StadiumBorder(
                  side: y == selected
                      ? BorderSide.none
                      : BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onSelected(y),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          l10n.fyLabel('$y', _twoDigits(y + 1)),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: y == selected
                                ? AppColors.onFill(primary)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _twoDigits(int year) => (year % 100).toString().padLeft(2, '0');

class _ReportBody extends ConsumerWidget {
  const _ReportBody({required this.report});

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
    final dates = DateFormat.yMMMd();
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
        _Hero(report: report, money: money),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.fyReportMoneyTitle, style: heading),
        const SizedBox(height: AppSpacing.sm),
        _Tiles(
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
              _TaxRow(
                label: l10n.fyReportInterestIncome,
                amount: money(report.interestIncome),
              ),
              const Divider(height: 1),
              _TaxRow(
                label: l10n.fyReportDividendIncome,
                amount: money(report.dividendIncome),
              ),
              const Divider(height: 1),
              // Capital gains are always 0 until a cost-basis model exists, so
              // say so instead of showing a misleading zero.
              _TaxRow(
                label: l10n.fyReportCapitalGains,
                value: l10n.fyReportNotCalculated,
                hint: l10n.fyReportCapitalGainsHint,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _Monthly(report: report, money: money),
        if (report.topPerformersByReturns.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.topPerformers, style: heading),
          const SizedBox(height: AppSpacing.sm),
          for (final p in report.topPerformersByReturns.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _Performer(p: p, money: money),
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

class _Hero extends StatelessWidget {
  const _Hero({required this.report, required this.money});

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
                Text(
                  xirr == null ? '—' : '${(xirr * 100).toStringAsFixed(1)}%',
                  style: chipValue,
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

class _Tiles extends StatelessWidget {
  const _Tiles({required this.tiles});

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

class _TaxRow extends StatelessWidget {
  const _TaxRow({required this.label, this.amount, this.value, this.hint});

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

class _Monthly extends StatelessWidget {
  const _Monthly({required this.report, required this.money});

  final FYReport report;
  final String Function(double, {bool signed}) money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final soft = primary.withValues(alpha: 0.35);
    final months = report.monthlyBreakdown;
    if (months.isEmpty) return const SizedBox.shrink();

    final maxAbs = months.map((m) => m.net.abs()).fold<double>(0, math.max);
    final best = months.reduce((a, b) => b.net > a.net ? b : a);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.fyReportMonthlyTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                image: true,
                label: l10n.fyReportMonthlyChart,
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final m in months)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: FractionallySizedBox(
                                heightFactor: maxAbs == 0
                                    ? 0.04
                                    : math.max(0.04, m.net.abs() / maxAbs),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: m.net < 0
                                        ? theme.colorScheme.error
                                        : identical(m, best)
                                        ? primary
                                        : soft,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(months.first.monthName, style: muted),
                  Text(months.last.monthName, style: muted),
                ],
              ),
              if (best.net > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: MaskedAmountText(
                    text: l10n.fyReportBestMonth(
                      best.monthName,
                      money(best.net, signed: true),
                    ),
                    style: muted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Performer extends StatelessWidget {
  const _Performer({required this.p, required this.money});

  final InvestmentWithReturns p;
  final String Function(double, {bool signed}) money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final muted = theme.colorScheme.onSurfaceVariant;
    final xirr = p.xirr;

    return GlassCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: primary.withValues(alpha: 0.1),
            child: Icon(Icons.trending_up_rounded, size: 20, color: primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.investment.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  p.investment.type.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MaskedAmountText(
                  text: money(p.absoluteReturns, signed: true),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  xirr == null
                      ? '—'
                      : l10n.fyReportXirrSuffix(
                          '${(xirr * 100).toStringAsFixed(1)}%',
                        ),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

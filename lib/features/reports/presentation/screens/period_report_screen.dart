/// Weekly, monthly and yearly report: one screen that renders a
/// [ReportResult] from the reporting engine (docs/reporting-engine.md).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/reporting/metric_value.dart';
import 'package:inv_tracker/core/reporting/report_definition.dart';
import 'package:inv_tracker/core/reporting/report_formatter.dart';
import 'package:inv_tracker/core/reporting/report_period.dart';
import 'package:inv_tracker/core/reporting/report_result.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/reports/presentation/providers/period_report_provider.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_stat_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class PeriodReportScreen extends ConsumerStatefulWidget {
  final ReportPeriodKind initialKind;
  const PeriodReportScreen({
    super.key,
    this.initialKind = ReportPeriodKind.week,
  });

  @override
  ConsumerState<PeriodReportScreen> createState() => _PeriodReportScreenState();
}

class _PeriodReportScreenState extends ConsumerState<PeriodReportScreen> {
  late ReportPeriodKind _kind = widget.initialKind;
  late DateTime _anchor = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  ReportPeriod get _period => ReportPeriod.containing(_kind, _anchor);

  void _step(int direction) => setState(() {
    final p = _period;
    _anchor = direction < 0 ? p.previous().start : p.endExclusive;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = ref.watch(
      periodReportProvider((kind: _kind, anchor: _anchor)),
    );
    final isCurrent = _period.contains(_today());

    return Scaffold(
      appBar: AppBar(title: Text(l10n.periodReportTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final (kind, label) in [
                (ReportPeriodKind.week, l10n.periodReportWeek),
                (ReportPeriodKind.month, l10n.periodReportMonth),
                (ReportPeriodKind.fy, l10n.periodReportYear),
              ])
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: l10n.periodReportPrevious,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _step(-1),
              ),
              Expanded(
                child: Text(
                  _label(l10n, _period),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: l10n.periodReportNext,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: isCurrent ? null : () => _step(1),
              ),
            ],
          ),
          result.when(
            data: (r) => PeriodReportView(result: r),
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(l10n.failedToGenerateReport),
            ),
          ),
        ],
      ),
    );
  }

  String _label(AppLocalizations l10n, ReportPeriod p) {
    switch (p.kind) {
      case ReportPeriodKind.week:
        final last = DateTime(
          p.endExclusive.year,
          p.endExclusive.month,
          p.endExclusive.day - 1,
        );
        return l10n.periodReportRange(
          AppDateUtils.formatShort(p.start),
          AppDateUtils.formatShort(last),
        );
      case ReportPeriodKind.fy:
        return l10n.periodReportFinancialYear(p.fyLabel);
      default:
        return AppDateUtils.formatMonthYear(p.start);
    }
  }
}

/// Renders a [ReportResult]: pure over its input, so a test can pump it with
/// a hand-made result.
class PeriodReportView extends ConsumerWidget {
  final ReportResult result;
  const PeriodReportView({super.key, required this.result});

  static const _cards = [
    (ReportMetric.invested, Icons.trending_down_rounded),
    (ReportMetric.returned, Icons.trending_up_rounded),
    (ReportMetric.income, Icons.payments_rounded),
    (ReportMetric.fees, Icons.receipt_long_rounded),
    (ReportMetric.netCashFlow, Icons.account_balance_wallet_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fmt = ReportFormatter(
      symbol: ref.watch(currencySymbolProvider),
      locale: ref.watch(currencyLocaleProvider),
      privacy: ref.watch(privacyModeProvider),
    );
    final labels = {
      ReportMetric.invested: l10n.periodReportInvested,
      ReportMetric.returned: l10n.periodReportReturned,
      ReportMetric.income: l10n.periodReportIncome,
      ReportMetric.fees: l10n.periodReportFees,
      ReportMetric.netCashFlow: l10n.periodReportNet,
    };
    final quiet = result.totals.values.every((v) => v.valueOrNull == 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final note in result.notes)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              note.kind == ReportNoteKind.excludedFlows
                  ? l10n.periodReportExcludedFlows(note.count)
                  : l10n.periodReportArchivedNote(note.count),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (quiet)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(l10n.periodReportNothing),
          ),
        for (final (metric, icon) in _cards)
          if (result.totals.containsKey(metric)) ...[
            ReportStatCard(
              icon: icon,
              label: labels[metric]!,
              value: fmt.money(result.totals[metric]!),
            ),
            if (result.previous != null)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.xs,
                  left: AppSpacing.xs,
                ),
                child: Text(
                  l10n.periodReportChange(
                    fmt.percent(result.changePercent(metric), signed: true),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        for (final b in result.breakdowns.entries)
          if (b.value.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(switch (b.key) {
                Breakdown.byInvestmentType => l10n.periodReportByType,
                Breakdown.byCurrency => l10n.periodReportByCurrency,
                Breakdown.byMonth => l10n.periodReportByMonth,
              }, style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final row in b.value)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Expanded(child: Text(_rowLabel(b.key, row.key))),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      fmt.money(
                        row.values[ReportMetric.netCashFlow] ??
                            const Unknown(UnknownReason.notApplicable),
                      ),
                      semanticsLabel: fmt.privacy ? l10n.hiddenAmount : null,
                    ),
                  ],
                ),
              ),
          ],
      ],
    );
  }

  static String _rowLabel(Breakdown b, String key) {
    switch (b) {
      case Breakdown.byInvestmentType:
        return InvestmentType.values.byName(key).displayName;
      case Breakdown.byMonth:
        final parts = key.split('-');
        return AppDateUtils.formatMonthYear(
          DateTime(int.parse(parts[0]), int.parse(parts[1])),
        );
      case Breakdown.byCurrency:
        return key;
    }
  }
}

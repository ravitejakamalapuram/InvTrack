/// Monthly bars and top performers of the Tax-Year (FY) report (#800). Amounts go
/// through [MaskedAmountText] so privacy mode hides them.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/fy_hero.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class FyMonthly extends ConsumerWidget {
  const FyMonthly({super.key, required this.report, required this.money});

  final FYReport report;
  final String Function(double, {bool signed}) money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bar heights and colours encode each month's cash flow, so privacy mode
    // draws them flat.
    final isPrivate = ref.watch(privacyModeProvider);
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
                                heightFactor: isPrivate
                                    ? 0.3
                                    : maxAbs == 0
                                    ? 0.04
                                    : math.max(0.04, m.net.abs() / maxAbs),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: isPrivate
                                        ? soft
                                        : m.net < 0
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

class FyPerformer extends StatelessWidget {
  const FyPerformer({super.key, required this.p, required this.money});

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
                xirr == null
                    ? Text(
                        '—',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      )
                    : MaskedAmountText(
                        text: l10n.fyReportXirrSuffix(fyPercent(context, xirr)),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

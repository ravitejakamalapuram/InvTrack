import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/router/navigation_extensions.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/accessibility_utils.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/empty_state_widget.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/core/widgets/privacy_toggle_button.dart';
import 'package:inv_tracker/features/digest/domain/monthly_digest.dart';
import 'package:inv_tracker/features/digest/presentation/providers/monthly_digest_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// What came in last month, what matures next month and which open
/// investments need a value. Mocked in design/system/components/MonthlyDigest.
class MonthlyRecapScreen extends ConsumerWidget {
  final DigestMonth month;

  const MonthlyRecapScreen({super.key, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final monthName = DateFormat.MMMM(locale).format(month.start);
    final range = l10n.monthlyRecapRange(
      DateFormat.d(locale).add_MMM().format(month.start),
      DateFormat.yMMMd(
        locale,
      ).format(month.end.subtract(const Duration(days: 1))),
    );
    final digestAsync = ref.watch(monthlyDigestProvider(month));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.safePop(),
          tooltip: l10n.tooltipBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.monthlyRecapTitle(monthName)),
            Text(range, style: AppTypography.caption),
          ],
        ),
        actions: const [
          CompactPrivacyToggle(),
          SizedBox(width: AppSpacing.appBarTrailingGap),
        ],
      ),
      body: digestAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          LoggerService.warn('Monthly recap failed to load', error: error);
          return EmptyStateWidget(
            icon: Icons.cloud_off_rounded,
            title: l10n.monthlyRecapLoadError,
            message: l10n.pleaseTryAgain,
            actionLabel: l10n.retry,
            actionIcon: Icons.refresh_rounded,
            onAction: () {
              ref.invalidate(convertedCashFlowsSnapshotProvider);
              ref.invalidate(activeInvestmentsProvider);
              ref.invalidate(activeInvestmentBasicStatsMapProvider);
            },
          );
        },
        data: (digest) => _RecapBody(digest: digest, locale: locale),
      ),
    );
  }
}

class _RecapBody extends StatelessWidget {
  final MonthlyDigest digest;
  final String locale;

  const _RecapBody({required this.digest, required this.locale});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.neutral500Dark : AppColors.neutral500Light;
    final nextName = DateFormat.MMMM(locale).format(digest.month.next.start);

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.listItemSpacing),
      child: Semantics(
        header: true,
        child: Text(text, style: AppTypography.h4),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenEdge,
        AppSpacing.md,
        AppSpacing.screenEdge,
        AppSpacing.xxl,
      ),
      children: [
        heading(l10n.monthlyRecapMoneyIn),
        _MoneyInCard(digest: digest, locale: locale),
        const SizedBox(height: AppSpacing.sectionSpacing),
        heading(l10n.monthlyRecapComingUp(nextName)),
        if (digest.maturingNextMonth.isEmpty)
          Text(
            l10n.monthlyRecapNothingMatures(nextName),
            style: AppTypography.body.copyWith(color: muted),
          )
        else
          for (final investment in digest.maturingNextMonth)
            _MaturingRow(investment: investment, locale: locale),
        if (digest.needingValue.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sectionSpacing),
          heading(l10n.monthlyRecapNeedsValue),
          for (final investment in digest.needingValue)
            _NeedsValueRow(investment: investment),
        ],
        const SizedBox(height: AppSpacing.sectionSpacing),
        Text(
          l10n.monthlyRecapArchivedNote,
          style: AppTypography.caption.copyWith(color: muted),
        ),
      ],
    );
  }
}

class _MoneyInCard extends ConsumerWidget {
  final MonthlyDigest digest;
  final String locale;

  const _MoneyInCard({required this.digest, required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPrivate = ref.watch(privacyModeProvider);
    final format = ref.watch(currencyFormatProvider);
    final symbol = ref.watch(currencySymbolProvider);
    final currencyLocale = ref.watch(currencyLocaleProvider);
    final monthName = DateFormat.MMMM(locale).format(digest.month.start);
    final previousName = DateFormat.MMMM(
      locale,
    ).format(digest.month.previous.start);
    final moneyIn = digest.moneyIn;

    if (moneyIn.count == 0) {
      return EmptyStateWidget(
        compact: true,
        icon: Icons.payments_outlined,
        title: l10n.monthlyRecapNoPayouts(monthName),
        message: l10n.monthlyRecapNoPayoutsHint(monthName),
        actionLabel: l10n.monthlyRecapAddPayout,
        onAction: () => context.go('/investments'),
      );
    }

    String spoken(double amount) => isPrivate
        ? l10n.hiddenAmount
        : AccessibilityUtils.formatCurrencyForScreenReader(
            amount,
            symbol,
            locale: currencyLocale,
          );
    final detail = l10n.monthlyRecapPayoutCount(
      moneyIn.count,
      moneyIn.investmentCount,
    );
    final change = digest.change;
    final changeText = format.formatSmart(change.abs());
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final Widget comparison;
    if (isPrivate) {
      comparison = Row(
        children: [
          Text(
            '${l10n.monthlyRecapCompared(previousName)} ',
            style: AppTypography.caption.copyWith(color: secondary),
          ),
          MaskedAmountText(text: changeText, style: AppTypography.caption),
        ],
      );
    } else if (change == 0) {
      comparison = _ChangeLine(
        icon: Icons.trending_flat,
        color: secondary,
        text: l10n.monthlyRecapSame(previousName),
      );
    } else {
      final up = change > 0;
      final color = up
          ? (isDark ? AppColors.successDark : AppColors.successLight)
          : (isDark ? AppColors.dangerDark : AppColors.dangerLight);
      final signed = '${up ? '+' : '-'}$changeText';
      comparison = Semantics(
        label: up
            ? l10n.monthlyRecapUpSemantics(spoken(change), previousName)
            : l10n.monthlyRecapDownSemantics(spoken(change), previousName),
        excludeSemantics: true,
        child: _ChangeLine(
          icon: up ? Icons.trending_up : Icons.trending_down,
          color: color,
          text: up
              ? l10n.monthlyRecapMore(signed, previousName)
              : l10n.monthlyRecapLess(signed, previousName),
        ),
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: l10n.monthlyRecapHeadlineSemantics(
              monthName,
              spoken(moneyIn.total),
              detail,
            ),
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.monthlyRecapPayoutsReceived,
                  style: AppTypography.caption.copyWith(color: secondary),
                ),
                const SizedBox(height: AppSpacing.xxs),
                MaskedAmountText(
                  text: format.formatSmart(moneyIn.total),
                  style: AppTypography.numberLarge.copyWith(fontSize: 28),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  detail,
                  style: AppTypography.caption.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          comparison,
        ],
      ),
    );
  }
}

class _ChangeLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _ChangeLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: AppSpacing.xxs),
      Flexible(
        child: Text(
          text,
          style: AppTypography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

class _MaturingRow extends StatelessWidget {
  final InvestmentEntity investment;
  final String locale;

  const _MaturingRow({required this.investment, required this.locale});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = investment.maturityDate!;
    final chipDate = DateFormat.d(locale).add_MMM().format(date).toUpperCase();
    final spokenDate = DateFormat.MMMMd(locale).format(date);
    final accent = Theme.of(context).colorScheme.primary;
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.listItemSpacing),
      child: GlassCard(
        semanticLabel: l10n.monthlyRecapMaturesSemantics(
          investment.name,
          investment.typeLabel,
          spokenDate,
        ),
        onTap: () => context.push('/investments/${investment.id}'),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: investment.type.tintColor(brightness),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                investment.type.icon,
                size: 20,
                color: investment.type.textColor(brightness),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    investment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Wrap(
                    spacing: AppSpacing.chipSpacing,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      Text(investment.typeLabel, style: AppTypography.caption),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event, size: 14, color: accent),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            l10n.monthlyRecapMatures(chipDate),
                            style: AppTypography.small.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _NeedsValueRow extends StatelessWidget {
  final InvestmentEntity investment;

  const _NeedsValueRow({required this.investment});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.neutral500Dark : AppColors.neutral500Light;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.listItemSpacing),
      child: GlassCard(
        child: Row(
          children: [
            Icon(Icons.hourglass_empty, color: muted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(investment.name, style: AppTypography.bodyMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    l10n.monthlyRecapNeedsValueReason,
                    style: AppTypography.caption.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.push('/investments/${investment.id}'),
              child: Text(l10n.monthlyRecapUpdate),
            ),
          ],
        ),
      ),
    );
  }
}

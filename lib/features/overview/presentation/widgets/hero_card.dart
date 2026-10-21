/// Hero card widgets for the overview screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/utils/accessibility_utils.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/text_measure.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/core/widgets/privacy_toggle_button.dart';
import 'package:inv_tracker/core/widgets/stat_columns.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/utils/return_display.dart';
import 'package:inv_tracker/features/investment/presentation/utils/xirr_viewed_logger.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Notifier for toggling between all and realized-only net position
class ShowRealizedOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool value) => state = value;
}

final showRealizedOnlyProvider =
    NotifierProvider<ShowRealizedOnlyNotifier, bool>(
      ShowRealizedOnlyNotifier.new,
    );

/// Hero card with toggle for showing all vs realized-only stats.
class HeroCardWithToggle extends ConsumerWidget {
  final AsyncValue<InvestmentStats> globalStats;
  final AsyncValue<InvestmentStats> openStats;
  final AsyncValue<InvestmentStats> closedStats;
  final NumberFormat currencyFormat;
  final Widget Function(String error) errorBuilder;

  /// Archived investments, which the totals leave out (A17).
  final int archivedCount;

  /// True when a total used an exchange rate over 24 hours old (A14).
  final bool isApproximate;

  const HeroCardWithToggle({
    super.key,
    required this.globalStats,
    required this.openStats,
    required this.closedStats,
    required this.currencyFormat,
    required this.errorBuilder,
    this.archivedCount = 0,
    this.isApproximate = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showRealizedOnly = ref.watch(showRealizedOnlyProvider);

    return globalStats.when(
      loading: () => const LoadingHeroCard(),
      error: (e, _) => errorBuilder(e.toString()),
      data: (global) {
        // Until the open subset is known, assume everything may be open so a
        // missing terminal value is never shown as a loss.
        final open = openStats.hasValue ? openStats.requireValue : global;
        return closedStats.when(
          loading: () => HeroCardContent(
            globalStats: global,
            openStats: open,
            closedStats: global,
            closedStatsReady: false,
            currencyFormat: currencyFormat,
            showRealizedOnly: showRealizedOnly,
            archivedCount: archivedCount,
            isApproximate: isApproximate,
          ),
          error: (e, s) => HeroCardContent(
            globalStats: global,
            openStats: open,
            closedStats: global,
            closedStatsReady: false,
            currencyFormat: currencyFormat,
            showRealizedOnly: showRealizedOnly,
            archivedCount: archivedCount,
            isApproximate: isApproximate,
          ),
          data: (closed) => HeroCardContent(
            globalStats: global,
            openStats: open,
            closedStats: closed,
            currencyFormat: currencyFormat,
            showRealizedOnly: showRealizedOnly,
            archivedCount: archivedCount,
            isApproximate: isApproximate,
          ),
        );
      },
    );
  }
}

/// Content of the hero card showing net position and stats.
class HeroCardContent extends ConsumerWidget {
  final InvestmentStats globalStats;

  /// Stats of the open investments within [globalStats]. They have no
  /// terminal value yet, which decides whether returns can be shown.
  final InvestmentStats openStats;
  final InvestmentStats closedStats;

  /// False while [closedStats] is a stand-in (still loading or failed), so
  /// no other figure is shown as the realised XIRR.
  final bool closedStatsReady;
  final NumberFormat currencyFormat;
  final bool showRealizedOnly;

  /// How many archived investments the figures leave out. Archived
  /// investments are excluded from every Overview total on purpose (A17), so
  /// the card says so when there are any.
  final int archivedCount;

  /// True when a total used an exchange rate over 24 hours old (A14): the
  /// card then carries a small marker saying so.
  final bool isApproximate;

  const HeroCardContent({
    super.key,
    required this.globalStats,
    required this.openStats,
    required this.closedStats,
    this.closedStatsReady = true,
    required this.currencyFormat,
    required this.showRealizedOnly,
    this.archivedCount = 0,
    this.isApproximate = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stats = showRealizedOnly ? closedStats : globalStats;
    final display = ReturnDisplay.resolve(
      stats: stats,
      openStats: showRealizedOnly ? null : openStats,
    );
    final isPrivacyMode = ref.watch(privacyModeProvider);
    logXirrViewedOnce(
      ref,
      surface: XirrSurface.overview,
      display: display,
      isHidden: isPrivacyMode,
    );
    final netPosition = stats.netCashFlow;
    final status = display.statusLabel(l10n);

    // Privacy mode hides amounts from the screen reader as well.
    final semanticLabel = AccessibilityUtils.statCardLabel(
      title: showRealizedOnly ? 'Realized Net Position' : l10n.netCashFlowSoFar,
      value: isPrivacyMode
          ? l10n.hiddenAmount
          : AccessibilityUtils.formatCurrencyForScreenReader(
              netPosition,
              currencyFormat.currencySymbol,
              locale: currencyFormat.locale,
            ),
      subtitle: !stats.hasData
          ? null
          : status != null
          ? 'Return: $status'
          : display.semanticsFigure(
              l10n,
              isPrivacyMode
                  ? 'Return: ${l10n.hiddenPercentage}'
                  : 'Return: ${AccessibilityUtils.formatPercentageForScreenReader(stats.absoluteReturn)}',
            ),
    );

    return Semantics(
      label: semanticLabel,
      child: GlassHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitleRow(context, ref),
            const SizedBox(height: 8),
            _buildValueRow(
              netPosition,
              stats,
              status,
              display.badgeText(l10n),
              ref,
            ),
            const SizedBox(height: 16),
            _buildStatsRow(stats, display, l10n, ref),
            // The return % is on paid-in capital, not on money out.
            if (status == null && stats.hasReinvestedPayouts) ...[
              const SizedBox(height: 6),
              Text(
                l10n.moneyOutIncludesFeesReinvested,
                style: TextStyle(
                  color: AppColors.heroSecondaryText,
                  fontSize: 11,
                ),
              ),
            ],
            if (display.isAwaitingValue ||
                (display.kind == ReturnDisplayKind.annualised &&
                    display.isEstimate)) ...[
              const SizedBox(height: 6),
              Text(
                display.secondaryText(l10n)!,
                style: TextStyle(
                  color: AppColors.heroSecondaryText,
                  fontSize: 11,
                ),
              ),
            ],
            if (archivedCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                l10n.overviewArchivedExcluded(archivedCount),
                style: TextStyle(
                  color: AppColors.heroSecondaryText,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 8),
            _buildCurrencyIndicator(ref),
            if (showRealizedOnly) ...[
              const SizedBox(height: 4),
              Text(
                'Showing closed investments only',
                style: TextStyle(
                  color: AppColors.heroSecondaryText,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: Text(
            showRealizedOnly
                ? 'Realized Net Position'
                : AppLocalizations.of(context).netCashFlowSoFar,
            style: TextStyle(color: AppColors.heroSecondaryText, fontSize: 14),
          ),
        ),
        if (isApproximate) ...[
          Semantics(
            label: AppLocalizations.of(context).approximateRatesNote,
            child: Tooltip(
              message: AppLocalizations.of(context).approximateRatesNote,
              excludeFromSemantics: true,
              triggerMode: TooltipTriggerMode.tap,
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.heroSecondaryText,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        // Privacy toggle button
        const PrivacyToggleButton(iconSize: 18),
        const SizedBox(width: 8),
        _buildToggleButton(ref),
      ],
    );
  }

  Widget _buildToggleButton(WidgetRef ref) {
    void onTap() {
      HapticFeedback.lightImpact();
      ref.read(showRealizedOnlyProvider.notifier).toggle();
    }

    return Semantics(
      button: true,
      label: showRealizedOnly
          ? 'Switch to all investments'
          : 'Switch to realized investments only',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        // A 48dp tap target around the 29dp chip.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.heroChipFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        showRealizedOnly
                            ? Icons.check_circle
                            : Icons.all_inclusive,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        showRealizedOnly ? 'Realized' : 'All',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValueRow(
    double netPosition,
    InvestmentStats stats,
    String? status,
    String badgeText,
    WidgetRef ref,
  ) {
    final isPrivacyMode = ref.watch(privacyModeProvider);
    // A neutral chip replaces the return % while open investments have no
    // terminal value; otherwise the badge would show a fake loss.
    const badgeColor = AppColors.heroChipFill;
    // White on a dark scrim: green and red text on a tint of itself fell to
    // 1.6:1. The badge starts with + or -, so colour is not the only carrier.
    final badgeTextColor = AppColors.heroSecondaryText;

    const figureStyle = TextStyle(
      color: Colors.white,
      fontSize: 36,
      fontWeight: FontWeight.bold,
    );
    final figureText = currencyFormat.formatSmart(netPosition);
    // Shrinks to fit the line instead of ending in an ellipsis: this is the
    // number people raise the text size to read (#1004). The box is the width
    // of the figure as written, so privacy mode, which draws dots in its
    // place, shrinks by the same factor and nothing moves.
    final value = Builder(
      builder: (context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: measureTextWidth(context, figureText, figureStyle),
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: PrivacyMask(
              child: CompactAmountText(
                key: const ValueKey('hero-net-cash-flow'),
                amount: netPosition,
                compactText: figureText,
                currencySymbol: currencyFormat.currencySymbol,
                locale: currencyFormat.locale,
                style: figureStyle,
                maxLines: 1,
              ),
            ),
          ),
        ),
      ),
    );

    final badgeStyle = TextStyle(
      color: badgeTextColor,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    );
    const badgePadding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    final badge = AnimatedOpacity(
      key: const ValueKey('hero-return-badge'),
      duration: const Duration(milliseconds: 200),
      opacity: isPrivacyMode ? 0.0 : 1.0,
      child: Container(
        padding: badgePadding,
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(status ?? badgeText, style: badgeStyle),
      ),
    );

    // Status text is descriptive, not a metric. Keep it below the amount so
    // a long localized "Awaiting current value" label can never squeeze the
    // primary net-cash-flow figure out of the row on narrow screens.
    if (status != null) {
      return SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [value, const SizedBox(height: 6), badge],
        ),
      );
    }

    if (!stats.hasData) return Row(children: [Flexible(child: value)]);

    // One rule for every return badge ("+12.3%", "+123.5% so far"): it sits
    // beside the figure on the figure's baseline when both fit on one line,
    // and drops below it, on the start edge, when they do not. The decision is
    // made on the figure as it would be written, so privacy mode, which draws
    // dots in its place, decides the same way and nothing moves.
    const gap = 10.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final needed =
            measureTextWidth(context, figureText, figureStyle) +
            gap +
            badgePadding.horizontal +
            measureTextWidth(context, badgeText, badgeStyle);
        if (needed + 0.5 > constraints.maxWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [value, const SizedBox(height: 6), badge],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(child: value),
            const SizedBox(width: gap),
            badge,
          ],
        );
      },
    );
  }

  Widget _buildStatsRow(
    InvestmentStats stats,
    ReturnDisplay display,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
    final isPrivacyMode = ref.watch(privacyModeProvider);
    final showRealised =
        closedStatsReady &&
        display.kind == ReturnDisplayKind.annualised &&
        display.isEstimate;

    // Equal columns that end on the card padding, like the buttons above:
    // out, in, XIRR. Large text drops them to fewer per row, the last one
    // alone on a line of label and value; see StatColumns.
    return StatColumns(
      minColumnWidth: AppSizes.statColumnMinWidth,
      columns: [
        // Cash Out with up arrow
        _buildCashFlowStat(
          icon: Icons.arrow_upward_rounded,
          amount: stats.totalInvested,
          value: currencyFormat.formatCompact(stats.totalInvested),
          label: 'out',
          isPrivacyMode: isPrivacyMode,
        ),
        // Cash In with down arrow
        _buildCashFlowStat(
          icon: Icons.arrow_downward_rounded,
          amount: stats.totalReturned,
          value: currencyFormat.formatCompact(stats.totalReturned),
          label: 'in',
          isPrivacyMode: isPrivacyMode,
        ),
        // XIRR
        _buildXirrStat(
          display.metricLabel(l10n),
          display.primaryText(l10n, showSign: false),
        ),
        // Realised XIRR of closed investments after the expected one
        if (showRealised)
          _buildXirrStat(
            l10n.realisedXirrLabel,
            ReturnDisplay.resolve(
              stats: closedStats,
            ).primaryText(l10n, showSign: false),
          ),
      ],
    );
  }

  StatColumn _buildXirrStat(String label, String value) {
    return StatColumn(
      labelText: label,
      label: Text(
        label,
        style: TextStyle(color: AppColors.heroSecondaryText, fontSize: 12),
      ),
      value: MaskedAmountText(
        text: value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCurrencyIndicator(WidgetRef ref) {
    final baseCurrency = ref.watch(currencyCodeProvider);
    final currencySymbol = getCurrencySymbol(baseCurrency);

    // Expanded, so the base-currency disclosure wraps onto a second line
    // instead of overflowing or being cut off.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 12, color: AppColors.heroSecondaryText),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'All amounts shown in $currencySymbol ($baseCurrency)',
            style: TextStyle(
              color: AppColors.heroSecondaryText,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  StatColumn _buildCashFlowStat({
    required IconData icon,
    required double amount,
    required String value,
    required String label,
    required bool isPrivacyMode,
  }) {
    return StatColumn(
      labelText: label,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The arrow has no baseline of its own: the label's is its text's.
          IgnoreBaseline(
            child: Icon(icon, color: AppColors.heroSecondaryText, size: 14),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.heroSecondaryText,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      // maxLines and the ellipsis are a last resort, so one very large amount
      // shrinks instead of overflowing.
      value: isPrivacyMode
          ? MaskedAmountText(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : CompactAmountText(
              amount: amount,
              compactText: value,
              currencySymbol: currencyFormat.currencySymbol,
              locale: currencyFormat.locale,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}

/// Loading state for the hero card.
class LoadingHeroCard extends StatelessWidget {
  const LoadingHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 200,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}

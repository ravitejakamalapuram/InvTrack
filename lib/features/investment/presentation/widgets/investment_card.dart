/// Investment card widget for the list view.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/accessibility_utils.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/utils/number_format_utils.dart';
import 'package:inv_tracker/core/utils/text_measure.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';
import 'package:inv_tracker/features/investment/presentation/utils/return_display.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// A card displaying an investment's summary information.
class InvestmentCard extends ConsumerWidget {
  final InvestmentEntity investment;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool?>? onCheckboxChanged;
  final DateTime? referenceDate;

  const InvestmentCard({
    super.key,
    required this.investment,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.onCheckboxChanged,
    this.referenceDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = investment.type.color;
    final typeName = investmentTypeName(ref, investment);
    final isClosed = investment.status == InvestmentStatus.closed;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final currencyFormat = ref.watch(currencyFormatProvider);
    final isPrivacyMode = ref.watch(privacyModeProvider);

    // Amounts are in the base currency: active cards read the converted
    // snapshot, archived cards the converted archived stats, the same values
    // as the detail screen.
    // OPTIMIZATION: Active cards use the basic stats map, which skips the
    // expensive XIRR calculation, and watch XIRR separately.
    final AsyncValue<InvestmentStats> statsAsync;
    final AsyncValue<XirrResult> xirrAsync;
    if (investment.isArchived) {
      statsAsync = ref.watch(
        multiCurrencyArchivedInvestmentStatsProvider(investment.id),
      );
      xirrAsync = statsAsync.whenData((stats) => stats.xirrResult);
    } else {
      statsAsync = ref.watch(investmentBasicStatsProvider(investment.id));
      // Watch XIRR separately to include in accessibility label when ready
      xirrAsync = ref.watch(investmentXirrProvider(investment.id));
    }

    final l10n = AppLocalizations.of(context);

    // Resolved once for the label, the value column and the bottom strip.
    final stats = statsAsync.maybeWhen(data: (s) => s, orElse: () => null);
    final xirrResult = xirrAsync.value;
    final display = stats == null
        ? null
        : ReturnDisplay.resolve(
            stats: stats,
            openStats: isClosed ? null : stats,
            // Null while XIRR is loading: the stats' own (basic) value is used.
            xirr: xirrResult?.value,
            xirrMethod: xirrResult?.method,
          );
    final isAwaitingValue = display?.isAwaitingValue ?? false;

    // Build accessibility label
    final String baseLabel;
    if (stats == null || display == null) {
      baseLabel =
          '${isClosed ? "Closed" : "Open"} investment: ${investment.name}, Type: $typeName';
    } else {
      final xirrValue = display.xirr;
      final double? returnPercent = switch (display.kind) {
        ReturnDisplayKind.annualised =>
          xirrValue != null ? xirrValue * 100 : null,
        ReturnDisplayKind.shortHolding => stats.absoluteReturn,
        _ => null,
      };

      baseLabel = AccessibilityUtils.investmentCardLabel(
        name: investment.name,
        type: typeName,
        // An open investment awaiting a value shows what went in and came
        // back; its net would read as a loss.
        currentValue: isAwaitingValue ? null : stats.netCashFlow,
        receivedSegment: isAwaitingValue
            ? l10n.investmentCardReceivedSemantics(
                isPrivacyMode
                    ? l10n.hiddenAmount
                    : AccessibilityUtils.formatCurrencyForScreenReader(
                        stats.totalReturned,
                        currencySymbol,
                        locale: currencyFormat.locale,
                      ),
              )
            : null,
        // Null while XIRR is loading or undefined: the label leaves it out
        returnPercent: returnPercent,
        returnIsApproximate:
            display.kind == ReturnDisplayKind.annualised &&
            display.xirrMethod == XirrMethod.approximate,
        // "Expected", with its basis, until the user confirms the value.
        expectedReturnBasis:
            display.kind == ReturnDisplayKind.annualised && display.isEstimate
            ? display.secondaryText(l10n)
            : null,
        returnStatus: display.statusLabel(l10n),
        // "So far", and what the figure leaves out, when it is a minimum.
        returnQualifier: (returns) => display.semanticsFigure(l10n, returns),
        currencySymbol: currencySymbol,
        currencyLocale: currencyFormat.locale,
        isClosed: isClosed,
        maturityDate: investment.maturityDate,
        totalInvested: stats.totalInvested,
        lastActivityDate: stats.lastCashFlowDate ?? investment.createdAt,
        shouldMask: isPrivacyMode,
      );
    }

    final semanticLabel = isSelectionMode
        ? '${isSelected ? "Selected" : "Not selected"}, $baseLabel'
        : baseLabel;

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassCard(
        semanticLabel: semanticLabel,
        selected: isSelectionMode ? isSelected : null,
        // OPTIMIZATION: Disable blur on list items to avoid expensive BackdropFilter/saveLayer.
        // Since the background is solid, blurring it has no visual effect but high cost.
        blur: 0,
        onTap: onTap,
        onLongPress: onLongPress,
        padding: EdgeInsets.zero,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = _isCompact(
              context,
              cardWidth: constraints.maxWidth,
              isSelectionMode: isSelectionMode,
              valueWidth: _valueColumnWidth(
                context,
                stats: stats,
                display: display,
                currencyFormat: currencyFormat,
                isPrivacyMode: isPrivacyMode,
              ),
            );
            // Icon with type icon
            final typeIcon = _TypeIcon(
              typeColor: typeColor,
              isClosed: isClosed,
              icon: investment.type.icon,
            );
            // Name and type
            final info = _InvestmentInfo(
              investment: investment,
              typeName: typeName,
              isDark: isDark,
              typeColor: typeColor,
              isClosed: isClosed,
              referenceDate: referenceDate,
            );
            // Stats
            final value = _InvestmentValueColumn(
              xirrAsync: xirrAsync,
              isClosed: isClosed,
              isDark: isDark,
              statsAsync: statsAsync,
              display: display,
              currencyFormat: currencyFormat,
              isPrivacyMode: isPrivacyMode,
              compact: compact,
            );
            // Checkbox in selection mode, with the tile centred on its 48dp
            // target.
            final leading = <Widget>[
              if (isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: onCheckboxChanged,
                  activeColor: AppColors.primaryLight,
                ),
                SizedBox(width: AppSpacing.xs),
              ],
              isSelectionMode
                  ? SizedBox(
                      height: AppSizes.minTouchTarget,
                      child: Center(child: typeIcon),
                    )
                  : typeIcon,
              SizedBox(width: AppSpacing.md),
            ];

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  // Tile, name and figures hang from the top edge so the name
                  // and the first figure share a baseline. On a narrow card or
                  // with large text the figures drop under the name.
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...leading,
                                Expanded(child: info),
                              ],
                            ),
                            SizedBox(height: AppSpacing.sm),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: value,
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...leading,
                            Expanded(child: info),
                            SizedBox(width: AppSpacing.sm),
                            value,
                          ],
                        ),
                ),
                // Bottom info strip with stats
                _InvestmentBottomStrip(
                  investment: investment,
                  isDark: isDark,
                  statsAsync: statsAsync,
                  currencyFormat: currencyFormat,
                  isPrivacyMode: isPrivacyMode,
                  referenceDate: referenceDate,
                  isAwaitingValue: isAwaitingValue,
                  compact: compact,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The least room the name gets beside the figures, in dp at normal text size:
/// about 5.3 em of the 18sp name, enough for eleven characters including the
/// ellipsis ("P2P loan po..."). It grows with the text scale so a name keeps as
/// many characters at 200% text. Below it the figures drop under the name. Not
/// a design token.
const double _minNameWidthDp = 96;

/// Whether the name would get less than [_minNameWidthDp] (scaled with the
/// text) beside a value column [valueWidth] wide, so the figures must drop
/// under it. [cardWidth] is the card's inner width. The value column's width is
/// measured on what it draws, never guessed from the card width.
bool _isCompact(
  BuildContext context, {
  required double cardWidth,
  required bool isSelectionMode,
  required double valueWidth,
}) {
  final leading =
      (isSelectionMode ? AppSizes.minTouchTarget + AppSpacing.xs : 0) +
      AppSizes.iconXl +
      AppSpacing.md;
  final nameWidth =
      cardWidth - 2 * AppSpacing.md - leading - AppSpacing.sm - valueWidth;
  final nameSize = AppTypography.bodyLarge.fontSize!;
  final textScale = MediaQuery.textScalerOf(context).scale(nameSize) / nameSize;
  return nameWidth < _minNameWidthDp * textScale;
}

/// Width of the value column as drawn: its widest line, measured on the text it
/// shows. A masked figure is measured as the dots drawn in its place, so privacy
/// mode lays out the same whatever the amounts.
double _valueColumnWidth(
  BuildContext context, {
  required InvestmentStats? stats,
  required ReturnDisplay? display,
  required NumberFormat currencyFormat,
  required bool isPrivacyMode,
}) {
  // The spinner, or the chevron of a card with nothing to show.
  if (stats == null || !stats.hasData || display == null) {
    return AppSizes.iconMd;
  }
  final l10n = AppLocalizations.of(context);

  double figure(double amount, TextStyle style, {String prefix = ''}) {
    if (isPrivacyMode) {
      final dots = maskedAmountDots(style);
      return measureTextWidth(context, dots.text, dots.style);
    }
    return measureTextWidth(
      context,
      '$prefix${currencyFormat.formatCompact(amount)}',
      style,
    );
  }

  if (display.isAwaitingValue) {
    final amounts = math.max(
      figure(stats.totalInvested, _figureStyle()),
      figure(stats.totalReturned, _receivedStyle()),
    );
    final words = math.max(
      measureTextWidth(context, l10n.investmentCardInvestedLabel, _wordStyle()),
      measureTextWidth(context, l10n.investmentCardReceivedLabel, _wordStyle()),
    );
    final chip = math.min(
      _statusChipMaxWidth,
      2 * _chipPaddingX +
          measureTextWidth(
            context,
            display.statusLabel(l10n)!,
            _statusChipStyle(),
          ),
    );
    return math.max(amounts + AppSpacing.xxs + words, chip);
  }

  final isPositive = stats.netCashFlow >= 0;
  final net = figure(
    stats.netCashFlow.abs(),
    _figureStyle(),
    prefix: isPositive ? '+' : '-',
  );
  // The pill keeps its space even where privacy mode fades it out.
  final pill =
      2 * _chipPaddingX +
      measureTextWidth(context, display.pillText(l10n), _pillStyle());
  return math.max(net, pill);
}

// Text styles of the value column, shared by the widgets and the width probe
// so the width measured is the width drawn. A colour never changes a width.
TextStyle _figureStyle([Color? color]) =>
    AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: color);

TextStyle _receivedStyle([Color? color]) =>
    AppTypography.small.copyWith(fontWeight: FontWeight.w500, color: color);

TextStyle _wordStyle([Color? color]) =>
    AppTypography.small.copyWith(color: color);

TextStyle _statusChipStyle([Color? color]) =>
    AppTypography.small.copyWith(color: color, fontWeight: FontWeight.w600);

TextStyle _pillStyle([Color? color]) => AppTypography.small.copyWith(
  color: color,
  fontWeight: FontWeight.w600,
  fontSize: 10,
);

/// Horizontal padding of the return pill and the status chip.
const double _chipPaddingX = 6;

/// Extracted widget for type icon to avoid rebuilds during selection toggling.
class _TypeIcon extends StatelessWidget {
  final Color typeColor;
  final bool isClosed;
  final IconData icon;

  const _TypeIcon({
    required this.typeColor,
    required this.isClosed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.iconXl,
      height: AppSizes.iconXl,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isClosed
              ? [Colors.grey, Colors.grey.withValues(alpha: 0.7)]
              : [typeColor, typeColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd + 2),
        boxShadow: [
          BoxShadow(
            color: (isClosed ? Colors.grey : typeColor).withValues(alpha: 0.3),
            blurRadius: AppSpacing.xs,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: AppSizes.iconMd),
      ),
    );
  }
}

/// Extracted widget for name and type info to avoid rebuilds during selection toggling.
class _InvestmentInfo extends StatelessWidget {
  final InvestmentEntity investment;
  final String typeName;
  final bool isDark;
  final Color typeColor;
  final bool isClosed;
  final DateTime? referenceDate;

  const _InvestmentInfo({
    required this.investment,
    required this.typeName,
    required this.isDark,
    required this.typeColor,
    required this.isClosed,
    this.referenceDate,
  });

  @override
  Widget build(BuildContext context) {
    final maturityInfo = _getMaturityInfo();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          investment.name,
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: AppSpacing.xxs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                typeName,
                style: AppTypography.small.copyWith(
                  color: typeColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isClosed)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  AppLocalizations.of(context).closed,
                  style: AppTypography.small.copyWith(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (maturityInfo != null && !isClosed)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: maturityInfo.tint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      maturityInfo.icon,
                      size: 10,
                      color: maturityInfo.color,
                    ),
                    SizedBox(width: AppSpacing.xxs),
                    // Wraps on a narrow card or with large text, as the type
                    // chip beside it does. A status label is never cut.
                    Flexible(
                      child: Text(
                        maturityInfo.label,
                        style: AppTypography.small.copyWith(
                          color: maturityInfo.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Returns maturity info if the investment has an upcoming maturity date
  _MaturityInfo? _getMaturityInfo() {
    final maturityDate = investment.maturityDate;
    if (maturityDate == null) return null;

    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maturity = DateTime(
      maturityDate.year,
      maturityDate.month,
      maturityDate.day,
    );
    final daysUntilMaturity = maturity.difference(today).inDays;

    // Already matured
    if (daysUntilMaturity < 0) {
      return _MaturityInfo(
        label: 'MATURED',
        color: isDark ? AppColors.successDark : AppColors.successLight,
        // Tinted with the brighter green: on a tint of the deeper text green
        // the label would be 4.34:1.
        tint: isDark ? AppColors.successDark : AppColors.successTintLight,
        icon: Icons.check_circle_rounded,
      );
    }

    // Maturing today
    if (daysUntilMaturity == 0) {
      return _MaturityInfo(
        label: 'MATURES TODAY',
        color: isDark ? AppColors.warningDark : AppColors.warningTextLight,
        // Tinted with the bright amber: on a tint of the deeper text amber the
        // label would be 4.25:1.
        tint: isDark ? AppColors.warningDark : AppColors.warningLight,
        icon: Icons.schedule_rounded,
      );
    }

    // Within 7 days - urgent
    if (daysUntilMaturity <= 7) {
      return _MaturityInfo(
        label: '${daysUntilMaturity}d TO MATURITY',
        color: isDark ? AppColors.warningDark : AppColors.warningTextLight,
        tint: isDark ? AppColors.warningDark : AppColors.warningLight,
        icon: Icons.schedule_rounded,
      );
    }

    // Within 30 days - upcoming
    if (daysUntilMaturity <= 30) {
      return _MaturityInfo(
        label: '${daysUntilMaturity}d TO MATURITY',
        color: isDark ? AppColors.accentDark : AppColors.accentTextLight,
        tint: isDark ? AppColors.accentDark : AppColors.accentLight,
        icon: Icons.event_rounded,
      );
    }

    return null;
  }
}

/// Helper class for maturity badge info
class _MaturityInfo {
  final String label;

  /// The colour of the label and the icon.
  final Color color;

  /// The colour the chip is tinted with: [color] unless the label's colour is
  /// deeper than the hue the chip should have.
  final Color tint;
  final IconData icon;

  const _MaturityInfo({
    required this.label,
    required this.color,
    Color? tint,
    required this.icon,
  }) : tint = tint ?? color;
}

/// Displays the investment value and return percentage.
class _InvestmentValueColumn extends StatelessWidget {
  final AsyncValue<XirrResult> xirrAsync;
  final bool isClosed;
  final bool isDark;
  final AsyncValue<InvestmentStats> statsAsync;

  /// The card's resolved return display; null until the stats are loaded.
  final ReturnDisplay? display;
  final NumberFormat currencyFormat;
  final bool isPrivacyMode;
  final bool compact;

  const _InvestmentValueColumn({
    required this.xirrAsync,
    required this.isClosed,
    required this.isDark,
    required this.statsAsync,
    required this.display,
    required this.currencyFormat,
    required this.isPrivacyMode,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return statsAsync.when(
      data: (stats) {
        final display = this.display;
        if (!stats.hasData || display == null) {
          return Icon(
            Icons.chevron_right_rounded,
            color: isDark
                ? AppColors.neutral400Dark
                : AppColors.neutral400Light,
          );
        }

        // Open with no terminal value: what went in and came back, and a
        // neutral status. No net figure and no return %.
        if (display.isAwaitingValue) {
          return _AwaitingValue(
            stats: stats,
            status: display.statusLabel(AppLocalizations.of(context))!,
            isDark: isDark,
            currencyFormat: currencyFormat,
            isPrivacyMode: isPrivacyMode,
            compact: compact,
          );
        }

        final l10n = AppLocalizations.of(context);
        final isPositive = stats.netCashFlow >= 0;
        final plColor = isPositive
            ? AppColors.graphEmerald
            : (isDark ? AppColors.errorDark : AppColors.errorLight);

        final valueStyle = _figureStyle(plColor);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Net Position (cash in - cash out)
            isPrivacyMode
                ? MaskedAmountText(
                    text:
                        '${isPositive ? '+' : '-'}${currencyFormat.formatCompact(stats.netCashFlow.abs())}',
                    style: valueStyle,
                  )
                : CompactAmountText(
                    amount: stats.netCashFlow.abs(),
                    compactText: currencyFormat.formatCompact(
                      stats.netCashFlow.abs(),
                    ),
                    currencySymbol: currencyFormat.currencySymbol,
                    locale: currencyFormat.locale,
                    prefix: isPositive ? '+' : '-',
                    style: valueStyle,
                  ),
            SizedBox(height: AppSpacing.xxs),

            // XIRR - only show if valid and loaded
            xirrAsync.when(
              data: (result) {
                final xirr = result.value;
                final isShortHolding =
                    display.kind == ReturnDisplayKind.shortHolding;
                // An undefined XIRR shows no badge, never "0%".
                if (!isShortHolding && xirr == null) {
                  return const SizedBox.shrink();
                }
                final isAboveMax =
                    xirr != null &&
                    xirr * 100 >
                        XirrFormatConfig.defaultConfig.maxDisplayPercent;
                if (!isShortHolding && !isValidXirr(xirr!) && !isAboveMax) {
                  return const SizedBox.shrink();
                }
                final isGain =
                    (isShortHolding ? stats.absoluteReturn : xirr!) >= 0;
                final xirrColor = isGain
                    ? AppColors.graphEmerald
                    : (isDark ? AppColors.errorDark : AppColors.errorLight);
                // A loss is tinted with the brighter red: on a tint of the
                // deeper text red the pill would fall under 4.5:1.
                final xirrTint = isGain
                    ? AppColors.graphEmerald
                    : (isDark
                          ? AppColors.errorDark
                          : AppColors.dangerTintLight);
                final xirrFormatted = display.pillText(l10n);

                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isPrivacyMode ? 0.0 : 1.0,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _chipPaddingX,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: xirrTint.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(xirrFormatted, style: _pillStyle(xirrColor)),
                  ),
                );
              },
              loading: () => SizedBox(
                height: 14,
                width: 40,
                // Optional: show skeleton or nothing while loading XIRR
                // Showing nothing avoids UI jumping if it loads fast
                child: const SizedBox.shrink(),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        );
      },
      loading: () => SizedBox(
        width: AppSpacing.md,
        height: AppSpacing.md,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (e, s) => Icon(
        Icons.chevron_right_rounded,
        color: isDark ? AppColors.neutral400Dark : AppColors.neutral400Light,
      ),
    );
  }
}

/// The widest an awaiting card's status chip grows before it wraps to a
/// second line, so a long status never widens the figures beside the name.
const double _statusChipMaxWidth = 104;

/// What an open investment that awaits its current value shows: the amount put
/// in, the amount received so far and a neutral status chip. Both figures are
/// the card's stats totals, converted to the base currency.
///
/// The amounts share one right edge and each word sits on its amount's
/// baseline, so every card lines up whatever its figures.
class _AwaitingValue extends StatelessWidget {
  final InvestmentStats stats;
  final String status;
  final bool isDark;
  final NumberFormat currencyFormat;
  final bool isPrivacyMode;
  final bool compact;

  const _AwaitingValue({
    required this.stats,
    required this.status,
    required this.isDark,
    required this.currencyFormat,
    required this.isPrivacyMode,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = isDark ? Colors.white : AppColors.neutral900Light;
    final secondary = isDark
        ? AppColors.neutral400Dark
        : AppColors.neutral600Light;
    final investedStyle = _figureStyle(primary);
    final receivedStyle = _receivedStyle(secondary);
    final wordStyle = _wordStyle(secondary);

    Widget amount(double value, TextStyle style) => isPrivacyMode
        ? MaskedAmountText(
            text: currencyFormat.formatCompact(value),
            style: style,
          )
        : CompactAmountText(
            amount: value,
            compactText: currencyFormat.formatCompact(value),
            currencySymbol: currencyFormat.currencySymbol,
            locale: currencyFormat.locale,
            style: style,
          );

    TableRow row(Widget figure, String word) => TableRow(
      children: [
        Align(alignment: AlignmentDirectional.centerEnd, child: figure),
        Padding(
          padding: EdgeInsetsDirectional.only(start: AppSpacing.xxs),
          child: Text(word, style: wordStyle),
        ),
      ],
    );

    // Amounts right-aligned in one column, each word on its amount's baseline.
    // The first row has the name's line box, so the invested figure and the
    // name share a baseline beside it.
    final ledger = Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        row(
          amount(stats.totalInvested, investedStyle),
          l10n.investmentCardInvestedLabel,
        ),
        row(
          amount(stats.totalReturned, receivedStyle),
          l10n.investmentCardReceivedLabel,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Under the name nothing limits the ledger's width, and a wide symbol
        // at large text would run past the card where its clip cuts a figure:
        // it scales down to the room instead, on the right edge.
        compact
            ? FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: ledger,
              )
            : ledger,
        SizedBox(height: AppSpacing.xxs),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compact ? double.infinity : _statusChipMaxWidth,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _chipPaddingX,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              textAlign: TextAlign.end,
              style: _statusChipStyle(secondary),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom strip showing investment stats.
/// OPTIMIZATION: Converted to StatelessWidget to avoid unnecessary provider listeners.
class _InvestmentBottomStrip extends StatelessWidget {
  final InvestmentEntity investment;
  final bool isDark;
  final AsyncValue<InvestmentStats> statsAsync;
  final NumberFormat currencyFormat;
  final bool isPrivacyMode;
  final DateTime? referenceDate;

  /// The card awaits a current value: its invested amount is in the main row,
  /// so the strip does not repeat it.
  final bool isAwaitingValue;

  /// Little room (narrow card or large text): everything wraps in one flow.
  final bool compact;

  const _InvestmentBottomStrip({
    required this.investment,
    required this.isDark,
    required this.statsAsync,
    required this.currencyFormat,
    required this.isPrivacyMode,
    required this.isAwaitingValue,
    required this.compact,
    this.referenceDate,
  });

  @override
  Widget build(BuildContext context) {
    // OPTIMIZATION: Using passed data instead of watching providers again.
    // This reduces listener count by ~3 per list item.

    final subtleColor = isDark
        ? AppColors.neutral400Dark
        : AppColors.neutral500Light;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppSizes.radiusXl),
          bottomRight: Radius.circular(AppSizes.radiusXl),
        ),
      ),
      child: statsAsync.when(
        data: (stats) {
          final lastActivityDate =
              stats.lastCashFlowDate ?? investment.createdAt;
          final cashFlowCount = stats.cashFlowCount;

          final subtleTextStyle = AppTypography.small.copyWith(
            color: subtleColor,
          );

          final items = <Widget>[
            // Last activity
            _StripItem(
              icon: Icons.update_rounded,
              color: subtleColor,
              text: AppDateUtils.formatRelative(
                lastActivityDate,
                relativeTo: referenceDate,
              ),
              style: subtleTextStyle,
            ),
            // Cash flow count
            _StripItem(
              icon: Icons.receipt_long_rounded,
              color: subtleColor,
              text: AppLocalizations.of(context).cashFlowEntries(cashFlowCount),
              style: subtleTextStyle,
            ),
          ];

          // Total invested, or a way in when nothing was invested. Not on an
          // awaiting card, which shows its invested amount above.
          final Widget? trailing = isAwaitingValue
              ? null
              : stats.totalInvested > 0
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context).invested,
                      style: subtleTextStyle.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Gives way to the label's width. A Cr-scale amount at
                    // large text scales down rather than wrapping, because a
                    // wrapped figure ("CHF 123" over ".5M") reads as another
                    // amount.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: isPrivacyMode
                            ? MaskedAmountText(
                                text: currencyFormat.formatCompact(
                                  stats.totalInvested,
                                ),
                                style: subtleTextStyle.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : CompactAmountText(
                                amount: stats.totalInvested,
                                compactText: currencyFormat.formatCompact(
                                  stats.totalInvested,
                                ),
                                currencySymbol: currencyFormat.currencySymbol,
                                locale: currencyFormat.locale,
                                style: subtleTextStyle.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),
                  ],
                )
              : Text(
                  AppLocalizations.of(context).viewDetails,
                  style: AppTypography.small.copyWith(
                    color: isDark
                        ? AppColors.primaryDark
                        : AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                );

          Widget flow(List<Widget> children) => Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          );

          if (trailing == null) return flow(items);
          // The items take what the trailing group leaves and wrap; with
          // little room the group joins the flow instead of squeezing them.
          if (compact) return flow([...items, trailing]);
          return Row(
            children: [
              Expanded(child: flow(items)),
              SizedBox(width: AppSpacing.sm),
              trailing,
            ],
          );
        },
        loading: () => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context).loading,
              style: AppTypography.small.copyWith(color: subtleColor),
            ),
          ],
        ),
        error: (e, s) => Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xxs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              AppLocalizations.of(context).addedRelative(
                AppDateUtils.formatRelative(
                  investment.createdAt,
                  relativeTo: referenceDate,
                ),
              ),
              style: AppTypography.small.copyWith(color: subtleColor),
            ),
            Text(
              AppLocalizations.of(context).viewDetails,
              style: AppTypography.small.copyWith(
                color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small icon and text in the bottom strip. The text wraps instead of
/// overflowing when the strip is narrow.
class _StripItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final TextStyle style;

  const _StripItem({
    required this.icon,
    required this.color,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        SizedBox(width: AppSpacing.xxs),
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}

/// Decides how an investment's (or a portfolio's) return is presented.
///
/// Open investments need a current value as their terminal inflow. Without
/// one, their cash flows alone make them look like a loss (−100% badge, −98%
/// XIRR), so those figures are replaced by a neutral status and a dash. With
/// an estimated value the XIRR is labelled "Expected". Short holdings show
/// their absolute return instead of a wildly annualised XIRR. Keep this the
/// single place that makes these decisions.
library;

import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/utils/number_format_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Which return figure to show.
enum ReturnDisplayKind {
  /// Open, nothing received yet.
  awaitingFirstPayout,

  /// Open, some payouts received but less than was invested.
  awaitingCurrentValue,

  /// Held for less than [ReturnDisplay.shortHoldingDays]: absolute return.
  shortHolding,

  /// Annualised XIRR (exact or approximate).
  annualised,

  /// No XIRR exists.
  undefined,
}

/// Presentation decision for a set of [InvestmentStats].
class ReturnDisplay {
  /// Holdings shorter than this show their absolute return as the primary
  /// figure (the one rule in [InvestmentStats.shortHoldingDays]).
  static const int shortHoldingDays = InvestmentStats.shortHoldingDays;

  /// Shown in place of a figure that cannot be calculated.
  static const String dash = '—';

  final ReturnDisplayKind kind;

  /// XIRR as a decimal, or null when [xirrMethod] is undefined.
  final double? xirr;
  final XirrMethod xirrMethod;

  /// Absolute return in percent (2.0 = +2%).
  final double absoluteReturn;

  /// Days from the first cash flow to the last cash flow or current value,
  /// or null without dates.
  final int? holdingDays;

  /// Whether the figures use an estimated current value.
  final bool isEstimate;

  /// The rate (% p.a.) the estimated current value accrued at, if one.
  final double? estimateRate;

  const ReturnDisplay._({
    required this.kind,
    required this.xirr,
    required this.xirrMethod,
    required this.absoluteReturn,
    required this.holdingDays,
    this.isEstimate = false,
    this.estimateRate,
  });

  /// Resolves the display for [stats].
  ///
  /// [openStats] are the stats of the open investments within [stats]: the
  /// same object for a single open investment, the open subset for a
  /// portfolio, or null when nothing in [stats] is open. Any return figure
  /// would be a fake loss while one of them has no current value and has
  /// returned less than was invested ([InvestmentStats.missingValueCount]).
  /// Stats calculated without current values fall back to checking the open
  /// subset as a whole.
  ///
  /// [xirr] and [xirrMethod] override the values in [stats], for callers that
  /// compute XIRR separately.
  factory ReturnDisplay.resolve({
    required InvestmentStats stats,
    InvestmentStats? openStats,
    double? xirr,
    XirrMethod? xirrMethod,
  }) {
    final value = xirr ?? stats.xirr;
    final method = xirrMethod ?? stats.xirrMethod;
    final days = stats.holdingDays;

    final ReturnDisplayKind kind;
    if (openStats != null && openStats.hasData && _awaitsValue(openStats)) {
      kind = openStats.totalReturned == 0 && stats.totalReturned == 0
          ? ReturnDisplayKind.awaitingFirstPayout
          : ReturnDisplayKind.awaitingCurrentValue;
    } else if (stats.isShortHolding) {
      kind = ReturnDisplayKind.shortHolding;
    } else if (method == XirrMethod.undefined ||
        value == null ||
        !value.isFinite) {
      kind = ReturnDisplayKind.undefined;
    } else {
      kind = ReturnDisplayKind.annualised;
    }

    return ReturnDisplay._(
      kind: kind,
      xirr: value,
      xirrMethod: method,
      absoluteReturn: stats.absoluteReturn,
      holdingDays: days,
      isEstimate: stats.currentValueIsEstimate,
      estimateRate: stats.currentValueRate,
    );
  }

  /// Whether an open investment in [openStats] still lacks a terminal value.
  static bool _awaitsValue(InvestmentStats openStats) {
    if (openStats.needsCurrentValue) return true;
    // Stats calculated without current values (or before they loaded).
    return openStats.currentValue == null &&
        openStats.totalReturned < openStats.totalInvested;
  }

  /// True when the investment is open and has no terminal value yet, so
  /// XIRR, MOIC and return % must not be shown.
  bool get isAwaitingValue =>
      kind == ReturnDisplayKind.awaitingFirstPayout ||
      kind == ReturnDisplayKind.awaitingCurrentValue;

  /// Neutral status shown instead of a return % badge, or null to show the
  /// badge.
  String? statusLabel(AppLocalizations l10n) {
    switch (kind) {
      case ReturnDisplayKind.awaitingFirstPayout:
        return l10n.returnAwaitingFirstPayout;
      case ReturnDisplayKind.awaitingCurrentValue:
        return l10n.returnAwaitingCurrentValue;
      case ReturnDisplayKind.shortHolding:
      case ReturnDisplayKind.annualised:
      case ReturnDisplayKind.undefined:
        return null;
    }
  }

  /// Label for [primaryText]: "Return" for short holdings, "Expected XIRR"
  /// while it uses an estimated current value, otherwise "XIRR".
  String metricLabel(AppLocalizations l10n) {
    if (kind == ReturnDisplayKind.shortHolding) return l10n.returnLabel;
    if (kind == ReturnDisplayKind.annualised && isEstimate) {
      return l10n.expectedXirrLabel;
    }
    return l10n.xirrLabel;
  }

  /// The main return figure, e.g. "+12.4%", "+2.0% in 3 days" or "—".
  String primaryText(AppLocalizations l10n, {bool showSign = true}) {
    switch (kind) {
      case ReturnDisplayKind.awaitingFirstPayout:
      case ReturnDisplayKind.awaitingCurrentValue:
      case ReturnDisplayKind.undefined:
        return dash;
      case ReturnDisplayKind.shortHolding:
        return l10n.returnInDays(
          formatPercent(absoluteReturn, showSign: true),
          holdingDays!,
        );
      case ReturnDisplayKind.annualised:
        return formatXirrText(xirr!, xirrMethod, l10n, showSign: showSign);
    }
  }

  /// A hint or secondary figure under [primaryText], or null.
  String? secondaryText(AppLocalizations l10n) {
    switch (kind) {
      case ReturnDisplayKind.awaitingFirstPayout:
      case ReturnDisplayKind.awaitingCurrentValue:
        return l10n.returnNeedsValueHint;
      case ReturnDisplayKind.shortHolding:
        final rate = xirr;
        if (xirrMethod == XirrMethod.undefined ||
            rate == null ||
            !rate.isFinite) {
          return null;
        }
        return l10n.returnAnnualised(formatXirrText(rate, xirrMethod, l10n));
      case ReturnDisplayKind.annualised:
        if (!isEstimate) return null;
        final rate = estimateRate;
        return rate != null
            ? l10n.expectedXirrBasisRate(formatRate(rate))
            : l10n.expectedXirrBasisEstimates;
      case ReturnDisplayKind.undefined:
        return null;
    }
  }

  /// Formats an annual rate in percent without trailing zeros: 7 → "7%",
  /// 7.25 → "7.25%".
  static String formatRate(double ratePercent) {
    final text = ratePercent
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$text%';
  }

  /// Formats an XIRR decimal: "—" when undefined, ">1000%" above the display
  /// cap (never "0.0%" or blank), and "approx." for approximate values.
  static String formatXirrText(
    double xirr,
    XirrMethod method,
    AppLocalizations l10n, {
    bool showSign = true,
  }) {
    if (method == XirrMethod.undefined || !xirr.isFinite) return dash;
    final config = XirrFormatConfig.defaultConfig;
    if (xirr * 100 > config.maxDisplayPercent) return l10n.xirrAboveMax;
    // formatXirr returns null only for near-zero values here.
    final text = formatXirr(xirr, showSign: showSign) ?? formatPercent(0);
    return method == XirrMethod.approximate ? l10n.xirrApproximate(text) : text;
  }
}

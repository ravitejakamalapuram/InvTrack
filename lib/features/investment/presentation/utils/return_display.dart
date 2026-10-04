/// Decides how an investment's (or a portfolio's) return is presented.
///
/// Open investments have no current or terminal value yet, so their cash
/// flows alone make them look like a loss (−100% badge, −98% XIRR). Until
/// valuations exist, those figures are replaced by a neutral status and a
/// dash. Short holdings show their absolute return instead of a wildly
/// annualised XIRR. Keep this the single place that makes these decisions so
/// valuations can plug in here later.
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
  /// figure, because annualising a few days of return gives absurd rates.
  static const int shortHoldingDays = 90;

  /// Shown in place of a figure that cannot be calculated.
  static const String dash = '—';

  final ReturnDisplayKind kind;

  /// XIRR as a decimal, or null when [xirrMethod] is undefined.
  final double? xirr;
  final XirrMethod xirrMethod;

  /// Absolute return in percent (2.0 = +2%).
  final double absoluteReturn;

  /// Days from the first to the last cash flow, or null without dates.
  final int? holdingDays;

  const ReturnDisplay._({
    required this.kind,
    required this.xirr,
    required this.xirrMethod,
    required this.absoluteReturn,
    required this.holdingDays,
  });

  /// Resolves the display for [stats].
  ///
  /// [openStats] are the stats of the open investments within [stats]: the
  /// same object for a single open investment, the open subset for a
  /// portfolio, or null when nothing in [stats] is open. While those open
  /// investments have returned less than was invested, they have no terminal
  /// value and any return figure would be a fake loss.
  ///
  /// For a portfolio this checks the open subset as a whole, so one open
  /// investment with a large payout can unmask the figure while others still
  /// count as total losses. That is accepted until current values exist.
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
    final days = _holdingDays(stats);

    final ReturnDisplayKind kind;
    if (openStats != null &&
        openStats.hasData &&
        openStats.totalReturned < openStats.totalInvested) {
      kind = openStats.totalReturned == 0 && stats.totalReturned == 0
          ? ReturnDisplayKind.awaitingFirstPayout
          : ReturnDisplayKind.awaitingCurrentValue;
    } else if (stats.totalInvested > 0 &&
        // Without any inflow there is no holding period to report a return
        // over: a closed investment with a single INVEST flow would otherwise
        // read "-100.0% in under a day".
        stats.totalReturned > 0 &&
        days != null &&
        days < shortHoldingDays) {
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
    );
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

  /// Label for [primaryText]: "Return" for short holdings, otherwise "XIRR".
  String metricLabel(AppLocalizations l10n) =>
      kind == ReturnDisplayKind.shortHolding
      ? l10n.returnLabel
      : l10n.xirrLabel;

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
      case ReturnDisplayKind.undefined:
        return null;
    }
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

  static int? _holdingDays(InvestmentStats stats) {
    final first = stats.firstCashFlowDate;
    final last = stats.lastCashFlowDate;
    if (first == null || last == null) return null;
    // Date-only difference in UTC, so DST changes cannot shift it.
    return DateTime.utc(
      last.year,
      last.month,
      last.day,
    ).difference(DateTime.utc(first.year, first.month, first.day)).inDays;
  }
}

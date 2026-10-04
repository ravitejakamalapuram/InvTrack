// A10 (#754): once an open investment has a current value, its XIRR is shown.
// While that value is estimated it is labelled "Expected XIRR" with its basis;
// an open investment without any value still shows "—" (money rule 4).
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/utils/return_display.dart';
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';

InvestmentStats _openFd({
  double? currentValue,
  DateTime? currentValueDate,
  bool isEstimate = true,
  double? rate,
  int missing = 0,
  double xirr = 0.071859,
}) {
  const invested = 100000.0;
  final terminal = currentValue ?? 0;
  return InvestmentStats(
    totalInvested: invested,
    totalReturned: 0,
    netCashFlow: -invested,
    absoluteReturn: (terminal - invested) / invested * 100,
    moic: terminal / invested,
    xirr: xirr,
    xirrMethod: currentValue == null ? XirrMethod.undefined : XirrMethod.exact,
    cashFlowCount: 1,
    firstCashFlowDate: DateTime(2025, 10, 2),
    lastCashFlowDate: DateTime(2025, 10, 2),
    currentValue: currentValue,
    currentValueDate: currentValueDate,
    currentValueIsEstimate: currentValue != null && isEstimate,
    currentValueRate: rate,
    missingValueCount: missing,
  );
}

void main() {
  final l10n = AppLocalizationsEn();

  test('estimated value at a rate shows Expected XIRR and its basis', () {
    final stats = _openFd(
      currentValue: 107185.90,
      currentValueDate: DateTime(2026, 10, 2),
      rate: 7,
    );
    final display = ReturnDisplay.resolve(stats: stats, openStats: stats);

    expect(display.kind, ReturnDisplayKind.annualised);
    expect(display.isAwaitingValue, isFalse);
    expect(display.statusLabel(l10n), isNull);
    expect(display.metricLabel(l10n), 'Expected XIRR');
    expect(display.primaryText(l10n), '+7.2%');
    expect(display.secondaryText(l10n), 'Based on 7% p.a.');
  });

  test('estimated principal shows Expected XIRR with its basis', () {
    final stats = _openFd(
      currentValue: 100000,
      currentValueDate: DateTime(2026, 10, 2),
    );
    final display = ReturnDisplay.resolve(stats: stats, openStats: stats);

    expect(display.metricLabel(l10n), 'Expected XIRR');
    expect(display.secondaryText(l10n), 'Includes estimated current values');
  });

  test('a user-confirmed value shows plain XIRR', () {
    final stats = _openFd(
      currentValue: 107000,
      currentValueDate: DateTime(2026, 9, 30),
      isEstimate: false,
    );
    final display = ReturnDisplay.resolve(stats: stats, openStats: stats);

    expect(display.kind, ReturnDisplayKind.annualised);
    expect(display.metricLabel(l10n), 'XIRR');
    expect(display.secondaryText(l10n), isNull);
  });

  test('an open holding without any value still awaits it', () {
    final stats = _openFd(missing: 1);
    final display = ReturnDisplay.resolve(stats: stats, openStats: stats);

    expect(display.kind, ReturnDisplayKind.awaitingFirstPayout);
    expect(display.primaryText(l10n), '—');
  });

  test('a portfolio with one valued and one unvalued holding awaits', () {
    final stats = _openFd(
      currentValue: 107185.90,
      currentValueDate: DateTime(2026, 10, 2),
      rate: 7,
      missing: 1,
    );
    final display = ReturnDisplay.resolve(stats: stats, openStats: stats);

    expect(display.isAwaitingValue, isTrue);
    expect(display.primaryText(l10n), '—');
  });

  test('holding period runs to the valuation date', () {
    // Opened 30 days before its valuation, nothing paid out: the accrued
    // value is still a return, so the short-holding rule applies.
    final stats = InvestmentStats(
      totalInvested: 100000,
      totalReturned: 0,
      netCashFlow: -100000,
      absoluteReturn: 0.57,
      moic: 1.0057,
      xirr: 0.0718,
      cashFlowCount: 1,
      firstCashFlowDate: DateTime(2026, 9, 2),
      lastCashFlowDate: DateTime(2026, 9, 2),
      currentValue: 100570,
      currentValueDate: DateTime(2026, 10, 2),
      currentValueIsEstimate: true,
      currentValueRate: 7,
    );
    final display = ReturnDisplay.resolve(stats: stats, openStats: stats);

    expect(display.kind, ReturnDisplayKind.shortHolding);
    expect(display.holdingDays, 30);
  });
}

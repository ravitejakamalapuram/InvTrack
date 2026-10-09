import 'dart:math' as math;

import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/core/utils/money_precision.dart';

/// Where a current value comes from.
enum ValuationSource {
  /// Entered by the user.
  manual,

  /// Deposits grown at the investment's expected rate (cumulative FD/RD,
  /// zero-coupon bonds).
  accruedInterest,

  /// Principal not yet returned (payout FD, bonds, P2P and other lending).
  outstandingPrincipal,
}

/// A dated current value of one investment, in [currency].
class InvestmentValuation {
  final double amount;

  /// Currency of [amount]: the investment's for a manual value, the
  /// currency of the cash flows for an estimate (money rule 2).
  final String currency;

  /// Date-only date the value applies to.
  final DateTime date;
  final ValuationSource source;

  /// Annual rate (%) a [ValuationSource.accruedInterest] value accrued at.
  final double? rate;

  const InvestmentValuation({
    required this.amount,
    required this.currency,
    required this.date,
    required this.source,
    this.rate,
  });

  bool get isEstimate => source != ValuationSource.manual;
}

/// The current values of a set of investments as terminal inflows (one
/// RETURN-like flow per valued investment, dated at its valuation and in the
/// valuation's currency), ready to be converted to the base currency and
/// passed to `FinancialCalculatorModule.calculateStats`.
class TerminalValues {
  /// One flow per valued investment; ids start with [idPrefix].
  final List<CashFlowEntity> flows;

  /// Open investments with no value that have not returned their cost, or
  /// whose cash flows are in more than one currency.
  final int missingValueCount;

  /// Whether any value in [flows] is an estimate.
  final bool isEstimate;

  /// The rate every value accrued at, when all of them are interest
  /// accruals at one rate; otherwise null.
  final double? rate;

  const TerminalValues({
    this.flows = const [],
    this.missingValueCount = 0,
    this.isEstimate = false,
    this.rate,
  });

  static const none = TerminalValues();

  /// Prefix of the ids of [flows], which are never stored.
  static const idPrefix = 'current-value:';

  /// The same values with [flows] replaced, e.g. by their converted copies.
  /// Values the conversion dropped count as missing, so they can never pass
  /// as a loss.
  TerminalValues withConvertedFlows(List<CashFlowEntity> converted) {
    return TerminalValues(
      flows: converted,
      missingValueCount:
          missingValueCount + math.max(0, flows.length - converted.length),
      isEstimate: isEstimate,
      rate: rate,
    );
  }
}

/// Current values of open investments: the user's own value when there is
/// one, otherwise an estimate for fixed-income types. This is the single
/// implementation of "current value" (money rule 3).
class CurrentValueCalculator {
  CurrentValueCalculator._();

  /// Types whose value can be estimated from their cash flows and rate.
  /// Gold, SGB, property, equity and private deals need the user's value.
  static const estimableTypes = {
    InvestmentType.fixedDeposit,
    InvestmentType.bonds,
    InvestmentType.p2pLending,
    InvestmentType.invoiceDiscounting,
    InvestmentType.financing,
  };

  /// P × (1 + r/n)^(n·t) with t = actual days / 365 (money rule 5).
  /// No compounding frequency compounds annually, like
  /// InvestmentProjector; [CompoundingFrequency.none] is simple interest.
  static double accruedValue({
    required double principal,
    required double annualRatePercent,
    CompoundingFrequency? compounding,
    required DateTime from,
    required DateTime to,
  }) {
    final days = _daysBetween(from, to);
    if (days <= 0) return principal;
    return accruedValueForYears(
      principal: principal,
      annualRatePercent: annualRatePercent,
      compounding: compounding,
      years: days / 365.0,
    );
  }

  /// P × (1 + r/n)^(n·t) for [years] = t.
  static double accruedValueForYears({
    required double principal,
    required double annualRatePercent,
    CompoundingFrequency? compounding,
    required double years,
  }) {
    if (principal <= 0 || annualRatePercent <= 0 || years <= 0) {
      return principal;
    }
    final rate = annualRatePercent / 100;
    final periodsPerYear = compounding?.periodsPerYear ?? 1;
    if (periodsPerYear == 0) return principal * (1 + rate * years);
    return principal *
        math.pow(1 + rate / periodsPerYear, periodsPerYear * years);
  }

  /// The current value of [investment] as of [asOf], or null when it has
  /// none: it is closed, has no cash flows, or is of a type (or lacks the
  /// rate) needed to estimate one. Amounts in different currencies are
  /// never added: a manual value with principal moved in another currency
  /// after its date, or an estimate from INVEST/RETURN flows in more than
  /// one currency, is none, as is an accrual with INCOME in another
  /// currency. So is a manual value dated before the first
  /// cash flow. [cashFlows] may include other investments'
  /// flows; only this investment's are used.
  static InvestmentValuation? valuationOf(
    InvestmentEntity investment,
    List<CashFlowEntity> cashFlows, {
    required DateTime asOf,
  }) {
    if (!investment.isOpen) return null;
    final flows = [
      for (final cf in cashFlows)
        if (cf.investmentId == investment.id) cf,
    ];
    if (flows.isEmpty) return null;

    final today = _dateOnly(asOf);
    DateTime lastFlow = _dateOnly(flows.first.date);
    for (final cf in flows) {
      final d = _dateOnly(cf.date);
      if (d.isAfter(lastFlow)) lastFlow = d;
    }

    if (_hasManualValue(investment)) {
      return _manualValuation(investment, flows, lastFlow);
    }

    if (!estimableTypes.contains(investment.type)) return null;
    final currency = _sharedCurrency(flows.where(_isPrincipal));
    if (currency == null) return null;

    // Value at maturity once it has passed, never after today.
    final maturity = investment.calculatedMaturityDate;
    var end = today;
    if (maturity != null && _dateOnly(maturity).isBefore(end)) {
      end = _dateOnly(maturity);
    }
    final date = lastFlow.isAfter(end) ? lastFlow : end;

    if (_isCumulative(investment, flows)) {
      if (!investment.hasExpectedRate) return null;
      // Interest recorded as INCOME has left the deposit like a RETURN, so
      // it comes off the balance and must be in the deposits' currency.
      if (flows.any(
        (cf) => cf.type == CashFlowType.income && cf.currency != currency,
      )) {
        return null;
      }
      final rate = investment.expectedRate!;
      var amount = 0.0;
      for (final cf in flows) {
        if (cf.type != CashFlowType.invest &&
            cf.type != CashFlowType.returnFlow &&
            cf.type != CashFlowType.income) {
          continue;
        }
        final grown = accruedValue(
          principal: cf.amount,
          annualRatePercent: rate,
          compounding: investment.compoundingFrequency,
          from: cf.date,
          to: end,
        );
        amount += cf.type == CashFlowType.invest ? grown : -grown;
      }
      return InvestmentValuation(
        amount: MoneyPrecision.round(
          math.max(0, amount),
          currencyCode: currency,
        ),
        currency: currency,
        date: date,
        source: ValuationSource.accruedInterest,
        rate: rate,
      );
    }

    return InvestmentValuation(
      amount: MoneyPrecision.round(
        math.max(0, _principalChange(flows)),
        currencyCode: currency,
      ),
      currency: currency,
      date: date,
      source: ValuationSource.outstandingPrincipal,
    );
  }

  /// Terminal values of [investments] as of [asOf]. Closed investments and
  /// investments without cash flows get none. [cashFlows] are unconverted;
  /// callers convert the returned flows to the base currency before adding
  /// them to converted cash flows (money rule 2).
  static TerminalValues terminalValues({
    required List<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
    required DateTime asOf,
  }) {
    final byInvestment = <String, List<CashFlowEntity>>{};
    for (final cf in cashFlows) {
      byInvestment.putIfAbsent(cf.investmentId, () => []).add(cf);
    }

    final flows = <CashFlowEntity>[];
    var missing = 0;
    var isEstimate = false;
    final rates = <double?>{};
    for (final investment in investments) {
      final own = byInvestment[investment.id];
      if (own == null || own.isEmpty || !investment.isOpen) continue;

      final valuation = valuationOf(investment, own, asOf: asOf);
      if (valuation == null) {
        var net = 0.0;
        for (final cf in own) {
          net += cf.signedAmount;
        }
        // Still out of pocket with no value: XIRR, MOIC and return % are
        // unknown. An investment that already returned its cost is not,
        // but that cannot be told from flows in more than one currency.
        if (net < 0 || _sharedCurrency(own) == null) missing++;
        continue;
      }

      isEstimate = isEstimate || valuation.isEstimate;
      rates.add(
        valuation.source == ValuationSource.accruedInterest
            ? valuation.rate
            : null,
      );
      flows.add(
        CashFlowEntity(
          id: '${TerminalValues.idPrefix}${investment.id}',
          investmentId: investment.id,
          date: valuation.date,
          type: CashFlowType.returnFlow,
          amount: valuation.amount,
          createdAt: valuation.date,
          currency: valuation.currency,
        ),
      );
    }

    return TerminalValues(
      flows: flows,
      missingValueCount: missing,
      isEstimate: isEstimate,
      rate: rates.length == 1 ? rates.single : null,
    );
  }

  static bool _hasManualValue(InvestmentEntity investment) {
    final value = investment.currentValue;
    return value != null &&
        investment.currentValueDate != null &&
        value.isFinite &&
        value >= 0;
  }

  /// The user's value, in the investment's currency, carried forward to the
  /// latest cash flow: principal put in or taken out after the valuation
  /// date changes it, income does not. Null when that principal is in
  /// another currency, or when the value is dated before the first cash
  /// flow: it cannot include principal not yet put in, and adding all of
  /// it would count the principal twice.
  static InvestmentValuation? _manualValuation(
    InvestmentEntity investment,
    List<CashFlowEntity> flows,
    DateTime lastFlow,
  ) {
    final date = _dateOnly(investment.currentValueDate!);
    if (flows.every((cf) => _dateOnly(cf.date).isAfter(date))) return null;
    final later = [
      for (final cf in flows)
        if (_dateOnly(cf.date).isAfter(date) && _isPrincipal(cf)) cf,
    ];
    if (later.any((cf) => cf.currency != investment.currency)) return null;
    return InvestmentValuation(
      amount: MoneyPrecision.round(
        math.max(0, investment.currentValue! + _principalChange(later)),
        currencyCode: investment.currency,
      ),
      currency: investment.currency,
      date: lastFlow.isAfter(date) ? lastFlow : date,
      source: ValuationSource.manual,
    );
  }

  static bool _isPrincipal(CashFlowEntity cf) =>
      cf.type == CashFlowType.invest || cf.type == CashFlowType.returnFlow;

  /// The one currency of [flows], or null when there are none or several.
  static String? _sharedCurrency(Iterable<CashFlowEntity> flows) {
    final currencies = {for (final cf in flows) cf.currency};
    return currencies.length == 1 ? currencies.single : null;
  }

  /// Interest accrues until maturity rather than being paid out.
  static bool _isCumulative(
    InvestmentEntity investment,
    List<CashFlowEntity> flows,
  ) {
    switch (investment.interestPayoutMode) {
      case InterestPayoutMode.cumulative:
      case InterestPayoutMode.atMaturity:
        return true;
      case InterestPayoutMode.periodic:
        return false;
      case null:
        // An FD with no payout schedule and no recorded interest payouts
        // compounds, like most bank FDs. Everything else pays out.
        return investment.type == InvestmentType.fixedDeposit &&
            investment.incomeFrequency == null &&
            !flows.any((cf) => cf.type == CashFlowType.income);
    }
  }

  /// INVEST minus RETURN: principal put in and not yet taken out.
  static double _principalChange(List<CashFlowEntity> flows) {
    var principal = 0.0;
    for (final cf in flows) {
      if (cf.type == CashFlowType.invest) principal += cf.amount;
      if (cf.type == CashFlowType.returnFlow) principal -= cf.amount;
    }
    return principal;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Whole days between the calendar dates of [from] and [to], in UTC so a
  /// DST change cannot shift it.
  static int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}

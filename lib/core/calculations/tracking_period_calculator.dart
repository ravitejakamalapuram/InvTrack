import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/calculations/valuation_snapshot_selector.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Whether a tracking period has figures to show, and if not why.
enum TrackingPeriodState {
  ready,

  /// No live opening baseline.
  notStarted,

  /// The latest value is a market value that a buy or a sale has made out of
  /// date, or the baseline itself with nothing newer entered: cash flows
  /// cannot establish a new price.
  needsNewerValue,

  /// There is an end value in no usable form: principal in another currency
  /// after the baseline, or an end value that could not be converted.
  valueUnavailable,

  /// The end value is dated the day the baseline starts.
  noElapsedTime,
}

/// The inputs of a tracking-period return, from an opening baseline to the
/// end value. [flows] and [terminal] are in the investment's currency until
/// [withConverted] swaps in their base-currency copies, converted by the same
/// converter as every other flow (money rule 2).
class TrackingPeriod {
  final TrackingPeriodState state;

  /// The baseline's day, D.
  final DateTime? start;

  /// The day of the end value.
  final DateTime? end;

  /// The baseline as an INVEST on D, then the real cash flows dated after D.
  /// The first one exists only in memory.
  final List<CashFlowEntity> flows;

  /// The end value as the terminal inflow.
  final CashFlowEntity? terminal;

  const TrackingPeriod({
    required this.state,
    this.start,
    this.end,
    this.flows = const [],
    this.terminal,
  });

  /// Calendar days from [start] to [end], in UTC so a DST change cannot
  /// shift it.
  int? get days {
    final from = start;
    final to = end;
    if (from == null || to == null) return null;
    return DateTime.utc(
      to.year,
      to.month,
      to.day,
    ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
  }

  /// Whether the period is long enough for an annualised rate. Shorter ones
  /// show their absolute return only ([InvestmentStats.shortHoldingDays]).
  bool get showsAnnualised {
    final d = days;
    return d != null && d >= InvestmentStats.shortHoldingDays;
  }

  /// The period with converted [flows] and [terminal]. A null [terminal] (a
  /// value the converter dropped) leaves the period without figures.
  TrackingPeriod withConverted({
    required List<CashFlowEntity> flows,
    required CashFlowEntity? terminal,
  }) => TrackingPeriod(
    state: state == TrackingPeriodState.ready && terminal == null
        ? TrackingPeriodState.valueUnavailable
        : state,
    start: start,
    end: end,
    flows: flows,
    terminal: terminal,
  );
}

/// Performance over a tracking period: from the dated opening baseline to the
/// end value, labelled with its start and never presented as lifetime
/// performance. It builds an ephemeral start flow and delegates to
/// [FinancialCalculatorModule.calculateStats], so XIRR, MOIC and absolute
/// return stay single implementations (money rule 3). Nothing built here is
/// ever persisted.
abstract final class TrackingPeriodCalculator {
  /// Prefix of the id of the start flow, which is never stored.
  static const startIdPrefix = TerminalValues.trackingStartIdPrefix;

  /// The tracking period of [investment] as of [asOf]: the baseline's value
  /// on its day as the start, the cash flows dated after that day, and as
  /// the end the latest snapshot dated after it, or else the baseline carried
  /// forward when its kind rolls forward. A market-value baseline with
  /// nothing newer has no end value.
  static TrackingPeriod build({
    required InvestmentEntity investment,
    required List<CashFlowEntity> cashFlows,
    required List<InvestmentValuationSnapshot> snapshots,
    required DateTime asOf,
  }) {
    final baseline = ValuationSnapshotSelector.openingBaseline(
      snapshots,
      investmentId: investment.id,
      currency: investment.currency,
    );
    if (baseline == null) {
      return const TrackingPeriod(state: TrackingPeriodState.notStarted);
    }
    final start = _dateOnly(baseline.effectiveDate);
    final byInvestment = {investment.id: snapshots};

    final winner = ValuationSnapshotSelector.select(
      investment: investment,
      snapshots: snapshots,
      asOf: asOf,
    );
    if (winner != null &&
        winner.snapshotId == baseline.id &&
        !winner.kind.rollsForward) {
      return TrackingPeriod(
        state: TrackingPeriodState.needsNewerValue,
        start: start,
      );
    }

    final own = [
      for (final cf in cashFlows)
        if (cf.investmentId == investment.id) cf,
    ];
    final valuation = CurrentValueCalculator.valuationOf(
      investment,
      own,
      asOf: asOf,
      snapshots: byInvestment,
    );
    if (valuation == null) {
      // A buy or a sale after the latest market value: only a newer value
      // can end the period.
      final stale = CurrentValueCalculator.staleValuationOf(
        investment,
        own,
        asOf: asOf,
        snapshots: byInvestment,
      );
      return TrackingPeriod(
        state: stale != null
            ? TrackingPeriodState.needsNewerValue
            : TrackingPeriodState.valueUnavailable,
        start: start,
      );
    }

    final flows = <CashFlowEntity>[
      CashFlowEntity(
        id: '$startIdPrefix${investment.id}',
        investmentId: investment.id,
        date: start,
        type: CashFlowType.invest,
        amount: baseline.amount,
        createdAt: start,
        currency: baseline.currency,
      ),
      for (final cf in own)
        if (_dateOnly(cf.date).isAfter(start)) cf,
    ];
    final terminal = CashFlowEntity(
      id: '${TerminalValues.idPrefix}${investment.id}',
      investmentId: investment.id,
      date: valuation.date,
      type: CashFlowType.returnFlow,
      amount: valuation.amount,
      createdAt: valuation.date,
      currency: valuation.currency,
    );
    final period = TrackingPeriod(
      state: TrackingPeriodState.ready,
      start: start,
      end: valuation.date,
      flows: flows,
      terminal: terminal,
    );
    return period.days == 0
        ? TrackingPeriod(
            state: TrackingPeriodState.noElapsedTime,
            start: start,
            end: valuation.date,
            flows: flows,
            terminal: terminal,
          )
        : period;
  }

  /// The XIRR, MOIC and absolute return of the period, or null when it has
  /// no figures. Not lifetime performance.
  static InvestmentStats? stats(TrackingPeriod period) {
    final terminal = period.terminal;
    if (period.state != TrackingPeriodState.ready || terminal == null) {
      return null;
    }
    return FinancialCalculatorModule().calculateStats(
      period.flows,
      terminalValues: TerminalValues(flows: [terminal]),
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

import 'package:inv_tracker/core/calculations/period_inflows.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// A calendar month as the half-open range [1st, next 1st) (rule 5).
class DigestMonth {
  final int year;
  final int month;

  const DigestMonth(this.year, this.month);

  /// The month before the one [now] falls in: the month a recap sent on
  /// [now] is about.
  factory DigestMonth.before(DateTime now) =>
      DigestMonth._normalised(now.year, now.month - 1);

  /// Parses a `yyyy-MM` key, as carried by a notification payload.
  factory DigestMonth.parse(String key) {
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(key);
    final month = match == null ? 0 : int.parse(match.group(2)!);
    if (match == null || month < 1 || month > 12) {
      throw FormatException('Not a yyyy-MM month', key);
    }
    return DigestMonth(int.parse(match.group(1)!), month);
  }

  factory DigestMonth._normalised(int year, int month) {
    final date = DateTime(year, month);
    return DigestMonth(date.year, date.month);
  }

  DateTime get start => DateTime(year, month);
  DateTime get end => DateTime(year, month + 1);
  DigestMonth get next => DigestMonth._normalised(year, month + 1);
  DigestMonth get previous => DigestMonth._normalised(year, month - 1);

  String get key => '$year-${month.toString().padLeft(2, '0')}';

  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && day.isBefore(end);
  }

  @override
  bool operator ==(Object other) =>
      other is DigestMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// What a month brought in and what the next one needs, for the monthly
/// recap screen and its notification. Archived investments are left out
/// (rule 9): callers pass the active ones.
class MonthlyDigest {
  final DigestMonth month;

  /// The currency every amount here is in.
  final String baseCurrency;

  final PeriodInflows moneyIn;
  final PeriodInflows previousMoneyIn;

  /// Open investments maturing in the month after [month], soonest first.
  final List<InvestmentEntity> maturingNextMonth;

  /// Open investments whose returns wait on a current value (rule 4).
  final List<InvestmentEntity> needingValue;

  const MonthlyDigest({
    required this.month,
    required this.baseCurrency,
    required this.moneyIn,
    required this.previousMoneyIn,
    required this.maturingNextMonth,
    required this.needingValue,
  });

  /// [convertedFlows] must already be in [baseCurrency]; [statsById] are the
  /// per-investment stats from the same snapshot.
  factory MonthlyDigest.build({
    required DigestMonth month,
    required String baseCurrency,
    required Iterable<CashFlowEntity> convertedFlows,
    required Iterable<InvestmentEntity> activeInvestments,
    required Map<String, InvestmentStats> statsById,
  }) {
    final open = activeInvestments.where((i) => i.isOpen).toList();
    final next = month.next;
    final maturing =
        open
            .where(
              (i) => i.maturityDate != null && next.contains(i.maturityDate!),
            )
            .toList()
          ..sort((a, b) => a.maturityDate!.compareTo(b.maturityDate!));
    return MonthlyDigest(
      month: month,
      baseCurrency: baseCurrency,
      moneyIn: PeriodInflows.of(
        convertedFlows,
        start: month.start,
        end: month.end,
      ),
      previousMoneyIn: PeriodInflows.of(
        convertedFlows,
        start: month.previous.start,
        end: month.previous.end,
      ),
      maturingNextMonth: maturing,
      needingValue: open
          .where((i) => statsById[i.id]?.needsCurrentValue ?? false)
          .toList(),
    );
  }

  /// Money in this month less money in the month before.
  double get change => moneyIn.total - previousMoneyIn.total;

  bool get isQuiet =>
      moneyIn.count == 0 && maturingNextMonth.isEmpty && needingValue.isEmpty;
}

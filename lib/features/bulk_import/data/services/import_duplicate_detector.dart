import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Row numbers of the valid [rows] that look like a cash flow the user
/// already has: the same investment name (ignoring case and surrounding
/// spaces), date, type, amount to the paisa and currency. A row without a
/// currency is in [baseCurrency].
///
/// Re-importing a file after fixing a few rows would otherwise add every
/// earlier row a second time and double the totals.
Set<int> findLikelyDuplicateRows(
  Iterable<ParsedCashFlowRow> rows, {
  required List<InvestmentEntity> investments,
  required List<CashFlowEntity> cashFlows,
  required String baseCurrency,
}) {
  final names = {for (final i in investments) i.id: i.name};
  final existing = {
    for (final cf in cashFlows)
      if (names[cf.investmentId] case final name?)
        _key(name, cf.date, cf.type, cf.amount, cf.currency),
  };
  if (existing.isEmpty) return const {};

  return {
    for (final row in rows)
      if (row.isValid &&
          existing.contains(
            _key(
              row.investmentName,
              row.date,
              row.type,
              row.amount,
              row.currency ?? baseCurrency,
            ),
          ))
        row.rowNumber,
  };
}

String _key(
  String name,
  DateTime date,
  CashFlowType type,
  double amount,
  String currency,
) =>
    '${name.trim().toLowerCase()}|${date.year}-${date.month}-${date.day}|'
    '${type.name}|${(amount * 100).round()}|$currency';

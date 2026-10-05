import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// For each valid row that looks like a cash flow the user already has, the
/// id of the investment holding that cash flow. A match has the same
/// investment name (ignoring case and surrounding spaces), date, type,
/// amount to the paisa and currency; a row without a currency is in
/// [baseCurrency].
///
/// Re-importing a file after fixing a few rows would otherwise add every
/// earlier row a second time and double the totals.
Map<int, String> findLikelyDuplicateRows(
  Iterable<ParsedCashFlowRow> rows, {
  required List<InvestmentEntity> investments,
  required List<CashFlowEntity> cashFlows,
  required String baseCurrency,
}) {
  final names = {for (final i in investments) i.id: i.name};
  final existing = <String, String>{};
  for (final cf in cashFlows) {
    if (names[cf.investmentId] case final name?) {
      existing.putIfAbsent(
        _key(name, cf.date, cf.type, cf.amount, cf.currency),
        () => cf.investmentId,
      );
    }
  }
  if (existing.isEmpty) return const {};

  return {
    for (final row in rows)
      if (row.isValid)
        row.rowNumber:
            ?existing[_key(
              row.investmentName,
              row.date,
              row.type,
              row.amount,
              row.currency ?? baseCurrency,
            )],
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

import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// The version of investments.json that this app writes and reads.
const investmentsBackupSchemaVersion = 1;

String _dateOnly(DateTime date) => date.toIso8601String().split('T').first;

/// One investment as investments.json holds it: every field of the entity
/// except the current value pair (valuations.csv) and the custom type link
/// (custom_types.json), which have their own files.
Map<String, dynamic> investmentToBackupJson(InvestmentEntity inv) => {
  'id': inv.id,
  'name': inv.name,
  'type': inv.type.name,
  'status': inv.status.name,
  'archived': inv.isArchived,
  'currency': inv.currency,
  'currencyAssumed': inv.currencyAssumed,
  'createdAt': inv.createdAt.toIso8601String(),
  'updatedAt': inv.updatedAt.toIso8601String(),
  if (inv.closedAt != null) 'closedAt': inv.closedAt!.toIso8601String(),
  if (inv.notes != null) 'notes': inv.notes,
  if (inv.startDate != null) 'startDate': _dateOnly(inv.startDate!),
  if (inv.maturityDate != null) 'maturityDate': _dateOnly(inv.maturityDate!),
  if (inv.incomeFrequency != null) 'incomeFrequency': inv.incomeFrequency!.name,
  if (inv.expectedRate != null) 'expectedRate': inv.expectedRate,
  if (inv.tenureMonths != null) 'tenureMonths': inv.tenureMonths,
  if (inv.platform != null) 'platform': inv.platform,
  if (inv.interestPayoutMode != null)
    'interestPayoutMode': inv.interestPayoutMode!.name,
  if (inv.autoRenewal != null) 'autoRenewal': inv.autoRenewal,
  if (inv.riskLevel != null) 'riskLevel': inv.riskLevel!.name,
  if (inv.compoundingFrequency != null)
    'compoundingFrequency': inv.compoundingFrequency!.name,
};

T? _enumNamed<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

DateTime? _date(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;

/// The investment of one investments.json row, or null when the row has no
/// usable id, name, type, status or listed currency, or a present rate or
/// tenure is not a number (a row of the wrong shape is skipped).
InvestmentEntity? investmentFromBackupJson(Object? row) {
  if (row is! Map) return null;
  final id = row['id'];
  final name = row['name'];
  final type = _enumNamed(InvestmentType.values, row['type']);
  final status = _enumNamed(InvestmentStatus.values, row['status']);
  final currency = row['currency'];
  final createdAt = _date(row['createdAt']);
  final updatedAt = _date(row['updatedAt']);
  if (id is! String ||
      id.isEmpty ||
      name is! String ||
      name.trim().isEmpty ||
      type == null ||
      status == null ||
      currency is! String ||
      !getValidCurrencyCodes().contains(currency) ||
      createdAt == null ||
      updatedAt == null) {
    return null;
  }
  final rate = row['expectedRate'];
  final tenure = row['tenureMonths'];
  if ((rate != null && rate is! num) || (tenure != null && tenure is! num)) {
    return null;
  }
  return InvestmentEntity(
    id: id,
    name: name,
    type: type,
    status: status,
    isArchived: row['archived'] == true,
    currency: currency,
    currencyAssumed: row['currencyAssumed'] == true,
    createdAt: createdAt,
    updatedAt: updatedAt,
    closedAt: _date(row['closedAt']),
    notes: row['notes'] is String ? row['notes'] as String : null,
    startDate: _date(row['startDate']),
    maturityDate: _date(row['maturityDate']),
    incomeFrequency: _enumNamed(IncomeFrequency.values, row['incomeFrequency']),
    expectedRate: rate is num ? rate.toDouble() : null,
    tenureMonths: tenure is num ? tenure.toInt() : null,
    platform: row['platform'] is String ? row['platform'] as String : null,
    interestPayoutMode: _enumNamed(
      InterestPayoutMode.values,
      row['interestPayoutMode'],
    ),
    autoRenewal: row['autoRenewal'] is bool ? row['autoRenewal'] as bool : null,
    riskLevel: _enumNamed(RiskLevel.values, row['riskLevel']),
    compoundingFrequency: _enumNamed(
      CompoundingFrequency.values,
      row['compoundingFrequency'],
    ),
  );
}

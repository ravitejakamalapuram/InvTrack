// Builders shared by the dated-valuation tests (#941).
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// An open investment in INR. [compat] is the legacy currentValue pair.
InvestmentEntity testInvestment(
  String id, {
  InvestmentType type = InvestmentType.gold,
  InvestmentStatus status = InvestmentStatus.open,
  String currency = 'INR',
  double? compatValue,
  DateTime? compatDate,
  DateTime? updatedAt,
  bool isArchived = false,
  double? rate,
}) => InvestmentEntity(
  id: id,
  name: id,
  type: type,
  status: status,
  createdAt: DateTime(2024),
  updatedAt: updatedAt ?? DateTime.utc(2026, 1, 1),
  currency: currency,
  currentValue: compatValue,
  currentValueDate: compatDate,
  isArchived: isArchived,
  expectedRate: rate,
);

/// A snapshot. [pending] leaves updatedAt null, as a server timestamp that
/// has not reached the server yet reads.
InvestmentValuationSnapshot testSnapshot(
  String id, {
  String investmentId = 'i1',
  required double amount,
  required DateTime date,
  ValuationKind kind = ValuationKind.carryingValue,
  ValuationProvenance provenance = ValuationProvenance.manual,
  String currency = 'INR',
  DateTime? updatedAt,
  bool pending = false,
  DateTime? deletedAt,
}) => InvestmentValuationSnapshot(
  id: id,
  investmentId: investmentId,
  amount: amount,
  currency: currency,
  effectiveDate: date,
  kind: kind,
  provenance: provenance,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: pending ? null : (updatedAt ?? DateTime.utc(2026, 1, 1)),
  deletedAt: deletedAt,
);

CashFlowEntity testFlow(
  String investmentId,
  CashFlowType type,
  double amount,
  DateTime date, {
  String currency = 'INR',
}) => CashFlowEntity(
  id: '$investmentId-${date.toIso8601String()}-${type.name}-$amount',
  investmentId: investmentId,
  date: date,
  type: type,
  amount: amount,
  createdAt: date,
  currency: currency,
);

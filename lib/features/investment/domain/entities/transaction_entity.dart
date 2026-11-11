import 'package:inv_tracker/core/calculations/models/cash_flow_interface.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';

/// Cash Flow Type - direction of money
///
/// Note: Icon and color are handled in UI extensions to keep domain layer
/// platform-agnostic (Rule 1.1).
enum CashFlowType {
  invest, // Cash going out (negative for XIRR)
  returnFlow, // Cash coming back from exit/sale (positive for XIRR)
  income, // Dividends, interest, rent (positive for XIRR)
  fee; // Fees, expenses (negative for XIRR)

  String get displayName {
    switch (this) {
      case CashFlowType.invest:
        return 'Invest';
      case CashFlowType.returnFlow:
        return 'Return';
      case CashFlowType.income:
        return 'Income';
      case CashFlowType.fee:
        return 'Fee';
    }
  }

  String get description {
    switch (this) {
      case CashFlowType.invest:
        return 'Money invested';
      case CashFlowType.returnFlow:
        return 'Money returned (exit/sale)';
      case CashFlowType.income:
        return 'Dividend/Interest/Rent';
      case CashFlowType.fee:
        return 'Fees & Expenses';
    }
  }

  String get icon {
    switch (this) {
      case CashFlowType.invest:
        return '↗️';
      case CashFlowType.returnFlow:
        return '↙️';
      case CashFlowType.income:
        return '💵';
      case CashFlowType.fee:
        return '📋';
    }
  }

  /// Returns true if this is a cash outflow (money leaving)
  bool get isOutflow => this == CashFlowType.invest || this == CashFlowType.fee;

  /// Returns true if this is a cash inflow (money coming back)
  bool get isInflow =>
      this == CashFlowType.returnFlow || this == CashFlowType.income;

  static CashFlowType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'INVEST':
        return CashFlowType.invest;
      case 'RETURN':
      case 'RETURNFLOW':
        return CashFlowType.returnFlow;
      case 'INCOME':
        return CashFlowType.income;
      case 'FEE':
        return CashFlowType.fee;
      default:
        return CashFlowType.invest;
    }
  }

  String toDbString() {
    switch (this) {
      case CashFlowType.invest:
        return 'INVEST';
      case CashFlowType.returnFlow:
        return 'RETURN';
      case CashFlowType.income:
        return 'INCOME';
      case CashFlowType.fee:
        return 'FEE';
    }
  }
}

/// Cash Flow Entity - tracks money in and out
class CashFlowEntity implements ICashFlow {
  final String id;
  @override
  final String investmentId;
  @override
  final DateTime date;
  final CashFlowType type;
  @override
  final double amount; // Always positive, direction determined by type
  final String? notes;
  final DateTime createdAt;

  /// Currency of this cash flow
  /// Each cash flow can have its own currency (not inherited from investment)
  @override
  final String currency;

  /// True when [currency] was not stored on the record but filled in from the
  /// user's base currency when it was read (records saved before
  /// multi-currency support, until the user confirms their currency). Screens
  /// show [currency] either way; a backup leaves the currency out of such a
  /// record, so a restore does not turn the guess into a stored value.
  final bool currencyAssumed;

  /// Optional weight bought or sold with this cash flow (for example grams of
  /// gold), kept with [quantityUnit]. Both are set or both are null. The
  /// amount is still the money paid, since making charges and tax mean it is
  /// not weight times price.
  final double? quantity;
  final QuantityUnit? quantityUnit;

  const CashFlowEntity({
    required this.id,
    required this.investmentId,
    required this.date,
    required this.type,
    required this.amount,
    this.notes,
    required this.createdAt,
    required this.currency,
    this.currencyAssumed = false,
    this.quantity,
    this.quantityUnit,
  }) : assert(
         (quantity == null) == (quantityUnit == null),
         'quantity and quantityUnit are set together',
       );

  /// The weight in grams, or null when this flow has none.
  double? get grams {
    final q = quantity;
    final u = quantityUnit;
    return (q == null || u == null) ? null : q * u.gramsPerUnit;
  }

  @override
  CalculationCashFlowType get calculationType {
    switch (type) {
      case CashFlowType.invest:
        return CalculationCashFlowType.invest;
      case CashFlowType.returnFlow:
        return CalculationCashFlowType.returnFlow;
      case CashFlowType.income:
        return CalculationCashFlowType.income;
      case CashFlowType.fee:
        return CalculationCashFlowType.fee;
    }
  }

  /// Returns the signed amount for calculations
  /// Outflows (INVEST, FEE) are negative, Inflows (RETURN, INCOME) are positive
  @override
  double get signedAmount => type.isOutflow ? -amount : amount;

  CashFlowEntity copyWith({
    String? id,
    String? investmentId,
    DateTime? date,
    CashFlowType? type,
    double? amount,
    String? notes,
    DateTime? createdAt,
    String? currency,
    bool? currencyAssumed,
    double? quantity,
    QuantityUnit? quantityUnit,
    bool clearWeight = false,
  }) {
    return CashFlowEntity(
      id: id ?? this.id,
      investmentId: investmentId ?? this.investmentId,
      date: date ?? this.date,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      currency: currency ?? this.currency,
      // Choosing a currency makes it a stored one.
      currencyAssumed:
          currencyAssumed ?? (currency == null && this.currencyAssumed),
      // The weight is a pair: change both, keep both, or [clearWeight].
      quantity: clearWeight ? null : quantity ?? this.quantity,
      quantityUnit: clearWeight ? null : quantityUnit ?? this.quantityUnit,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CashFlowEntity &&
        other.id == id &&
        other.investmentId == investmentId &&
        other.date == date &&
        other.type == type &&
        other.amount == amount &&
        other.notes == notes &&
        other.createdAt == createdAt &&
        other.currency == currency &&
        other.currencyAssumed == currencyAssumed &&
        other.quantity == quantity &&
        other.quantityUnit == quantityUnit;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        investmentId.hashCode ^
        date.hashCode ^
        type.hashCode ^
        amount.hashCode ^
        notes.hashCode ^
        createdAt.hashCode ^
        currency.hashCode ^
        currencyAssumed.hashCode ^
        quantity.hashCode ^
        quantityUnit.hashCode;
  }
}

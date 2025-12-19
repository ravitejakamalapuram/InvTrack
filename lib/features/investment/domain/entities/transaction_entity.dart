import 'package:flutter/material.dart';

/// Cash Flow Type - direction of money
enum CashFlowType {
  invest,  // Cash going out (negative for XIRR)
  returnFlow,  // Cash coming back from exit/sale (positive for XIRR)
  income,  // Dividends, interest, rent (positive for XIRR)
  fee;     // Fees, expenses (negative for XIRR)

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

  /// Returns the color associated with this cash flow type
  Color get color {
    switch (this) {
      case CashFlowType.invest:
        return const Color(0xFF3B82F6); // Blue
      case CashFlowType.returnFlow:
        return const Color(0xFF10B981); // Emerald
      case CashFlowType.income:
        return const Color(0xFFF59E0B); // Amber
      case CashFlowType.fee:
        return const Color(0xFFEC4899); // Pink
    }
  }

  /// Returns the icon data for this cash flow type
  IconData get iconData {
    switch (this) {
      case CashFlowType.invest:
        return Icons.arrow_upward_rounded;
      case CashFlowType.returnFlow:
        return Icons.arrow_downward_rounded;
      case CashFlowType.income:
        return Icons.payments_rounded;
      case CashFlowType.fee:
        return Icons.receipt_long_rounded;
    }
  }

  /// Returns true if this is a cash outflow (money leaving)
  bool get isOutflow => this == CashFlowType.invest || this == CashFlowType.fee;

  /// Returns true if this is a cash inflow (money coming back)
  bool get isInflow => this == CashFlowType.returnFlow || this == CashFlowType.income;

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
class CashFlowEntity {
  final String id;
  final String investmentId;
  final DateTime date;
  final CashFlowType type;
  final double amount; // Always positive, direction determined by type
  final String? notes;
  final DateTime createdAt;

  const CashFlowEntity({
    required this.id,
    required this.investmentId,
    required this.date,
    required this.type,
    required this.amount,
    this.notes,
    required this.createdAt,
  });

  /// Returns the signed amount for calculations
  /// Outflows (INVEST, FEE) are negative, Inflows (RETURN, INCOME) are positive
  double get signedAmount => type.isOutflow ? -amount : amount;

  CashFlowEntity copyWith({
    String? id,
    String? investmentId,
    DateTime? date,
    CashFlowType? type,
    double? amount,
    String? notes,
    DateTime? createdAt,
  }) {
    return CashFlowEntity(
      id: id ?? this.id,
      investmentId: investmentId ?? this.investmentId,
      date: date ?? this.date,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
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
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        investmentId.hashCode ^
        date.hashCode ^
        type.hashCode ^
        amount.hashCode ^
        notes.hashCode ^
        createdAt.hashCode;
  }
}

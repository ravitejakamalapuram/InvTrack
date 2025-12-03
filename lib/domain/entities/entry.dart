/// Represents a ledger entry (transaction) for an investment.
/// 
/// Each entry records a buy, sell, dividend, or other transaction
/// for a specific investment.
class Entry {
  final String id;
  final String investmentId;
  final EntryType type;
  final double amount;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Entry({
    required this.id,
    required this.investmentId,
    required this.type,
    required this.amount,
    required this.date,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Entry copyWith({
    String? id,
    String? investmentId,
    EntryType? type,
    double? amount,
    DateTime? date,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Entry(
      id: id ?? this.id,
      investmentId: investmentId ?? this.investmentId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Returns true if this is an inflow (money going into investment).
  bool get isInflow => type == EntryType.buy || type == EntryType.dividend;

  /// Returns true if this is an outflow (money coming out of investment).
  bool get isOutflow => type == EntryType.sell || type == EntryType.withdrawal;

  /// Returns the signed amount (negative for outflows).
  double get signedAmount => isOutflow ? -amount : amount;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Entry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Entry(id: $id, type: ${type.name}, amount: $amount, date: $date)';
  }
}

/// Types of ledger entries.
enum EntryType {
  buy('Buy'),
  sell('Sell'),
  dividend('Dividend'),
  withdrawal('Withdrawal'),
  bonus('Bonus'),
  split('Split');

  final String displayName;
  const EntryType(this.displayName);
}


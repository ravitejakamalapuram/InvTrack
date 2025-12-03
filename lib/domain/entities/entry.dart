/// Represents a ledger entry (transaction) for an investment.
///
/// Each entry records a buy, sell, dividend, or other transaction
/// for a specific investment.
class Entry {
  final String id;
  final String investmentId;
  final EntryType type;
  final double amount;
  final double? units;
  final double? pricePerUnit;
  final DateTime date;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  const Entry({
    required this.id,
    required this.investmentId,
    required this.type,
    required this.amount,
    this.units,
    this.pricePerUnit,
    required this.date,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  Entry copyWith({
    String? id,
    String? investmentId,
    EntryType? type,
    double? amount,
    double? units,
    double? pricePerUnit,
    DateTime? date,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return Entry(
      id: id ?? this.id,
      investmentId: investmentId ?? this.investmentId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      units: units ?? this.units,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  /// Returns true if this is an inflow (money going into investment).
  bool get isInflow => type == EntryType.inflow || type == EntryType.dividend;

  /// Returns true if this is an outflow (money coming out of investment).
  bool get isOutflow => type == EntryType.outflow || type == EntryType.expense;

  /// Returns the signed amount (negative for inflows, positive for outflows).
  /// Inflows are negative because they represent money spent (invested).
  /// Outflows are positive because they represent money received.
  double get signedAmount => isInflow ? -amount : amount;

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

/// Types of ledger entries matching database schema.
enum EntryType {
  inflow('Inflow'),
  outflow('Outflow'),
  dividend('Dividend'),
  expense('Expense'),
  valuation('Valuation');

  final String displayName;
  const EntryType(this.displayName);

  /// Parse entry type from string.
  static EntryType fromString(String value) {
    return EntryType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => EntryType.inflow,
    );
  }
}


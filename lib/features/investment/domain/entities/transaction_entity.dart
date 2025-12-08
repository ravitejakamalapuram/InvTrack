class TransactionEntity {
  final String id;
  final String investmentId;
  final DateTime date;
  final String type;
  final double quantity;
  final double pricePerUnit;
  final double fees;
  final double totalAmount;
  final String? notes;
  final DateTime createdAt;

  const TransactionEntity({
    required this.id,
    required this.investmentId,
    required this.date,
    required this.type,
    required this.quantity,
    required this.pricePerUnit,
    required this.fees,
    required this.totalAmount,
    this.notes,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TransactionEntity &&
        other.id == id &&
        other.investmentId == investmentId &&
        other.date == date &&
        other.type == type &&
        other.quantity == quantity &&
        other.pricePerUnit == pricePerUnit &&
        other.fees == fees &&
        other.totalAmount == totalAmount &&
        other.notes == notes &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        investmentId.hashCode ^
        date.hashCode ^
        type.hashCode ^
        quantity.hashCode ^
        pricePerUnit.hashCode ^
        fees.hashCode ^
        totalAmount.hashCode ^
        notes.hashCode ^
        createdAt.hashCode;
  }
}

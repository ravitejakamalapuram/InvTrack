class InvestmentEntity {
  final String id;
  final String portfolioId;
  final String name;
  final String? symbol;
  final String type;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InvestmentEntity({
    required this.id,
    required this.portfolioId,
    required this.name,
    this.symbol,
    required this.type,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is InvestmentEntity &&
        other.id == id &&
        other.portfolioId == portfolioId &&
        other.name == name &&
        other.symbol == symbol &&
        other.type == type &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        portfolioId.hashCode ^
        name.hashCode ^
        symbol.hashCode ^
        type.hashCode ^
        isActive.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}

class PortfolioEntity {
  final String id;
  final String name;
  final String currency;
  final DateTime createdAt;

  const PortfolioEntity({
    required this.id,
    required this.name,
    required this.currency,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PortfolioEntity &&
        other.id == id &&
        other.name == name &&
        other.currency == currency &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ currency.hashCode ^ createdAt.hashCode;
  }
}

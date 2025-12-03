/// Represents an investment entity in the domain layer.
/// 
/// This is a pure domain object with no dependencies on
/// external frameworks or data sources.
class Investment {
  final String id;
  final String name;
  final String type;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Investment({
    required this.id,
    required this.name,
    required this.type,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Investment copyWith({
    String? id,
    String? name,
    String? type,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Investment(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Investment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Investment(id: $id, name: $name, type: $type)';
  }
}

/// Investment types supported by the app.
enum InvestmentType {
  mutualFund('Mutual Fund'),
  stock('Stock'),
  fixedDeposit('Fixed Deposit'),
  gold('Gold'),
  realEstate('Real Estate'),
  crypto('Cryptocurrency'),
  bond('Bond'),
  ppf('PPF'),
  nps('NPS'),
  other('Other');

  final String displayName;
  const InvestmentType(this.displayName);
}


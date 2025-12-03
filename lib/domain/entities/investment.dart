/// Represents an investment entity in the domain layer.
///
/// This is a pure domain object with no dependencies on
/// external frameworks or data sources.
class Investment {
  final String id;
  final String name;
  final String category;
  final DateTime startDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;

  const Investment({
    required this.id,
    required this.name,
    required this.category,
    required this.startDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
  });

  Investment copyWith({
    String? id,
    String? name,
    String? category,
    DateTime? startDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? isDeleted,
  }) {
    return Investment(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
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
    return 'Investment(id: $id, name: $name, category: $category)';
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


/// The metal of a precious-metals investment (#946). Stored by [name] on an
/// investment of type [InvestmentType.gold]; an investment saved before the
/// choice has none and reads as gold where a metal is needed.
enum Metal {
  gold,
  silver;

  /// English name, like the other enums' display names. Screens use the
  /// localised name (`metalName`).
  String get displayName => switch (this) {
    Metal.gold => 'Gold',
    Metal.silver => 'Silver',
  };

  /// The metal stored as [value], or null for anything else.
  static Metal? tryParse(Object? value) {
    for (final metal in values) {
      if (metal.name == value) return metal;
    }
    return null;
  }
}

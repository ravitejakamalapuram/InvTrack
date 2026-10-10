import 'package:inv_tracker/core/utils/custom_type_label.dart';

/// A reusable, account-scoped label for investments of the built-in type
/// Other (#936).
///
/// It only names a group of investments. It never selects calculation,
/// payout, tax, maturity or valuation rules, and renaming or removing it
/// never touches an investment, which keeps its own copy of the label.
class CustomInvestmentType {
  const CustomInvestmentType({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.updatedAt,
    this.removedAt,
  });

  /// Stable for the life of the definition; investments refer to it.
  final String id;

  /// Cleaned display text, with the casing it was first saved with (see
  /// [CustomTypeLabel.clean]).
  final String label;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// When the user removed it from their suggestions; null while active. A
  /// removed definition stays stored so investments can keep referring to it
  /// and saving the same label again revives it.
  final DateTime? removedAt;

  bool get isRemoved => removedAt != null;

  /// Lower-cased [label]: two definitions with the same key are one type. The
  /// label is cleaned again, so a document written by another build still
  /// compares the same way.
  String get key => CustomTypeLabel.keyOf(CustomTypeLabel.clean(label));

  /// [removedAt] can be cleared (revive) only with [clearRemoved], because a
  /// null argument means "keep".
  CustomInvestmentType copyWith({
    String? label,
    DateTime? updatedAt,
    DateTime? removedAt,
    bool clearRemoved = false,
  }) {
    return CustomInvestmentType(
      id: id,
      label: label ?? this.label,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      removedAt: clearRemoved ? null : (removedAt ?? this.removedAt),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomInvestmentType &&
        other.id == id &&
        other.label == label &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.removedAt == removedAt;
  }

  @override
  int get hashCode => Object.hash(id, label, createdAt, updatedAt, removedAt);
}

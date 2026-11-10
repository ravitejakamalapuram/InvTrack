import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';

/// What a dated valuation says it measures. Only [carryingValue] and
/// [principalOutstanding] are carried forward by principal that moves after
/// their date; a [marketValue] needs a new price, which cash flows cannot
/// establish.
enum ValuationKind {
  marketValue,
  carryingValue,
  principalOutstanding;

  /// Whether INVEST and RETURN dated after the valuation move it.
  bool get rollsForward => this != ValuationKind.marketValue;

  /// The kind stored under [name], or null when it is unknown. An unknown
  /// kind is never reinterpreted as another one.
  static ValuationKind? tryParse(Object? value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    return null;
  }
}

/// How a valuation was captured. Not the same as `ValuationSource`, which
/// says where a calculated current value came from: every provenance except
/// [estimate] maps to `ValuationSource.manual`, and a computed estimate has
/// no stored provenance at all.
enum ValuationProvenance {
  manual,

  /// The value when tracking started, standing in for history the user
  /// cannot enter. Lifetime XIRR, MOIC and return stay unknown while it is
  /// live. At most one per investment.
  openingBaseline,

  /// Restored from an export file. Stored as `import`.
  imported,

  /// Reserved for computed values (#946). Never written.
  estimate;

  /// The string stored in Firestore and in exports.
  String get storageName => this == imported ? 'import' : name;

  static ValuationProvenance? tryParse(Object? value) {
    for (final provenance in values) {
      if (provenance.storageName == value) return provenance;
    }
    return null;
  }
}

/// A dated valuation of one investment, kept apart from its cash flows: it is
/// never an actual cash flow and never counts as money received. Snapshots
/// are history; the latest applicable one is used and they are never summed.
class InvestmentValuationSnapshot {
  final String id;
  final String investmentId;

  /// In [currency], at the precision of that currency.
  final double amount;

  /// Required and never defaulted (money rule 1): a snapshot with no
  /// currency is not a snapshot.
  final String currency;

  /// Date-only, the day the value applies to.
  final DateTime effectiveDate;

  /// How [amount] was reached when it is quantity × price (#946); null for
  /// an amount typed in. When set, [amount] equals `holding.value(currency)`;
  /// [copyWith] keeps the two in step.
  final UnitHolding? holding;
  final ValuationKind kind;
  final ValuationProvenance provenance;

  /// Client time of creation; never changes.
  final DateTime createdAt;

  /// Server time of the last write. Null while that write has not reached
  /// the server, which counts as the newest write.
  final DateTime? updatedAt;

  /// Set when cleared. A cleared snapshot is kept so that a clear and an
  /// edit from two devices converge, and so that Undo can restore it.
  final DateTime? deletedAt;

  const InvestmentValuationSnapshot({
    required this.id,
    required this.investmentId,
    required this.amount,
    required this.currency,
    required this.effectiveDate,
    required this.kind,
    required this.provenance,
    required this.createdAt,
    this.holding,
    this.updatedAt,
    this.deletedAt,
  });

  bool get isLive => deletedAt == null;

  bool get isOpeningBaseline =>
      provenance == ValuationProvenance.openingBaseline;

  /// A copy with the given fields replaced. [clearDeletedAt] restores a
  /// cleared snapshot, which a null [deletedAt] cannot express. [clearUpdatedAt]
  /// makes it a write still on its way (a null update time), which a null
  /// [updatedAt] cannot express.
  InvestmentValuationSnapshot copyWith({
    double? amount,
    UnitHolding? holding,
    DateTime? effectiveDate,
    ValuationKind? kind,
    ValuationProvenance? provenance,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    bool clearUpdatedAt = false,
  }) => InvestmentValuationSnapshot(
    id: id,
    investmentId: investmentId,
    // A new holding sets the amount; a new amount alone drops the old
    // holding, so the two can never disagree.
    amount: holding != null ? holding.value(currency) : amount ?? this.amount,
    holding: holding ?? (amount != null ? null : this.holding),
    currency: currency,
    effectiveDate: effectiveDate ?? this.effectiveDate,
    kind: kind ?? this.kind,
    provenance: provenance ?? this.provenance,
    createdAt: createdAt,
    updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvestmentValuationSnapshot &&
          other.id == id &&
          other.investmentId == investmentId &&
          other.amount == amount &&
          other.currency == currency &&
          other.effectiveDate == effectiveDate &&
          other.holding == holding &&
          other.kind == kind &&
          other.provenance == provenance &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
    id,
    investmentId,
    amount,
    currency,
    effectiveDate,
    holding,
    kind,
    provenance,
    createdAt,
    updatedAt,
    deletedAt,
  );
}

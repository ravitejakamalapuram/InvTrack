/// Today's gold and silver rates, as the daily job stores them in
/// `metalRates/latest`. Two independent sides, so one source failing leaves
/// the other's last good value in place:
/// - `inr`: the India selling rate in rupees per gram (what a seller gets).
/// - `usd`: the international rate in US dollars per gram.
/// Anything missing or of the wrong type reads as null, never as 0.
class MetalRates {
  const MetalRates({
    this.goldInrSellPerGram,
    this.silverInrSellPerGram,
    this.inrUpdatedAt,
    this.goldUsdPerGram,
    this.silverUsdPerGram,
    this.usdUpdatedAt,
  });

  final double? goldInrSellPerGram;
  final double? silverInrSellPerGram;
  final DateTime? inrUpdatedAt;
  final double? goldUsdPerGram;
  final double? silverUsdPerGram;
  final DateTime? usdUpdatedAt;

  /// Reads the stored document. Timestamps may be a [DateTime] or anything
  /// with a `toDate()` (Firestore's Timestamp). Never throws on bad data.
  static MetalRates? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final inr = _side(data['inr']);
    final usd = _side(data['usd']);
    return MetalRates(
      goldInrSellPerGram: _number(inr?['gold']),
      silverInrSellPerGram: _number(inr?['silver']),
      inrUpdatedAt: _time(inr?['updatedAt']),
      goldUsdPerGram: _number(usd?['gold']),
      silverUsdPerGram: _number(usd?['silver']),
      usdUpdatedAt: _time(usd?['updatedAt']),
    );
  }

  static Map<String, dynamic>? _side(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  static double? _number(Object? v) => v is num ? v.toDouble() : null;

  static DateTime? _time(Object? v) {
    if (v is DateTime) return v;
    if (v == null || v is String || v is num) return null;
    try {
      final date = (v as dynamic).toDate();
      return date is DateTime ? date : null;
    } catch (_) {
      return null;
    }
  }
}

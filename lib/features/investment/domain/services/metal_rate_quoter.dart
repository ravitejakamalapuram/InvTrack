import 'package:inv_tracker/features/investment/domain/entities/metal.dart';
import 'package:inv_tracker/features/investment/domain/entities/metal_rates.dart';

/// Where a quoted price comes from, so the screen can label it honestly.
enum MetalRateKind {
  /// India selling rate in rupees: what a seller receives, close to retail
  /// rates quoted in India.
  indiaSelling,

  /// The international rate, converted. About 15% below Indian shop prices.
  international,
}

/// A price per gram in the investment's own currency.
class MetalRateQuote {
  const MetalRateQuote({
    required this.pricePerGram,
    required this.kind,
    required this.asOf,
  });

  final double pricePerGram;
  final MetalRateKind kind;
  final DateTime asOf;
}

/// Picks today's price per gram for an investment's currency (pure, no I/O).
/// Rupee investments use the India selling rate; every other currency, and
/// rupees without a fresh India rate, use the international rate times the
/// dollar conversion. Never a dollar price under another currency's symbol.
class MetalRateQuoter {
  const MetalRateQuoter._();

  /// A rate older than this is not shown.
  static const maxAge = Duration(days: 3);

  /// Null when there is no fresh, valid price for [currency]. [usdToCurrency]
  /// is dollars to [currency]; it may be omitted for USD itself.
  static MetalRateQuote? quote({
    required MetalRates rates,
    required Metal metal,
    required String currency,
    required DateTime now,
    double? usdToCurrency,
  }) {
    final code = currency.trim().toUpperCase();
    if (code.isEmpty) return null;

    if (code == 'INR') {
      final inr = metal == Metal.gold
          ? rates.goldInrSellPerGram
          : rates.silverInrSellPerGram;
      if (_usable(inr) && _fresh(rates.inrUpdatedAt, now)) {
        return MetalRateQuote(
          pricePerGram: _round(inr!),
          kind: MetalRateKind.indiaSelling,
          asOf: rates.inrUpdatedAt!,
        );
      }
    }

    final usd = metal == Metal.gold
        ? rates.goldUsdPerGram
        : rates.silverUsdPerGram;
    if (!_usable(usd) || !_fresh(rates.usdUpdatedAt, now)) return null;
    final factor = code == 'USD' ? 1.0 : usdToCurrency;
    if (!_usable(factor)) return null;
    final price = _round(usd! * factor!);
    if (!_usable(price)) return null;
    return MetalRateQuote(
      pricePerGram: price,
      kind: MetalRateKind.international,
      asOf: rates.usdUpdatedAt!,
    );
  }

  static bool _usable(double? v) => v != null && v.isFinite && v > 0;

  /// Whether a rate dated [at] can still be shown at [now]: not older than
  /// [maxAge], and not dated in the future (a few minutes of clock drift are
  /// allowed).
  static bool isFresh(DateTime at, DateTime now) => _fresh(at, now);

  static bool _fresh(DateTime? at, DateTime now) =>
      at != null &&
      now.difference(at) <= maxAge &&
      !at.isAfter(now.add(const Duration(minutes: 5)));

  /// Four places: enough for a per-gram price of any currency, and the value
  /// is rounded once, at the end, to the currency's own precision.
  static double _round(double v) => (v * 10000).roundToDouble() / 10000;
}

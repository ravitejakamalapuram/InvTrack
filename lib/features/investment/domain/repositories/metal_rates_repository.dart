import 'package:inv_tracker/features/investment/domain/entities/metal_rates.dart';

/// Today's stored gold and silver rates (one public document, written once a
/// day by the rates job). Not user data.
abstract class MetalRatesRepository {
  /// The stored rates, or null when there are none or they cannot be read.
  Future<MetalRates?> latest();
}
